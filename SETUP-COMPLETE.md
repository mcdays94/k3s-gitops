# K3s GitOps Cluster -- Current State

## Infrastructure

- **3-node k3s cluster** (1 control-plane + 2 workers, all Raspberry Pi 5)
- **Embedded etcd** datastore (no external database dependency)
- **k3s v1.34.5+k3s1** with `--cluster-init --disable traefik --disable servicelb`
- **MetalLB v0.14.8** LoadBalancer (IP pool 10.10.10.200-220)
- **local-path** storage provisioner (built into k3s)
- **Cloudflare Tunnel** for external access
- **Pocket ID** as OIDC identity provider for Cloudflare Zero Trust

## GitOps Stack

- **ArgoCD** -- GitOps continuous deployment (auto-sync + self-heal on all apps)
- **Sealed Secrets** -- Encrypted secrets in Git
- **GitHub Repository** -- Single source of truth

## Deployed Applications

| Application | IP | Port | Purpose |
|------------|-----|------|---------|
| Portainer | 10.10.10.200 | 9000 | Kubernetes management UI |
| Grafana | 10.10.10.201 | 80 | Monitoring dashboards |
| Uptime Kuma | 10.10.10.202 | 3001 | Uptime monitoring (15 monitors) |
| pgAdmin | 10.10.10.203 | 80 | PostgreSQL admin |
| ArgoCD | 10.10.10.204 | 443 | GitOps management |
| AdGuard Home (Web) | 10.10.10.205 | 80 | DNS filtering UI |
| AdGuard DNS (TCP) | 10.10.10.206 | 53 | DNS over TCP |
| Pocket ID | 10.10.10.207 | 80 | OIDC identity provider |
| Homepage | 10.10.10.208 | 80 | Internal dashboard |
| AdGuard DNS (UDP) | 10.10.10.209 | 53 | DNS over UDP |
| Homepage Public | 10.10.10.210 | 80 | Public-facing dashboard |
| Prometheus | Internal | 9090 | Metrics collection |
| K8up | Internal | - | Backup operator |

## Backup Strategy

- **K8up** operator with weekly PVC backups to Cloudflare R2 (Sundays, staggered 02:00-03:00)
- **etcd snapshot** CronJob uploads to R2 weekly (Sundays at 03:00)
- **Restic** for incremental, encrypted backups with pruning

## Security

- All secrets encrypted via Sealed Secrets (no plain text in repo)
- Pocket ID provides OIDC authentication for Cloudflare Zero Trust
- Cloudflare Access protects all externally-exposed services

## Monitoring

- **Grafana** at http://10.10.10.201 -- 30 dashboards (27 from kube-prometheus-stack + 3 imported)
- **Uptime Kuma** at http://10.10.10.202:3001 -- 15 monitors covering all services
- **Prometheus** collects cluster and node metrics via kube-prometheus-stack

## Power Loss Recovery

Everything auto-recovers after power loss:
- k3s service enabled on all nodes (`Restart=always`)
- All deployments have `restartPolicy: Always`
- All PVCs on local-path (data on local disk, survives reboot)
- ArgoCD self-heal reconciles any drift

## Quick Access

```bash
# ArgoCD
open https://10.10.10.204
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Cluster status
kubectl get nodes
kubectl get applications -n argocd
kubectl get pods -A
```

## Documentation

- [README.md](README.md) -- Repository overview
- [OPERATIONS.md](OPERATIONS.md) -- Disaster recovery and maintenance
- [GITOPS-WORKFLOW.md](GITOPS-WORKFLOW.md) -- GitOps workflow guide
- [SECRETS.md](SECRETS.md) -- Secrets management
- [SHUTDOWN-CHECKLIST.md](SHUTDOWN-CHECKLIST.md) -- Shutdown/startup procedures
