# AdGuard Home

DNS-level ad blocker and privacy protection for your network.

## Services

| Service | IP | Port |
|---------|-----|------|
| Web UI | 10.10.10.205 | 80 |
| DNS (TCP) | 10.10.10.206 | 53 |
| DNS (UDP) | 10.10.10.209 | 53 |

## AdGuard Home Instances

This is one of 3 AdGuard Home instances, kept in sync via AdGuardHome-Sync:

| Instance | Location | IP |
|----------|----------|-----|
| Origin | Ubuntu Server (Docker) | 10.10.10.79 |
| Pi4 | Raspberry Pi 4 (Docker) | 10.10.10.23 |
| K3s | This cluster | 10.10.10.205 |

AdGuardHome-Sync runs on the Pi4 (10.10.10.23) and replicates config from the origin to all replicas.

## Storage

- **Work data** (logs, stats): PVC on local-path
- **Config data** (settings, filters): PVC on local-path

Both backed up weekly to Cloudflare R2 via K8up.

## DNS Configuration

Point your router/devices to use these DNS servers for redundancy:
- Primary: 10.10.10.209 (K3s UDP)
- Secondary: 10.10.10.79 (Origin)
- Tertiary: 10.10.10.23 (Pi4)
