# GridPool Hydrapool Monitoring

Local, tailnet-only monitoring for the native Hydrapool process used by the
GridPool public beta.

## Start

```bash
cd /home/keegreil/Documents/GitHub/hydrapool/monitoring-gridpool
docker compose up -d
```

## Endpoints

- Grafana: `http://100.86.192.114:3300`
- Prometheus: `http://127.0.0.1:9090`
- Hydrapool API source: `http://127.0.0.1:46884`

Prometheus and Grafana use host networking so Prometheus can scrape the native
Hydrapool process bound to `127.0.0.1:46884`. Prometheus is bound to localhost
only. Grafana is bound to the host's Tailscale IP only. It should not be
reachable from the public internet unless Tailscale or firewall routing is
changed.

## Useful Checks

```bash
docker compose ps
curl -fsS http://127.0.0.1:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health, scrapeUrl, lastError}'
curl -fsS -u hydrapool:hydrapool http://127.0.0.1:46884/metrics | head
```
