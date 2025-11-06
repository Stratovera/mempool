# mempool-stack

Modular bash toolkit that deploys the complete mempool.space stack (Bitcoin Core, electrs, MariaDB, backend API, frontend web, Prometheus/Grafana) for both Bitcoin mainnet and signet. The original monolithic `deploy-mempool.sh` has been split into libraries, templates, and tests so each concern can evolve independently.

## Highlights
- 10 reusable libraries under `lib/` (config, directories, docker-compose, monitoring, etc.)
- Template-based configuration (`templates/`) rendered with `envsubst` instead of heredocs
- Makefile-driven UX (`make install|config|deploy|start|stop|logs|backup|monitoring|test`)
- Fixes from `UPGRADE-PLAN.md`: safe permissions, disk validation, RPC credential handling, mysqldump backups, shell safety, monitoring stack
- CI via GitHub Actions (ShellCheck + `make test`)

## Quick Start
```bash
make install            # prerequisite check (docker, compose, envsubst, openssl)
make config             # create config/mempool-stack.conf interactively
sudo make deploy        # render configs, compose bundles, start containers
make status             # show container status for all networks
make logs NETWORK=mainnet SERVICE=api
```

Artifacts live under `$MEMPOOL_BASE_DIR/<network>/` (default `/opt/mempool`). Helper scripts such as `start-all.sh`, `stop-all.sh`, and `backup.sh` are rendered from templates so they inherit your custom base path.

Need to pin each network to a specific host IP? Set `MAINNET_BIND_ADDRESS` and `SIGNET_BIND_ADDRESS` in `config/mempool-stack.conf`. During template rendering, those values become host-side bindings (e.g., `192.0.2.10:8080:8080`) so mainnet and signet can listen on different addresses even if they share the same ports.

Exposed ports for bitcoind and electrs are controlled via the per-network config keys (`<NETWORK>_RPC_PORT`, `<NETWORK>_P2P_PORT`, `<NETWORK>_ELECTRS_PORT`), so you can align them with firewall rules or external reverse proxies without touching the templates.

## Credential Management
- Database passwords live in `config/.secrets/db-password` and are copied to `$MEMPOOL_BASE_DIR/<network>/secrets/db-password-<network>` during `sudo make deploy`. These files are `600` so Docker can bind-mount them as secrets without persisting credentials in version control.
- `sudo make deploy` now force-recreates every Compose project (`docker compose up -d --force-recreate --remove-orphans`) so refreshed configs or secrets immediately reach the running containers.
- Use `sudo bin/mempool-deploy rotate-credentials` whenever you need new RPC or MariaDB credentials. The command:
  1. Reads the existing root password from the secret store.
  2. Generates new DB + RPC secrets.
  3. Updates each MariaDB container before writing the new secrets to disk.
  4. Redeploys both networks so the services consume the rotated values.
- If the secret store is empty (fresh install), defaults from `config/defaults.conf` (`DB_PASSWORD_FALLBACK`, `DB_ROOT_PASSWORD_FALLBACK`) are written once and you can rotate afterward.

### Networking & Web/API access
- Each frontend publishes on `<NETWORK>_WEB_PORT` (default 9090) and proxies `/api/*` to the matching backend container over Docker’s internal network. You can hit the backend directly on `<NETWORK>_API_PORT` (default 9091) for debugging, but the UI always goes through the proxy.
- Host bindings can overlap across networks by pinning different `*_BIND_ADDRESS` values (e.g., mainnet on `10.10.10.181`, signet on `10.10.10.182`).
- To verify connectivity from another host:
  ```bash
  curl http://10.10.10.181:9090/api/v1/statistics/2h   # mainnet
  curl http://10.10.10.182:9090/api/v1/statistics/2h   # signet
  ```

### Bitcoind performance overrides
The bitcoind template now respects optional per-network tuning variables defined in `config/mempool-stack.conf`:

```
<NETWORK>_BITCOIND_DBCACHE
<NETWORK>_BITCOIND_MAX_CONNECTIONS
<NETWORK>_BITCOIND_MAX_OUTBOUND
<NETWORK>_BITCOIND_MAX_UPLOAD_TARGET
<NETWORK>_BITCOIND_PARALLELISM   # maps to bitcoind's "par" option
```

Set them in your config (e.g., `MAINNET_BITCOIND_DBCACHE=8192`) and re-run `sudo make deploy`; the rendered `bitcoin.conf` picks up the parameters automatically. Example for a 10 Gbps host:

```bash
MAINNET_BITCOIND_DBCACHE=8192
MAINNET_BITCOIND_MAX_CONNECTIONS=256
MAINNET_BITCOIND_MAX_OUTBOUND=32
MAINNET_BITCOIND_MAX_UPLOAD_TARGET=0
MAINNET_BITCOIND_PARALLELISM=32
```

Duplicate the lines with `SIGNET_...` prefixes if you want the same policy there. Leave any variable blank to fall back to Bitcoin Core defaults.

## Repository Layout
```
bin/                # mempool-deploy CLI entrypoint
lib/                # bash libraries (<200 lines each)
templates/          # docker-compose services, configs, management scripts
config/             # defaults + user config template
tests/              # unit and integration smoke tests
docs/               # INSTALLATION, CONFIGURATION, ARCHITECTURE, etc.
.github/workflows/  # CI & release pipelines
```

## Development
```bash
make test                  # runs unit + integration shell tests
find . -name "*.sh" -print0 | xargs -0 shellcheck
```
See `docs/ARCHITECTURE.md` for module boundaries and `docs/UPGRADE-GUIDE.md` for migration notes from the legacy script.

## License
See [LICENSE](LICENSE).
