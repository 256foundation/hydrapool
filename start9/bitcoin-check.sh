#!/bin/bash

# Bitcoin dependency check script for Hydra-Pool
set -e

# Check if Bitcoin node is accessible
BITCOIN_RPC_URL="${BITCOIN_RPC_URL:-http://bitcoind.embassy:8332}"
BITCOIN_RPC_USER="${BITCOIN_RPC_USER:-}"
BITCOIN_RPC_PASSWORD="${BITCOIN_RPC_PASSWORD:-}"

echo "Checking Bitcoin node connectivity..."

# Test RPC connection
if command -v curl >/dev/null 2>&1; then
    if [ -n "$BITCOIN_RPC_USER" ] && [ -n "$BITCOIN_RPC_PASSWORD" ]; then
        RESPONSE=$(curl -s -u "$BITCOIN_RPC_USER:$BITCOIN_RPC_PASSWORD" \
            --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "getblockchaininfo", "params": []}' \
            -H 'content-type: text/plain;' "$BITCOIN_RPC_URL" 2>/dev/null || echo "")
    else
        RESPONSE=$(curl -s \
            --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "getblockchaininfo", "params": []}' \
            -H 'content-type: text/plain;' "$BITCOIN_RPC_URL" 2>/dev/null || echo "")
    fi
    
    if echo "$RESPONSE" | jq -e '.result' >/dev/null 2>&1; then
        CHAIN=$(echo "$RESPONSE" | jq -r '.result.chain')
        BLOCKS=$(echo "$RESPONSE" | jq -r '.result.blocks')
        echo "✓ Bitcoin node is accessible"
        echo "  Chain: $CHAIN"
        echo "  Blocks: $BLOCKS"
        exit 0
    else
        echo "✗ Bitcoin node is not accessible"
        echo "  Response: $RESPONSE"
        exit 1
    fi
else
    echo "✗ curl command not available for Bitcoin node check"
    exit 1
fi