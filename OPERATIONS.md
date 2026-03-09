# K3s Cluster Operations Guide

Common operational scenarios, disaster recovery, and maintenance procedures.

---

## Table of Contents

1. [Disaster Recovery](#disaster-recovery)
2. [Power Management](#power-management)
3. [Backup & Restore](#backup--restore)
4. [Troubleshooting](#troubleshooting)
5. [Quick Reference](#quick-reference)

---

## Disaster Recovery

### Scenario 1: Complete Cluster Rebuild (GitOps from Scratch)

**When:** Cluster is unrecoverable and needs full rebuild.

**Prerequisites:**
- Access to GitHub repo: https://github.com/mcdays94/k3s-gitops
- Sealed Secrets private key backup (`sealed-secrets-key-backup.yaml`)

**Steps:**

#### 1. Rebuild K3s Cluster

```bash
# On master node (10.10.10.71, user: mdias)
sudo systemctl stop k3s
sudo /usr/local/bin/k3s-uninstall.sh

# Reinstall K3s with embedded etcd
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --disable=traefik \
  --disable=servicelb \
  --write-kubeconfig-mode=644

# Get the node token for workers
sudo cat /var/lib/rancher/k3s/server/node-token

# On worker nodes (10.10.10.72 and 10.10.10.73, user: mdias)
sudo systemctl stop k3s-agent
sudo /usr/local/bin/k3s-agent-uninstall.sh

# Reinstall agent
curl -sfL https://get.k3s.io | K3S_URL=https://10.10.10.71:6443 \
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

#### 3. Install Sealed Secrets + Restore Key

```bash
# Install controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.1/controller.yaml

# Wait for controller
kubectl wait --for=condition=ready pod -n kube-system -l name=sealed-secrets-controller --timeout=90s

# Restore private key (CRITICAL -- must be done before deploying apps)
kubectl apply -f sealed-secrets-key-backup.yaml

# Restart controller to pick up the key
kubectl rollout restart deployment sealed-secrets-controller -n kube-system
```

#### 4. Install ArgoCD + Deploy All Applications

```bash
# Clone the repo
git clone https://github.com/mcdays94/k3s-gitops.git
cd k3s-gitops

# Install ArgoCD
kubectl apply -k argocd/bootstrap/
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# Deploy all applications
kubectl apply -f argocd/applications/

# Watch applications sync
kubectl get applications -n argocd -w
```

#### 5. Post-Deploy Manual Steps

```bash
# Create prometheus admission TLS secret (Helm hook not executed by ArgoCD)
# Generate self-signed cert:
openssl req -x509 -newkey rsa:2048 -keyout /tmp/tls.key -out /tmp/tls.crt \
  -days 3650 -nodes -subj '/CN=kube-prometheus-stack-admission'

kubectl create secret generic kube-prometheus-stack-admission \
  -n monitoring \
  --from-file=cert=/tmp/tls.crt \
  --from-file=key=/tmp/tls.key \
  --from-file=tls-ca.crt=/tmp/tls.crt

rm /tmp/tls.key /tmp/tls.crt

# Verify all apps are healthy
kubectl get applications -n argocd
kubectl get pods -A
kubectl get svc -A | grep LoadBalancer
```

**Total time:** ~15-20 minutes

---

### Scenario 2: Rollback a Bad Change

**Option A: Git Revert (Recommended)**
```bash
cd /Users/miguelcaetanodias/Documents/Projects/k3s-gitops
git log --oneline -10
git revert <commit-hash>
git push
# ArgoCD will auto-sync within 3 minutes
```

**Option B: ArgoCD History**
- Go to https://10.10.10.204
- Select application > History > Rollback

---

## Power Management

### Powering Down All Cluster Nodes

**Safe Shutdown Procedure:**

```bash
# 1. (Optional) Drain worker nodes for graceful pod termination
kubectl drain k3s-worker-01 --ignore-daemonsets --delete-emptydir-data --timeout=300s
kubectl drain k3s-worker-02 --ignore-daemonsets --delete-emptydir-data --timeout=300s

# 2. Shutdown workers first, then master
ssh mdias@10.10.10.72 "sudo shutdown -h now"
ssh mdias@10.10.10.73 "sudo shutdown -h now"
# Wait 30 seconds
ssh mdias@10.10.10.71 "sudo shutdown -h now"
```

### Powering Back Up

1. Power on master first (10.10.10.71), wait 2-3 minutes
2. Power on workers (10.10.10.72, 10.10.10.73)
3. Verify:

```bash
kubectl get nodes
# Should show:
# k3s-master-01   Ready   control-plane,etcd,master
# k3s-worker-01   Ready   <none>
# k3s-worker-02   Ready   <none>

kubectl get applications -n argocd
kubectl get pods -A
```

**What to expect:**
- Cluster resumes automatically (k3s service is `enabled` on all nodes)
- All pods restart (`restartPolicy: Always`)
- MetalLB reassigns LoadBalancer IPs
- ArgoCD reconciles any drift (self-heal enabled)
- Full recovery: 5-10 minutes

If nodes were drained:
```bash
kubectl uncordon k3s-worker-01
kubectl uncordon k3s-worker-02
```

---

## Backup & Restore

### Automated Backups (K8up to Cloudflare R2)

Weekly PVC backups run every Sunday via K8up Schedule CRs:

| Time (UTC) | Namespace | What |
|------------|-----------|------|
| 02:00 | pocket-id | Pocket ID database + uploads |
| 02:10 | uptime-kuma | Uptime Kuma SQLite DB |
| 02:20 | monitoring | Grafana DB + Prometheus data |
| 02:30 | adguard-home | AdGuard config + work dirs |
| 02:40 | portainer | Portainer data |
| 02:50 | pgadmin | pgAdmin config |
| 03:00 | k3s-backup | etcd snapshot upload (CronJob) |

Prune at 04:xx, Check at 05:xx (Sundays).

Backups go to Cloudflare R2 bucket `r2-backups` using Restic (encrypted, incremental).

### Manual Backup

```bash
# Trigger a one-off backup for a namespace
kubectl apply -f - <<EOF
apiVersion: k8up.io/v1
kind: Backup
metadata:
  name: manual-backup
  namespace: <namespace>
spec:
  failedJobsHistoryLimit: 1
  successfulJobsHistoryLimit: 1
EOF

# Check status
kubectl get backup -n <namespace>
```

### etcd Snapshot Backup

The `etcd-snapshot-backup` CronJob uploads the latest etcd snapshot to R2 under the `k3s-etcd-snapshots/` prefix. To trigger manually:

```bash
kubectl create job etcd-manual --from=cronjob/etcd-snapshot-backup -n k3s-backup
kubectl logs -l job-name=etcd-manual -n k3s-backup
kubectl delete job etcd-manual -n k3s-backup
```

### What to Backup Externally

| Item | Location | Notes |
|------|----------|-------|
| Sealed Secrets key | `sealed-secrets-key-backup.yaml` | Store in password manager. Without this, secrets cannot be decrypted on rebuild. |
| Git repo | GitHub | Already remote. Consider local clone as additional backup. |

---

## Troubleshooting

### Pod Stuck in Pending
```bash
kubectl describe pod <pod-name> -n <namespace>
# Common causes: insufficient resources, PVC not bound, node selector mismatch
```

### ArgoCD Application OutOfSync
```bash
# Check diff
argocd app diff <app-name>

# Force sync
argocd app sync <app-name> --force

# Or hard refresh
kubectl patch app <app-name> -n argocd --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### LoadBalancer IP Not Assigned
```bash
kubectl get pods -n metallb-system
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system
kubectl rollout restart deployment controller -n metallb-system
```

### Sealed Secret Not Decrypting
```bash
kubectl get pods -n kube-system -l name=sealed-secrets-controller
kubectl logs -n kube-system -l name=sealed-secrets-controller
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key

# If key missing, restore from backup
kubectl apply -f sealed-secrets-key-backup.yaml
kubectl rollout restart deployment sealed-secrets-controller -n kube-system
```

### Node Not Ready
```bash
kubectl describe node <node-name>

# On the node (user: mdias):
ssh mdias@<node-ip> "sudo systemctl status k3s"        # master
ssh mdias@<node-ip> "sudo systemctl status k3s-agent"   # worker
ssh mdias@<node-ip> "sudo systemctl restart k3s-agent"  # restart if needed
```

---

## Quick Reference

### Cluster Nodes

| Node | IP | Role |
|------|-----|------|
| k3s-master-01 | 10.10.10.71 | Control-plane + etcd |
| k3s-worker-01 | 10.10.10.72 | Worker |
| k3s-worker-02 | 10.10.10.73 | Worker |

SSH user: `mdias` on all nodes.

### Service IPs

| Service | IP | Port |
|---------|-----|------|
| Portainer | 10.10.10.200 | 9000 |
| Grafana | 10.10.10.201 | 80 |
| Uptime Kuma | 10.10.10.202 | 3001 |
| pgAdmin | 10.10.10.203 | 80 |
| ArgoCD | 10.10.10.204 | 443 |
| AdGuard Home (Web) | 10.10.10.205 | 80 |
| AdGuard DNS (TCP) | 10.10.10.206 | 53 |
| Pocket ID | 10.10.10.207 | 80 |
| Homepage | 10.10.10.208 | 80 |
| AdGuard DNS (UDP) | 10.10.10.209 | 53 |
| Homepage Public | 10.10.10.210 | 80 |

### Useful Commands

```bash
# Cluster health
kubectl get nodes
kubectl get pods -A
kubectl get applications -n argocd

# Resource usage
kubectl top nodes
kubectl top pods -A

# ArgoCD password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Force sync all apps
for app in $(kubectl get applications -n argocd -o name); do
  argocd app sync $(basename $app)
done
```

### Key Files

- Sealed Secrets Key: password manager (not in repo)
- Git Repo: https://github.com/mcdays94/k3s-gitops
