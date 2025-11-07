#!/bin/bash

# Restore script for Hydra-Pool Start9 package
set -e

BACKUP_DIR="$1"
if [ -z "$BACKUP_DIR" ]; then
    echo "Usage: $0 <backup_directory>"
    exit 1
fi

if [ ! -d "$BACKUP_DIR" ]; then
    echo "Error: Backup directory does not exist"
    exit 1
fi

echo "Restoring Hydra-Pool from backup..."

# Stop services before restore
echo "Stopping services..."
supervisorctl stop hydrapool prometheus grafana || true

# Restore Hydra-Pool data
if [ -d "$BACKUP_DIR/hydrapool-data" ]; then
    echo "Restoring Hydra-Pool data..."
    mkdir -p /var/lib/hydrapool
    rm -rf /var/lib/hydrapool/*
    cp -r "$BACKUP_DIR/hydrapool-data"/* /var/lib/hydrapool/ 2>/dev/null || true
    chown -R hydrapool:hydrapool /var/lib/hydrapool
fi

# Restore Prometheus data
if [ -d "$BACKUP_DIR/prometheus-data" ]; then
    echo "Restoring Prometheus data..."
    mkdir -p /var/lib/prometheus
    rm -rf /var/lib/prometheus/*
    cp -r "$BACKUP_DIR/prometheus-data"/* /var/lib/prometheus/ 2>/dev/null || true
    chown -R hydrapool:hydrapool /var/lib/prometheus
fi

# Restore Grafana data
if [ -d "$BACKUP_DIR/grafana-data" ]; then
    echo "Restoring Grafana data..."
    mkdir -p /var/lib/grafana
    rm -rf /var/lib/grafana/*
    cp -r "$BACKUP_DIR/grafana-data"/* /var/lib/grafana/ 2>/dev/null || true
    chown -R hydrapool:hydrapool /var/lib/grafana
fi

# Restore configuration
if [ -f "$BACKUP_DIR/config/config.toml" ]; then
    echo "Restoring configuration..."
    cp "$BACKUP_DIR/config/config.toml" /var/lib/hydrapool/config.toml
    chown hydrapool:hydrapool /var/lib/hydrapool/config.toml
fi

# Start services after restore
echo "Starting services..."
supervisorctl start prometheus grafana hydrapool

echo "Restore completed successfully"