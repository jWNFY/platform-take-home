#!/bin/bash
echo "Generating proto code"
cd proto

# Ensure we have the latest dependencies
buf dep update

# Generate the code
buf generate

cd ..