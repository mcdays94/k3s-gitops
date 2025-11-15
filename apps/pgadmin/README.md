# pgAdmin

PostgreSQL administration and visualization tool.

## Secret Required

Create the pgAdmin secret before deploying:

```bash
kubectl create secret generic pgadmin-secret \
  --from-literal=password=YOUR_SECURE_PASSWORD \
  -n pgadmin
```

Or use Sealed Secrets (recommended for GitOps).

## Access

- URL: http://10.10.10.203
- Email: admin@admin.com
- Password: (from secret)

## Connecting to PostgreSQL

- Host: 10.10.10.70
- Port: 5432
- Username: k3s or postgres
- Password: (your PostgreSQL password)
