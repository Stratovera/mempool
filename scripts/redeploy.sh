#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$REPO_DIR"

echo "Updating repository..."
git pull

echo "Stopping existing deployments..."
for net in mainnet signet; do
  compose="/opt/mempool/${net}/docker-compose.yml"
  if [[ -f "$compose" ]]; then
    sudo docker compose -f "$compose" down --remove-orphans || true
  fi
done

echo "Removing existing deployments..."
sudo rm -rf /opt/mempool/mainnet /opt/mempool/signet

echo "Deploying stack..."
sudo make deploy
