#!/bin/bash
set -e

NAMESPACE=$1

if [ -z "$NAMESPACE" ]; then
    echo "Error: Namespace not provided"
    exit 1
fi

kubectl create namespace $NAMESPACE
kubectl label namespace $NAMESPACE purpose=feature-testing

# Apply configurations
kubectl apply -f k8s/base -n $NAMESPACE

# Apply any branch-specific configurations if they exist
if [ -d "k8s/branches/$NAMESPACE" ]; then
    kubectl apply -f k8s/branches/$NAMESPACE -n $NAMESPACE
fi

echo "Environment $NAMESPACE set up successfully"