# Configuration

All settings are shell-style `KEY=value` pairs. Defaults live in `config/defaults.conf`; user overrides go in `config/mempool-stack.conf` (generated via `make config`).

## Core Options
- `MEMPOOL_BASE_DIR` — absolute path for rendered artifacts (default `/opt/mempool`)
- `MEMPOOL_NETWORKS` — comma list (`mainnet,signet`)
- `ENABLE_SSL` / `DOMAIN_MAINNET` / `DOMAIN_SIGNET` — configure external TLS termination
- `ENABLE_UFW` — apply UFW allow rules for exposed ports
- `USE_EXTERNAL_BITCOIND` — skip bundled bitcoind container
- `BITCOIND_RPC_HOST` / `BITCOIND_RPC_PORT` / `BITCOIND_RPC_USER` / `BITCOIND_RPC_PASS` — RPC endpoint + credentials when using an external node
- `<NETWORK>_BIND_ADDRESS` — optional IPv4 per network (`MAINNET_BIND_ADDRESS`, `SIGNET_BIND_ADDRESS`) to pin published ports to a specific host interface
- `MONITORING_ENABLED` — render Prometheus/Grafana assets and add exporters (`MAINNET_PROMETHEUS_PORT`, `SIGNET_PROMETHEUS_PORT`, etc. control host ports)
- `MIN_DISK_GB` — minimum free disk required before deployment proceeds

## Per-Network Ports
`<NETWORK>_WEB_PORT`, `<NETWORK>_API_PORT`, `<NETWORK>_RPC_PORT`, `<NETWORK>_ELECTRS_PORT`, `<NETWORK>_P2P_PORT`, `<NETWORK>_PROMETHEUS_PORT`, `<NETWORK>_GRAFANA_PORT` (e.g., `MAINNET_WEB_PORT=8080`). Validation in `lib/config.sh` ensures they stay in 1024-65535.

## Database
`DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_ROOT_PASSWORD` control the MariaDB container and exporter connection string.

## Advanced
- Update image tags (`MEMPOOL_WEB_IMAGE`, `BITCOIND_IMAGE`, etc.) to pin releases.
- Edit template files in `templates/` to customize Compose fragments, Prometheus scrape jobs, or helper scripts.

After editing the config, rerun `sudo make deploy` to apply changes.
