# MetalLB Configuration

MetalLB provides LoadBalancer services for bare-metal Kubernetes clusters.

## IP Address Pool

**Range:** 10.10.10.200 - 10.10.10.220  
**Network:** 10.10.10.0/24

## Current Allocations

- 10.10.10.200 - Portainer
- 10.10.10.201 - Grafana
- 10.10.10.202 - Uptime Kuma
- 10.10.10.203 - pgAdmin
- 10.10.10.204 - ArgoCD
- 10.10.10.205-220 - Available

## Installation

MetalLB itself is installed via Helm or manifest. This directory only contains the configuration (IPAddressPool and L2Advertisement).

To install MetalLB:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
```

Then apply this configuration.
