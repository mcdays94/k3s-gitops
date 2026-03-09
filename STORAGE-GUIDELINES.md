# Storage Guidelines for K3s Cluster

## Current Storage Architecture

All persistent volumes use the **`local-path`** storage provisioner built into k3s. Data is stored on the local disk of the node where the pod runs.

- **Storage path:** `/var/lib/rancher/k3s/storage/` on each node
- **Access mode:** `ReadWriteOnce` (single node)
- **Provisioner:** `rancher.io/local-path` (default storageClass)

## Current PVC Allocations

| Namespace | PVC | Size | Node |
|-----------|-----|------|------|
| monitoring | Prometheus data | 50Gi | (where pod runs) |
| monitoring | Grafana data | 1Gi | (where pod runs) |
| uptime-kuma | Uptime Kuma data | 5Gi | worker-01 |
| adguard-home | AdGuard work | 2Gi | (where pod runs) |
| adguard-home | AdGuard conf | 1Gi | (where pod runs) |
| portainer | Portainer data | 1Gi | (where pod runs) |
| pgadmin | pgAdmin data | 1Gi | (where pod runs) |
| pocket-id | Pocket ID data | 1Gi | worker-02 |

## Important Caveats

### Data is Node-Local

If a pod moves to a different node (e.g., node failure, drain, reschedule), it will get a **new empty PVC** on the new node. The old data remains on the original node but is not automatically migrated.

For a 3-node Raspberry Pi homelab cluster, this is acceptable because:
- Pod rescheduling is rare
- K8up weekly backups to R2 provide recovery capability
- Services can be rebuilt from backup if a node fails

### SD Card Wear

The Raspberry Pi 5 nodes use microSD cards (or USB/NVMe if you've added one). For high-write workloads like Prometheus, monitor disk health periodically:

```bash
# Check disk usage on each node
ssh mdias@10.10.10.71 "df -h /var/lib/rancher/k3s/storage/"
ssh mdias@10.10.10.72 "df -h /var/lib/rancher/k3s/storage/"
ssh mdias@10.10.10.73 "df -h /var/lib/rancher/k3s/storage/"
```

## When Adding New Applications

1. Use `local-path` storageClass (or omit storageClassName to use the default)
2. Size the PVC appropriately -- start small, you can always recreate larger
3. Add a K8up backup Schedule if the data matters (see `apps/k3s-backup/`)

**Example PVC:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-data
  namespace: my-app
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
```

## Monitoring Disk Usage

```bash
# Check which nodes have PVCs and how much space is used
kubectl get pvc -A

# Check node disk usage
kubectl top nodes
```

## Historical Note

The cluster previously used NFS storage from a Proxmox VM (10.10.10.70). This was migrated to local-path when the cluster was rebuilt with embedded etcd. See [MIGRATION-FROM-EXTERNAL-POSTGRES-TO-EMBEDDED-DB.md](MIGRATION-FROM-EXTERNAL-POSTGRES-TO-EMBEDDED-DB.md) for details.
