# K3s GitOps Repository

This repository contains all Kubernetes manifests for the K3s Raspberry Pi cluster, managed via ArgoCD.

## 🏗️ Repository Structure

```
k3s-gitops/
├── apps/                      # Application deployments
│   ├── monitoring/           # Prometheus + Grafana stack
│   ├── uptime-kuma/          # Uptime monitoring
│   ├── pgadmin/              # PostgreSQL admin UI
│   └── portainer/            # Kubernetes management UI
├── infrastructure/           # Infrastructure components
│   ├── metallb/              # LoadBalancer
│   ├── cloudflare-tunnel/   # External access
│   └── nfs-storage/          # NFS persistent volumes
└── argocd/                   # ArgoCD configuration
    ├── applications/         # ArgoCD Application manifests
    └── bootstrap/            # Initial ArgoCD setup
```

## 🚀 Quick Start

### Prerequisites
- K3s cluster running
- kubectl configured
- ArgoCD installed

### Deploy Everything

```bash
# Install ArgoCD
kubectl apply -k argocd/bootstrap/

# Deploy all applications
kubectl apply -f argocd/applications/
```

## 📊 Deployed Applications

| Application | Namespace | URL | Description | Storage |
|------------|-----------|-----|-------------|---------|
| Portainer | portainer | http://10.10.10.200:9000 | K8s management | NFS (10Gi) |
| Grafana | monitoring | http://10.10.10.201 | Monitoring dashboards | NFS (1Gi) |
| Uptime Kuma | uptime-kuma | http://10.10.10.202:3001 | Uptime monitoring | NFS (5Gi) |
| pgAdmin | pgadmin | http://10.10.10.203 | PostgreSQL admin | Local (1Gi) |
| ArgoCD | argocd | http://10.10.10.204 | GitOps management | - |
| AdGuard Home | adguard-home | http://10.10.10.207 | DNS filtering | NFS (7Gi) |
| Homepage | homepage | http://10.10.10.205 | Dashboard | - |
| Cloudflare Tunnel | cloudflare-tunnel | N/A | External access gateway | - |
| Prometheus | monitoring | Internal | Metrics collection | NFS (50Gi) |
| MetalLB | metallb-system | N/A | LoadBalancer provider | - |

## 🔄 GitOps Workflow

1. **Make changes** to YAML files in this repo
2. **Commit and push** to Git
3. **ArgoCD automatically syncs** changes to cluster
4. **Monitor** sync status in ArgoCD UI

## 🔐 Secrets Management

Secrets are managed using Sealed Secrets:
- Encrypt secrets: `kubeseal < secret.yaml > sealed-secret.yaml`
- Commit encrypted secrets to Git
- Sealed Secrets controller decrypts in cluster

## 📝 Adding New Applications

1. Create directory under `apps/` or `infrastructure/`
2. Add Kubernetes manifests
3. Create ArgoCD Application in `argocd/applications/`
4. Commit and push - ArgoCD will deploy automatically!

## � Disaster Recovery

### Prometheus Stack Deployment Order

The Prometheus stack requires manual PVC creation before ArgoCD deployment:

```bash
# 1. Apply NFS PersistentVolumes
kubectl apply -f apps/monitoring/prometheus-nfs-storage.yaml

# 2. Apply Grafana PVC (must be created before ArgoCD app)
kubectl apply -f apps/monitoring/grafana-pvc.yaml

# 3. ArgoCD will deploy the rest automatically
kubectl apply -f argocd/applications/kube-prometheus-stack.yaml
```

**Note:** Grafana PVC must be manually created with NFS selector to bind to the NFS PersistentVolume. This is why the application shows `OutOfSync` but remains `Healthy`.

### Sealed Secrets Key Backup

The sealed-secrets encryption key is backed up in `sealed-secrets-key-backup.yaml` (gitignored). To restore:

```bash
kubectl apply -f sealed-secrets-key-backup.yaml
kubectl delete pod -n kube-system -l name=sealed-secrets-controller
```

## �🛠️ Maintenance

```bash
# Check ArgoCD sync status
kubectl get applications -n argocd

# Manual sync if needed
argocd app sync <app-name>

# View application details
argocd app get <app-name>
```

## 📚 Documentation

See [post-setup.md](../k3s-rpi-cluster/post-setup.md) for detailed setup instructions.

## 🏷️ Cluster Information

- **Nodes**: 3x Raspberry Pi 5 (1 master, 2 workers)
- **Network**: 10.10.10.0/24
- **MetalLB Pool**: 10.10.10.200-220
- **External DB**: PostgreSQL on 10.10.10.70
- **NFS Storage**: 10.10.10.70:/srv/nfs (72Gi allocated)
  - All high-write apps (databases, logs) use NFS
  - Protects Raspberry Pi microSD cards from wear
  - See [STORAGE-GUIDELINES.md](STORAGE-GUIDELINES.md) for details
