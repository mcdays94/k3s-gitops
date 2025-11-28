#!/bin/bash
# Script to copy secrets from homepage namespace to homepage-public namespace

echo "Copying secrets from homepage to homepage-public namespace..."

# Copy AdGuard credentials
kubectl get secret adguard-creds -n homepage -o yaml | \
  sed 's/namespace: homepage/namespace: homepage-public/' | \
  kubectl apply -f -

# Copy Home Assistant credentials
kubectl get secret homeassistant-creds -n homepage -o yaml | \
  sed 's/namespace: homepage/namespace: homepage-public/' | \
  kubectl apply -f -

echo "Secrets copied successfully!"
