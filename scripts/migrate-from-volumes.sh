#!/bin/bash
set -euo pipefail

BASE_DIR="${MEMPOOL_BASE_DIR:-/opt/mempool}"
OUTPUT_DIR="${BASE_DIR}/volume-migrations"
mkdir -p "$OUTPUT_DIR"

volumes=(
  mempool-mysql-mainnet
  mempool-api-mainnet
  mempool-electrs-mainnet
  mempool-bitcoin-mainnet
  mempool-mysql-signet
  mempool-api-signet
  mempool-electrs-signet
  mempool-bitcoin-signet
)

for volume in "${volumes[@]}"; do
  if docker volume inspect "$volume" >/dev/null 2>&1; then
    echo "Exporting $volume"
    docker run --rm \
      -v "$volume:/data" \
      -v "$OUTPUT_DIR:/backup" \
      busybox sh -c "cd /data && tar -czf /backup/${volume}.tar.gz ."
  fi
done

echo "Tarballs stored in $OUTPUT_DIR. Extract them into ${BASE_DIR}/<network>/data/* before redeploying."
