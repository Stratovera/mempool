# Monitoring

Monitoring is optional but enabled by default (`MONITORING_ENABLED=true`).

## Components
- `prometheus-${NETWORK}` with config rendered to `${MEMPOOL_BASE_DIR}/${network}/monitoring/prometheus/prometheus.yml`
- `grafana-${NETWORK}` pre-provisioned with a Prometheus datasource
- Exporters: node (host), bitcoin RPC, MariaDB exporter

## Setup
```bash
make monitoring       # re-render configs if you edit templates
sudo make deploy      # starts exporters + dashboards alongside the stack
```

Prometheus listens on `${NETWORK}_PROMETHEUS_PORT` and Grafana on `${NETWORK}_GRAFANA_PORT` (defaults 9090/3000 for mainnet, 9190/3100 for signet). Expose them through a reverse proxy if you want remote access.

## Customizing Dashboards
Add JSON dashboards to `templates/grafana/` and reference them from `dashboards.yml.tmpl`. Re-run `make monitoring` followed by `sudo make deploy` to refresh the Grafana provisioning volume.
