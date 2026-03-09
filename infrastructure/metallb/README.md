# MetalLB Configuration

MetalLB v0.14.8 provides LoadBalancer services for the bare-metal k3s cluster.

## IP Address Pool

**Range:** 10.10.10.200 - 10.10.10.220
**Network:** 10.10.10.0/24
**Mode:** L2 Advertisement

## Current Allocations

| IP | Service |
|-----|---------|
| 10.10.10.200 | Portainer |
| 10.10.10.201 | Grafana |
| 10.10.10.202 | Uptime Kuma |
| 10.10.10.203 | pgAdmin |
| 10.10.10.204 | ArgoCD |
| 10.10.10.205 | AdGuard Home (Web) |
| 10.10.10.206 | AdGuard DNS (TCP) |
| 10.10.10.207 | Pocket ID |
| 10.10.10.208 | Homepage |
| 10.10.10.209 | AdGuard DNS (UDP) |
| 10.10.10.210 | Homepage Public |
| 10.10.10.211-220 | Available |

## Installation

MetalLB is installed via native manifest (not managed by ArgoCD):

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
```

Then apply the IP pool and L2 advertisement from this directory:

```bash
kubectl apply -f ipaddresspool.yaml
kubectl apply -f l2advertisement.yaml
```

## IP Assignment

Services request specific IPs via the `metallb.universe.tf/loadBalancerIPs` annotation (not `spec.loadBalancerIP`, which is deprecated).
