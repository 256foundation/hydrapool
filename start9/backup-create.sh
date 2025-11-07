#!/bin/bash

# Backup script for Hydra-Pool Start9 package
set -e

BACKUP_DIR="$1"
if [ -z "$BACKUP_DIR" ]; then
    echo "Usage: $0 <backup_directory>"
    exit 1
fi

echo "Creating Hydra-Pool backup..."

# Create backup directory structure
mkdir -p "$BACKUP_DIR/hydrapool-data"
mkdir -p "$BACKUP_DIR/prometheus-data"
mkdir -p "$BACKUP_DIR/grafana-data"
mkdir -p "$BACKUP_DIR/config"

# Backup Hydra-Pool data
if [ -d "/var/lib/hydrapool" ]; then
    echo "Backing up Hydra-Pool data..."
    cp -r /var/lib/hydrapool/* "$BACKUP_DIR/hydrapool-data/" 2>/dev/null || true
fi

# Backup Prometheus data
if [ -d "/var/lib/prometheus" ]; then
    echo "Backing up Prometheus data..."
    cp -r /var/lib/prometheus/* "$BACKUP_DIR/prometheus-data/" 2>/dev/null || true
fi

# Backup Grafana data
if [ -d "/var/lib/grafana" ]; then
    echo "Backing up Grafana data..."
    cp -r /var/lib/grafana/* "$BACKUP_DIR/grafana-data/" 2>/dev/null || true
fi

# Backup configuration
if [ -f "/var/lib/hydrapool/config.toml" ]; then
    echo "Backing up configuration..."
    cp /var/lib/hydrapool/config.toml "$BACKUP_DIR/config/"
fi

# Create backup metadata
cat > "$BACKUP_DIR/backup-info.json" << EOF
{
  "created": "$(date -Iseconds)",
  "version": "1.1.18",
  "components": {
    "hydrapool-data": "Hydra-Pool database and state",
    "prometheus-data": "Prometheus metrics storage",
    "grafana-data": "Grafana dashboards and configuration",
    "config": "Hydra-Pool configuration file"
  }
}
EOF

echo "Backup completed successfully"