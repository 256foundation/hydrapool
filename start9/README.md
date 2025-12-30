# Hydra-Pool Start9 Package

This package provides [Hydra-Pool](https://hydrapool.org) as a Start9 service. Hydra-Pool is an open source Bitcoin mining pool with support for solo mining and PPLNS (Pay Per Last N Shares) accounting.

## Features

- **Private Mining Pool**: Run your own solo or PPLNS mining pool
- **Direct Coinbase Payouts**: No custody - payouts go directly from coinbase
- **Share Accounting API**: Download and validate all share accounting data
- **Comprehensive Monitoring**: Built-in Prometheus and Grafana dashboards
- **Multi-Network Support**: Mainnet, Testnet4, and Signet support
- **Tor Integration**: Full StartOS Tor compatibility

## Installation

### Prerequisites

- StartOS server with internet access
- Bitcoin node service (bitcoind) installed and running
- Sufficient disk space for data storage

### Install from Package

1. Download the latest `.s9pk` package from the [releases page](https://github.com/256-Foundation/Hydra-Pool/releases)
2. In StartOS, navigate to **Marketplace**
3. Click **Install Package** and upload the `.s9pk` file
4. Follow the configuration wizard

### Build from Source

For developers who want to build the package:

```bash
git clone https://github.com/256-Foundation/Hydra-Pool.git
cd Hydra-Pool/start9
make build-release
make pack
```

## Configuration

### Required Settings

- **Bitcoin Network**: Choose mainnet, testnet4, or signet
- **Bootstrap Address**: Bitcoin address for early block payouts
- **Bitcoin RPC Connection**: Auto-configured from your bitcoind service

### Optional Settings

- **Pool Fee**: Operator fee (100 = 1%)
- **Developer Donation**: Support development (100 = 1%)
- **Difficulty Multiplier**: PPLNS window calculation (default: 1.0)
- **Pool Signature**: Identify your pool in blocks (max 16 bytes)
- **Log Level**: Logging verbosity (error, warn, info, debug, trace)

## Services and Ports

The package includes multiple services accessible through StartOS:

### Mining Services

- **Stratum Port (3333)**: Mining protocol connection
  - Connect your miners here: `stratum://your-start9-address:3333`
- **API Server (46884)**: REST API for pool management
  - Access pool statistics and configuration

### Monitoring Services

- **Prometheus (9090)**: Metrics collection
  - Raw metrics endpoint for monitoring
- **Grafana (3000)**: Dashboard interface
  - Pre-configured mining pool dashboards
  - Default credentials: admin/admin (change immediately)

## Usage

### Connecting Miners

Configure your mining software to connect to:

```
Stratum URL: stratum://your-start9-address:3333
Username: your-bitcoin-address
Password: any-string (worker identifier)
```

### Monitoring

1. Access Grafana dashboard through StartOS service interface
2. View pool hashrate, user statistics, and worker performance
3. Monitor system health through StartOS health checks

### API Access

The API server provides endpoints for:
- Pool statistics
- User information
- Share accounting data
- Configuration management

API documentation is available at `http://your-start9-address:46884/docs`

## Security

- **No Fund Custody**: Pool operator never handles funds
- **Transparent Accounting**: All share data publicly verifiable
- **Tor Integration**: All services accessible via Tor
- **API Authentication**: Secure API access with configurable credentials

## Backup and Restore

The package includes automated backup of:
- Pool database and state
- Prometheus metrics data
- Grafana dashboards and configuration
- Pool configuration settings

Use StartOS backup/restore functionality to preserve your mining operation.

## Troubleshooting

### Common Issues

1. **Miners cannot connect**
   - Check Bitcoin node is running and synced
   - Verify network configuration matches your Bitcoin node
   - Check StartOS firewall settings

2. **No payouts appearing**
   - Verify bootstrap address is correct
   - Check pool has found blocks
   - Confirm minimum payout thresholds

3. **Dashboard not loading**
   - Restart the service through StartOS
   - Check available disk space
   - Verify all services are healthy

### Logs

Access service logs through StartOS or directly:
- Hydra-Pool: `/var/log/hydrapool/`
- Prometheus: `/var/log/prometheus/`
- Grafana: `/var/log/grafana/`

## Development

### Building the Package

```bash
# Development build
make dev-build

# Full package build
make build-release
make pack

# Verify package integrity
make verify
```

### Testing

```bash
# Run tests
make dev-test

# Lint code
make dev-lint
```

### Package Structure

```
start9/
├── Dockerfile                 # Multi-service container definition
├── manifest.yaml             # Start9 package metadata
├── Makefile                  # Build automation
├── docker_entrypoint.sh      # Service initialization
├── health_check.sh           # Health monitoring
├── config-get.sh             # Configuration retrieval
├── config-set.sh             # Configuration updates
├── backup-create.sh          # Data backup
├── backup-restore.sh         # Data restore
├── bitcoin-check.sh          # Bitcoin node verification
├── bitcoin-autoconfigure.sh  # Bitcoin integration
├── supervisord.conf          # Service management
└── assets/compat/            # Configuration specifications
    ├── config_spec.yaml
    └── config_rules.yaml
```

## Support

- **Documentation**: [Hydra-Pool Wiki](https://github.com/256-Foundation/Hydra-Pool/wiki)
- **Issues**: [GitHub Issues](https://github.com/256-Foundation/Hydra-Pool/issues)
- **Community**: [Telegram](https://t.me/hydrapool)

## License

This package is licensed under AGPL-3.0. See the [LICENSE](../LICENSE) file for details.

## Contributing

Contributions are welcome! Please see the [contributing guidelines](../CONTRIBUTING.md) for information on how to contribute to Hydra-Pool.