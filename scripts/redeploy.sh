#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$REPO_DIR"

echo "Updating repository..."
git pull

echo "Removing existing deployments..."
sudo rm -rf /opt/mempool/mainnet /opt/mempool/signet

echo "Deploying stack..."
sudo make deploy
