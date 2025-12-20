#!/bin/bash
set -e

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
kubectl create secret generic rabbitmq-credentials \
  --namespace=rabbitmq \
  --from-literal=username=admin_user \
  --from-literal=password="$(openssl rand -hex 16)" \
  --dry-run=client -o yaml | kubectl apply -f -

# Create the definitions secret
kubectl create secret generic rabbitmq-definitions \
  --namespace=rabbitmq \
  --from-file=definitions.json=/dev/stdin << 'EOF'
{
  "users": [{
    "name": "admin_user",
    "password_hash": "$2a$10$2Qx1pY2yy0m8pC7bZ5z0kOQJ9XvV6q9Xk1Vc6J9XvV6q9Xk1Vc6J",
    "tags": "administrator"
  }],
  "vhosts": [{
    "name": "/"
  }],
  "permissions": [{
    "user": "admin_user",
    "vhost": "/",
    "configure": ".*",
    "write": ".*",
    "read": ".*"
  }]
}
EOF

echo "Secrets created successfully!"