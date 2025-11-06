#!/bin/bash
set -euo pipefail

BASE_DIR="${MEMPOOL_BASE_DIR:-/opt/mempool}"
NETWORK="${1:-mainnet}"

compose="${BASE_DIR}/${NETWORK}/docker-compose.yml"
if [[ ! -f "$compose" ]]; then
  echo "compose file not found for $NETWORK"
  exit 1
fi

docker compose -f "$compose" ps
