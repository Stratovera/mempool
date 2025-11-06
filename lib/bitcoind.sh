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

rpc_credentials_file() {
    local network="$1"
    echo "${MEMPOOL_BASE_DIR}/${network}/.rpc_credentials"
}

load_rpc_credentials() {
    local network="$1"
    local file
    file="$(rpc_credentials_file "$network")"
    [[ -f "$file" ]] || return 1
    # shellcheck disable=SC1090
    source "$file"
    [[ -n "${RPC_USER:-}" && -n "${RPC_PASS:-}" ]] || return 1
    set_rpc_user "$network" "$RPC_USER"
    set_rpc_pass "$network" "$RPC_PASS"
    return 0
}

persist_rpc_credentials() {
    local network="$1"
    local file
    file="$(rpc_credentials_file "$network")"
    cat > "$file" <<EOF
RPC_USER=$(get_rpc_user "$network")
RPC_PASS=$(get_rpc_password "$network")
EOF
    chmod 600 "$file"
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
    if load_rpc_credentials "$network"; then
        return
    fi
    if [[ "${USE_EXTERNAL_BITCOIND}" == true ]]; then
        set_rpc_user "$network" "${BITCOIND_RPC_USER}"
        set_rpc_pass "$network" "${BITCOIND_RPC_PASS}"
        return
    fi

    set_rpc_user "$network" "mempool_${network}"
    set_rpc_pass "$network" "$(openssl rand -hex 32)"
    persist_rpc_credentials "$network"
}

create_bitcoind_config() {
    local network="$1"
    local template="templates/configs/bitcoin.conf.tmpl"
    local output="${MEMPOOL_BASE_DIR}/${network}/bitcoin.conf"

    generate_rpc_credentials "$network"
    local upper
    upper="$(to_upper "$network")"
    local rpc_port_var="${upper}_RPC_PORT"
    local rpc_port="${!rpc_port_var}"
    local dbcache_var="${upper}_BITCOIND_DBCACHE"
    local max_conn_var="${upper}_BITCOIND_MAX_CONNECTIONS"
    local max_out_var="${upper}_BITCOIND_MAX_OUTBOUND"
    local max_upload_var="${upper}_BITCOIND_MAX_UPLOAD_TARGET"
    local parallel_var="${upper}_BITCOIND_PARALLELISM"
    local extra_lines=""
    append_bitcoind_line() {
        local key="$1" value="$2"
        if [[ -n "${value:-}" ]]; then
            extra_lines+="${key}=${value}"$'\n'
        fi
    }
    append_bitcoind_line "dbcache" "${!dbcache_var:-}"
    append_bitcoind_line "maxconnections" "${!max_conn_var:-}"
    append_bitcoind_line "maxoutboundconnections" "${!max_out_var:-}"
    append_bitcoind_line "maxuploadtarget" "${!max_upload_var:-}"
    append_bitcoind_line "par" "${!parallel_var:-}"
    local network_flag=""
    if [[ "$network" == "signet" ]]; then
        network_flag=$'signet=1\n[signet]'
    fi

    RPC_USER="$(get_rpc_user "$network")" \
    RPC_PASS="$(get_rpc_password "$network")" \
    RPC_PORT="$rpc_port" \
    NETWORK_CONFIG="$network_flag" \
    BITCOIND_EXTRA_LINES="$extra_lines" \
    envsubst < "$template" > "$output"

    chmod 600 "$output"
    log_success "bitcoin.conf rendered for ${network}"
}
