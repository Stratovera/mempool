#!/bin/bash

set -euo pipefail

create_mempool_config() {
    local network="$1"
    local template="templates/configs/mempool-config.json.tmpl"
    local output="${MEMPOOL_BASE_DIR}/${network}/mempool-config.json"
    local upper="${network^^}"
    local rpc_host="$BITCOIND_RPC_HOST"
    local rpc_port_var="${upper}_RPC_PORT"
    local rpc_port="${!rpc_port_var}"

    ensure_rpc_credentials "$network"

    CORE_RPC_HOST="$rpc_host" \
    CORE_RPC_PORT="$rpc_port" \
    CORE_RPC_USER="$(get_rpc_user "$network")" \
    CORE_RPC_PASS="$(get_rpc_password "$network")" \
    NETWORK="$network" \
    envsubst < "$template" > "$output"

    log_success "Mempool config rendered for ${network}"
}
