# Storage Guidelines for K3s Cluster

## ⚠️ SD Card Protection

The K3s worker nodes run on Raspberry Pi with microSD cards. To prevent SD card wear and failure, **all applications with frequent writes must use NFS storage**.

## Storage Classes

### 🚫 `local-path` (Avoid for databases/logs)
- **Location:** Node's local storage (`/var/lib/rancher/k3s/storage/`)
- **Medium:** microSD card on Raspberry Pi nodes
- **Use for:** Temporary data, caches, read-only configs
- **Avoid for:** Databases, logs, anything with frequent writes

### ✅ NFS Storage (Preferred for persistent data)
- **Location:** NFS server at `10.10.10.70:/srv/nfs/`
- **Medium:** Proxmox VM with proper storage
- **Use for:** Databases, logs, application data, anything with frequent writes

## Current NFS Volumes

All high-write applications have been migrated to NFS to protect SD cards:

```
/srv/nfs/
├── prometheus/      (50Gi) - Prometheus metrics database
├── uptime-kuma/     (5Gi)  - Uptime Kuma monitoring database
├── adguard-work/    (5Gi)  - AdGuard Home DNS query logs
├── adguard-conf/    (2Gi)  - AdGuard Home configuration
└── portainer/       (10Gi) - Portainer container management data
```

**Total NFS Usage:** 72Gi allocated

**Remaining on SD cards (local-path):**
- `pgadmin` (1Gi) - Low-write UI configuration only - acceptable to keep on SD

## When Adding New Applications

**Before deploying:**
1. ✅ Check if the app writes frequently (databases, logs, caches)
2. ✅ If yes, create NFS PV/PVC instead of using `local-path`
3. ✅ Create directory on NFS server: `sudo mkdir -p /srv/nfs/<app-name>`
4. ✅ Set permissions: `sudo chmod 777 /srv/nfs/<app-name> && sudo chown debian:2000 /srv/nfs/<app-name>`

## NFS PV Template

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: <app>-nfs-pv
  labels:
    app: <app>
spec:
  capacity:
    storage: <size>Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: 10.10.10.70
    path: /srv/nfs/<app>
  mountOptions:
    - nfsvers=4
    - hard
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: <app>-pvc
  namespace: <namespace>
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ""
  resources:
    requests:
      storage: <size>Gi
  selector:
    matchLabels:
      app: <app>
```

## Migration Checklist

When moving existing apps from `local-path` to NFS:

1. Scale down deployment: `kubectl scale deployment <name> -n <namespace> --replicas=0`
2. Find PVC volume path: `kubectl get pv <pv-name> -o yaml | grep path`
3. Backup data from node to NFS
4. Delete old PVC/PV
5. Apply new NFS PV/PVC configuration
6. Scale up deployment: `kubectl scale deployment <name> -n <namespace> --replicas=1`
7. Verify data is intact

## Monitoring

Monitor NFS usage:
```bash
ssh debian@10.10.10.70 "df -h /srv/nfs"
```

Check which apps are still on SD cards:
```bash
kubectl get pvc --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,STORAGECLASS:.spec.storageClassName
```

Look for `local-path` - these should be evaluated for migration to NFS.
