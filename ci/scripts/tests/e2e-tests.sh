#!/bin/bash
set -e

# Environment can be passed as an argument or default to "local"
ENVIRONMENT=${1:-"local"}
NAMESPACE=${2:-"platform"}
TEST_TYPE=${3:-"all"}  # Add test type parameter with default "all"

# Configuration based on environment
if [ "$ENVIRONMENT" = "local" ]; then
    # Local k3d configuration
    HOST="localhost"
    HTTP_PORT="8081"
    GRPC_PORT="9009"
    DB_HOST="db"
    CONTEXT="k3d-platform-dev-local"
elif [ "$ENVIRONMENT" = "preview" ]; then
    # Preview/staging configuration
    HOST=$(kubectl get ingress -n ${NAMESPACE} -o jsonpath='{.items[0].spec.rules[0].host}')
    HTTP_PORT="80"
    GRPC_PORT="9009"
    DB_HOST="db.${NAMESPACE}.svc.cluster.local"
    CONTEXT="platform-staging"
else
    echo "Unknown environment: $ENVIRONMENT"
    exit 1
fi

# Switch to the correct context
kubectl config use-context ${CONTEXT}

# Function to run a command with port-forwarding if needed
run_with_port_forward() {
    local service=$1
    local local_port=$2
    local remote_port=$3
    local command=$4

    if [ "$ENVIRONMENT" = "local" ]; then
        # Start port-forward
        kubectl port-forward -n ${NAMESPACE} svc/${service} ${local_port}:${remote_port} >/dev/null 2>&1 &
        PF_PID=$!
        sleep 3

        # Run command
        if ! eval "$command"; then
            kill $PF_PID
            return 1
        fi
        kill $PF_PID
    else
        # Run command directly
        eval "$command"
    fi
}

# Function to check service readiness
check_service_readiness() {
    echo "Checking service readiness..."
    echo "\nPod details:"
    kubectl get pods -n ${NAMESPACE} -l app=platform-app -o wide
    
    echo "\nPod logs:"
    kubectl logs -n ${NAMESPACE} deployment/platform-app --tail=50
    
    echo "\nService details:"
    kubectl get svc -n ${NAMESPACE} platform-app -o wide
    
    echo "\nEndpoints:"
    kubectl get endpoints -n ${NAMESPACE} platform-app -o wide
}

# Test HTTP endpoint
test_http() {
    echo "Testing HTTP endpoint..."
    echo "Checking service readiness before HTTP test..."
    check_service_readiness
    
    run_with_port_forward "platform-app" ${HTTP_PORT} 8080 \
        "curl -v http://${HOST}:${HTTP_PORT}/v1/items" || {
        echo "HTTP test failed. Checking logs..."
        kubectl logs -n ${NAMESPACE} deployment/platform-app
        return 1
    }
}

# Test gRPC endpoint
test_grpc() {
    echo "Testing gRPC endpoint..."
    echo "Checking service readiness before gRPC test..."
    check_service_readiness
    
    run_with_port_forward "platform-app" ${GRPC_PORT} 9008 \
        "grpcurl -plaintext -v ${HOST}:${GRPC_PORT} list && \
         grpcurl -plaintext -v ${HOST}:${GRPC_PORT} describe TakeHomeService && \
         grpcurl -plaintext ${HOST}:${GRPC_PORT} TakeHomeService/GetItems" || {
        echo "gRPC test failed. Checking logs..."
        kubectl logs -n ${NAMESPACE} deployment/platform-app
        return 1
    }
}
# Test item creation
test_create_item() {
    echo "Testing item creation..."
    run_with_port_forward "platform-app" ${GRPC_PORT} 9009 \
        "grpcurl -plaintext -d '{\"name\": \"test-item\", \"description\": \"test description\"}' \
         ${HOST}:${GRPC_PORT} TakeHomeService/CreateItem"
}

# Test getting specific item
test_get_item() {
    echo "Testing get specific item..."
    run_with_port_forward "platform-app" ${GRPC_PORT} 9009 \
        "grpcurl -plaintext -d '{\"id\": 1}' ${HOST}:${GRPC_PORT} TakeHomeService/GetItem"
}

# Test database connection
test_db() {
    echo "Testing database connection..."
    kubectl exec -n ${NAMESPACE} deployment/platform-app -- env PGPASSWORD=postgres \
        psql -h ${DB_HOST} -U postgres -d platform -c "\dt"
}

# Test application logs
test_logs() {
    echo "Checking application logs for errors..."
    if kubectl logs -n ${NAMESPACE} deployment/platform-app | grep -i "error"; then
        echo "Found errors in logs"
        return 1
    else
        echo "No errors found in logs"
    fi
}

# Test metrics endpoint
test_metrics() {
    echo "Testing metrics endpoint..."
    run_with_port_forward "platform-app" ${HTTP_PORT} 8081 \
        "curl -s http://${HOST}:${HTTP_PORT}/metrics"
}

# Test deployment health
test_health() {
    echo "Testing deployment health..."
    
    echo "Checking pod status..."
    if ! kubectl get pods -n ${NAMESPACE} | grep platform-app | grep Running; then
        echo "Platform app pod is not running"
        return 1
    fi
    
    echo "Checking deployment status..."
    if ! kubectl rollout status deployment/platform-app -n ${NAMESPACE}; then
        echo "Deployment is not healthy"
        return 1
    fi
    
    echo "Checking service endpoints..."
    if ! kubectl get endpoints platform-app -n ${NAMESPACE} | grep -v "none"; then
        echo "No endpoints available for service"
        return 1
    fi
}

# Add these functions to the script

# Test with timeout
test_with_timeout() {
    local timeout=$1
    local command=$2
    local message=$3
    
    echo "Running: $message"
    timeout ${timeout}s bash -c "${command}" || {
        echo "Test failed: ${message} (timeout after ${timeout}s)"
        return 1
    }
}

# Retry mechanism
retry() {
    local retries=$1
    local wait=$2
    local command=$3
    local message=$4
    
    echo "Testing: $message"
    for i in $(seq 1 ${retries}); do
        if eval "${command}"; then
            return 0
        fi
        echo "Attempt $i failed. Waiting ${wait}s before retry..."
        sleep ${wait}
    done
    echo "Test failed after ${retries} attempts: ${message}"
    return 1
}

# Add to the main test functions:
test_http() {
    echo "Testing HTTP endpoint..."
    retry 3 5 "run_with_port_forward 'platform-app' ${HTTP_PORT} 8081 \
        'curl -v http://${HOST}:${HTTP_PORT}/v1/items'" "HTTP endpoint test"
}

# Function to run a command with port-forwarding if needed
run_with_port_forward() {
    local service=$1
    local local_port=$2
    local remote_port=$3
    local command=$4

    if [ "$ENVIRONMENT" = "local" ]; then
        # Kill any existing port-forward on the same port
        lsof -ti:${local_port} | xargs -r kill -9

        # Start port-forward
        kubectl port-forward -n ${NAMESPACE} svc/${service} ${local_port}:${remote_port} >/dev/null 2>&1 &
        PF_PID=$!
        
        # Wait for port-forward to be ready
        for i in {1..10}; do
            if lsof -i:${local_port} >/dev/null 2>&1; then
                break
            fi
            sleep 1
        done

        # Run command
        if ! eval "$command"; then
            kill $PF_PID 2>/dev/null || true
            return 1
        fi
        kill $PF_PID 2>/dev/null || true
    else
        eval "$command"
    fi
}

check_db_init() {
    echo "Checking database initialization..."
    kubectl exec -n ${NAMESPACE} deployment/db -- env PGPASSWORD=postgres \
        psql -h localhost -U postgres -d platform -c "\dt" || {
        echo "Database not initialized. Initializing..."
        kubectl exec -n ${NAMESPACE} deployment/platform-app -- /app/init-db || return 1
    }
}

# Run all tests
run_all_tests() {
    test_health || exit 1
    test_http || exit 1
    test_grpc || exit 1
    test_create_item || exit 1
    test_get_item || exit 1
    test_db || exit 1
    test_logs || exit 1
    test_metrics || exit 1
    echo "All tests passed!"
}

# Main execution
case "${TEST_TYPE}" in
    "health")
        test_health
        ;;
    "http")
        test_http
        ;;
    "grpc")
        test_grpc
        ;;
    "db")
        test_db
        ;;
    "all")
        run_all_tests
        ;;
    *)
        echo "Unknown test type: $TEST_TYPE"
        echo "Available test types: health, http, grpc, db, all"
        exit 1
        ;;
esac