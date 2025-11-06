#!/bin/bash

# Config get script for Hydra-Pool Start9 package
set -e

# Read current configuration from config.toml
CONFIG_FILE="/var/lib/hydrapool/config.toml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found"
    exit 1
fi

# Function to extract value from config file
get_config_value() {
    local key="$1"
    local default="$2"
    
    if grep -q "^${key}" "$CONFIG_FILE"; then
        grep "^${key}" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d ' "' | sed 's/^"//;s/"$//'
    else
        echo "$default"
    fi
}

# Output configuration as JSON
echo "{"
echo "  \"bitcoin-network\": \"$(get_config_value 'network' 'signet')\","
echo "  \"bootstrap-address\": \"$(get_config_value 'bootstrap_address' '')\","
echo "  \"pool-fee\": \"$(get_config_value 'fee' '0')\","
echo "  \"donation-fee\": \"$(get_config_value 'donation' '50')\","
echo "  \"difficulty-multiplier\": \"$(get_config_value 'difficulty_multiplier' '1.0')\","
echo "  \"pool-signature\": \"$(get_config_value 'pool_signature' 'hydrapool')\","
echo "  \"log-level\": \"$(get_config_value 'level' 'info')\","
echo "  \"bitcoin-rpc-url\": \"$(get_config_value 'url' 'http://bitcoind.embassy:8332')\","
echo "  \"bitcoin-rpc-user\": \"$(get_config_value 'username' '')\","
echo "  \"bitcoin-rpc-password\": \"[REDACTED]\","
echo "  \"bitcoin-zmq-url\": \"$(get_config_value 'zmqpubhashblock' 'tcp://bitcoind.embassy:28334')\""
echo "}"