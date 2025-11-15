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

### Option 1: Manual Recreation (Current)

Keep this file and your passwords in a **secure password manager** (1Password, Bitwarden, etc.)

### Option 2: Sealed Secrets (Recommended)

**Coming in Phase 5!**

1. Install Sealed Secrets controller
2. Backup the sealing key:
   ```bash
   kubectl get secret -n kube-system sealed-secrets-key -o yaml > sealed-secrets-key-backup.yaml
   ```
3. Store backup in secure location (NOT in Git!)
4. Encrypt secrets and commit to Git

### Option 3: External Secrets Operator

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
