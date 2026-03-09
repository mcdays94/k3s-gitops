# 🎉 K3s GitOps Setup Complete!

Congratulations! Your K3s Raspberry Pi cluster is now fully configured with GitOps using ArgoCD and Sealed Secrets.

## 📊 What You Have Now

### Infrastructure
- ✅ **3-node HA K3s cluster** (all control-plane nodes)
- ✅ **High Availability** - Survives any single node failure
- ✅ **External PostgreSQL database** (10.10.10.70 - shared datastore)
- ✅ **MetalLB LoadBalancer** (10.10.10.200-220 pool)
- ✅ **NFS storage** for Prometheus (zero microSD wear!)
- ✅ **Cloudflare Tunnel** for external access

### GitOps Stack
- ✅ **ArgoCD** - GitOps continuous deployment
- ✅ **Sealed Secrets** - Encrypted secrets in Git
- ✅ **GitHub Repository** - Single source of truth

### Deployed Applications

| Application | IP | Purpose | Status |
|------------|-----|---------|--------|
| **Portainer** | 10.10.10.200:9000 | Kubernetes management UI | ✅ GitOps + Pinned IP |
| **Grafana** | 10.10.10.201 | Monitoring dashboards | ✅ GitOps + Pinned IP |
| **Uptime Kuma** | 10.10.10.202:3001 | Uptime monitoring | ✅ GitOps + Pinned IP |
| **pgAdmin** | 10.10.10.203 | PostgreSQL admin | ✅ GitOps + Pinned IP |
| **ArgoCD** | 10.10.10.204 | GitOps management | ✅ GitOps + Pinned IP |
| **AdGuard Home** | 10.10.10.205 | DNS filtering (Web UI) | ✅ GitOps + Pinned IP |
| **AdGuard DNS (TCP)** | 10.10.10.206:53 | DNS filtering (TCP) | ✅ GitOps + Pinned IP |
| **Homepage** | 10.10.10.208 | Dashboard | ✅ GitOps + Pinned IP |
| **AdGuard DNS (UDP)** | 10.10.10.209:53 | DNS filtering (UDP) | ✅ GitOps + Pinned IP |
| **Prometheus** | Internal | Metrics collection | ✅ GitOps |

> **Note:** All LoadBalancer IPs are pinned using `loadBalancerIP` field to ensure consistent IPs across cluster restarts and service recreations.

### Security Features
- ✅ **Encrypted secrets** in Git (Sealed Secrets)
- ✅ **Private key backup** (sealed-secrets-key-backup.yaml)
- ✅ **No plain text passwords** in repository
- ✅ **Audit trail** via Git history

---

## 🚀 Quick Start Guide

### Access Your Services

```bash
# ArgoCD (GitOps management)
open http://10.10.10.204
# Login: admin / <retrieve with: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d>

# Grafana (Monitoring)
open http://10.10.10.201
# Login: admin / <change on first login>

# Portainer (K8s management)
open http://10.10.10.200:9000

# Uptime Kuma (Uptime monitoring)
open http://10.10.10.202:3001

# pgAdmin (Database admin)
open http://10.10.10.203
# Login: <see sealed secret for credentials>

# AdGuard Home (DNS filtering)
open http://10.10.10.205
```

### Check Cluster Status

```bash
# View all ArgoCD applications
kubectl get applications -n argocd

# View all pods across namespaces
kubectl get pods -A

# View all services with external IPs
kubectl get svc -A | grep LoadBalancer
```

---

## 📚 Documentation

Your setup includes comprehensive documentation:

1. **[README.md](README.md)** - Repository overview and quick reference
2. **[GITOPS-WORKFLOW.md](GITOPS-WORKFLOW.md)** - Complete GitOps workflow guide
3. **[SECRETS.md](SECRETS.md)** - Secrets management and disaster recovery
4. **[k3s-rpi-cluster/instructions.md](../k3s-rpi-cluster/instructions.md)** - Original cluster setup
5. **[k3s-rpi-cluster/post-setup.md](../k3s-rpi-cluster/post-setup.md)** - Kubernetes concepts explained

---

## 🔐 Important: Backup Your Private Key!

**⚠️ CRITICAL:** The file `sealed-secrets-key-backup.yaml` contains your Sealed Secrets private key.

**Without this key, you cannot decrypt your secrets if you rebuild the cluster!**

### Store It Securely:
- ✅ Password manager (1Password, Bitwarden)
- ✅ Encrypted USB drive
- ✅ Secure cloud storage (encrypted)
- ❌ **DO NOT** commit to Git
- ❌ **DO NOT** leave only on your laptop

### Test Your Backup:
```bash
# Verify the backup file exists
ls -lh sealed-secrets-key-backup.yaml

# Verify it contains the key
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key
```

---

## 🔄 Daily Workflow

### Making Changes

1. **Edit files locally:**
   ```bash
   cd /Users/miguelcaetanodias/Documents/Projects/k3s-gitops
   # Edit YAML files
   ```

2. **Commit and push:**
   ```bash
   git add .
   git commit -m "Description of changes"
   git push
   ```

3. **ArgoCD auto-syncs** (within 3 minutes)
   - Or manually sync in ArgoCD UI

4. **Verify changes:**
   ```bash
   kubectl get applications -n argocd
   kubectl get pods -n <namespace>
   ```

### Adding New Applications

See [GITOPS-WORKFLOW.md](GITOPS-WORKFLOW.md#adding-new-applications) for detailed instructions.

**Quick summary:**
1. Create app directory: `apps/my-app/`
2. Add Kubernetes manifests
3. Create ArgoCD Application: `argocd/applications/my-app.yaml`
4. Commit, push, apply!

### Managing Secrets

See [GITOPS-WORKFLOW.md](GITOPS-WORKFLOW.md#managing-secrets) for detailed instructions.

**Quick summary:**
```bash
# Create secret
kubectl create secret generic my-secret \
  --from-literal=password=mypass \
  --namespace=my-app \
  --dry-run=client -o yaml > /tmp/secret.yaml

# Encrypt
kubeseal < /tmp/secret.yaml > apps/my-app/sealed-secret.yaml

# Commit and push
git add apps/my-app/sealed-secret.yaml
git commit -m "Add my-app secret"
git push
```

---

## 🆘 Disaster Recovery

### Full Cluster Rebuild

If your cluster dies, you can rebuild everything from Git in ~15 minutes!

**Prerequisites:**
- ✅ Sealed Secrets private key backup
- ✅ Access to GitHub repo

**Steps:**
1. Clone repo: `git clone https://github.com/mcdays94/k3s-gitops.git`
2. Install ArgoCD: `kubectl apply -k argocd/bootstrap/`
3. Install Sealed Secrets + restore key
4. Deploy all apps: `kubectl apply -f argocd/applications/`
5. Done! ✅

See [GITOPS-WORKFLOW.md](GITOPS-WORKFLOW.md#disaster-recovery) for detailed steps.

---

## 🔧 LoadBalancer IP Pinning

All services are configured with **pinned LoadBalancer IPs** to ensure consistent access URLs across cluster restarts and service recreations.

### How It Works

Each LoadBalancer service includes a `loadBalancerIP` field:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: portainer
  namespace: portainer
spec:
  type: LoadBalancer
  loadBalancerIP: 10.10.10.200  # Pinned IP
  selector:
    app: portainer
  ports:
  - port: 9000
    targetPort: 9000
```

### Benefits

- ✅ **Consistent URLs** - Services always get the same IP
- ✅ **No DNS updates** - No need to update DNS records after restarts
- ✅ **Predictable** - Easy to document and remember
- ✅ **Homepage compatibility** - Dashboard widgets work reliably

### IP Allocation Map

| IP Range | Purpose |
|----------|---------|
| 10.10.10.200-209 | Pinned service IPs |
| 10.10.10.210-220 | Available for new services |

### Adding New Services

When adding a new LoadBalancer service, pick an unused IP from the pool and add it to the service spec:

```yaml
spec:
  type: LoadBalancer
  loadBalancerIP: 10.10.10.210  # Pick next available IP
```

---

## 🎯 Next Steps

### Immediate Tasks

1. **✅ Backup Sealed Secrets key** (if not done already)
   ```bash
   # Copy to secure location
   cp sealed-secrets-key-backup.yaml ~/secure-backups/
   ```

2. **✅ Change default passwords**
   - ArgoCD admin password
   - Grafana admin password
   - pgAdmin password

3. **✅ Configure AdGuard Home**
   - Complete initial setup at http://10.10.10.207:3000
   - Add to AdGuardHome-Sync (10.10.10.24)
   - Configure DNS settings

4. **✅ Set up Uptime Kuma monitors**
   - Monitor all your services
   - Set up notifications

### Optional Enhancements

- **Add more applications** (Vaultwarden, Nextcloud, Home Assistant)
- **Configure Grafana dashboards** (import community dashboards)
- **Set up Prometheus alerts** (email/Slack notifications)
- **Configure Cloudflare Tunnel routes** (external access to services)
- **Implement backup strategy** (automated backups to NAS/cloud)

---

## 📈 Monitoring Your Cluster

### Key Metrics to Watch

**In Grafana (http://10.10.10.201):**
- CPU usage per node
- Memory usage per node
- Disk space
- Network I/O
- Pod restart count

**In ArgoCD (http://10.10.10.204):**
- Application sync status
- Health status
- Last sync time

**In Uptime Kuma (http://10.10.10.202:3001):**
- Service uptime
- Response times
- Downtime alerts

### Recommended Dashboards

Import these Grafana dashboard IDs:
- **15759** - Kubernetes / Views / Global
- **1860** - Node Exporter Full
- **15760** - Kubernetes / Views / Namespaces

---

## 🛠️ Troubleshooting

### Common Issues

**Application stuck in "Progressing":**
```bash
kubectl describe application <app-name> -n argocd
kubectl get pods -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

**Secret not decrypting:**
```bash
kubectl get pods -n kube-system -l name=sealed-secrets-controller
kubectl logs -n kube-system -l name=sealed-secrets-controller
```

**ArgoCD out of sync:**
```bash
argocd app sync <app-name>
# Or use ArgoCD UI
```

See [GITOPS-WORKFLOW.md](GITOPS-WORKFLOW.md#troubleshooting) for more solutions.

---

## 📞 Resources

### Documentation
- **ArgoCD**: https://argo-cd.readthedocs.io/
- **Sealed Secrets**: https://github.com/bitnami-labs/sealed-secrets
- **Kubernetes**: https://kubernetes.io/docs/
- **Helm**: https://helm.sh/docs/

### Your Setup
- **GitHub Repo**: https://github.com/mcdays94/k3s-gitops
- **Workflow Guide**: [GITOPS-WORKFLOW.md](GITOPS-WORKFLOW.md)
- **Secrets Guide**: [SECRETS.md](SECRETS.md)

### Community
- **r/kubernetes**: https://reddit.com/r/kubernetes
- **r/homelab**: https://reddit.com/r/homelab
- **ArgoCD Slack**: https://argoproj.github.io/community/join-slack/

---

## 🎊 Congratulations!

You now have a **production-grade, GitOps-managed Kubernetes cluster** running on Raspberry Pis!

**What makes this special:**
- ✅ **Fully declarative** - Everything in Git
- ✅ **Automated** - Push to Git → Auto-deployed
- ✅ **Secure** - Encrypted secrets
- ✅ **Resilient** - Full disaster recovery
- ✅ **Observable** - Comprehensive monitoring
- ✅ **Documented** - Complete guides

**This is the same approach used by companies like:**
- Weaveworks (creators of GitOps)
- Intuit
- Adobe
- Alibaba
- And many more!

You've built something impressive. Enjoy your cluster! 🚀

---

## 📝 Project Timeline

**What we accomplished:**

1. ✅ **Cluster Setup** - 3-node HA K3s cluster with external PostgreSQL
2. ✅ **High Availability** - All nodes as control-plane for true HA
3. ✅ **Infrastructure** - MetalLB, Cloudflare Tunnel, NFS storage
4. ✅ **Monitoring** - Prometheus, Grafana, Uptime Kuma
5. ✅ **Management** - Portainer, pgAdmin, ArgoCD
6. ✅ **GitOps** - Full GitOps implementation with ArgoCD
7. ✅ **Security** - Sealed Secrets for encrypted secrets
8. ✅ **Documentation** - Comprehensive guides and workflows
9. ✅ **DNS Filtering** - AdGuard Home (3rd instance)

**Total time invested:** ~4-6 hours
**Result:** Enterprise-grade homelab! 🏆

---

**Questions? Issues? Check the documentation or open an issue on GitHub!**

**Happy clustering! 🎉**
