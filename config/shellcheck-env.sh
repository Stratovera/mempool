#!/bin/bash
# Stub variables for ShellCheck static analysis only.
# shellcheck disable=SC2034

export MEMPOOL_BASE_DIR="/opt/mempool"
export MEMPOOL_NETWORKS="mainnet,signet"
export ENABLE_SSL=false
export DOMAIN_MAINNET=""
export DOMAIN_SIGNET=""
export ENABLE_UFW=true
export USE_EXTERNAL_BITCOIND=false
export BITCOIND_RPC_HOST="bitcoind"
export BITCOIND_RPC_PORT=8332
export BITCOIND_RPC_USER="stub-user"
export BITCOIND_RPC_PASS="stub-pass"
export RPC_ALLOWED_CIDRS="172.16.0.0/12,192.168.0.0/16,10.0.0.0/8,127.0.0.1/32"
export RPC_COOKIE_AUTH=true
export BITCOIN_COOKIE_WAIT_SECONDS=30
export MONITORING_ENABLED=true
export MAINNET_WEB_PORT=8080
export MAINNET_API_PORT=8999
export MAINNET_BIND_ADDRESS=""
export SIGNET_WEB_PORT=8081
export SIGNET_API_PORT=8998
export SIGNET_BIND_ADDRESS=""
export DB_USER="mempool"
export DB_PASSWORD="stub-db-pass"
export DB_NAME="mempool"
