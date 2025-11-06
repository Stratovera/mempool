#!/bin/bash
# Configuration management: loading, prompting, validation

set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../config" && pwd)"
USER_CONFIG_FILE="${CONFIG_DIR}/mempool-stack.conf"

load_config() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    # shellcheck source=../config/defaults.conf
    # shellcheck disable=SC1090
    set -o allexport
    source "$file"
    set +o allexport
}

interactive_config() {
    log_info "Interactive configuration"
    read -r -p "Base directory [${MEMPOOL_BASE_DIR}]: " ans || true
    MEMPOOL_BASE_DIR="${ans:-$MEMPOOL_BASE_DIR}"
    validate_path "$MEMPOOL_BASE_DIR" "MEMPOOL_BASE_DIR"

    read -r -p "Networks (comma list mainnet,signet) [${MEMPOOL_NETWORKS}]: " ans || true
    MEMPOOL_NETWORKS="$(echo "${ans:-$MEMPOOL_NETWORKS}" | tr -d ' ')"

    local ssl_default="n"
    [[ "${ENABLE_SSL}" == true ]] && ssl_default="y"
    if prompt_yes_no "Enable SSL termination?" "$ssl_default"; then
        ENABLE_SSL=true
        read -r -p "Mainnet domain [${DOMAIN_MAINNET:-mempool.example.com}]: " ans || true
        DOMAIN_MAINNET="${ans:-$DOMAIN_MAINNET}"
        read -r -p "Signet domain [${DOMAIN_SIGNET:-signet.example.com}]: " ans || true
        DOMAIN_SIGNET="${ans:-$DOMAIN_SIGNET}"
    else
        ENABLE_SSL=false
    fi

    read -r -p "Mainnet bind address (blank = all interfaces) [${MAINNET_BIND_ADDRESS}]: " ans || true
    MAINNET_BIND_ADDRESS="${ans:-$MAINNET_BIND_ADDRESS}"

    read -r -p "Signet bind address (blank = all interfaces) [${SIGNET_BIND_ADDRESS}]: " ans || true
    SIGNET_BIND_ADDRESS="${ans:-$SIGNET_BIND_ADDRESS}"

    local ext_default="n"
    [[ "${USE_EXTERNAL_BITCOIND}" == true ]] && ext_default="y"
    if prompt_yes_no "Use external bitcoind?" "$ext_default"; then
        USE_EXTERNAL_BITCOIND=true
        read -r -p "External RPC host [${BITCOIND_RPC_HOST}]: " ans || true
        BITCOIND_RPC_HOST="${ans:-$BITCOIND_RPC_HOST}"
        read -r -p "External RPC port [${BITCOIND_RPC_PORT}]: " ans || true
        BITCOIND_RPC_PORT="${ans:-$BITCOIND_RPC_PORT}"
        read -r -p "External RPC username [${BITCOIND_RPC_USER}]: " ans || true
        BITCOIND_RPC_USER="${ans:-$BITCOIND_RPC_USER}"
        read -r -p "External RPC password [hidden]: " ans || true
        BITCOIND_RPC_PASS="${ans:-$BITCOIND_RPC_PASS}"
    else
        USE_EXTERNAL_BITCOIND=false
    fi

    cat > "$USER_CONFIG_FILE" <<EOF
MEMPOOL_BASE_DIR="${MEMPOOL_BASE_DIR}"
MEMPOOL_NETWORKS="${MEMPOOL_NETWORKS}"
ENABLE_SSL=${ENABLE_SSL}
DOMAIN_MAINNET="${DOMAIN_MAINNET}"
DOMAIN_SIGNET="${DOMAIN_SIGNET}"
ENABLE_UFW=${ENABLE_UFW}
USE_EXTERNAL_BITCOIND=${USE_EXTERNAL_BITCOIND}
BITCOIND_RPC_HOST="${BITCOIND_RPC_HOST}"
BITCOIND_RPC_PORT=${BITCOIND_RPC_PORT}
BITCOIND_RPC_USER="${BITCOIND_RPC_USER}"
BITCOIND_RPC_PASS="${BITCOIND_RPC_PASS}"
MONITORING_ENABLED=${MONITORING_ENABLED}
MAINNET_WEB_PORT=${MAINNET_WEB_PORT}
MAINNET_API_PORT=${MAINNET_API_PORT}
MAINNET_BIND_ADDRESS="${MAINNET_BIND_ADDRESS}"
SIGNET_WEB_PORT=${SIGNET_WEB_PORT}
SIGNET_API_PORT=${SIGNET_API_PORT}
SIGNET_BIND_ADDRESS="${SIGNET_BIND_ADDRESS}"
EOF

    log_success "Configuration saved to ${USER_CONFIG_FILE}"
}

validate_config() {
    MEMPOOL_NETWORKS="$(echo "$MEMPOOL_NETWORKS" | tr -d '[:space:]')"
    validate_path "$MEMPOOL_BASE_DIR" "MEMPOOL_BASE_DIR"
    [[ -n "${MEMPOOL_NETWORKS:-}" ]] || die "MEMPOOL_NETWORKS must not be empty"

    local network
    for network in $(tr ',' ' ' <<<"$MEMPOOL_NETWORKS"); do
        case "$network" in
            mainnet|signet) ;;
            *) die "Unsupported network: $network" ;;
        esac
        local upper="${network^^}"
        local web_var="${upper}_WEB_PORT"
        local api_var="${upper}_API_PORT"
        local bind_var="${upper}_BIND_ADDRESS"
        validate_port "${!web_var}" "${network} web port"
        validate_port "${!api_var}" "${network} api port"
        validate_ip "${!bind_var}" "${network} bind address"
    done

    [[ "$ENABLE_SSL" == true ]] && validate_domain "$DOMAIN_MAINNET" "DOMAIN_MAINNET"
    [[ "$ENABLE_SSL" == true ]] && validate_domain "$DOMAIN_SIGNET" "DOMAIN_SIGNET"

    validate_port "$BITCOIND_RPC_PORT" "BITCOIND_RPC_PORT"
    if [[ "${USE_EXTERNAL_BITCOIND}" == true ]]; then
        [[ -n "${BITCOIND_RPC_USER}" ]] || die "BITCOIND_RPC_USER required for external bitcoind"
        [[ -n "${BITCOIND_RPC_PASS}" ]] || die "BITCOIND_RPC_PASS required for external bitcoind"
    fi
}

get_networks() {
    tr ',' ' ' <<<"$MEMPOOL_NETWORKS"
}
