# GitOps Workflow Guide

This guide explains how to work with your GitOps-managed K3s cluster.

## 📚 Table of Contents

- [Overview](#overview)
- [Daily Workflow](#daily-workflow)
- [Adding New Applications](#adding-new-applications)
- [Managing Secrets](#managing-secrets)
- [Making Changes](#making-changes)
- [Disaster Recovery](#disaster-recovery)
- [Troubleshooting](#troubleshooting)

---

## Overview

### What is GitOps?

**GitOps** means your entire cluster configuration lives in Git. Every change goes through Git, and ArgoCD automatically syncs changes to your cluster.

**Benefits:**
- ✅ **Version Control**: Every change tracked in Git
- ✅ **Audit Trail**: Who changed what and when
- ✅ **Easy Rollback**: `git revert` to undo changes
- ✅ **Disaster Recovery**: Clone repo → Apply → Cluster rebuilt!
- ✅ **Collaboration**: Multiple people can contribute via PRs

### Your GitOps Stack

```
┌─────────────────────────────────────┐
│  GitHub: k3s-gitops                 │
│  (Single source of truth)           │
└─────────────────────────────────────┘
              ↓
         Git push
              ↓
┌─────────────────────────────────────┐
│  ArgoCD                             │
│  (Watches Git, syncs to cluster)    │
└─────────────────────────────────────┘
              ↓
         Auto-sync
              ↓
┌─────────────────────────────────────┐
│  K3s Cluster                        │
│  (Runs your applications)           │
└─────────────────────────────────────┘
```

---

## Daily Workflow

### Checking Application Status

**Via ArgoCD UI:**
```bash
open http://10.10.10.204
# Login: admin / h9vab3RFdv6Xmggk
```

**Via kubectl:**
```bash
# View all ArgoCD applications
kubectl get applications -n argocd

# Check specific application
kubectl describe application uptime-kuma -n argocd

# View application pods
kubectl get pods -n uptime-kuma
```

### Viewing Application Logs

```bash
# Get pod name
kubectl get pods -n uptime-kuma

# View logs
kubectl logs <pod-name> -n uptime-kuma

# Follow logs (live)
kubectl logs -f <pod-name> -n uptime-kuma
```

### Syncing Applications Manually

If an app is out of sync:

```bash
# Via ArgoCD UI: Click "Sync" button

# Via CLI:
argocd app sync uptime-kuma
```

---

## Adding New Applications

### Step 1: Create Application Directory

```bash
cd /Users/miguelcaetanodias/Documents/Projects/k3s-gitops

# Create directory structure
mkdir -p apps/my-new-app
```

### Step 2: Create Kubernetes Manifests

**Example: Simple web app**

`apps/my-new-app/namespace.yaml`:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-new-app
```

`apps/my-new-app/deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-new-app
  namespace: my-new-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-new-app
  template:
    metadata:
      labels:
        app: my-new-app
    spec:
      containers:
      - name: my-new-app
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: my-new-app
  namespace: my-new-app
spec:
  type: LoadBalancer
  selector:
    app: my-new-app
  ports:
  - port: 80
    targetPort: 80
```

### Step 3: Create ArgoCD Application

`argocd/applications/my-new-app.yaml`:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-new-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/mcdays94/k3s-gitops
    targetRevision: main
    path: apps/my-new-app
  destination:
    server: https://kubernetes.default.svc
    namespace: my-new-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Step 4: Commit and Deploy

```bash
# Add files to Git
git add apps/my-new-app/ argocd/applications/my-new-app.yaml

# Commit
git commit -m "Add my-new-app"

# Push to GitHub
git push

# Apply ArgoCD Application
kubectl apply -f argocd/applications/my-new-app.yaml

# Watch it deploy
kubectl get applications -n argocd -w
```

---

## Managing Secrets

### Creating a New Secret

**Step 1: Create secret locally (NOT applied to cluster)**
```bash
kubectl create secret generic my-app-secret \
  --from-literal=password=mypassword \
  --namespace=my-app \
  --dry-run=client -o yaml > /tmp/my-secret.yaml
```

**Step 2: Encrypt with Sealed Secrets**
```bash
kubeseal < /tmp/my-secret.yaml > apps/my-app/sealed-secret.yaml

# Clean up temp file
rm /tmp/my-secret.yaml
```

**Step 3: Commit to Git**
```bash
git add apps/my-app/sealed-secret.yaml
git commit -m "Add my-app secret"
git push
```

**Step 4: Apply (or let ArgoCD sync)**
```bash
kubectl apply -f apps/my-app/sealed-secret.yaml

# Verify secret was created
kubectl get secret my-app-secret -n my-app
```

### Updating an Existing Secret

```bash
# 1. Delete old sealed secret
rm apps/my-app/sealed-secret.yaml

# 2. Create new secret with updated value
kubectl create secret generic my-app-secret \
  --from-literal=password=newpassword \
  --namespace=my-app \
  --dry-run=client -o yaml > /tmp/my-secret.yaml

# 3. Encrypt
kubeseal < /tmp/my-secret.yaml > apps/my-app/sealed-secret.yaml
rm /tmp/my-secret.yaml

# 4. Commit and push
git add apps/my-app/sealed-secret.yaml
git commit -m "Update my-app secret"
git push

# 5. Apply
kubectl apply -f apps/my-app/sealed-secret.yaml

# 6. Restart pods to use new secret
kubectl rollout restart deployment/my-app -n my-app
```

---

## Making Changes

### Updating Application Configuration

**Example: Change replica count**

1. **Edit the file:**
   ```bash
   # Edit apps/uptime-kuma/uptime-kuma.yaml
   # Change: replicas: 1
   # To:     replicas: 2
   ```

2. **Commit and push:**
   ```bash
   git add apps/uptime-kuma/uptime-kuma.yaml
   git commit -m "Scale Uptime Kuma to 2 replicas"
   git push
   ```

3. **ArgoCD auto-syncs** (within 3 minutes)
   - Or manually sync in ArgoCD UI

4. **Verify:**
   ```bash
   kubectl get pods -n uptime-kuma
   # Should see 2 pods now
   ```

### Rolling Back Changes

**Option 1: Git Revert**
```bash
# Find commit hash
git log --oneline

# Revert the change
git revert <commit-hash>

# Push
git push

# ArgoCD will sync the rollback
```

**Option 2: ArgoCD History**
```bash
# Via ArgoCD UI:
# 1. Click application
# 2. Click "History and Rollback"
# 3. Select previous version
# 4. Click "Rollback"
```

---

## Disaster Recovery

### Full Cluster Rebuild

**Prerequisites:**
- Sealed Secrets private key backup (`sealed-secrets-key-backup.yaml`)
- Access to GitHub repo

**Steps:**

1. **Clone Git repository:**
   ```bash
   git clone https://github.com/mcdays94/k3s-gitops.git
   cd k3s-gitops
   ```

2. **Install ArgoCD:**
   ```bash
   kubectl apply -k argocd/bootstrap/
   kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
   ```

3. **Install Sealed Secrets:**
   ```bash
   kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
   
   # Restore private key
   kubectl apply -f sealed-secrets-key-backup.yaml
   
   # Restart controller to use restored key
   kubectl delete pod -n kube-system -l name=sealed-secrets-controller
   ```

4. **Deploy all applications:**
   ```bash
   kubectl apply -f argocd/applications/
   ```

5. **Wait for sync:**
   ```bash
   kubectl get applications -n argocd -w
   ```

6. **Verify:**
   ```bash
   # Check all applications are healthy
   kubectl get applications -n argocd
   
   # Check all pods are running
   kubectl get pods -A
   ```

**Total time:** ~10-15 minutes for full cluster rebuild! 🎉

---

## Troubleshooting

### Application Stuck in "Progressing"

```bash
# Check application status
kubectl describe application <app-name> -n argocd

# Check pod status
kubectl get pods -n <namespace>

# View pod logs
kubectl logs <pod-name> -n <namespace>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Application "OutOfSync"

**Cause:** Manual changes made to cluster (not via Git)

**Solution:**
```bash
# Option 1: Sync from Git (overwrites manual changes)
argocd app sync <app-name>

# Option 2: Update Git to match cluster
kubectl get <resource> -n <namespace> -o yaml > apps/<app>/resource.yaml
git add apps/<app>/resource.yaml
git commit -m "Update resource"
git push
```

### Secret Not Decrypting

```bash
# Check Sealed Secrets controller is running
kubectl get pods -n kube-system -l name=sealed-secrets-controller

# Check controller logs
kubectl logs -n kube-system -l name=sealed-secrets-controller

# Verify SealedSecret exists
kubectl get sealedsecret -n <namespace>

# Check if regular Secret was created
kubectl get secret -n <namespace>
```

### ArgoCD Can't Access Git Repo

```bash
# Check ArgoCD can reach GitHub
kubectl exec -n argocd deployment/argocd-server -- curl -I https://github.com

# Check repo settings in ArgoCD
argocd repo list

# Re-add repo if needed
argocd repo add https://github.com/mcdays94/k3s-gitops
```

---

## Best Practices

### ✅ DO:
- Always commit changes to Git first
- Use descriptive commit messages
- Test changes in a separate branch
- Keep secrets encrypted with Sealed Secrets
- Backup Sealed Secrets private key
- Monitor ArgoCD UI regularly
- Use namespaces to organize applications

### ❌ DON'T:
- Make manual changes with `kubectl` (bypasses GitOps)
- Commit plain text secrets to Git
- Delete the Sealed Secrets private key backup
- Force-push to main branch
- Ignore ArgoCD sync errors

---

## Quick Reference

### Common Commands

```bash
# View all applications
kubectl get applications -n argocd

# Sync application
argocd app sync <app-name>

# View application details
argocd app get <app-name>

# View application logs
kubectl logs -n <namespace> -l app=<app-name>

# Restart application
kubectl rollout restart deployment/<app-name> -n <namespace>

# Encrypt secret
kubeseal < secret.yaml > sealed-secret.yaml

# View ArgoCD password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Important URLs

- **ArgoCD UI**: http://10.10.10.204
- **Grafana**: http://10.10.10.201
- **Portainer**: http://10.10.10.200:9000
- **Uptime Kuma**: http://10.10.10.202:3001
- **pgAdmin**: http://10.10.10.203
- **AdGuard Home**: http://10.10.10.207
- **GitHub Repo**: https://github.com/mcdays94/k3s-gitops

---

## Need Help?

- **ArgoCD Docs**: https://argo-cd.readthedocs.io/
- **Sealed Secrets**: https://github.com/bitnami-labs/sealed-secrets
- **Kubernetes Docs**: https://kubernetes.io/docs/
- **Your Setup Docs**: See `README.md` and `SECRETS.md`
