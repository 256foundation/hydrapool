# Hydra-Pool Start9 Installation Instructions

## Quick Start

1. **Install Bitcoin Node**: Ensure `bitcoind` service is running on your Start9 server
2. **Install Hydra-Pool**: Download and install the `.s9pk` package from StartOS Marketplace
3. **Configure**: Set your Bitcoin network and bootstrap address
4. **Connect Miners**: Point your miners to `stratum://your-start9-address:3333`

## Detailed Configuration

### Step 1: Bitcoin Network Selection

Choose the network you want to mine on:
- **Mainnet**: Real Bitcoin mining (requires full sync)
- **Testnet4**: Test network for development
- **Signet**: Signet test network (recommended for testing)

### Step 2: Bootstrap Address

Enter a Bitcoin address that will receive payouts for blocks found in the first 10 seconds. This is a safety mechanism to ensure the pool operator gets compensated for immediate block finds.

### Step 3: Pool Configuration (Optional)

- **Pool Fee**: Set operator fee (0-1000 basis points, where 100 = 1%)
- **Developer Donation**: Support Hydra-Pool development (0-500 basis points)
- **Difficulty Multiplier**: Adjust PPLNS window calculation (default: 1.0)
- **Pool Signature**: Identify your pool in blockchain (max 16 characters)

### Step 4: Mining Connection

Configure your mining software:

```
URL: stratum://your-start9-address:3333
Username: your-bitcoin-address
Password: worker-name (optional)
```

### Step 5: Monitoring

Access the Grafana dashboard through StartOS to monitor:
- Pool hashrate and statistics
- Individual miner performance
- Block finds and payouts
- System health metrics

## Security Notes

- Your Bitcoin RPC credentials are automatically configured from your bitcoind service
- API authentication is handled automatically with secure credentials
- All services are accessible through Tor for privacy
- No funds are custodied by the pool operator

## Troubleshooting

If miners cannot connect:

1. Verify your Bitcoin node is fully synced
2. Check that the network settings match your Bitcoin node
3. Ensure your Start9 server has sufficient resources
4. Review service logs in StartOS for error messages

For additional support, see the main README.md file or visit the Hydra-Pool GitHub repository.