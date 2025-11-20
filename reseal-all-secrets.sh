#!/bin/bash
# Script to re-seal all secrets with new sealed-secrets key
# Run this after rotating the sealed-secrets key

set -e

echo "🔐 Re-sealing all Homepage secrets with new key..."
echo ""
echo "You'll need to provide all the credentials again."
echo "Press Ctrl+C to cancel at any time."
echo ""

# AdGuard credentials
echo "=== AdGuard Home Credentials ==="
read -p "K3s AdGuard username: " ADGUARD_K3S_USER
read -sp "K3s AdGuard password: " ADGUARD_K3S_PASS
echo ""
read -p "Origin AdGuard username: " ADGUARD_ORIGIN_USER
read -sp "Origin AdGuard password: " ADGUARD_ORIGIN_PASS
echo ""
read -p "Pi4 AdGuard username: " ADGUARD_PI4_USER
read -sp "Pi4 AdGuard password: " ADGUARD_PI4_PASS
echo ""
echo ""

# ArgoCD
echo "=== ArgoCD API Key ==="
read -sp "ArgoCD API key: " ARGOCD_KEY
echo ""
echo ""

# Grafana
echo "=== Grafana Service Account Token ==="
read -sp "Grafana token: " GRAFANA_TOKEN
echo ""
echo ""

# Home Assistant
echo "=== Home Assistant Token ==="
read -sp "Home Assistant token: " HA_TOKEN
echo ""
echo ""

# Portainer
echo "=== Portainer API Keys ==="
read -sp "K3s Portainer key: " PORTAINER_K3S
echo ""
read -sp "Pi4 Portainer key: " PORTAINER_PI4
echo ""
read -sp "Ubuntu Portainer key: " PORTAINER_UBUNTU
echo ""
echo ""

# Proxmox
echo "=== Proxmox API Token ==="
read -p "Proxmox username (e.g. k3s@pam!homepage): " PROXMOX_USER
read -sp "Proxmox token secret: " PROXMOX_PASS
echo ""
echo ""

# UniFi
echo "=== UniFi Credentials ==="
read -p "UniFi username: " UNIFI_USER
read -sp "UniFi password: " UNIFI_PASS
echo ""
echo ""

echo "🔄 Creating sealed secrets..."
echo ""

# AdGuard
kubectl create secret generic adguard-creds \
  -n homepage \
  --from-literal=k3s-username="$ADGUARD_K3S_USER" \
  --from-literal=k3s-password="$ADGUARD_K3S_PASS" \
  --from-literal=origin-username="$ADGUARD_ORIGIN_USER" \
  --from-literal=origin-password="$ADGUARD_ORIGIN_PASS" \
  --from-literal=pi4-username="$ADGUARD_PI4_USER" \
  --from-literal=pi4-password="$ADGUARD_PI4_PASS" \
  --dry-run=client -o yaml | \
kubeseal --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  -o yaml > apps/homepage/sealed-secret-adguard.yaml
echo "✅ AdGuard"

# ArgoCD
kubectl create secret generic argocd-creds \
  -n homepage \
  --from-literal=key="$ARGOCD_KEY" \
  --dry-run=client -o yaml | \
kubeseal --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  -o yaml > apps/homepage/sealed-secret-argocd.yaml
echo "✅ ArgoCD"

# Grafana
kubectl create secret generic grafana-creds \
  -n homepage \
  --from-literal=token="$GRAFANA_TOKEN" \
  --dry-run=client -o yaml | \
kubeseal --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  -o yaml > apps/homepage/sealed-secret-grafana.yaml
echo "✅ Grafana"

# Home Assistant
kubectl create secret generic homeassistant-creds \
  -n homepage \
  --from-literal=key="$HA_TOKEN" \
  --dry-run=client -o yaml | \
kubeseal --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  -o yaml > apps/homepage/sealed-secret-homeassistant.yaml
echo "✅ Home Assistant"

# Portainer
kubectl create secret generic portainer-keys \
  -n homepage \
  --from-literal=k3s-key="$PORTAINER_K3S" \
  --from-literal=pi4-key="$PORTAINER_PI4" \
  --from-literal=ubuntu-key="$PORTAINER_UBUNTU" \
  --dry-run=client -o yaml | \
kubeseal --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  -o yaml > apps/homepage/sealed-secret-portainer.yaml
echo "✅ Portainer"

# Proxmox
kubectl create secret generic proxmox-creds \
  -n homepage \
  --from-literal=username="$PROXMOX_USER" \
  --from-literal=password="$PROXMOX_PASS" \
  --dry-run=client -o yaml | \
kubeseal --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  -o yaml > apps/homepage/sealed-secret-proxmox.yaml
echo "✅ Proxmox"

# UniFi
kubectl create secret generic unifi-creds \
  -n homepage \
  --from-literal=username="$UNIFI_USER" \
  --from-literal=password="$UNIFI_PASS" \
  --dry-run=client -o yaml | \
kubeseal --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  -o yaml > apps/homepage/sealed-secret-unifi.yaml
echo "✅ UniFi"

echo ""
echo "🎉 All secrets re-sealed successfully!"
echo ""
echo "Next steps:"
echo "1. Review the sealed secret files"
echo "2. Commit and push to git"
echo "3. ArgoCD will sync and apply the new secrets"
echo ""
