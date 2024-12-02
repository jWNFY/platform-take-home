#!/bin/bash
set -e  # Exit on any error

CLUSTER_NAME=${1:-"platform-dev-local"}  # Use provided name or default to platform-dev-local

# Function to check Docker status
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        echo "Error: Docker is not running or not accessible"
        exit 1
    fi
}

# Function to check ports
check_ports() {
    echo "Checking if required ports are available..."
    local ports=(6443 8081 9009)
    for port in "${ports[@]}"; do
        if lsof -i ":$port" > /dev/null 2>&1; then
            echo "Error: Port $port is already in use"
            lsof -i ":$port"
            exit 1
        fi
    done
    echo "All required ports are available"
}

# Function to clean up existing resources
cleanup() {
    echo "Cleaning up existing resources..."
    # Stop existing services
    docker compose -f ci/docker-compose.yml down -v || true
    # Delete k3d cluster
    k3d cluster delete ${CLUSTER_NAME} || true
    # Clean up any leftover networks
    docker network prune -f || true
    # Remove existing kubeconfig
    rm -f ~/.kube/config || true
}

# Function to create and configure cluster
create_cluster() {
    echo "Creating k3d cluster..."
    k3d cluster create ${CLUSTER_NAME} \
        --servers 1 \
        --agents 2 \
        --no-lb \
        --k3s-arg "--disable=traefik@server:0" \
        --network "devcontainer-generic_app-network" \
        --image rancher/k3s:v1.27.4-k3s1 \
        --wait \
        --timeout 120s

    # Wait for the cluster to be ready
    echo "Waiting for cluster to be ready..."
    sleep 20

    # Get the container IP address
    SERVER_IP=$(docker inspect k3d-${CLUSTER_NAME}-server-0 | jq -r '.[0].NetworkSettings.Networks."devcontainer-generic_app-network".IPAddress')
    if [ -z "$SERVER_IP" ]; then
        echo "Error: Could not get server IP"
        return 1
    fi
    echo "Server IP: $SERVER_IP"

    # Create kubeconfig
    echo "Setting up kubeconfig..."
    mkdir -p ~/.kube
    cat > ~/.kube/config <<EOF
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: $(docker exec k3d-${CLUSTER_NAME}-server-0 cat /var/lib/rancher/k3s/server/tls/server-ca.crt | base64 -w 0)
    server: https://${SERVER_IP}:6443
  name: ${CLUSTER_NAME}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    user: admin
  name: k3d-${CLUSTER_NAME}
current-context: k3d-${CLUSTER_NAME}
kind: Config
preferences: {}
users:
- name: admin
  user:
    client-certificate-data: $(docker exec k3d-${CLUSTER_NAME}-server-0 cat /var/lib/rancher/k3s/server/tls/client-admin.crt | base64 -w 0)
    client-key-data: $(docker exec k3d-${CLUSTER_NAME}-server-0 cat /var/lib/rancher/k3s/server/tls/client-admin.key | base64 -w 0)
EOF
    chmod 600 ~/.kube/config
}

# Function to verify cluster
verify_cluster() {
    echo "Verifying cluster setup..."
    local max_retries=30
    local retry_count=0
    
    while ! kubectl get nodes --request-timeout=5s &>/dev/null; do
        if [ $retry_count -ge $max_retries ]; then
            echo "Error: Failed to verify cluster after $max_retries attempts"
            return 1
        fi
        echo "Waiting for cluster to be ready... (attempt $((retry_count + 1))/$max_retries)"
        sleep 5
        ((retry_count++))
    done

    echo "Cluster is responding. Waiting for nodes to be ready..."
    kubectl wait --for=condition=ready nodes --all --timeout=120s || return 1

    echo "Verifying node status..."
    kubectl get nodes -o wide

    return 0
}

verify_network() {
    echo "Verifying network setup..."
    
    # Check if the network exists
    if ! docker network inspect devcontainer-generic_app-network >/dev/null 2>&1; then
        echo "Error: Required network 'devcontainer-generic_app-network' does not exist"
        return 1
    fi

    # Check if the k3d containers are running
    if ! docker ps | grep -q k3d-${CLUSTER_NAME}-server-0; then
        echo "Error: K3d server container is not running"
        return 1
    fi

    # Get the server IP
    SERVER_IP=$(docker inspect k3d-${CLUSTER_NAME}-server-0 | jq -r '.[0].NetworkSettings.Networks."devcontainer-generic_app-network".IPAddress')
    if [ -z "$SERVER_IP" ]; then
        echo "Error: Could not get server IP"
        return 1
    fi

    # Try to connect to the API server
    echo "Checking API server connectivity at ${SERVER_IP}:6443..."
    if ! curl -k https://${SERVER_IP}:6443 -f -s -o /dev/null; then
        echo "Warning: Initial API server check failed, but this might be expected during startup"
        echo "Continuing with setup..."
    fi

    return 0
}

# Function to setup namespace and resources
setup_resources() {
    echo "Setting up Kubernetes resources..."
    
    # Create namespace
    kubectl create namespace platform --dry-run=client -o yaml | kubectl apply -f -
    
    # Create secrets
    kubectl create secret generic db-credentials \
        --from-literal=dsn="postgresql://postgres:postgres@db:5432/platform?sslmode=disable" \
        --namespace platform \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply base manifests
    kubectl apply -k ci/k8s/base -n platform
}

main() {
    echo "Starting local Kubernetes setup..."
    
    # Pre-flight checks
    check_docker
    check_ports
    
    # Clean up existing resources
    cleanup
    
    # Create and configure cluster
    create_cluster

    echo "Waiting for API server to be ready..."
    sleep 45  # Increased from 30 to 45
    
    # Verify network setup
    verify_network || exit 1
    
    # No need for second wait since we've already waited
    # Verify cluster
    verify_cluster || exit 1
    
    # Setup resources
    setup_resources
    
    echo "Local Kubernetes setup completed successfully!"
    echo "Cluster Info:"
    kubectl cluster-info
    echo "Node Status:"
    kubectl get nodes
    echo "Platform Namespace Resources:"
    kubectl get all -n platform
}

# Execute main function with error handling
if ! main "$@"; then
    echo "Error: Setup failed!"
    exit 1
fi