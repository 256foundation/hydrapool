# Hydra-Pool - Setup Instructions

## Prerequisites

- **Bitcoin Core** must be installed and fully synced on your StartOS server.
- Bitcoin Core must have **ZMQ block notifications** enabled (this is auto-configured when you install Hydra-Pool).

## Initial Configuration

1. Install Hydra-Pool from the Start9 marketplace (or sideload the `.s9pk` file).
2. Go to **Hydra-Pool > Config** in the StartOS dashboard.
3. Set your **Bootstrap Address** — this is the Bitcoin address that receives payouts when a block is found before any miners have submitted shares. **Change this from the default.**
4. Adjust the **Pool Fee** and **Donation** settings if desired.
5. Click **Save** and start the service.

## Connecting Miners

Point your mining hardware or software to:

```
stratum+tcp://<your-tor-address>:3333
```

You can find your Tor address in the StartOS dashboard under **Hydra-Pool > Interfaces > Stratum Mining**.

For LAN connections, use the LAN address shown in the interfaces section.

**Username:** Your Bitcoin payout address (e.g., `bc1q...`)
**Password:** Anything (e.g., `x`)

## Monitoring

### Grafana Dashboard

Access the built-in Grafana monitoring dashboard from your StartOS dashboard under **Hydra-Pool > Interfaces > Grafana Dashboard**.

Default credentials:
- **Username:** `admin`
- **Password:** `hydrapool`

The dashboard shows pool hashrate, connected miners, shares, and block statistics.

### API

The REST API is available at the **API & Metrics** interface. It provides:
- Pool statistics
- User/worker statistics
- Prometheus metrics endpoint at `/metrics`

## How Payouts Work

Hydra-Pool uses **PPLNS (Pay Per Last N Shares)** accounting:
- Payouts are made **directly from the coinbase transaction** when a block is found.
- There is **no fund custody** — miners receive their share directly in the mined block.
- The PPLNS window is determined by the **Difficulty Multiplier** and **PPLNS Share TTL** settings.

## Security Notes

- All external connections are routed through **Tor** by default.
- The pool does **not custody any funds** — all payouts are made directly via coinbase outputs.
- API access requires authentication (auto-generated credentials).

## Troubleshooting

### Service won't start
- Ensure Bitcoin Core is running and fully synced.
- Check the service logs in StartOS for error details.

### No miners connecting
- Verify your Tor address is correct.
- Ensure your miner is configured with a valid Bitcoin address as the username.
- Check that port 3333 is accessible (shown as healthy in the dashboard).

### Grafana shows no data
- Wait a few minutes after starting — Prometheus needs time to collect initial metrics.
- Verify the API health check is passing (green in the StartOS dashboard).
