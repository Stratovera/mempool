#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "${ROOT_DIR}/lib/common.sh"
# shellcheck source=/dev/null
source "${ROOT_DIR}/lib/bitcoind.sh"

TMP_DIR="${ROOT_DIR}/.tmp-bitcoin-conf"
rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}/mainnet"

export MEMPOOL_BASE_DIR="${TMP_DIR}"
export USE_EXTERNAL_BITCOIND=false
export MAINNET_RPC_PORT=18444

create_bitcoind_config "mainnet"

conf="${MEMPOOL_BASE_DIR}/mainnet/bitcoin.conf"
grep -q "rpcport=18444" "$conf"
grep -q "rpcbind=0.0.0.0" "$conf"
grep -q "rpccookiefile=/data/bitcoin/.cookie" "$conf"
grep -q "rpcallowip=172.16.0.0/12" "$conf"
grep -q "rpcallowip=192.168.0.0/16" "$conf"
grep -q "rpcallowip=10.0.0.0/8" "$conf"
grep -q "rpcallowip=127.0.0.1/32" "$conf"

rm -rf "${TMP_DIR}"
