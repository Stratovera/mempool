# Troubleshooting

| Symptom | Fix |
| --- | --- |
| `Missing required commands` | Run `make install` and ensure docker, docker compose, envsubst, openssl are installed. |
| `Insufficient disk space` | Increase the partition backing `MEMPOOL_BASE_DIR` or lower `MIN_DISK_GB`. |
| `Existing deployment detected` | Remove `${MEMPOOL_BASE_DIR}/<network>` or set `ALLOW_REDEPLOY=true` when running `make deploy`. |
| Containers exit immediately | Run `make logs NETWORK=mainnet SERVICE=api` (or `docker compose ps`) to inspect service logs. |
| Prometheus/Grafana missing | Ensure `MONITORING_ENABLED=true` and re-run `sudo make deploy`. |
| Firewall blocks traffic | Disable `ENABLE_UFW` or whitelist ports manually with `ufw allow <port>`. |

For deeper debugging, use the helper scripts rendered to `$MEMPOOL_BASE_DIR` (`start-all.sh`, `stop-all.sh`, `status.sh`, `logs.sh`, `backup.sh`).
