# AdGuard Home

DNS-level ad blocker and privacy protection for your network.

## Overview

This is your **3rd AdGuard Home instance** that syncs with:
- Proxmox VM instance
- Raspberry Pi 4 instance (outside cluster)

## Services

**Web UI:**
- LoadBalancer IP will be assigned (likely 10.10.10.205)
- Port 80 (HTTP), 443 (HTTPS), 3000 (initial setup)

**DNS Services:**
- Separate LoadBalancer IPs for TCP and UDP DNS (port 53)
- This allows you to use this instance as a DNS server

## Initial Setup

1. Access web UI at `http://<LOADBALANCER-IP>:3000`
2. Complete initial setup wizard
3. Configure AdGuard Sync to sync with your other instances

## AdGuard Sync Configuration

To sync with your existing instances:

1. Install AdGuard Sync on all instances
2. Configure sync settings to include this K3s instance
3. All settings, filters, and blocklists will sync automatically

## High Availability

With 3 instances:
- Proxmox VM
- Raspberry Pi 4
- K3s Cluster (this one)

You have redundancy if any single instance goes down!

## DNS Configuration

Point your devices/router to use multiple DNS servers:
- Primary: Proxmox VM IP
- Secondary: This K3s instance IP
- Tertiary: Raspberry Pi 4 IP

## Storage

- **Work data**: 2Gi PVC (logs, stats)
- **Config data**: 1Gi PVC (settings, filters)

Both use local-path storage on the cluster.
