# pgAdmin

PostgreSQL administration and visualization tool.

## Access

- URL: http://10.10.10.203
- Email: admin@admin.com
- Password: (from sealed secret)

## Secret

The pgAdmin password is managed via Sealed Secrets (`sealed-secret.yaml`).

## Storage

- 1Gi PVC on local-path
- Backed up weekly to Cloudflare R2 via K8up
