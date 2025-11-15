# Secrets Management Guide

This document lists all secrets required for the cluster and how to recreate them.

## 🔐 Required Secrets

### 1. Cloudflare Tunnel Token

**Namespace:** `cloudflare-tunnel`

```bash
kubectl create secret generic tunnel-token \
  --from-literal=token=YOUR_CLOUDFLARE_TUNNEL_TOKEN \
  -n cloudflare-tunnel
```

**Where to get it:** Cloudflare Zero Trust Dashboard → Access → Tunnels

---

### 2. pgAdmin Password

**Namespace:** `pgadmin`

```bash
kubectl create secret generic pgadmin-secret \
  --from-literal=password=YOUR_SECURE_PASSWORD \
  -n pgadmin
```

**Recommended:** Use a strong random password

---

### 3. ArgoCD Admin Password

**Namespace:** `argocd`

**Initial password:** Auto-generated, retrieve with:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

**Change it:** Via ArgoCD UI or:
```bash
argocd account update-password
```

---

## 🔄 Disaster Recovery

### ✅ Sealed Secrets (ACTIVE)

**Sealed Secrets is now installed!** All secrets are encrypted and stored in Git.

**What's encrypted:**
- ✅ Cloudflare Tunnel token → `infrastructure/cloudflare-tunnel/sealed-secret.yaml`
- ✅ pgAdmin password → `apps/pgadmin/sealed-secret.yaml`

**Private Key Backup:**
The Sealed Secrets private key is backed up at:
- `sealed-secrets-key-backup.yaml` (in this directory, NOT committed to Git!)

**⚠️ IMPORTANT:** Store `sealed-secrets-key-backup.yaml` in a secure location:
- Password manager (1Password, Bitwarden)
- Encrypted USB drive
- Secure cloud storage (encrypted)

**Disaster Recovery Steps:**
1. Clone Git repo: `git clone https://github.com/mcdays94/k3s-gitops.git`
2. Install Sealed Secrets controller
3. Restore private key:
   ```bash
   kubectl apply -f sealed-secrets-key-backup.yaml
   kubectl delete pod -n kube-system -l name=sealed-secrets-controller
   ```
4. Apply all manifests: `kubectl apply -f argocd/applications/`
5. Sealed Secrets controller decrypts everything automatically!

### Option 2: External Secrets Operator (Alternative)

Use external vault (AWS Secrets Manager, HashiCorp Vault, etc.)

---

## 📝 Secrets Checklist for New Cluster

When rebuilding from scratch:

- [ ] Create `cloudflare-tunnel/tunnel-token` secret
- [ ] Create `pgadmin/pgadmin-secret` secret  
- [ ] Note ArgoCD initial admin password
- [ ] (Future) Restore Sealed Secrets key

---

## 🔒 Security Best Practices

1. **Never commit plain secrets to Git**
2. **Use strong, unique passwords**
3. **Rotate secrets periodically**
4. **Backup Sealed Secrets key securely**
5. **Use RBAC to limit secret access**
6. **Enable audit logging**

---

## 📚 Related Documentation

- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [External Secrets Operator](https://external-secrets.io/)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
