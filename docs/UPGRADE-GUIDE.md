# Upgrade Guide

## From Legacy `deploy-mempool.sh`
1. Back up `/opt/mempool` (or your custom base dir)
2. Clone this repo and run `make config` to recreate settings. Match the answers you used previously.
3. Compare the generated `config/mempool-stack.conf` with your old script variables (`MEMPOOL_BASE_DIR`, port overrides, domains, external bitcoind).
4. Run `sudo make deploy`. Existing network directories are detected—remove them if you want a pristine redeploy.

## Applying Future Changes
- Update image tags or templates → `sudo make deploy`
- Pull git updates → `git pull && sudo make deploy`
- Changes to Prometheus/Grafana → `make monitoring && sudo make deploy`

## Rollback
`start-all.sh`/`stop-all.sh` continue to work because they are rendered per deployment. Use `git checkout <tag>` plus `sudo make deploy` to recreate older templates.
