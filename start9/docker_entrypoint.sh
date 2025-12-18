#!/bin/bash

# Docker entrypoint script for Hydra-Pool Start9 package
set -e

# Function to generate random password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Function to update config file with environment variables
update_config() {
    local template_file="/etc/hydrapool/config.toml.template"
    local config_file="/etc/hydrapool/config.toml"
    
    # Copy template to config
    cp "$template_file" "$config_file"
    
    # Replace Bitcoin RPC settings if provided
    if [ -n "$BITCOIN_RPC_URL" ]; then
        sed -i "s|url = \".*\"|url = \"$BITCOIN_RPC_URL\"|g" "$config_file"
    fi
    
    if [ -n "$BITCOIN_RPC_USER" ]; then
        sed -i "s/username = \".*\"/username = \"$BITCOIN_RPC_USER\"/g" "$config_file"
    fi
    
    if [ -n "$BITCOIN_RPC_PASSWORD" ]; then
        sed -i "s/password = \".*\"/password = \"$BITCOIN_RPC_PASSWORD\"/g" "$config_file"
    fi
    
    # Replace ZMQ setting if provided
    if [ -n "$BITCOIN_ZMQ_URL" ]; then
        sed -i "s|zmqpubhashblock = \".*\"|zmqpubhashblock = \"$BITCOIN_ZMQ_URL\"|g" "$config_file"
    fi
    
    # Replace network if provided
    if [ -n "$BITCOIN_NETWORK" ]; then
        sed -i "s/network = \".*\"/network = \"$BITCOIN_NETWORK\"/g" "$config_file"
    fi
    
    # Replace bootstrap address if provided
    if [ -n "$BOOTSTRAP_ADDRESS" ]; then
        sed -i "s/bootstrap_address = \".*\"/bootstrap_address = \"$BOOTSTRAP_ADDRESS\"/g" "$config_file"
    fi
    
    # Generate API credentials if not set
    if [ -z "$API_USER" ]; then
        export API_USER="hydrapool"
    fi
    
    if [ -z "$API_TOKEN" ]; then
        # Generate hashed password
        local password=$(generate_password)
        local salt=$(openssl rand -hex 16)
        local hash=$(echo -n "${password}${salt}" | sha256sum | cut -d' ' -f1)
        export API_TOKEN="${hash}\$${salt}"
    fi
    
    # Update API credentials
    sed -i "s/auth_user = \".*\"/auth_user = \"$API_USER\"/g" "$config_file"
    sed -i "s/auth_token = \".*\"/auth_token = \"$API_TOKEN\"/g" "$config_file"
    
    # Set ownership
    chown hydrapool:hydrapool "$config_file"
}

# Function to update Prometheus config
update_prometheus_config() {
    local template_file="/etc/prometheus/prometheus.yml.template"
    local config_file="/etc/prometheus/prometheus.yml"
    
    # Copy template to config
    cp "$template_file" "$config_file"
    
    # Update basic auth credentials
    if [ -n "$API_USER" ] && [ -n "$API_TOKEN" ]; then
        sed -i "s/username: '.*'/username: '$API_USER'/g" "$config_file"
        sed -i "s/password: '.*'/password: '$API_TOKEN'/g" "$config_file"
    fi
    
    # Set ownership
    chown hydrapool:hydrapool "$config_file"
}

# Function to set Grafana admin credentials
set_grafana_credentials() {
    if [ -z "$GRAFANA_ADMIN_USER" ]; then
        export GRAFANA_ADMIN_USER="admin"
    fi
    
    if [ -z "$GRAFANA_ADMIN_PASSWORD" ]; then
        export GRAFANA_ADMIN_PASSWORD=$(generate_password)
    fi
}

# Main setup
echo "Initializing Hydra-Pool Start9 package..."

# Create log directories
mkdir -p /var/log/hydrapool /var/log/prometheus /var/log/grafana /var/log/supervisor
chown -R hydrapool:hydrapool /var/log/hydrapool /var/log/prometheus /var/log/grafana

# Update configurations
update_config
update_prometheus_config
set_grafana_credentials

echo "Configuration complete. Starting services..."

# Execute the command passed to this script
exec "$@"