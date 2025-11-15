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

Your AdGuardHome-Sync instance is running at **10.10.10.24** (Pi4 Docker container).

### Add This K3s Instance to Sync

1. **Get the AdGuard Home web UI IP:**
   ```bash
   kubectl get svc -n adguard-home adguard-home-web
   # Use the EXTERNAL-IP (e.g., 10.10.10.207)
   ```

2. **Complete initial setup:**
   - Access: `http://10.10.10.207:3000`
   - Set admin username/password
   - Configure DNS settings

3. **Update AdGuardHome-Sync configuration:**
   
   SSH into your Pi4 (10.10.10.24) and edit the sync config:
   
   ```yaml
   # Add this K3s instance to your sync configuration
   replicas:
     - url: http://10.10.10.70:3000  # Proxmox VM
       username: admin
       password: your-password
     
     - url: http://YOUR_OTHER_PI_IP:3000  # Other Pi4
       username: admin
       password: your-password
     
     - url: http://10.10.10.207:3000  # K3s instance (NEW!)
       username: admin
       password: your-password
   ```

4. **Restart AdGuardHome-Sync:**
   ```bash
   docker restart adguardhome-sync
   ```

5. **Verify sync:**
   - Check sync logs: `docker logs adguardhome-sync`
   - All 3 instances should now have identical settings!

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
