#!/bin/bash

# Bitcoin auto-configure script for Hydra-Pool
set -e

# Get Bitcoin configuration from StartOS environment
BITCOIN_RPC_URL="${BITCOIN_RPC_URL:-http://bitcoind.embassy:8332}"
BITCOIN_RPC_USER="${BITCOIN_RPC_USER:-}"
BITCOIN_RPC_PASSWORD="${BITCOIN_RPC_PASSWORD:-}"
BITCOIN_ZMQ_URL="${BITCOIN_ZMQ_URL:-tcp://bitcoind.embassy:28334}"

CONFIG_FILE="/var/lib/hydrapool/config.toml"

echo "Auto-configuring Hydra-Pool for Bitcoin node..."

# Update configuration file
if [ -f "$CONFIG_FILE" ]; then
    # Backup original config
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup"
    
    # Update RPC settings
    sed -i "s|url = \".*\"|url = \"$BITCOIN_RPC_URL\"|g" "$CONFIG_FILE"
    
    if [ -n "$BITCOIN_RPC_USER" ]; then
        sed -i "s/username = \".*\"/username = \"$BITCOIN_RPC_USER\"/g" "$CONFIG_FILE"
    fi
    
    if [ -n "$BITCOIN_RPC_PASSWORD" ]; then
        sed -i "s/password = \".*\"/password = \"$BITCOIN_RPC_PASSWORD\"/g" "$CONFIG_FILE"
    fi
    
    # Update ZMQ setting
    sed -i "s|zmqpubhashblock = \".*\"|zmqpubhashblock = \"$BITCOIN_ZMQ_URL\"|g" "$CONFIG_FILE"
    
    # Set ownership
    chown hydrapool:hydrapool "$CONFIG_FILE"
    
    echo "✓ Bitcoin configuration updated"
else
    echo "✗ Configuration file not found"
    exit 1
fi

# Test the configuration
echo "Testing Bitcoin connection..."
if /usr/local/bin/bitcoin-check.sh; then
    echo "✓ Bitcoin auto-configuration successful"
else
    echo "✗ Bitcoin auto-configuration failed"
    # Restore backup
    if [ -f "$CONFIG_FILE.backup" ]; then
        mv "$CONFIG_FILE.backup" "$CONFIG_FILE"
    fi
    exit 1
fi