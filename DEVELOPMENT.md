
# Development Guide

This document provides comprehensive guidance for developers working with this repository. It covers development environment setup, available tools, testing procedures, and deployment workflows.

## Table of Contents
- [Development Guide](#development-guide)
  - [Table of Contents](#table-of-contents)
  - [Development Environment Setup](#development-environment-setup)
    - [Prerequisites](#prerequisites)
    - [Dev Container Options](#dev-container-options)
      - [1. VS Code Dev Container (Recommended)](#1-vs-code-dev-container-recommended)
      - [2. Generic Dev Container](#2-generic-dev-container)
  - [Development Workflow](#development-workflow)
    - [Code Generation](#code-generation)
    - [Testing](#testing)
    - [Code Quality](#code-quality)
  - [Local Development](#local-development)
    - [Docker Compose Environment](#docker-compose-environment)
    - [Local Kubernetes Environment](#local-kubernetes-environment)
  - [Deployment](#deployment)
    - [Preview Environments](#preview-environments)
    - [Production Deployment](#production-deployment)
  - [Troubleshooting](#troubleshooting)
    - [Common Issues](#common-issues)
    - [Development Tools](#development-tools)
    - [Environment Variables](#environment-variables)
  - [Development Environment Architecture](#development-environment-architecture)
    - [Multiple Environment Layers](#multiple-environment-layers)
      - [1. **Dev Container Environment**](#1-dev-container-environment)
      - [2. **Docker Compose Environment**](#2-docker-compose-environment)
      - [3. **Local Kubernetes Environment**](#3-local-kubernetes-environment)
      - [4. **Preview Environments**](#4-preview-environments)
    - [DevContainer Management and Testing](#devcontainer-management-and-testing)
    - [Make-based Workflow Automation](#make-based-workflow-automation)
      - [1. **Development Setup**](#1-development-setup)
      - [2. **Testing Workflows**](#2-testing-workflows)
      - [3. **Environment Management**](#3-environment-management)
      - [4. **Benefits of Make-based Approach**:](#4-benefits-of-make-based-approach)
      - [5. **Design Philosophy**:](#5-design-philosophy)
    - [Environment Isolation Strategy](#environment-isolation-strategy)
      - [1. **Development Isolation**](#1-development-isolation)
      - [2. **Testing Strategy**](#2-testing-strategy)
      - [3. **Data Management**](#3-data-management)
      - [4. **Network Isolation**](#4-network-isolation)
      - [5. **Resource Management**](#5-resource-management)
  - [Design Decisions and Technical Rationale](#design-decisions-and-technical-rationale)
    - [Architecture Decisions](#architecture-decisions)
      - [1. Development Environment](#1-development-environment)
      - [2. Container Orchestration](#2-container-orchestration)
      - [3. Use Makefiles for Automation](#3-use-makefiles-for-automation)
    - [Future Improvements](#future-improvements)
      - [Short-term Improvements (1-2 weeks)](#short-term-improvements-1-2-weeks)
      - [Medium-term Improvements (1-2 months)](#medium-term-improvements-1-2-months)
      - [Long-term Improvements (3+ months)](#long-term-improvements-3-months)
    - [Trade-offs and Considerations](#trade-offs-and-considerations)
      - [Current Trade-offs](#current-trade-offs)
      - [Lessons Learned](#lessons-learned)
    - [Discussion Points for Review](#discussion-points-for-review)
  - [Other TODOs](#other-todos)
    - [Documentation](#documentation)
    - [Platform](#platform)
  - [Additional Resources](#additional-resources)

## Development Environment Setup

### Prerequisites

- Docker
- VS Code (recommended) or any IDE with dev containers support
- Git
- Make

### Dev Container Options

#### 1. VS Code Dev Container (Recommended)

For VS Code users:

1. Install the "Remote - Containers" extension.
2. Open the project in VS Code.
3. Press F1 and select "Dev Containers: Reopen in Container."

The VS Code setup includes:

- Go development environment.
- PostgreSQL database.
- Required development tools.
- VS Code extensions for Go, Protocol Buffers, Docker, and Git.
- Code formatting and editor settings.

#### 2. Generic Dev Container

For other IDEs supporting dev containers:
1. Use the configuration in `.devcontainer-generic/`.
2. The setup includes:
   - Go development environment.
   - PostgreSQL database.
   - Development tools.
   - Pre-configured environment variables.

## Development Workflow

### Code Generation

Protocol Buffers code generation:

```bash
make proto
```

This will:
1. Update buf dependencies.
2. Generate Go code from proto files.
3. Generate gRPC service definitions.
4. Generate HTTP gateway code.

### Testing

Run all tests:

```bash
make test
```

Run specific test types:

```bash
make test-env-http   # HTTP endpoint tests
make test-env-grpc   # gRPC endpoint tests
make test-env-db     # Database tests
make test-env-health # Health check tests
```

### Code Quality

Pre-commit hooks ensure code quality. They are pre-configured to run linters, formatters, and other checks before each commit automatically.

```bash
# Install pre-commit hooks
make install-hooks

# Run all hooks manually
pre-commit run --all-files

# Format code
make format

# Run linters
make lint
```

The format, lint, test, and build targets are enforced in the CI/CD pipeline to ensure that the code is clean and functional. This triggers on each push to any branch.

## Local Development

### Docker Compose Environment

```bash
# Start the environment
make docker-up

# View logs
make logs          # All logs
make logs-app      # Application logs
make logs-db       # Database logs

# Stop the environment
make docker-down

# Test endpoints
make test-endpoints
```

The docker-up, docker-down, and test-endpoints targets are enforced in the CI/CD pipeline to ensure that the application runs correctly in a local environment. This triggers on each push to any branch.

### Local Kubernetes Environment

```bash
# Set up local k3d cluster and deploy application
make k8s-local-full-setup 

# Deploy application
make k8s-local-deploy

# View status
make k8s-local-status

# Access the application
make k8s-local-port-forward

# Run tests
make k8s-test-local

# Clean up
make k8s-local-delete
```

The k8s-local-setup, k8s-local-deploy, k8s-test-local, and k8s-local-delete targets are enforced in the CI/CD pipeline to ensure that the application runs correctly in a Kubernetes environment. This triggers on each PR to any branch.

## Deployment

### Preview Environments

For feature branch testing:

```bash
# Create preview environment
make k8s-env-setup

# Deploy to preview
make k8s-env-deploy

# Get preview URL
make k8s-env-url

# View logs
make k8s-env-logs

# Clean up
make k8s-env-clean
```

The preview environments are automatically created for each PR, and the URL is posted in GitHub actions logs. This allows testing the application in a production-like environment before merging the PR.

### Production Deployment

Production deployments are handled through GitHub Actions:

1. Push to the main branch triggers the CI/CD pipeline (merges to main from PRs are the same as direct pushes in this context)
2. Tests are run.
3. Docker image is built and pushed.
4. Kubernetes manifests are updated.
5. Application is deployed.

## Troubleshooting

### Common Issues

1. **Proto Generation Fails**

   ```bash
   make proto
   cd proto && buf mod update
   ```

2. **Database Connection Issues**

   ```bash
   # Check database status
   make logs-db

   # Verify connection
   make test-env-db
   ```

3. **Kubernetes Issues**

   ```bash
   # Check cluster status
   make k8s-local-status

   # View detailed pod logs
   kubectl logs -n platform deployment/platform-app
   ```

### Development Tools

Available Make commands more examples:

```bash
make dev-setup         # Install development tools
make docker-up         # Start application
make docker-down       # Stop application
make test              # Run tests
make proto             # Generate proto files
make format            # Format code
make lint              # Run linters
make ps                # Show running containers
make logs              # View all logs
make k8s-local-setup   # Set up local Kubernetes
make k8s-local-deploy  # Deploy to local Kubernetes
```

### Environment Variables

Key environment variables used by docker-compose and Kubernetes:

- `POSTGRES_USER`: Database user (default: postgres)
- `POSTGRES_PASSWORD`: Database password (default: postgres)
- `POSTGRES_DB`: Database name (default: platform)
- `POSTGRES_DSN`: Database connection string
- `HTTP_PORT`: HTTP port (default: 8080)
- `GRPC_PORT`: gRPC port (default: 9008)


## Development Environment Architecture

### Multiple Environment Layers

#### 1. **Dev Container Environment**
- **Purpose**: Primary development environment
- **Components**:
  - PostgreSQL database for development
  - Full development toolchain
  - VS Code integration
- **Use Cases**:
  - Local development
  - Unit testing
  - Database schema development
  - Quick iterations

#### 2. **Docker Compose Environment**
- **Purpose**: CI/CD and ephemeral testing
- **Components**:
  - Application container
  - Separate PostgreSQL instance
  - Shared network setup
- **Use Cases**:
  - Integration testing
  - CI pipeline testing
  - Quick application testing
  - Scenarios not requiring data persistence

#### 3. **Local Kubernetes Environment**
- **Purpose**: Production simulation
- **Components**:
  - k3d cluster
  - Full Kubernetes deployments
  - Service mesh
- **Use Cases**:
  - Production environment testing
  - Kubernetes manifest validation
  - Service interaction testing
  - Performance testing

#### 4. **Preview Environments**
- **Purpose**: Feature testing in isolation
- **Accessibility**: Available from dev container
- **Status**: Implementation in progress
- **Note**: Further testing needed for robustness
- **Use Cases**:
  - Feature branch testing
  - Stakeholder reviews
  - Integration testing
  - Production-like validation


### DevContainer Management and Testing

The project provides comprehensive tooling for managing and testing development containers:

1. **Basic DevContainer Operations**
```bash
# Start devcontainer
make devcontainer-up

# Stop and clean up devcontainer
make devcontainer-down

# View devcontainer logs
make devcontainer-logs

# Check workspace contents
make check-devcontainer
```

2. **Testing DevContainer Setup**
```bash
# Run all devcontainer tests
make test-devcontainer
```
This checks:
- Go installation
- PostgreSQL client
- Required tools (protoc, buf, grpcurl)
- Database connection
- Go tools installation
- Pre-commit hooks

3. **Full DevContainer Testing Workflow**
```bash
# Full test cycle (down, up, and test)
make devcontainer-test-full

# Test development environment
make test-dev-env

# Generic devcontainer test
make test-devcontainer-generic
```

4. **Available Test Commands**
```makefile
test-devcontainer:
  # Tests Go installation
  go version

  # Tests PostgreSQL client
  psql --version

  # Tests required tools
  protoc --version
  buf --version
  grpcurl --version
  pre-commit --version

  # Tests database connection
  pg_isready -h db -U postgres

  # Tests Go tools
  which protoc-gen-go
  which protoc-gen-go-grpc
  which protoc-gen-grpc-gateway

  # Tests pre-commit hooks
  pre-commit run --all-files
```

5. **DevContainer Environment Verification**
   - **Tools and Dependencies**:
     - Verifies all required development tools
     - Checks correct versions of dependencies
     - Validates tool configurations

   - **Network and Services**:
     - Tests database connectivity
     - Verifies network access
     - Checks service availability

   - **Development Setup**:
     - Validates workspace mounting
     - Confirms file permissions
     - Tests build environment

6. **Common DevContainer Workflows**
```bash
# Full development setup
make devcontainer-up && make dev-setup

# Quick restart
make devcontainer-down && make devcontainer-up

# Test and verify setup
make devcontainer-test-full

# Check logs for troubleshooting
make devcontainer-logs
```

7. **Integration with Other Environments**
   - DevContainer can access:
     - Local Kubernetes cluster
     - Docker Compose services
     - Preview environments
     - All testing tools and utilities

8. **Troubleshooting DevContainer**
```bash
# Check container status
docker ps

# Inspect container details
make inspect

# View detailed logs
make devcontainer-logs

# Check workspace contents
make check-devcontainer
```

This comprehensive testing and management approach ensures:
- Consistent development environment
- Reliable tool installation
- Proper configuration
- Easy troubleshooting
- Quick setup verification

The DevContainer setup is tested in CI/CD to ensure it works reliably across different systems and setups. This includes:
- Testing tool installation
- Verifying development workflows
- Checking environment variables
- Validating network connectivity
- Ensuring proper isolation


### Make-based Workflow Automation

The project extensively uses Makefiles to simplify developer workflows:

#### 1. **Development Setup**
```bash
make dev-setup       # Install all tools
make install-hooks   # Set up git hooks
make proto           # Generate protobuf code
```

#### 2. **Testing Workflows**
```bash
make test            # Run unit tests
make test-endpoints  # Test HTTP/gRPC endpoints
make test-env        # Run environment-specific tests
```

#### 3. **Environment Management**
```bash
make docker-up       # Start Docker environment
make k8s-local-setup # Set up local Kubernetes
make k8s-env-setup   # Set up preview environment
```

#### 4. **Benefits of Make-based Approach**:
- **Standardization**: Common commands across environments
- **Documentation**: Self-documenting development tasks
- **Automation**: Reduced manual steps
- **Consistency**: Same commands in CI/CD and local
- **Modularity**: Easy to add new commands
- **Discoverability**: Clear list of available commands

#### 5. **Design Philosophy**:
- Keep commands simple and memorable
- Provide consistent naming conventions
- Include help text and documentation
- Ensure idempotency where possible
- Support both local and CI/CD use cases

### Environment Isolation Strategy

The multi-environment approach provides several benefits:

#### 1. **Development Isolation**
- Dev container database for persistent development
- Docker Compose database for disposable testing
- K8s environment for production simulation

#### 2. **Testing Strategy**
- Unit tests against dev container DB
- Integration tests against Docker Compose DB
- E2E tests against K8s environment
- Feature tests in preview environments

#### 3. **Data Management**
- **Development**: Persistent data in dev container
- **Testing**: Ephemeral data in Docker Compose
- **Staging**: Isolated data in preview environments
- **Production**: Simulated in local K8s

#### 4. **Network Isolation**
- Separate networks for different environments
- Shared networks when needed (e.g., dev container to Docker Compose)
- K8s cluster network for production simulation

#### 5. **Resource Management**
- **Dev container**: Minimal resource usage
- **Docker Compose**: Moderate resources
- **K8s**: Production-like resource allocation

## Design Decisions and Technical Rationale

### Architecture Decisions

#### 1. Development Environment

- **Decision**: Used Dev Containers with VS Code integration

- **Rationale**:
  - Ensures consistent development environment across team members
  - Reduces "works on my machine" issues
  - Simplifies onboarding for new developers
  - Integrates well with VS Code's extensive Go tooling

- **Alternatives Considered**:
  - Local installation of tools: Rejected due to inconsistency risks
  - Virtual machines: Rejected due to higher resource overhead
  - Cloud development environments: Could be considered for future scaling

#### 2. Container Orchestration

- **Decision**: Used k3d for local Kubernetes development

- **Rationale**:
  - Lightweight alternative to minikube
  - Closer parity with production environment
  - Easier integration with Docker

- **Alternatives Considered**:
  - Docker Compose only: Too simplified compared to production
  - Minikube: Higher resource requirements
  - Kind: Similar capabilities but k3d has better Docker integration

#### 3. Use Makefiles for Automation

- **Decision**: Used Makefiles for automation tasks

- **Rationale**:
  - Simple and widely supported
  - Easy to read and write
  - Supports complex workflows
  - Integrates well with CI/CD pipelines

- **Alternatives Considered**:
  - Shell scripts: Less structured and harder to maintain

### Future Improvements

#### Short-term Improvements (1-2 weeks)

- **Iron out any issues with the current setup**:
  - Not every feature is fully tested
  - The basic stuff like docker-compose, devcontainerss, and k8s-local-setup should be working
  - The CI/CD pipeline fails because files are not satisfying the linting rules
    - Same for pre-commit hooks
  - The preview environments haven't been tested as well as the production environments
  - The documentation is not 100% complete
  - The Makefile targets are not all tested

- **Developer Experience**:
  - Add hot reload capability
  - Improve error messages and logging
  - Create debugging guide

- **Documentation**:
  - Add architecture diagrams
  - Include API documentation with examples
  - Create troubleshooting decision tree

#### Medium-term Improvements (1-2 months)

- **Infrastructure**:
  - Implement Terraform for AWS resources
  - Add Helm charts for Kubernetes deployments
  - Set up monitoring stack (Prometheus/Grafana)

- **Security**:
  - Implement authentication/authorization
  - Add security scanning in CI/CD
  - Implement secrets management

- **Performance**:
  - Add caching layer
  - Implement connection pooling
  - Optimize database queries

#### Long-term Improvements (3+ months)

- **Architecture Evolution**:
  - Consider microservices split if needed
  - Evaluate event-driven architecture
  - Plan for multi-region deployment

- **Scalability**:
  - Implement horizontal pod autoscaling
  - Add database replication
  - Set up CDN for static assets

- **Observability**:
  - Implement distributed tracing
  - Add business metrics tracking
  - Set up automated alerting

### Trade-offs and Considerations

#### Current Trade-offs

1. **Simplicity vs. Features**:
   - Focused on core functionality
   - Minimized external dependencies
   - Prioritized developer experience

2. **Development Speed vs. Production Readiness**:
   - Used simplified local setup
   - Deferred some production concerns
   - Maintained basic security practices

3. **Technology Choices**:
   - Go for performance and simplicity
   - PostgreSQL for reliability
   - Kubernetes for scalability

#### Lessons Learned

1. **What Worked Well**:
   - Dev container approach
   - Automated testing setup
   - Documentation-first approach

2. **Challenges Faced**:
   - Initial Kubernetes setup complexity
   - Proto generation workflow
   - CI/CD pipeline setup

3. **Key Insights**:
   - Importance of clear documentation
   - Value of automated testing
   - Need for simplified developer workflow

### Discussion Points for Review

1. **Architectural Decisions**:
   - Why Go over alternatives?
   - Why Kubernetes for this scale?
   - Database choice considerations

2. **Development Process**:
   - CI/CD pipeline design
   - Testing strategy
   - Code organization

3. **Future Considerations**:
   - Scaling strategy
   - Monitoring approach
   - Security improvements

## Other TODOs

### Documentation

- [ ] Add more examples
- [ ] Add more troubleshooting steps
- [ ] Add more resources
- [ ] Add more detailed explanations

### Platform

- [ ] Test GitHub Actions workflows and all the Make targets thoroughly
- [ ] Use better alternatives to authenticate to AWS for EKS deployments like AWS IAM Authenticator or OIDC
- [ ] Pin versions of dependencies more comprehensively, including Docker images, CI, and so on.
- [ ] Add more pre-commit hooks for security checks, secrets detection, code quality, linting of other languages and formats, and so on.
- [ ] Add more tests for edge cases, error handling, and so on.
- [ ] Add more features like caching, rate limiting, authentication, authorization, and so on.
- [ ] Add Terraform scripts for infrastructure provisioning and management, include them in the CI/CD pipeline.
- [ ] Add Helm charts for application deployment, include them in the CI/CD pipeline.
- [ ] Add more deployment strategies like blue-green, canary, and so on.
- [ ] Add more monitoring, logging, and alerting tools and configurations, automatically configured through IaC.
- [ ] Add more security tools and configurations like vulnerability scanning, static code analysis, and so on.
- [ ] Add more CI/CD pipeline steps like performance testing, load testing, and so on.
- [ ] Add more extensions for VS Code, like Docker, Kubernetes, and so on in the dev container.
- [ ] Add more automation for tasks like dependency updates, version bumps, and so on.

## Additional Resources

- [Protocol Buffers Documentation](https://developers.google.com/protocol-buffers)
- [gRPC Documentation](https://grpc.io/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Documentation](https://docs.docker.com/)

