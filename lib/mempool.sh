#!/bin/bash

set -euo pipefail

create_mempool_config() {
    local network="$1"
    local template="templates/configs/mempool-config.json.tmpl"
    local output="${MEMPOOL_BASE_DIR}/${network}/mempool-config.json"
    local upper
    upper="$(to_upper "$network")"
    local rpc_host="bitcoind"
    [[ "${USE_EXTERNAL_BITCOIND}" == true ]] && rpc_host="$BITCOIND_RPC_HOST"
    local rpc_port_var="${upper}_RPC_PORT"
    local rpc_port="${!rpc_port_var}"
    local electrum_host="electrs-${network}"

    ensure_rpc_credentials "$network"

    local core_rpc_cookie="false"
    local core_rpc_cookie_path=""
    local cookie_container_path="/bitcoin/.cookie"
    local core_rpc_user
    local core_rpc_pass
    if [[ "${RPC_COOKIE_AUTH}" == true ]]; then
        core_rpc_user=""
        core_rpc_pass=""
        core_rpc_cookie="true"
        core_rpc_cookie_path="$cookie_container_path"
    else
        core_rpc_user="$(get_rpc_user "$network")"
        core_rpc_pass="$(get_rpc_password "$network")"
    fi

    CORE_RPC_HOST="$rpc_host" \
    CORE_RPC_PORT="$rpc_port" \
    CORE_RPC_USER="$core_rpc_user" \
    CORE_RPC_PASS="$core_rpc_pass" \
    CORE_RPC_COOKIE="$core_rpc_cookie" \
    CORE_RPC_COOKIE_PATH="$core_rpc_cookie_path" \
    ELECTRUM_HOST="$electrum_host" \
    NETWORK="$network" \
    envsubst < "$template" > "$output"

    write_checksum_file "$output"
    log_success "Mempool config rendered for ${network}"
}
