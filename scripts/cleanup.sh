#!/bin/bash
set -euo pipefail

BASE_DIR="${MEMPOOL_BASE_DIR:-/opt/mempool}"
NETWORK="${1:-mainnet}"

compose="${BASE_DIR}/${NETWORK}/docker-compose.yml"
if [[ -f "$compose" ]]; then
  docker compose -f "$compose" down || true
fi
rm -rf "${BASE_DIR:?}/${NETWORK}"
