# K3s GitOps Repository

This repository contains all Kubernetes manifests for the K3s Raspberry Pi cluster, managed via ArgoCD.

## Repository Structure

```
k3s-gitops/
├── apps/                        # Application deployments
│   ├── adguard-home/            # DNS filtering (AdGuard Home)
│   ├── homepage/                # Internal dashboard
│   ├── homepage-public/         # Public-facing dashboard
│   ├── k3s-backup/              # K8up backup schedules + etcd snapshot CronJob
│   ├── monitoring/              # Prometheus + Grafana stack (Helm)
│   ├── pgadmin/                 # PostgreSQL admin UI
│   ├── pocket-id/               # Pocket ID OIDC provider
│   ├── portainer/               # Kubernetes management UI
│   └── uptime-kuma/             # Uptime monitoring
├── infrastructure/              # Infrastructure components
│   ├── metallb/                 # MetalLB LoadBalancer config
│   └── cloudflare-tunnel/       # Cloudflare Tunnel deployment
└── argocd/                      # ArgoCD configuration
    ├── applications/            # ArgoCD Application manifests
    └── bootstrap/               # Initial ArgoCD setup (Kustomize)
```

## Quick Start

### Prerequisites
- K3s cluster running (1 master with `--cluster-init`, 2 workers)
- kubectl configured
- Sealed Secrets controller installed + private key restored

### Deploy Everything

```bash
# Install ArgoCD
kubectl apply -k argocd/bootstrap/

# Deploy all applications
kubectl apply -f argocd/applications/
```

## Deployed Applications

| Application | Namespace | IP | Description | Storage |
|------------|-----------|-----|-------------|---------|
| Portainer | portainer | 10.10.10.200:9000 | K8s management UI | local-path (1Gi) |
| Grafana | monitoring | 10.10.10.201 | Monitoring dashboards | local-path (1Gi) |
| Uptime Kuma | uptime-kuma | 10.10.10.202:3001 | Uptime monitoring | local-path (5Gi) |
| pgAdmin | pgadmin | 10.10.10.203 | PostgreSQL admin | local-path (1Gi) |
| ArgoCD | argocd | 10.10.10.204 (HTTPS) | GitOps management | - |
| AdGuard Home (Web) | adguard-home | 10.10.10.205 | DNS filtering UI | local-path (3Gi) |
| AdGuard DNS (TCP) | adguard-home | 10.10.10.206:53 | DNS over TCP | - |
| Pocket ID | pocket-id | 10.10.10.207 | OIDC identity provider | local-path (1Gi) |
| Homepage | homepage | 10.10.10.208 | Internal dashboard | - |
| AdGuard DNS (UDP) | adguard-home | 10.10.10.209:53 | DNS over UDP | - |
| Homepage Public | homepage-public | 10.10.10.210 | Public dashboard | - |
| Prometheus | monitoring | Internal | Metrics collection | local-path (50Gi) |
| MetalLB | metallb-system | N/A | LoadBalancer provider | - |
| Cloudflare Tunnel | cloudflare-tunnel | N/A | External access gateway | - |
| K8up | k3s-backup | N/A | Backup operator | - |

**Available MetalLB IPs:** 10.10.10.211 through 10.10.10.220

## GitOps Workflow

1. **Make changes** to YAML files in this repo
2. **Commit and push** to `main`
3. **ArgoCD automatically syncs** changes to cluster (self-heal enabled)
4. **Monitor** sync status in ArgoCD UI at https://10.10.10.204

## Secrets Management

Secrets are managed using [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets):
- Controller: `sealed-secrets-controller` in `kube-system` namespace
- Encrypt: `kubeseal --controller-name=sealed-secrets-controller --controller-namespace=kube-system < secret.yaml > sealed-secret.yaml`
- Commit encrypted sealed secrets to Git
- Sealed Secrets controller decrypts them in-cluster automatically

See [SECRETS.md](SECRETS.md) for details.

## Adding New Applications

1. Create directory under `apps/`
2. Add Kubernetes manifests (namespace, deployment, service, etc.)
3. Create ArgoCD Application in `argocd/applications/`
4. Commit and push -- ArgoCD will deploy automatically

## Backups

Weekly PVC backups to Cloudflare R2 via [K8up](https://k8up.io/) operator, plus etcd snapshot uploads. See `apps/k3s-backup/` for schedules.

## Disaster Recovery

### Sealed Secrets Key Backup

The sealed-secrets encryption key is backed up in `sealed-secrets-key-backup.yaml` (gitignored). To restore:

```bash
kubectl apply -f sealed-secrets-key-backup.yaml
kubectl delete pod -n kube-system -l name=sealed-secrets-controller
```

See [OPERATIONS.md](OPERATIONS.md) for full disaster recovery procedures.

## Cluster Information

- **Master:** Raspberry Pi 5 at 10.10.10.71 (control-plane + embedded etcd, `--cluster-init --disable traefik --disable servicelb`)
- **Worker 1:** Raspberry Pi 5 at 10.10.10.72 (agent)
- **Worker 2:** Raspberry Pi 5 at 10.10.10.73 (agent)
- **k3s Version:** v1.34.5+k3s1
- **Datastore:** Embedded etcd (no external database dependency)
- **Storage:** `local-path` provisioner (built into k3s)
- **Network:** 10.10.10.0/24
- **MetalLB Pool:** 10.10.10.200-220

## Documentation

- [OPERATIONS.md](OPERATIONS.md) -- Disaster recovery, power management, troubleshooting
- [GITOPS-WORKFLOW.md](GITOPS-WORKFLOW.md) -- GitOps workflow guide
- [SECRETS.md](SECRETS.md) -- Secrets management and recreation
- [SHUTDOWN-CHECKLIST.md](SHUTDOWN-CHECKLIST.md) -- Graceful shutdown/startup procedures
- [MIGRATION-FROM-EXTERNAL-POSTGRES-TO-EMBEDDED-DB.md](MIGRATION-FROM-EXTERNAL-POSTGRES-TO-EMBEDDED-DB.md) -- Historical migration notes
