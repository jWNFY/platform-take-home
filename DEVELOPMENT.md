
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
  - [Additional Resources](#additional-resources)
  - [TODOs](#todos)
    - [Documentation](#documentation)
    - [Platform](#platform)

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
# Set up local k3d cluster
make k8s-local-setup

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

Available Make commands:

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

## Additional Resources

- [Protocol Buffers Documentation](https://developers.google.com/protocol-buffers)
- [gRPC Documentation](https://grpc.io/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Documentation](https://docs.docker.com/)

## TODOs

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
