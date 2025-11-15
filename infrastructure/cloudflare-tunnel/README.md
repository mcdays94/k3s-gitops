# Cloudflare Tunnel

This directory contains the Cloudflare Tunnel (cloudflared) deployment for external access to cluster services.

## Secret Management

The `tunnel-token` secret contains sensitive Cloudflare credentials and should NOT be committed to Git in plain text.

### Option 1: Manual Secret Creation (Current)

The secret already exists in your cluster. To recreate it:

```bash
kubectl create secret generic tunnel-token \
  --from-literal=token=YOUR_TUNNEL_TOKEN \
  -n cloudflare-tunnel
```

### Option 2: Sealed Secrets (Recommended for GitOps)

We'll set up Sealed Secrets in Phase 5 to encrypt this secret for safe Git storage.

## Deployment

This deployment runs 2 replicas of cloudflared for high availability.

## Configuration

The tunnel is configured via the Cloudflare Dashboard at:
https://one.dash.cloudflare.com/

Routes are managed there, pointing to your cluster's LoadBalancer IPs:
- Portainer: 10.10.10.200:9000
- Grafana: 10.10.10.201
- Uptime Kuma: 10.10.10.202:3001
- pgAdmin: 10.10.10.203
- ArgoCD: 10.10.10.204
