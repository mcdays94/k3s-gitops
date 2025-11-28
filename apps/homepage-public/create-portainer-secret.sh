#!/bin/bash
# Script to create Portainer API keys sealed secret
# Run this after generating API keys in each Portainer instance

echo "Enter Portainer API keys:"
echo ""
read -p "K3s Portainer (http://10.10.10.200:9000) API key: " K3S_KEY
read -p "Pi4 Portainer (https://10.10.10.23:9443) API key: " PI4_KEY
read -p "Ubuntu VM Portainer (https://10.10.10.79:9443) API key: " UBUNTU_KEY

echo ""
echo "Creating sealed secret..."

kubectl create secret generic portainer-keys \
  -n homepage \
  --from-literal=k3s-key="$K3S_KEY" \
  --from-literal=pi4-key="$PI4_KEY" \
  --from-literal=ubuntu-key="$UBUNTU_KEY" \
  --dry-run=client -o yaml | \
kubeseal --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  -o yaml > sealed-secret-portainer.yaml

echo ""
echo "✅ Created: sealed-secret-portainer.yaml"
echo "Review the file and commit it to Git!"
