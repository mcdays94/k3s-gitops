# Graceful Shutdown/Startup Checklist

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
ssh mdias@10.10.10.72 "sudo shutdown -h now"

# Worker 02
ssh mdias@10.10.10.73 "sudo shutdown -h now"

# Master (last!)
ssh mdias@10.10.10.71 "sudo shutdown -h now"
```

### Step 3: Shutdown Pi4 (1 min)
```bash
ssh migueldias@10.10.10.23 "sudo shutdown -h now"
```

### Step 4: Shutdown Proxmox + VMs (5 min)
```bash
# SSH to Proxmox
ssh root@10.10.10.96

# List all VMs
qm list

# Shutdown each VM gracefully
qm shutdown 100  # Ubuntu VM (10.10.10.79)
# Add more VMs if needed

# Wait for VMs to stop
watch -n 5 'qm list'

# Once all VMs are stopped, shutdown Proxmox host
shutdown -h now
```

### Step 5: Shutdown Other Devices
- Perform normal OS shutdown on any other machines

### Step 6: Wait for Complete Shutdown (3 min)
- Wait 3 minutes for all devices to fully power down
- Check that all LEDs are off

---

## Startup Sequence (15 minutes)

### Step 1: Power On (1 min)
- Turn on power (smart plug or manual)
- All devices should start powering on

### Step 2: Wait for Network (3 min)
- Wait for UniFi Gateway to boot (LED solid blue)
- Wait for PoE Switch to boot
- Test network: `ping 10.10.10.1`

### Step 3: Wait for Proxmox (3 min)
- Wait for Proxmox host to boot
- Test access: `ping 10.10.10.96`
- Start VMs if not auto-started: `qm start 100`

### Step 4: Wait for K3s Cluster (5 min)
```bash
# Check nodes are booting (will fail initially, keep trying)
kubectl get nodes

# Wait until all nodes show "Ready"
watch -n 5 'kubectl get nodes'

# Expected output:
# NAME             STATUS   ROLES                       AGE   VERSION
# k3s-master-01    Ready    control-plane,etcd,master   Xd    v1.34.5+k3s1
# k3s-worker-01    Ready    <none>                      Xd    v1.34.5+k3s1
# k3s-worker-02    Ready    <none>                      Xd    v1.34.5+k3s1
```

### Step 5: Uncordon Nodes (if drained)
```bash
kubectl uncordon k3s-worker-01
kubectl uncordon k3s-worker-02
```

### Step 6: Verify Pods (3 min)
```bash
# Check all pods are starting
kubectl get pods -A

# Wait for all pods to be Running
watch -n 5 'kubectl get pods -A | grep -v Running | grep -v Completed'
```

---

## Post-Startup Verification (5 minutes)

### 1. Check PVCs
```bash
# Verify all PVCs are Bound
kubectl get pvc -A
```

### 2. Check ArgoCD
```bash
# Verify all applications are synced
kubectl get applications -n argocd

# If any are OutOfSync, they should self-heal within 3 minutes
# Or manually sync via ArgoCD UI at https://10.10.10.204
```

### 3. Check Services
```bash
curl -I http://10.10.10.208       # Homepage
curl -I http://10.10.10.202:3001  # Uptime Kuma
curl -I http://10.10.10.201       # Grafana
curl -I http://10.10.10.205       # AdGuard Home
curl -I http://10.10.10.207       # Pocket ID
```

### 4. Check Sealed Secrets
```bash
kubectl get pods -n kube-system | grep sealed-secrets

# If not running:
kubectl rollout restart deployment sealed-secrets-controller -n kube-system
```

---

## Troubleshooting

### Issue: Pods Stuck in Pending
```bash
kubectl describe pod <pod-name> -n <namespace>
# Check for: insufficient resources, PVC not bound, node not ready
```

### Issue: Sealed Secrets Not Decrypting
```bash
kubectl get pods -n kube-system | grep sealed-secrets
kubectl rollout restart deployment sealed-secrets-controller -n kube-system
```

### Issue: ArgoCD Applications OutOfSync
Normal after reboot. Self-heal should fix within 3 minutes. Otherwise:
- Go to ArgoCD UI at https://10.10.10.204
- Click application > Sync > Synchronize

---

## Estimated Timeline

| Phase | Duration | Notes |
|-------|----------|-------|
| Pre-checks | 5 min | Verify everything is healthy |
| Shutdown | 20 min | Graceful shutdown of all services |
| Hardware work | varies | Install smart plug, rearrange, etc. |
| Startup | 15 min | Wait for everything to boot |
| Verification | 5 min | Check all services are working |

---

## Success Criteria

- All 3 K3s nodes show "Ready"
- All pods are "Running" (except completed jobs)
- All ArgoCD applications are "Synced" and "Healthy"
- Homepage loads at http://10.10.10.208
- All PVCs are "Bound"
- Sealed secrets are decrypting correctly
