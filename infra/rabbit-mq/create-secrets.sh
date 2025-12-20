#!/bin/bash

# Create namespace if it doesn't exist
kubectl create namespace rabbitmq --dry-run=client -o yaml | kubectl apply -f -

# Generate a secure Erlang cookie
ERLANG_COOKIE=$(openssl rand -hex 32)

# Create the Erlang cookie secret
kubectl create secret generic rabbitmq-erlang-cookie \
  --namespace=rabbitmq \
  --from-literal=erlang-cookie="$ERLANG_COOKIE" \
  --dry-run=client -o yaml | kubectl apply -f -

# Create the credentials secret
kubectl apply -f rabbitmq-credentials-secret.yaml

# Create the definitions secret
kubectl apply -f rabbitmq-definitions-secret.yaml

echo "Secrets created successfully!"
