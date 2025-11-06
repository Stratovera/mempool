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
