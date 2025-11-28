# Homepage Public

Public-facing version of the homelab dashboard for embedding in mdias.info blog.

## Features

**Included:**

- ✅ Kubernetes cluster stats (CPU, memory, node count)
- ✅ AdGuard Home statistics (query counts only)
- ✅ Home Assistant power consumption widget
- ✅ Uptime Kuma service status
- ✅ Link back to mdias.info blog

**Removed for security:**

- ❌ pgAdmin (database management)
- ❌ Proxmox (infrastructure access)
- ❌ Portainer (container management)
- ❌ ArgoCD (deployment access)
- ❌ Grafana (detailed metrics)
- ❌ All clickable service links (view-only)
- ❌ Google search bar

## Deployment

### 1. Copy secrets from homepage namespace

```bash
chmod +x copy-secrets.sh
./copy-secrets.sh
```

### 2. Apply manifests

```bash
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f homepage-public.yaml
```

### 3. Verify deployment

```bash
kubectl get pods -n homepage-public
kubectl get svc -n homepage-public
```

## Access

- **LoadBalancer IP:** 10.10.10.210
- **Intended domain:** homelab.mdias.info (via Cloudflare Tunnel)

## Customization

The `custom.css` and `custom.js` in the ConfigMap can be updated to match mdias.info's theme:

1. Update colors and fonts to match your blog
2. Adjust light/dark mode styling
3. Modify layout spacing and sizing

## Security Notes

- All service links are disabled via CSS and JavaScript
- Only read-only widgets are exposed
- No management interfaces are accessible
- Secrets are only used for read-only API access to widgets
