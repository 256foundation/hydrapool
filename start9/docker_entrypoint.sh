#!/bin/bash
set -euo pipefail

CONFIG_FILE="/data/start9/config.yaml"
HYDRAPOOL_CONFIG="/data/hydrapool/config.toml"
PROMETHEUS_CONFIG="/data/prometheus/prometheus.yml"
GRAFANA_INI="/data/grafana/grafana.ini"
AUTH_FILE="/data/hydrapool/auth_credentials"

echo "Starting Hydra-Pool Start9 entrypoint..."

# Create directories if they don't exist
mkdir -p /data/hydrapool /data/prometheus/data /data/grafana \
    /data/logs /data/start9

# Wait for Start9 config to be written
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Waiting for Start9 config at $CONFIG_FILE..."
    while [ ! -f "$CONFIG_FILE" ]; do
        sleep 1
    done
fi

echo "Reading configuration from $CONFIG_FILE..."

# Read config values using yq
NETWORK=$(yq e '.bitcoin-network // "main"' "$CONFIG_FILE")
BOOTSTRAP_ADDRESS=$(yq e '.bootstrap-address // "bc1qypskemx80lznv4tjpnmpw9c5pgpy32fpkk3sw2"' "$CONFIG_FILE")
POOL_FEE=$(yq e '.pool-fee // 0' "$CONFIG_FILE")
POOL_FEE_ADDRESS=$(yq e '.pool-fee-address // ""' "$CONFIG_FILE")
DONATION=$(yq e '.donation // 50' "$CONFIG_FILE")
DIFFICULTY_MULTIPLIER=$(yq e '.difficulty-multiplier // 1.0' "$CONFIG_FILE")
PPLNS_TTL_DAYS=$(yq e '.pplns-ttl-days // 7' "$CONFIG_FILE")
POOL_SIGNATURE=$(yq e '.pool-signature // "hydrapool"' "$CONFIG_FILE")
LOG_LEVEL=$(yq e '.log-level // "info"' "$CONFIG_FILE")

# Read bitcoind connection details from the Start9 dependency system.
# These are injected into /data/start9/config.yaml by StartOS when
# the bitcoind dependency is auto-configured.
BITCOIND_RPC_HOST=$(yq e '.bitcoind-rpc-host // "bitcoind.embassy"' "$CONFIG_FILE")
BITCOIND_RPC_PORT=$(yq e '.bitcoind-rpc-port // 8332' "$CONFIG_FILE")
BITCOIND_RPC_USER=$(yq e '.bitcoind-rpc-user // "hydrapool"' "$CONFIG_FILE")
BITCOIND_RPC_PASS=$(yq e '.bitcoind-rpc-pass // "hydrapool"' "$CONFIG_FILE")
BITCOIND_ZMQ_HOST=$(yq e '.bitcoind-zmq-host // "bitcoind.embassy"' "$CONFIG_FILE")
BITCOIND_ZMQ_PORT=$(yq e '.bitcoind-zmq-port // 28334' "$CONFIG_FILE")

# Generate API auth token if not already persisted
API_USER="hydrapool"
if [ ! -f "$AUTH_FILE" ]; then
    echo "Generating API authentication token..."
    API_PASS=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 24)
    AUTH_TOKEN=$(/usr/local/bin/hydrapool_cli gen-auth "$API_USER" "$API_PASS" 2>/dev/null || echo "")
    if [ -z "$AUTH_TOKEN" ]; then
        # Fallback: use a placeholder that will still allow the pool to start
        echo "Warning: Could not generate auth token, using default"
        AUTH_TOKEN="28a556ceb0b24c9b664d1e35a81239ed\$5c9fb3271b22be05eb87272ce11c3cad55242d045eb379873ce0dc821586204a"
        API_PASS="hydrapool"
    fi
    echo "$API_USER" > "$AUTH_FILE"
    echo "$API_PASS" >> "$AUTH_FILE"
    echo "$AUTH_TOKEN" >> "$AUTH_FILE"
    chmod 600 "$AUTH_FILE"
else
    API_USER=$(sed -n '1p' "$AUTH_FILE")
    API_PASS=$(sed -n '2p' "$AUTH_FILE")
    AUTH_TOKEN=$(sed -n '3p' "$AUTH_FILE")
fi

# Generate Hydra-Pool config.toml
echo "Generating Hydra-Pool config at $HYDRAPOOL_CONFIG..."
cat > "$HYDRAPOOL_CONFIG" << TOML
[store]
path = "/data/hydrapool/store.db"
background_task_frequency_hours = 24
pplns_ttl_days = ${PPLNS_TTL_DAYS}

[stratum]
hostname = "0.0.0.0"
port = 3333
start_difficulty = 1
minimum_difficulty = 1
bootstrap_address = "${BOOTSTRAP_ADDRESS}"
TOML

# Add optional donation config
if [ "$DONATION" -gt 0 ] 2>/dev/null; then
    cat >> "$HYDRAPOOL_CONFIG" << TOML
donation_address = "${BOOTSTRAP_ADDRESS}"
donation = ${DONATION}
TOML
fi

# Add optional fee config
if [ "$POOL_FEE" -gt 0 ] 2>/dev/null && [ -n "$POOL_FEE_ADDRESS" ] && [ "$POOL_FEE_ADDRESS" != "null" ]; then
    cat >> "$HYDRAPOOL_CONFIG" << TOML
fee_address = "${POOL_FEE_ADDRESS}"
fee = ${POOL_FEE}
TOML
fi

cat >> "$HYDRAPOOL_CONFIG" << TOML
zmqpubhashblock = "tcp://${BITCOIND_ZMQ_HOST}:${BITCOIND_ZMQ_PORT}"
network = "${NETWORK}"
version_mask = "1fffe000"
difficulty_multiplier = ${DIFFICULTY_MULTIPLIER}
TOML

# Add optional pool signature
if [ -n "$POOL_SIGNATURE" ] && [ "$POOL_SIGNATURE" != "null" ]; then
    cat >> "$HYDRAPOOL_CONFIG" << TOML
pool_signature = "${POOL_SIGNATURE}"
TOML
fi

cat >> "$HYDRAPOOL_CONFIG" << TOML

[bitcoinrpc]
url = "http://${BITCOIND_RPC_HOST}:${BITCOIND_RPC_PORT}"
username = "${BITCOIND_RPC_USER}"
password = "${BITCOIND_RPC_PASS}"

[logging]
level = "${LOG_LEVEL}"
stats_dir = "/data/hydrapool/stats"

[api]
hostname = "0.0.0.0"
port = 46884
auth_user = "${API_USER}"
auth_token = "${AUTH_TOKEN}"
TOML

chown hydrapool:hydrapool "$HYDRAPOOL_CONFIG"
echo "Hydra-Pool config generated."

# Generate Prometheus config
echo "Generating Prometheus config at $PROMETHEUS_CONFIG..."
cat > "$PROMETHEUS_CONFIG" << YAML
global:
  scrape_interval: 15s
  external_labels:
    monitor: 'hydrapool-start9'

scrape_configs:
  - job_name: 'Hydrapool'
    scrape_interval: 15s
    static_configs:
      - targets: ['localhost:46884']
    metric_relabel_configs:
      - source_labels: [__name__]
        regex: ''
        action: drop
    metrics_path: "/metrics"
    basic_auth:
      username: '${API_USER}'
      password: '${API_PASS}'
YAML

chown nobody:nogroup "$PROMETHEUS_CONFIG" 2>/dev/null || true
echo "Prometheus config generated."

# Update Grafana provisioning datasource to point to local Prometheus
mkdir -p /etc/grafana/provisioning/datasources
cat > /etc/grafana/provisioning/datasources/prometheus.yml << YAML
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: true
    jsonData:
      httpMethod: POST
      timeInterval: 5s
YAML

# Generate Grafana config
echo "Generating Grafana config at $GRAFANA_INI..."
cat > "$GRAFANA_INI" << INI
[server]
http_addr = 0.0.0.0
http_port = 3000
root_url = %(protocol)s://%(domain)s:%(http_port)s/

[security]
admin_user = admin
admin_password = hydrapool

[auth.anonymous]
enabled = true
org_role = Viewer

[dashboards]
default_home_dashboard_path = /etc/grafana/dashboards/pool.json

[paths]
data = /data/grafana
logs = /data/logs
plugins = /data/grafana/plugins
provisioning = /etc/grafana/provisioning
INI

chown -R 472:0 /data/grafana 2>/dev/null || true
echo "Grafana config generated."

# Set RUST_LOG for supervisord
export RUST_LOG="${LOG_LEVEL}"

echo "Starting services via supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
