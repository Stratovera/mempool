#!/bin/bash

set -euo pipefail

set_rpc_user() {
    local network="$1" value="$2"
    eval "RPC_USER_${network}=\"${value}\""
}

set_rpc_pass() {
    local network="$1" value="$2"
    eval "RPC_PASS_${network}=\"${value}\""
}

get_rpc_user() {
    local network="$1"
    eval "echo \${RPC_USER_${network}:-}"
}

get_rpc_password() {
    local network="$1"
    eval "echo \${RPC_PASS_${network}:-}"
}

ensure_rpc_credentials() {
    local network="$1"
    local user
    user="$(get_rpc_user "$network")"
    if [[ -z "$user" ]]; then
        generate_rpc_credentials "$network"
    fi
}

generate_rpc_credentials() {
    local network="$1"
    if [[ "${USE_EXTERNAL_BITCOIND}" == true ]]; then
        set_rpc_user "$network" "${BITCOIND_RPC_USER}"
        set_rpc_pass "$network" "${BITCOIND_RPC_PASS}"
        return
    fi

    set_rpc_user "$network" "mempool_${network}"
    set_rpc_pass "$network" "$(openssl rand -hex 32)"
}

create_bitcoind_config() {
    local network="$1"
    local template="templates/configs/bitcoin.conf.tmpl"
    local output="${MEMPOOL_BASE_DIR}/${network}/bitcoin.conf"

    generate_rpc_credentials "$network"
    local network_flag="mainnet=1"
    if [[ "$network" == "signet" ]]; then
        network_flag="signet=1"
    fi

    RPC_USER="$(get_rpc_user "$network")" \
    RPC_PASS="$(get_rpc_password "$network")" \
    NETWORK_CONFIG="$network_flag" \
    envsubst < "$template" > "$output"

    chmod 600 "$output"
    log_success "bitcoin.conf rendered for ${network}"
}
