# Secrets Management Guide

This document lists all secrets required for the cluster and how to recreate them.

## How Secrets Work

All secrets are managed using **Sealed Secrets**. Plain secrets are encrypted with `kubeseal` and committed to Git as `SealedSecret` resources. The Sealed Secrets controller (`sealed-secrets-controller` in `kube-system`) decrypts them in-cluster.

**Encrypt a secret:**
```bash
kubectl create secret generic my-secret \
  --from-literal=key=value \
  --namespace=my-namespace \
  --dry-run=client -o yaml | \
  kubeseal --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system -o yaml > sealed-secret.yaml
```

---

## Required Secrets

### 1. Cloudflare Tunnel Token

**Namespace:** `cloudflare-tunnel`
**Sealed Secret:** `infrastructure/cloudflare-tunnel/sealed-secret.yaml`

```bash
kubectl create secret generic tunnel-token \
  --from-literal=token=YOUR_CLOUDFLARE_TUNNEL_TOKEN \
  -n cloudflare-tunnel \
  --dry-run=client -o yaml | kubeseal ... > infrastructure/cloudflare-tunnel/sealed-secret.yaml
```

**Where to get it:** Cloudflare Zero Trust Dashboard > Access > Tunnels

---

### 2. pgAdmin Password

**Namespace:** `pgadmin`
**Sealed Secret:** `apps/pgadmin/sealed-secret.yaml`

---

### 3. Pocket ID Encryption Key

**Namespace:** `pocket-id`
**Sealed Secret:** `apps/pocket-id/sealed-secret.yaml`

Contains the `ENCRYPTION_KEY` used by Pocket ID for encrypting OIDC client secrets.

---

### 4. Homepage Widget Credentials

**Namespace:** `homepage` (and `homepage-public`)

Multiple sealed secrets for dashboard widget authentication:

| Secret | File | Contents |
|--------|------|----------|
| AdGuard creds | `sealed-secret-adguard.yaml` | K3s, Origin, Pi4 AdGuard usernames/passwords |
| ArgoCD creds | `sealed-secret-argocd.yaml` | ArgoCD API key |
| Grafana creds | `sealed-secret-grafana.yaml` | Grafana username/password |
| Home Assistant | `sealed-secret-homeassistant.yaml` | HA long-lived access token |
| Portainer creds | `sealed-secret-portainer.yaml` | Portainer API keys |
| Proxmox creds | `sealed-secret-proxmox.yaml` | Proxmox API token |
| UniFi creds | `sealed-secret-unifi.yaml` | UniFi username/password |

The `homepage-public` namespace has its own copies of these sealed secrets (sealed secrets are namespace-scoped).

---

### 5. K8up Backup Secrets

**Namespaces:** `k3s-backup` + each app namespace

| Secret | Namespace | Purpose |
|--------|-----------|---------|
| `r2-credentials` | `k3s-backup` | Cloudflare R2 S3 access key + secret + restic password |
| `k8up-s3-credentials` | per-app namespace | R2 access credentials for that namespace's backups |
| `k8up-repo-password` | per-app namespace | Restic repository password for that namespace's backups |

Sealed secret files are in `apps/k3s-backup/` as individual `.json` files.

---

### 6. ArgoCD Admin Password

**Namespace:** `argocd`

Auto-generated on install. Retrieve with:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

---

## Sealed Secrets Key Backup

The Sealed Secrets private key is backed up at:
- `sealed-secrets-key-backup.yaml` (in repo root, **NOT committed to Git** -- gitignored)

**IMPORTANT:** Store this file in a secure location (password manager, encrypted storage). Without it, you cannot decrypt any sealed secrets if you rebuild the cluster.

**Restore procedure:**
```bash
kubectl apply -f sealed-secrets-key-backup.yaml
kubectl delete pod -n kube-system -l name=sealed-secrets-controller
```

---

## Secrets Checklist for New Cluster

When rebuilding from scratch:

1. Install k3s cluster
2. Install Sealed Secrets controller
3. **Restore Sealed Secrets private key** from backup
4. Restart sealed-secrets controller pod
5. Install ArgoCD (`kubectl apply -k argocd/bootstrap/`)
6. Apply all ArgoCD applications (`kubectl apply -f argocd/applications/`)
7. All sealed secrets auto-decrypt -- no manual secret creation needed

---

## Security Best Practices

1. **Never commit plain secrets to Git**
2. **Backup Sealed Secrets key securely** (password manager)
3. **Rotate secrets periodically**
4. **Use RBAC to limit secret access**
