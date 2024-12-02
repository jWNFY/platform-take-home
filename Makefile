.PHONY: build test proto docker-up docker-down format lint ps logs logs-app logs-db inspect clean dev-setup test-http test-grpc test-endpoints test-devcontainer test-dev-env devcontainer-up devcontainer-down devcontainer-logs check-devcontainer test-devcontainer-generic devcontainer-test-full k8s-local-prereq k8s-local-setup k8s-local-delete k8s-local-switch k8s-local-status k8s-local-prereq

###################
# Basic Commands ##
###################

# Build the application
build:
	go build -o bin/server ./cmd/server

# Run tests
test:
	go test -v ./...

# Clean build artifacts
clean:
	rm -rf bin/

######################
# Code Management ####
######################

# Generate proto files
proto:
	./scripts/proto-gen.sh

# Format code
format:
	go fmt ./...
	buf format -w

# Lint code
lint:
	go vet ./...
	(cd proto && buf dep update && buf lint && cd ..)

########################
# Docker Environment ####
########################

# Start docker environment
docker-up: create-network
	docker compose -f ci/docker-compose.yml up --build -d

# Stop docker environment
docker-down:
	docker compose -f ci/docker-compose.yml down -v

# Show running containers
ps:
	docker compose -f ci/docker-compose.yml ps

create-network:
	docker network create app-network || true

################
# Logging ######
################

# Show logs of all services
logs:
	docker compose -f ci/docker-compose.yml logs -f

# Show logs of app service
logs-app:
	docker compose -f ci/docker-compose.yml logs -f app

# Show logs of database service
logs-db:
	docker compose -f ci/docker-compose.yml logs -f db

# Inspect containers
inspect:
	docker compose -f ci/docker-compose.yml ps -q | xargs -I {} docker inspect {}

#########################
# Development Setup #####
#########################

# Local development setup
dev-setup:
	# Install protoc-gen-go with specific version
	go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.35.2
	# Install protoc-gen-go-grpc with specific version
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.5.1
	# Install grpc-gateway with specific version
	go install github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway@v2.23.0
	# Install buf with specific version
	go install github.com/bufbuild/buf/cmd/buf@v1.47.2
	# Install protoc-gen-go-grpc-mock
	go install github.com/sorcererxw/protoc-gen-go-grpc-mock@latest
	# Install grpcurl
	go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
	# Generate proto files first
	make proto
	# Now run go mod tidy
	go mod tidy
	# Install pre-commit using pipx since it's already set up in the container
	pipx install pre-commit || true  # The || true prevents failure if already installed
	pre-commit install

# Install pre-commit hooks only
install-hooks:
	pipx install pre-commit || true  # The || true prevents failure if already installed
	pre-commit install

######################
# Testing Tools for simple docker-compose environment
######################

# Test HTTP endpoint
test-http:
	curl -v http://ci-app:8080/v1/items

# Test gRPC endpoint (requires grpcurl)
test-grpc:
	grpcurl -plaintext ci-app:9008 list
	grpcurl -plaintext ci-app:9008 TakeHomeService/GetItems

# Combined test endpoints
test-endpoints: test-http test-grpc

#############################
# Development Container #####
#############################

# Start devcontainer (generic)
devcontainer-up:
	docker compose -f .devcontainer-generic/docker-compose.yml up --build -d

# Stop devcontainer (generic)
devcontainer-down:
	docker compose -f .devcontainer-generic/docker-compose.yml down -v

# Show devcontainer logs
devcontainer-logs:
	docker compose -f .devcontainer-generic/docker-compose.yml logs -f

# Check devcontainer workspace
check-devcontainer:
	docker compose -f .devcontainer-generic/docker-compose.yml exec devcontainer ls -la /workspace

# Test devcontainer setup
test-devcontainer:
	@echo "Testing devcontainer setup..."
	@echo "\n1. Testing Go installation..."
	go version || exit 1
	@echo "\n2. Testing PostgreSQL client..."
	psql --version || exit 1
	@echo "\n3. Testing required tools..."
	protoc --version || exit 1
	buf --version || exit 1
	grpcurl --version || exit 1
	pre-commit --version || exit 1
	@echo "\n4. Testing database connection..."
	pg_isready -h db -U postgres || exit 1
	@echo "\n5. Testing Go tools..."
	@echo "Checking protoc-gen-go..."
	which protoc-gen-go || exit 1
	@echo "Checking protoc-gen-go-grpc..."
	which protoc-gen-go-grpc || exit 1
	@echo "Checking protoc-gen-grpc-gateway..."
	which protoc-gen-grpc-gateway || exit 1
	@echo "\n6. Testing pre-commit hooks..."
	pre-commit run --all-files || exit 1
	@echo "\nAll tests completed!"

# Test full development environment
test-dev-env: test-devcontainer docker-up test-endpoints
	@echo "Development environment test complete!"

# Test devcontainer (generic)
test-devcontainer-generic: devcontainer-up
	docker compose -f .devcontainer-generic/docker-compose.yml exec devcontainer ls -la /workspace
	docker compose -f .devcontainer-generic/docker-compose.yml exec -w /workspace devcontainer make dev-setup
	docker compose -f .devcontainer-generic/docker-compose.yml exec -w /workspace devcontainer make test-devcontainer
	docker compose -f .devcontainer-generic/docker-compose.yml exec -w /workspace devcontainer make test-dev-env

# Full devcontainer test (down and up)
devcontainer-test-full: devcontainer-down test-devcontainer-generic
	@echo "Full devcontainer test completed!"


#########################
# Local K8s Deployment ##
#########################

# Variables for local deployment
IMAGE_NAME := platform-app
IMAGE_TAG := latest
K8S_LOCAL_CLUSTER := platform-dev-local

k8s-local-prereq:
	curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
	k3d version

k8s-local-setup: k8s-local-prereq
	./ci/scripts/local/setup-local-k8s.sh

k8s-local-switch:
	kubectl config use-context k3d-$(K8S_LOCAL_CLUSTER)

# Build and load Docker image into k3d
k8s-local-build:
	@echo "Building Docker image..."
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) -f ci/Dockerfile .
	@echo "Importing image into k3d cluster..."
	k3d image import $(IMAGE_NAME):$(IMAGE_TAG) -c $(K8S_LOCAL_CLUSTER)

# Deploy application to local k3d cluster
k8s-local-deploy: k8s-local-build
	@echo "Deploying application to local cluster..."
	kubectl create namespace platform --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -k ci/k8s/base -n platform
	@echo "Waiting for database to be ready..."
	kubectl wait --for=condition=available --timeout=60s deployment/db -n platform
	@echo "Waiting for application to be ready..."
	kubectl wait --for=condition=available --timeout=60s deployment/platform-app -n platform

# Delete application from local cluster
k8s-local-delete:
	@echo "Deleting application from local cluster..."
	kubectl delete -k ci/k8s/base -n platform || true
	kubectl delete namespace platform || true

# Get application status
k8s-local-status:
	@echo "Checking application status..."
	@echo "\nPods:"
	kubectl get pods -n platform
	@echo "\nServices:"
	kubectl get svc -n platform
	@echo "\nDeployments:"
	kubectl get deployments -n platform

# Get application logs
k8s-local-logs:
	@echo "Application logs:"
	kubectl logs -f deployment/platform-app -n platform

# Port forward to access the application locally
k8s-local-port-forward:
	@echo "Port forwarding application services..."
	kubectl port-forward -n platform svc/platform-app 8081:8081 9009:9009

# Restart the application deployment
k8s-local-restart:
	@echo "Restarting application deployment..."
	kubectl rollout restart deployment/platform-app -n platform

# Redeploy everything
k8s-local-redeploy: k8s-local-delete k8s-local-deploy
	@echo "Waiting for services to be ready..."
	sleep 10
	make k8s-test-local

# One-command setup and deploy
k8s-local-full-setup: k8s-local-setup k8s-local-deploy k8s-local-status

#####################################
# Kubernetes Staging Environments ##
#####################################

K8S_STAGING_CLUSTER := platform-staging
K8S_NAMESPACE := $(shell git rev-parse --abbrev-ref HEAD | tr '[:upper:]' '[:lower:]' | sed 's/[^-a-z0-9]/-/g' | cut -c1-63)

k8s-staging-switch:
	kubectl config use-context $(K8S_STAGING_CLUSTER)

k8s-env-setup: k8s-staging-switch
	@echo "Setting up environment for branch: $(K8S_NAMESPACE)"
	./ci/scripts/preview_envs/k8s-env-setup.sh $(K8S_NAMESPACE)

k8s-env-deploy: k8s-staging-switch
	@echo "Deploying to environment: $(K8S_NAMESPACE)"
	./ci/scripts/preview_envs/k8s-env-deploy.sh $(K8S_NAMESPACE)

k8s-env-url: k8s-staging-switch
	@echo "URL for environment $(K8S_NAMESPACE):"
	@kubectl get ingress -n $(K8S_NAMESPACE) -o jsonpath='{.items[0].spec.rules[0].host}'

k8s-env-logs: k8s-staging-switch
	kubectl logs -f deployment/app -n $(K8S_NAMESPACE)

k8s-env-clean: k8s-staging-switch
	@echo "Cleaning up environment: $(K8S_NAMESPACE)"
	kubectl delete namespace $(K8S_NAMESPACE)

k8s-env-list: k8s-staging-switch
	@echo "Existing environments:"
	@kubectl get namespaces -l purpose=feature-testing --no-headers | awk '{print $$1}'

k8s-staging-status: k8s-staging-switch
	kubectl get nodes
	kubectl get pods --all-namespaces


######################
# Unified Testing ####
######################

# Variables for environment detection
CURRENT_CONTEXT := $(shell kubectl config current-context)
IS_LOCAL := $(findstring k3d,$(CURRENT_CONTEXT))
DEFAULT_ENV := $(if $(IS_LOCAL),local,preview)
DEFAULT_NAMESPACE := $(if $(IS_LOCAL),platform,$(shell git rev-parse --abbrev-ref HEAD | tr '[:upper:]' '[:lower:]' | sed 's/[^-a-z0-9]/-/g' | cut -c1-63))

# Environment variables with defaults
ENV ?= $(DEFAULT_ENV)
NAMESPACE ?= $(DEFAULT_NAMESPACE)
TEST_TYPE ?= all

# Test targets for both environments
test-env:
	./ci/scripts/tests/e2e-tests.sh $(ENV) $(NAMESPACE) $(TEST_TYPE)

test-env-health:
	./ci/scripts/tests/e2e-tests.sh $(ENV) $(NAMESPACE) health

test-env-http:
	./ci/scripts/tests/e2e-tests.sh $(ENV) $(NAMESPACE) http

test-env-grpc:
	./ci/scripts/tests/e2e-tests.sh $(ENV) $(NAMESPACE) grpc

test-env-db:
	./ci/scripts/tests/e2e-tests.sh $(ENV) $(NAMESPACE) db

# Local k3d cluster convenience targets
k8s-test-local: ENV=local
k8s-test-local: NAMESPACE=platform
k8s-test-local: TEST_TYPE=all
k8s-test-local: test-env

k8s-test-local-health: ENV=local
k8s-test-local-health: NAMESPACE=platform
k8s-test-local-health: test-env-health

# Preview environment convenience targets
k8s-test-preview: ENV=preview
k8s-test-preview: NAMESPACE=$(shell git rev-parse --abbrev-ref HEAD | tr '[:upper:]' '[:lower:]' | sed 's/[^-a-z0-9]/-/g' | cut -c1-63)
k8s-test-preview: TEST_TYPE=all
k8s-test-preview: test-env

k8s-test-preview-health: ENV=preview
k8s-test-preview-health: NAMESPACE=$(shell git rev-parse --abbrev-ref HEAD | tr '[:upper:]' '[:lower:]' | sed 's/[^-a-z0-9]/-/g' | cut -c1-63)
k8s-test-preview-health: test-env-health

# Integration test workflows
k8s-test-local-integration: k8s-local-deploy k8s-test-local
	@echo "Local integration tests completed!"

k8s-test-preview-integration: k8s-env-deploy k8s-test-preview
	@echo "Preview environment integration tests completed!"

# Auto-detect environment and run tests
k8s-test-auto:
	@echo "Detected environment: $(DEFAULT_ENV)"
	@echo "Detected namespace: $(DEFAULT_NAMESPACE)"
	@make test-env ENV=$(DEFAULT_ENV) NAMESPACE=$(DEFAULT_NAMESPACE)

# Test summary
k8s-test-summary:
	@echo "Test Summary for $(ENV) environment in namespace $(NAMESPACE)"
	@echo "Context: $(CURRENT_CONTEXT)"
	@echo "\nDeployment Status:"
	@kubectl get deployments -n $(NAMESPACE)
	@echo "\nPod Status:"
	@kubectl get pods -n $(NAMESPACE)
	@echo "\nService Status:"
	@kubectl get svc -n $(NAMESPACE)
	@echo "\nEndpoint Status:"
	@kubectl get endpoints -n $(NAMESPACE)

# Cleanup test artifacts
k8s-test-cleanup:
	@echo "Cleaning up test artifacts in $(NAMESPACE)..."
	-kubectl delete pods -n $(NAMESPACE) -l test=true --force --grace-period=0 2>/dev/null || true
	@echo "Cleanup complete"

# Watch test environment
k8s-test-watch:
	watch -n 2 "kubectl get pods,svc,endpoints -n $(NAMESPACE)"