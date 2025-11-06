# Architecture

## Module Overview
- `lib/common.sh` — logging, validation utilities, root checks
- `lib/config.sh` — config loading, interactive setup, validation, `get_networks`
- `lib/prerequisites.sh` — dependency checks for docker, compose, envsubst, openssl
- `lib/directories.sh` — disk validation, directory creation with correct ownership (Fix 1.1/2.1/2.2)
- `lib/bitcoind.sh` — RPC credential generation (kept in-memory) and bitcoin.conf rendering (Fix 1.3)
- `lib/mempool.sh` — renders `mempool-config.json` per network
- `lib/docker-compose.sh` — exposes `render_template` and assembles docker-compose.yml from service templates
- `lib/firewall.sh` — optional UFW allow rules for all exposed ports
- `lib/monitoring.sh` — Prometheus/Grafana provisioning (Fix 3.5)
- `lib/deployment.sh` — orchestration: deploy/start/stop/status/logs/backup/test

Each file is <200 LoC and can be sourced independently for unit tests.

## Template Pipeline
1. Config + library exports produce environment variables
2. `envsubst` renders:
   - Docker Compose fragments (`templates/docker-compose/services/*.yml`)
   - Config files (`templates/configs/*.tmpl`)
   - Helper scripts (`templates/scripts/*.tmpl`)
   - Monitoring definitions (`templates/grafana/*.yml`)
3. `lib/docker-compose.sh` concatenates base + services into `${MEMPOOL_BASE_DIR}/${network}/docker-compose.yml`

## Data Layout
```
${MEMPOOL_BASE_DIR}/
  mainnet/
    docker-compose.yml
    bitcoin.conf
    mempool-config.json
    data/{bitcoin,mysql,api,electrs}
    monitoring/{prometheus,grafana}
```
Ownership aligns with container UIDs (999 for MariaDB, 1000 for everything else).

## Fix Integration Summary
- **1.1** Permissions handled in `lib/directories.sh`
- **1.2** Helper scripts now templated and inherit `MEMPOOL_BASE_DIR`
- **1.3** RPC credentials never touch disk
- **2.1** Disk space check before directory creation
- **2.2** Deployment aborts when existing compose files detected
- **2.3** `set -euo pipefail` enforced in `bin/mempool-deploy` and templates
- **2.4** Backup template uses `mysqldump` with streaming output
- **2.5** Validations in `lib/common.sh` + `lib/config.sh`
- **3.5** Monitoring module renders Prometheus/Grafana assets and docker services
