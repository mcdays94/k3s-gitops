# K3s Cluster Operations Guide

This guide covers common operational scenarios, disaster recovery, and maintenance procedures.

---

## 📋 Table of Contents

1. [Disaster Recovery](#disaster-recovery)
2. [Power Management](#power-management)
3. [Database Maintenance](#database-maintenance)
4. [Backup Procedures](#backup-procedures)
5. [Troubleshooting](#troubleshooting)

---

## 🚨 Disaster Recovery

### Scenario 1: Complete Cluster Rebuild (GitOps from Scratch)

**When:** A change broke the cluster and you need to rebuild everything.

**Prerequisites:**
- ✅ Access to GitHub repo: https://github.com/mcdays94/k3s-gitops
- ✅ Sealed Secrets private key backup (from Bitwarden)
- ✅ PostgreSQL VM is running (10.10.10.70)

**Steps:**

#### 1. Rebuild K3s Cluster (if needed)

If nodes are intact but K3s is broken:
```bash
# On master node (10.10.10.21)
sudo systemctl stop k3s
sudo /usr/local/bin/k3s-uninstall.sh

# Reinstall K3s with external database
curl -sfL https://get.k3s.io | sh -s - server \
  --datastore-endpoint="postgres://k3s:your-password@10.10.10.70:5432/k3s" \
  --disable=traefik \
  --write-kubeconfig-mode=644

# On worker nodes (10.10.10.22, 10.10.10.23)
sudo systemctl stop k3s-agent
sudo /usr/local/bin/k3s-agent-uninstall.sh

# Get token from master
sudo cat /var/lib/rancher/k3s/server/node-token

# Reinstall agent
curl -sfL https://get.k3s.io | K3S_URL=https://10.10.10.21:6443 \
  K3S_TOKEN=<token> sh -
```

#### 2. Install MetalLB

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml

# Wait for MetalLB to be ready
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s

# Apply IP pool and L2 advertisement
kubectl apply -f infrastructure/metallb/ipaddresspool.yaml
kubectl apply -f infrastructure/metallb/l2advertisement.yaml
```

#### 3. Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Patch service to LoadBalancer
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Wait for LoadBalancer IP
kubectl get svc argocd-server -n argocd -w

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

#### 4. Install Sealed Secrets Controller

```bash
# Install controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.1/controller.yaml

# Wait for controller to be ready
kubectl wait --for=condition=ready pod -n kube-system -l name=sealed-secrets-controller --timeout=90s
```

#### 5. Restore Sealed Secrets Private Key

**CRITICAL:** This must be done before deploying applications!

```bash
# Get the backup from Bitwarden (sealed-secrets-key-backup.yaml)
# Copy it to your local machine

# Apply the backup to restore the private key
kubectl apply -f sealed-secrets-key-backup.yaml

# Restart the controller to pick up the key
kubectl rollout restart deployment sealed-secrets-controller -n kube-system

# Verify the key is loaded
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key
```

#### 6. Deploy All Applications via ArgoCD

```bash
# Clone the repo
git clone https://github.com/mcdays94/k3s-gitops.git
cd k3s-gitops

# Apply all ArgoCD applications
kubectl apply -f argocd/applications/

# Watch applications sync
kubectl get applications -n argocd -w
```

#### 7. Verify Everything

```bash
# Check all applications are healthy
kubectl get applications -n argocd

# Check all pods are running
kubectl get pods -A

# Check all LoadBalancer IPs are assigned
kubectl get svc -A | grep LoadBalancer

# Test services
curl http://10.10.10.200:9000  # Portainer
curl http://10.10.10.201       # Grafana
curl http://10.10.10.202:3001  # Uptime Kuma
curl http://10.10.10.203       # pgAdmin
curl http://10.10.10.204       # ArgoCD
curl http://10.10.10.207       # AdGuard Home
```

**Total time:** ~15-20 minutes ⏱️

---

### Scenario 2: Rollback a Bad Change

**When:** You pushed a change that broke an application.

**Option A: Git Revert (Recommended)**
```bash
cd /Users/miguelcaetanodias/Documents/Projects/k3s-gitops

# View recent commits
git log --oneline -10

# Revert the bad commit
git revert <commit-hash>
git push

# ArgoCD will auto-sync within 3 minutes
```

**Option B: Manual Rollback in ArgoCD**
```bash
# Via CLI
argocd app rollback <app-name> <revision>

# Via UI
# Go to http://10.10.10.204
# Select application → History → Rollback
```

**Option C: Quick Fix**
```bash
# Edit the file locally
vim apps/<app-name>/<file>.yaml

# Commit and push
git add .
git commit -m "Fix: revert bad change"
git push

# Force sync if needed
argocd app sync <app-name>
```

---

## 🔌 Power Management

### Scenario 1: Powering Down All Cluster Nodes

**When:** Rearranging hardware, moving equipment, etc.

**Safe Shutdown Procedure:**

#### Step 1: Drain Nodes (Optional, for graceful shutdown)
```bash
# Drain worker nodes first
kubectl drain k3s-worker1 --ignore-daemonsets --delete-emptydir-data
kubectl drain k3s-worker2 --ignore-daemonsets --delete-emptydir-data

# Wait for pods to migrate
kubectl get pods -A
```

#### Step 2: Shutdown Nodes
```bash
# Shutdown workers first
ssh ubuntu@10.10.10.22 "sudo shutdown -h now"
ssh ubuntu@10.10.10.23 "sudo shutdown -h now"

# Wait 30 seconds, then shutdown master
ssh ubuntu@10.10.10.21 "sudo shutdown -h now"
```

#### Step 3: Power Off
- Physically unplug or use power switch
- Wait at least 30 seconds before moving

### Powering Back Up

**Startup Procedure:**

#### Step 1: Power On Nodes
- Power on master first (10.10.10.21)
- Wait 2-3 minutes for it to fully boot
- Power on workers (10.10.10.22, 10.10.10.23)

#### Step 2: Verify Cluster
```bash
# Check nodes are ready
kubectl get nodes

# Should show:
# NAME           STATUS   ROLES                  AGE   VERSION
# k3s-master     Ready    control-plane,master   Xd    v1.x.x
# k3s-worker1    Ready    <none>                 Xd    v1.x.x
# k3s-worker2    Ready    <none>                 Xd    v1.x.x
```

#### Step 3: Uncordon Nodes (if drained)
```bash
kubectl uncordon k3s-worker1
kubectl uncordon k3s-worker2
```

#### Step 4: Verify Applications
```bash
# Check all pods are running
kubectl get pods -A

# Check ArgoCD applications
kubectl get applications -n argocd

# Test services
curl http://10.10.10.200:9000  # Portainer
```

**What to Expect:**
- ✅ Cluster will resume automatically
- ✅ All pods will restart
- ✅ LoadBalancer IPs will be reassigned
- ✅ ArgoCD will reconcile any drift
- ⏱️ Full recovery: 5-10 minutes

**Potential Issues:**
- Pods stuck in `Pending`: Check node resources
- Pods stuck in `CrashLoopBackOff`: Check logs with `kubectl logs`
- LoadBalancer IPs not assigned: Check MetalLB pods

---

## 🗄️ Database Maintenance

### Scenario: Rebooting Proxmox/PostgreSQL VM

**When:** Proxmox host reboot, VM maintenance, updates.

**What Happens:**

#### During Reboot:
1. **K3s cluster loses database connection**
   - API server continues to run (uses local cache)
   - Existing pods keep running
   - **Cannot create/modify resources** until DB is back

2. **Applications keep running**
   - All pods continue to serve traffic
   - LoadBalancer IPs remain active
   - No service interruption for end users

3. **What breaks temporarily:**
   - ❌ `kubectl` commands fail (API server can't write)
   - ❌ ArgoCD can't sync changes
   - ❌ New pods can't be scheduled
   - ❌ Scaling operations fail

#### After Reboot:
1. **PostgreSQL VM comes back online**
2. **K3s reconnects automatically** (within 30 seconds)
3. **Everything resumes normal operation**
4. **ArgoCD reconciles any missed changes**

**Safe Reboot Procedure:**

```bash
# 1. Check cluster is healthy before reboot
kubectl get nodes
kubectl get pods -A

# 2. Reboot Proxmox/VM
# (via Proxmox UI or SSH)

# 3. Wait for PostgreSQL to come back
# Test connection from master node
ssh ubuntu@10.10.10.21
psql -h 10.10.10.70 -U k3s -d k3s -c "SELECT 1;"

# 4. Verify K3s reconnected
kubectl get nodes
# If this works, you're good!

# 5. Check for any issues
kubectl get pods -A | grep -v Running
```

**Recovery Time:**
- PostgreSQL startup: ~30-60 seconds
- K3s reconnection: ~30 seconds
- Total downtime for management: ~1-2 minutes
- **User-facing services: 0 downtime** ✅

**Best Practices:**
- ✅ Reboot during low-traffic hours
- ✅ Announce maintenance window
- ✅ Monitor cluster after reboot
- ✅ Keep PostgreSQL VM backed up

---

## 💾 Backup Procedures

### What to Backup

#### 1. Sealed Secrets Private Key (CRITICAL)
- **Location:** `sealed-secrets-key-backup.yaml`
- **Backup to:** Bitwarden (already done ✅)
- **Frequency:** Once (doesn't change)
- **Why:** Without this, you can't decrypt secrets

#### 2. Git Repository
- **Location:** https://github.com/mcdays94/k3s-gitops
- **Backup to:** GitHub (already done ✅)
- **Frequency:** Every commit
- **Why:** Single source of truth for cluster config

#### 3. PostgreSQL Database
- **What:** K3s cluster state
- **How:** Automated backups on Proxmox VM
- **Frequency:** Daily
- **Why:** Cluster recovery without rebuilding

**PostgreSQL Backup Script:**
```bash
# On PostgreSQL VM (10.10.10.70)
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/postgresql"
mkdir -p $BACKUP_DIR

# Backup K3s database
pg_dump -U k3s k3s | gzip > $BACKUP_DIR/k3s-backup-$DATE.sql.gz

# Keep last 7 days
find $BACKUP_DIR -name "k3s-backup-*.sql.gz" -mtime +7 -delete
```

#### 4. Application Data (Optional)
- **Prometheus data:** NFS mount (already on PostgreSQL VM)
- **Uptime Kuma data:** PVC (stored on nodes)
- **pgAdmin data:** PVC (stored on nodes)
- **AdGuard Home data:** PVC (stored on nodes)

**PVC Backup (if needed):**
```bash
# List PVCs
kubectl get pvc -A

# Backup a PVC (example: Uptime Kuma)
kubectl exec -n uptime-kuma <pod-name> -- tar czf - /app/data > uptime-kuma-backup.tar.gz
```

---

## 🔧 Troubleshooting

### Common Issues

#### Issue 1: Pod Stuck in Pending
```bash
# Check why
kubectl describe pod <pod-name> -n <namespace>

# Common causes:
# - Insufficient resources
# - PVC not bound
# - Node selector mismatch

# Fix: Scale down other pods or add resources
```

#### Issue 2: ArgoCD Application OutOfSync
```bash
# Check diff
argocd app diff <app-name>

# Force sync
argocd app sync <app-name> --force

# Or delete and recreate
kubectl delete application <app-name> -n argocd
kubectl apply -f argocd/applications/<app-name>.yaml
```

#### Issue 3: LoadBalancer IP Not Assigned
```bash
# Check MetalLB
kubectl get pods -n metallb-system

# Check IP pool
kubectl get ipaddresspool -n metallb-system

# Check L2 advertisement
kubectl get l2advertisement -n metallb-system

# Restart MetalLB if needed
kubectl rollout restart deployment controller -n metallb-system
```

#### Issue 4: Sealed Secret Not Decrypting
```bash
# Check controller is running
kubectl get pods -n kube-system -l name=sealed-secrets-controller

# Check logs
kubectl logs -n kube-system -l name=sealed-secrets-controller

# Verify private key is loaded
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key

# If missing, restore from backup
kubectl apply -f sealed-secrets-key-backup.yaml
kubectl rollout restart deployment sealed-secrets-controller -n kube-system
```

#### Issue 5: Node Not Ready
```bash
# Check node status
kubectl describe node <node-name>

# Check K3s service
ssh ubuntu@<node-ip> "sudo systemctl status k3s"
# or for worker:
ssh ubuntu@<node-ip> "sudo systemctl status k3s-agent"

# Restart K3s
ssh ubuntu@<node-ip> "sudo systemctl restart k3s"
# or for worker:
ssh ubuntu@<node-ip> "sudo systemctl restart k3s-agent"
```

---

## 📞 Emergency Contacts & Resources

### Quick Reference

**Cluster IPs:**
- Master: 10.10.10.21
- Worker 1: 10.10.10.22
- Worker 2: 10.10.10.23
- PostgreSQL: 10.10.10.70

**Service IPs:**
- Portainer: 10.10.10.200:9000
- Grafana: 10.10.10.201
- Uptime Kuma: 10.10.10.202:3001
- pgAdmin: 10.10.10.203
- ArgoCD: 10.10.10.204
- AdGuard Home: 10.10.10.207

**Important Files:**
- Sealed Secrets Key: Bitwarden
- Git Repo: https://github.com/mcdays94/k3s-gitops
- Documentation: `/Users/miguelcaetanodias/Documents/Projects/k3s-rpi-cluster/`

### Useful Commands

```bash
# Check cluster health
kubectl get nodes
kubectl get pods -A
kubectl get applications -n argocd

# Check resource usage
kubectl top nodes
kubectl top pods -A

# View logs
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous  # Previous crash

# Force sync all applications
for app in $(kubectl get applications -n argocd -o name); do
  argocd app sync $(basename $app)
done

# Emergency: Delete and recreate application
kubectl delete application <app-name> -n argocd
kubectl apply -f argocd/applications/<app-name>.yaml
```

---

## 🎯 Summary

**Key Takeaways:**

1. **Disaster Recovery:** 15-20 minutes to rebuild from Git + Sealed Secrets backup
2. **Power Cycling:** Safe to power off/on, cluster resumes automatically in 5-10 minutes
3. **Database Reboots:** No user-facing downtime, management plane down for 1-2 minutes
4. **Backups:** Sealed Secrets key (Bitwarden) + Git repo = full recovery
5. **GitOps:** Everything in Git, ArgoCD reconciles automatically

**You're well protected!** 🛡️
