#!/bin/bash

# Config set script for Hydra-Pool Start9 package
set -e

CONFIG_FILE="/var/lib/hydrapool/config.toml"
TEMPLATE_FILE="/etc/hydrapool/config.toml.template"

# Read JSON input
INPUT_JSON=$(cat)

# Function to extract JSON value
get_json_value() {
    local key="$1"
    echo "$INPUT_JSON" | jq -r ".$key // empty"
}

# Get configuration values
BITCOIN_NETWORK=$(get_json_value "bitcoin-network")
BOOTSTRAP_ADDRESS=$(get_json_value "bootstrap-address")
POOL_FEE=$(get_json_value "pool-fee")
DONATION_FEE=$(get_json_value "donation-fee")
DIFFICULTY_MULTIPLIER=$(get_json_value "difficulty-multiplier")
PPLNS_TTL_DAYS=$(get_json_value "pplns-ttl-days")
POOL_SIGNATURE=$(get_json_value "pool-signature")
LOG_LEVEL=$(get_json_value "log-level")
BITCOIN_RPC_URL=$(get_json_value "bitcoin-rpc-url")
BITCOIN_RPC_USER=$(get_json_value "bitcoin-rpc-user")
BITCOIN_RPC_PASSWORD=$(get_json_value "bitcoin-rpc-password")
BITCOIN_ZMQ_URL=$(get_json_value "bitcoin-zmq-url")

# Validate required fields
if [ -z "$BITCOIN_NETWORK" ] || [ -z "$BOOTSTRAP_ADDRESS" ] || [ -z "$BITCOIN_RPC_URL" ] || [ -z "$BITCOIN_RPC_USER" ] || [ -z "$BITCOIN_RPC_PASSWORD" ] || [ -z "$BITCOIN_ZMQ_URL" ]; then
    echo "Error: Required configuration fields are missing"
    exit 1
fi

# Copy template to new config
cp "$TEMPLATE_FILE" "$CONFIG_FILE"

# Update configuration file
sed -i "s/network = \".*\"/network = \"$BITCOIN_NETWORK\"/g" "$CONFIG_FILE"
sed -i "s/bootstrap_address = \".*\"/bootstrap_address = \"$BOOTSTRAP_ADDRESS\"/g" "$CONFIG_FILE"
sed -i "s/donation = .*/donation = $DONATION_FEE/g" "$CONFIG_FILE"
sed -i "s/fee = .*/fee = $POOL_FEE/g" "$CONFIG_FILE"
sed -i "s/difficulty_multiplier = .*/difficulty_multiplier = $DIFFICULTY_MULTIPLIER/g" "$CONFIG_FILE"
sed -i "s/pplns_ttl_days = .*/pplns_ttl_days = $PPLNS_TTL_DAYS/g" "$CONFIG_FILE"
sed -i "s/pool_signature = \".*\"/pool_signature = \"$POOL_SIGNATURE\"/g" "$CONFIG_FILE"
sed -i "s/level = \".*\"/level = \"$LOG_LEVEL\"/g" "$CONFIG_FILE"
sed -i "s|url = \".*\"|url = \"$BITCOIN_RPC_URL\"|g" "$CONFIG_FILE"
sed -i "s/username = \".*\"/username = \"$BITCOIN_RPC_USER\"/g" "$CONFIG_FILE"
sed -i "s/password = \".*\"/password = \"$BITCOIN_RPC_PASSWORD\"/g" "$CONFIG_FILE"
sed -i "s|zmqpubhashblock = \".*\"|zmqpubhashblock = \"$BITCOIN_ZMQ_URL\"|g" "$CONFIG_FILE"

# Set ownership
chown hydrapool:hydrapool "$CONFIG_FILE"

# Restart services to apply new configuration
echo "Configuration updated. Restarting services..."
supervisorctl restart hydrapool
supervisorctl restart prometheus

echo "Configuration applied successfully"