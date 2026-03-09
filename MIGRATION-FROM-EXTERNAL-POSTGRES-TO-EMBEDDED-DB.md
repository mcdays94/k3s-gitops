# Migration: External PostgreSQL to Embedded etcd

**Date:** 2026-03-09
**Reason:** The external PostgreSQL datastore (Proxmox VM at 10.10.10.70) went down, breaking the k3s control plane. Pods continued running from stale state but no changes could be made via kubectl.

---

## What Changed

### Architecture

| Component | Before | After |
|-----------|--------|-------|
| Datastore | External PostgreSQL at 10.10.10.70 | Embedded etcd on master node |
| k3s Version | v1.28.x | v1.34.5+k3s1 |
| Master | `k3s server --datastore-endpoint=postgres://...` | `k3s server --cluster-init` (embedded etcd) |
| Workers | k3s agent pointing to 10.10.10.71:6443 | Same, re-joined with new token |
| Storage | NFS PVs from 10.10.10.70 | `local-path` storageClass (built into k3s) |

### Nodes

- **k3s-master-01** (10.10.10.71) -- Control plane + etcd, `--cluster-init --disable traefik --disable servicelb`
- **k3s-worker-01** (10.10.10.72) -- Agent
- **k3s-worker-02** (10.10.10.73) -- Agent

### Storage Migration (NFS to local-path)

All persistent volumes were changed from NFS (hosted on the dead 10.10.10.70 VM) to `local-path` provisioner (built into k3s). This means data is stored locally on the node where the pod runs.

**Files changed:**
- `apps/adguard-home/adguard-home.yaml` -- Removed NFS PV/PVC, added local-path PVC
- `apps/portainer/portainer.yaml` -- Same
- `apps/uptime-kuma/uptime-kuma.yaml` -- Same, also removed `wait-for-nfs` init container and `init-status-page` init container (chicken-and-egg with fresh PVC)
- `apps/monitoring/prometheus-nfs-storage.yaml` -- Replaced with comment (NFS PVs removed)
- `apps/monitoring/grafana-pvc.yaml` -- Replaced with comment (managed by Helm)
- `argocd/applications/kube-prometheus-stack.yaml` -- Changed Prometheus/Grafana storage to `local-path`

### MetalLB Compatibility Fix

MetalLB v0.14.8 rejects services with both `spec.loadBalancerIP` and the `metallb.universe.tf/loadBalancerIPs` annotation. Removed `loadBalancerIP` from all service specs, keeping only the annotation.

**Files changed:**
- `apps/adguard-home/adguard-home.yaml` (3 services)
- `apps/portainer/portainer.yaml`
- `apps/uptime-kuma/uptime-kuma.yaml`
- `apps/pgadmin/pgadmin.yaml`
- `apps/homepage/homepage.yaml`
- `apps/homepage-public/homepage.yaml`
- `argocd/bootstrap/kustomization.yaml` (ArgoCD server service patch)

### Sealed Secrets Fix

The `homepage-public` sealed secrets were originally cloned from the `homepage` app but sealed secrets are namespace-scoped. Re-encrypted all 7 sealed secrets for the `homepage-public` namespace using the active cluster key.

**Files changed:**
- `apps/homepage-public/sealed-secret-*.yaml` (all 7 files)

### Cluster Recovery Script

Updated `cluster-recovery.sh` for the new embedded etcd architecture (1 server + 2 agents, no PostgreSQL dependency).

---

## Bootstrap Order

The cluster was rebuilt from scratch in this order:

1. **Install k3s master** on 10.10.10.71 with `--cluster-init`
2. **Join workers** 10.10.10.72 and 10.10.10.73 as agents
3. **Install MetalLB** v0.14.8 via native manifest + IP pool (10.10.10.200-220) + L2 advertisement
4. **Install Sealed Secrets** controller v0.27.1 + restore key backup from `sealed-secrets-key-backup.yaml`
5. **Push manifest changes to Git** (NFS-to-local-path, loadBalancerIP removal)
6. **Bootstrap ArgoCD** via `kubectl apply -k argocd/bootstrap/`
7. **Apply ArgoCD applications** via `kubectl apply -f argocd/applications/`
8. **Fix runtime issues:**
   - Create `kube-prometheus-stack-admission` TLS secret manually (Helm hook not executed by ArgoCD)
   - Initialize k3s AdGuard Home via setup API (`POST /control/install/configure`)
9. **Trigger adguardhome-sync** to replicate config from origin

---

## Service Endpoints

| Service | IP | Port |
|---------|-----|------|
| Portainer | 10.10.10.200 | 9000 |
| Grafana | 10.10.10.201 | 80 |
| Uptime Kuma | 10.10.10.202 | 3001 |
| pgAdmin | 10.10.10.203 | 80 |
| ArgoCD | 10.10.10.204 | 443 |
| AdGuard Home (web) | 10.10.10.205 | 80 |
| AdGuard Home (DNS TCP) | 10.10.10.206 | 53 |
| Homepage | 10.10.10.208 | 80 |
| AdGuard Home (DNS UDP) | 10.10.10.209 | 53 |
| Homepage Public | 10.10.10.210 | 80 |

---

## Known Issues / Notes

- **homepage / homepage-public OutOfSync**: These two ArgoCD apps share the `homepage` and `homepage-public` namespaces respectively, but both create resources that the other considers "out of sync". This is cosmetic; both apps are Healthy.
- **Prometheus operator admission webhook**: The `kube-prometheus-stack-admission` TLS secret must be created manually after ArgoCD deploys the Helm chart, because ArgoCD doesn't run Helm pre-install hooks. The self-signed cert was created with: `openssl req -x509 -newkey rsa:2048 ... -subj '/CN=kube-prometheus-stack-admission'` and stored as a generic secret with keys `cert`, `key`, `tls-ca.crt`.
- **Data loss**: All persistent data from the old cluster (Prometheus metrics, Uptime Kuma monitors, Grafana dashboards, pgAdmin connections) was lost because the NFS server (10.10.10.70) is offline. Services start fresh.
- **local-path storage caveat**: Data is node-local. If a pod moves to a different node, it loses its data. For a 3-node Raspberry Pi cluster this is acceptable.

---

## Commits

1. `17224db` -- Migrate storage from NFS to local-path for embedded etcd cluster rebuild
2. `9a805cc` -- Remove deprecated loadBalancerIP spec field from all services
3. `988767e` -- Remove uptime-kuma init container and fix loadBalancerIP conflicts
4. `97a35ec` -- Re-seal homepage-public secrets for correct namespace
