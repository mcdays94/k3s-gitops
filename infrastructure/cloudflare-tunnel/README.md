# Cloudflare Tunnel

Cloudflare Tunnel (cloudflared) deployment for external access to cluster services via Cloudflare Zero Trust.

## Secret

The tunnel token is managed via Sealed Secrets (`sealed-secret.yaml`). The token is obtained from Cloudflare Zero Trust Dashboard > Access > Tunnels.

## Configuration

The tunnel is configured via the **Cloudflare Dashboard** (token-based config, not local config files):
https://one.dash.cloudflare.com/

Routes are managed there, pointing to the cluster's MetalLB LoadBalancer IPs.

## Authentication

External access is protected by Cloudflare Access with Pocket ID as the OIDC identity provider. Access policies use OIDC group claims for authorization.
