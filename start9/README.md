# Hydra-Pool for StartOS

This directory contains the Start9 package for Hydra-Pool, allowing it to run as a service on [StartOS](https://start9.com/).

The package bundles Hydra-Pool, Prometheus, and Grafana into a single container managed by supervisord.

## Prerequisites

- [start-sdk](https://github.com/Start9Labs/start-os) (v0.3.5+)
- Docker with buildx (multi-platform support)
- [Deno](https://deno.land/)
- [yq](https://github.com/mikefarah/yq)

### Installing start-sdk

```bash
git clone -b latest --recursive https://github.com/Start9Labs/start-os.git
cd start-os/core
./install-sdk.sh
start-sdk init
```

## Building

From the `start9/` directory:

```bash
# Full build (Docker images + pack + verify)
make

# Or from the project root with just:
just start9
```

This will:
1. Bundle the TypeScript procedures (`scripts/embassy.js`)
2. Build Docker images for aarch64 and x86_64
3. Pack everything into `hydrapool.s9pk`
4. Verify the package

## Installing

Sideload the `.s9pk` onto a running StartOS instance:

```bash
start-cli package install hydrapool.s9pk
```

Or upload `hydrapool.s9pk` through the StartOS web UI under **System > Sideload**.

## Architecture

```
StartOS
└── Hydra-Pool container (supervisord)
    ├── hydrapool        — Mining pool (ports 3333, 46884)
    ├── prometheus       — Metrics collection (port 9090)
    └── grafana          — Monitoring dashboards (port 3000)
```

### Interfaces

| Interface | Port | Access | Description |
|-----------|------|--------|-------------|
| Stratum | 3333 | Tor | Mining protocol for connecting miners |
| API | 46884 | Tor + LAN | REST API and Prometheus metrics |
| Grafana | 3000 | Tor + LAN | Monitoring dashboard (UI) |

### Dependencies

- **Bitcoin Core** — required, auto-configured for RPC and ZMQ

### Configuration

User-configurable settings are defined in `assets/compat/config_spec.yaml`. Bitcoin RPC and ZMQ settings are auto-configured from the bitcoind dependency.

## File Structure

```
start9/
├── Makefile                 # Build automation
├── manifest.yaml            # Start9 package manifest
├── Dockerfile               # Multi-service container (multi-stage)
├── docker_entrypoint.sh     # Init script + config generation
├── supervisord.conf         # Process manager for 3 services
├── health_check.sh          # Health check dispatcher
├── check-api.sh             # API health check
├── check-stratum.sh         # Stratum port check
├── instructions.md          # User-facing setup guide
├── icon.png                 # Service icon
├── deps.ts                  # Embassy SDK dependency
├── assets/
│   └── compat/
│       └── config_spec.yaml # Configuration UI schema
└── scripts/
    ├── embassy.ts           # Entry point for TS procedures
    ├── bundle.ts            # Deno bundler
    └── services/
        ├── getConfig.ts     # Read config
        ├── setConfig.ts     # Validate + write config
        ├── properties.ts    # UI properties
        └── migrations.ts    # Version migrations
```
