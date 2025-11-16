# Smart Plug Installation - Graceful Shutdown/Startup Checklist

## Pre-Shutdown Checks (5 minutes)

### 1. Verify Cluster Health
```bash
# Check all nodes are ready
kubectl get nodes

# Check for any failing pods
kubectl get pods -A | grep -v Running | grep -v Completed

# Verify ArgoCD applications
kubectl get applications -n argocd
```

### 2. Check NFS Storage
```bash
# Verify NFS is accessible
ssh ubuntu@10.10.10.71
df -h | grep nfs
exit
```

---

## Shutdown Sequence (20 minutes)

### Step 1: Drain K3s Worker Nodes (5 min)
```bash
# Drain worker-01 (moves pods to other nodes)
kubectl drain k3s-worker-01 --ignore-daemonsets --delete-emptydir-data --timeout=300s

# Drain worker-02
kubectl drain k3s-worker-02 --ignore-daemonsets --delete-emptydir-data --timeout=300s

# Verify pods moved
kubectl get pods -A -o wide | grep worker
```

### Step 2: Shutdown K3s Nodes (5 min)
```bash
# Worker 01
ssh ubuntu@10.10.10.72
sudo shutdown -h now

# Worker 02
ssh ubuntu@10.10.10.73
sudo shutdown -h now

# Master (last!)
ssh ubuntu@10.10.10.71
sudo shutdown -h now
```

### Step 3: Shutdown Pi4 (1 min)
```bash
ssh pi@10.10.10.23
sudo shutdown -h now
```

### Step 4: Shutdown Proxmox VMs (5 min)
```bash
# SSH to Proxmox
ssh root@10.10.10.96

# List all VMs
qm list

# Shutdown each VM gracefully (replace IDs with your actual VM IDs)
qm shutdown 100  # Ubuntu VM
# Add more VMs if you have them

# Wait for VMs to stop (check every 30 seconds)
watch -n 5 'qm list'

# Once all VMs are stopped, shutdown Proxmox host
shutdown -h now
```

### Step 5: Shutdown Gaming Rig (2 min)
- Perform normal OS shutdown (Windows/Linux)

### Step 6: Wait for Complete Shutdown (3 min)
- ⏰ Wait 3 minutes for all devices to fully power down
- Check that all LEDs are off on devices

---

## Hardware Installation (5 minutes)

### Step 1: Power Off
- [ ] Unplug power brick from wall outlet

### Step 2: Install Smart Plug
- [ ] Plug smart plug into wall outlet
- [ ] Configure smart plug (if needed)
- [ ] Plug power brick into smart plug

### Step 3: Verify
- [ ] Smart plug LED is on
- [ ] Smart plug is controllable from app

---

## Startup Sequence (15 minutes)

### Step 1: Power On (1 min)
- [ ] Turn on smart plug
- [ ] All devices should start powering on

### Step 2: Wait for Network (3 min)
- [ ] Wait for UniFi Gateway to boot (LED solid blue)
- [ ] Wait for PoE Switch to boot (all port LEDs active)
- [ ] Test network: `ping 10.10.10.1`

### Step 3: Wait for Proxmox (3 min)
- [ ] Wait for Proxmox host to boot
- [ ] Test access: `ping 10.10.10.96`
- [ ] Access Proxmox UI: https://10.10.10.96:8006

### Step 4: Start Proxmox VMs (2 min)
```bash
# SSH to Proxmox
ssh root@10.10.10.96

# Check VM status
qm list

# Start VMs if not auto-started
qm start 100  # Ubuntu VM
# Add more VMs if needed

# Verify VMs are running
qm list
```

### Step 5: Wait for K3s Cluster (5 min)
```bash
# Check nodes are booting (will fail initially, keep trying)
kubectl get nodes

# Wait until all nodes show "Ready"
watch -n 5 'kubectl get nodes'

# Expected output:
# NAME             STATUS   ROLES                  AGE   VERSION
# k3s-master       Ready    control-plane,master   XXd   v1.33.5+k3s1
# k3s-worker-01    Ready    <none>                 XXd   v1.33.5+k3s1
# k3s-worker-02    Ready    <none>                 XXd   v1.33.5+k3s1
```

### Step 6: Verify Pods (3 min)
```bash
# Check all pods are starting
kubectl get pods -A

# Wait for all pods to be Running
watch -n 5 'kubectl get pods -A | grep -v Running | grep -v Completed'

# Check for any issues
kubectl get pods -A | grep -E 'Error|CrashLoop|Pending'
```

---

## Post-Startup Verification (5 minutes)

### 1. Check Storage
```bash
# Verify NFS mounts
kubectl get pv
kubectl get pvc -A

# If any PVs are not Bound, remount NFS on nodes:
ssh ubuntu@10.10.10.71
sudo mount -a
df -h | grep nfs
exit
```

### 2. Check ArgoCD
```bash
# Verify all applications are synced
kubectl get applications -n argocd

# If any are OutOfSync, sync them:
# - Go to ArgoCD UI: http://10.10.10.204
# - Click on the application
# - Click "Sync"
```

### 3. Check Services
```bash
# Test Homepage
curl -I http://10.10.10.208

# Test Uptime Kuma
curl -I http://10.10.10.202:3001

# Test Prometheus
curl -I http://10.10.10.201

# Test AdGuard
curl -I http://10.10.10.207
```

### 4. Check Sealed Secrets
```bash
# Verify sealed-secrets controller is running
kubectl get pods -n kube-system | grep sealed-secrets

# If not running, restart it:
kubectl rollout restart deployment sealed-secrets-controller -n kube-system
```

---

## Troubleshooting

### Issue: Pods Stuck in Pending
**Cause:** Node not ready or storage not available

**Solution:**
```bash
# Check node status
kubectl get nodes

# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# If storage issue, remount NFS
ssh ubuntu@10.10.10.71
sudo mount -a
```

### Issue: Sealed Secrets Not Decrypting
**Cause:** Sealed secrets controller not running

**Solution:**
```bash
# Check controller
kubectl get pods -n kube-system | grep sealed-secrets

# Restart controller
kubectl rollout restart deployment sealed-secrets-controller -n kube-system

# Wait for it to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=sealed-secrets -n kube-system --timeout=60s
```

### Issue: ArgoCD Applications OutOfSync
**Cause:** Normal after reboot

**Solution:**
- Go to ArgoCD UI: http://10.10.10.204
- Click each application
- Click "Sync" → "Synchronize"

### Issue: NFS Mount Fails
**Cause:** NFS server (10.10.10.70) not accessible

**Solution:**
```bash
# Check NFS server is reachable
ping 10.10.10.70

# Check NFS exports
showmount -e 10.10.10.70

# Manually mount on each node
ssh ubuntu@10.10.10.71
sudo mount -a
```

---

## Estimated Timeline

| Phase | Duration | Notes |
|-------|----------|-------|
| Pre-checks | 5 min | Verify everything is healthy |
| Shutdown | 20 min | Graceful shutdown of all services |
| Hardware work | 5 min | Install smart plug |
| Startup | 15 min | Wait for everything to boot |
| Verification | 5 min | Check all services are working |
| **Total** | **50 min** | Add 10 min buffer for issues |

---

## Success Criteria

- [ ] All K3s nodes show "Ready"
- [ ] All pods are "Running" (except completed jobs)
- [ ] All ArgoCD applications are "Synced" and "Healthy"
- [ ] Homepage loads at http://10.10.10.208
- [ ] All widgets show correct data (no API errors)
- [ ] NFS storage is accessible (all PVs "Bound")
- [ ] Sealed secrets are decrypting correctly

---

## Emergency Rollback

If something goes wrong and you can't recover:

1. **Power off everything** via smart plug
2. **Remove smart plug** and plug power brick directly
3. **Power on** and follow startup sequence
4. **Debug issues** without time pressure
5. **Reinstall smart plug** once everything is stable
