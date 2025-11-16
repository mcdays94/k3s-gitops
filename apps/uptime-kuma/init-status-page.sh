#!/bin/sh
# Auto-create default status page if it doesn't exist

DB_PATH="/app/data/kuma.db"
SLUG="default"
TITLE="Homelab Status"

# Wait for database to be ready
echo "Waiting for Uptime Kuma database..."
until [ -f "$DB_PATH" ]; do
  sleep 2
done

# Check if status page exists
STATUS_PAGE_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM status_page WHERE slug='$SLUG';" 2>/dev/null || echo "0")

if [ "$STATUS_PAGE_COUNT" = "0" ]; then
  echo "Status page '$SLUG' not found. Creating..."
  
  # Create status page
  sqlite3 "$DB_PATH" <<EOF
INSERT INTO status_page (slug, title, description, icon, theme, published, show_tags, custom_css, show_powered_by)
VALUES ('$SLUG', '$TITLE', 'Automated homelab monitoring', '/icon.svg', 'auto', 1, 0, '', 1);
EOF
  
  # Get the status page ID
  STATUS_PAGE_ID=$(sqlite3 "$DB_PATH" "SELECT id FROM status_page WHERE slug='$SLUG';")
  
  # Add all monitors to the status page
  MONITOR_IDS=$(sqlite3 "$DB_PATH" "SELECT id FROM monitor;")
  
  for MONITOR_ID in $MONITOR_IDS; do
    echo "Adding monitor $MONITOR_ID to status page..."
    sqlite3 "$DB_PATH" "INSERT OR IGNORE INTO status_page_cname (status_page_id, monitor_id) VALUES ($STATUS_PAGE_ID, $MONITOR_ID);"
  done
  
  echo "Status page created successfully!"
else
  echo "Status page '$SLUG' already exists. Skipping creation."
fi
