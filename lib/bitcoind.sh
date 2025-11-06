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
    local user pass
    user="$(get_rpc_user "$network")"
    pass="$(get_rpc_password "$network")"
    if [[ -n "$user" && -n "$pass" ]]; then
        return
    fi

    if [[ "${USE_EXTERNAL_BITCOIND}" == true ]]; then
        [[ -n "${BITCOIND_RPC_USER:-}" ]] || die "External bitcoind requires BITCOIND_RPC_USER"
        [[ -n "${BITCOIND_RPC_PASS:-}" ]] || die "External bitcoind requires BITCOIND_RPC_PASS"
        set_rpc_user "$network" "${BITCOIND_RPC_USER}"
        set_rpc_pass "$network" "${BITCOIND_RPC_PASS}"
        return
    fi

    set_rpc_user "$network" "mempool_${network}"
    set_rpc_pass "$network" "$(openssl rand -hex 32)"
}

rotate_rpc_credentials() {
    local network="$1"
    if [[ "${USE_EXTERNAL_BITCOIND}" == true ]]; then
        log_info "Skipping RPC credential rotation for ${network} (external bitcoind)"
        return
    fi
    set_rpc_user "$network" "mempool_${network}"
    set_rpc_pass "$network" "$(generate_secret 32)"
    record_credential_rotation "rpc-${network}"
    audit_event "RPC_CREDENTIAL_ROTATED" "network=${network}"
    log_info "Generated new RPC credentials for ${network}"
}

create_bitcoind_config() {
    local network="$1"
    local template="templates/configs/bitcoin.conf.tmpl"
    local output="${MEMPOOL_BASE_DIR}/${network}/bitcoin.conf"

    ensure_rpc_credentials "$network"
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
    local rpc_allow_lines=""
    IFS=',' read -ra __rpc_allow <<<"$RPC_ALLOWED_CIDRS"
    for cidr in "${__rpc_allow[@]}"; do
        cidr="${cidr// /}"
        [[ -z "$cidr" ]] && continue
        rpc_allow_lines+="rpcallowip=${cidr}"$'\n'
    done
    local auth_block=""
    if [[ "${RPC_COOKIE_AUTH}" == true ]]; then
        auth_block=$'rpccookiefile=/data/bitcoin/.cookie'
    else
        auth_block=$"rpcuser=$(get_rpc_user "$network")"$'\n'
        auth_block+="rpcpassword=$(get_rpc_password "$network")"
    fi

    RPC_AUTH_BLOCK="$auth_block" \
    RPC_PORT="$rpc_port" \
    NETWORK_CONFIG="$network_flag" \
    RPC_ALLOW_LINES="$rpc_allow_lines" \
    BITCOIND_EXTRA_LINES="$extra_lines" \
    envsubst < "$template" > "$output"

    chmod 600 "$output"
    write_checksum_file "$output"
    log_success "bitcoin.conf rendered for ${network}"
}
