#!/bin/bash
set -e

NAMESPACE=$1
DOCKER_REGISTRY=$2

if [ -z "$NAMESPACE" ]; then
    echo "Error: Namespace not provided"
    exit 1
fi

# Build and push Docker image
DOCKER_TAG=$(git rev-parse --short HEAD)
docker build -t $DOCKER_REGISTRY/app:$DOCKER_TAG .
docker push $DOCKER_REGISTRY/app:$DOCKER_TAG

# Update deployment
kubectl set image deployment/app app=your-docker-registry/app:$DOCKER_TAG -n $NAMESPACE

echo "Deployed to environment $NAMESPACE successfully"
