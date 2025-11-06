# Installation

## Prerequisites
- Ubuntu/Debian host with sudo access
- Docker Engine + Docker Compose V2 plugin
- `git`, `envsubst` (gettext-base), `openssl`, `tar`, `ufw`

## Steps
1. Clone the repo and enter it:
   ```bash
   git clone https://github.com/your-org/mempool-stack.git
   cd mempool-stack
   ```
2. Run the prerequisite check:
   ```bash
   make install
   ```
3. Generate a user config:
   ```bash
   make config
   ```
   This writes `config/mempool-stack.conf`. Edit it to adjust ports, domains, or disable networks.
4. Deploy:
   ```bash
   sudo make deploy
   ```
   Deployment renders templates into `$MEMPOOL_BASE_DIR/<network>/`, pulls container images, and starts Docker Compose stacks.

## Post-Install
- `make status` — confirm containers are healthy
- `make logs NETWORK=mainnet SERVICE=api` — tail a service
- `curl http://<MAINNET_BIND_ADDRESS>:<MAINNET_WEB_PORT>/api/v1/statistics/2h` — verify the nginx proxy reaches the backend (repeat for signet)
- `make monitoring` — re-render Prometheus/Grafana configs after edits

## Upgrades
Re-run `sudo make deploy` after updating templates or images. Existing directories are protected; delete the network dir if you want a clean redeploy.
