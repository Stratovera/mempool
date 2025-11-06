#!/bin/bash
# Configuration management: loading, prompting, validation

set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../config" && pwd)"
USER_CONFIG_FILE="${CONFIG_DIR}/mempool-stack.conf"
SECRET_STORE_DIR="${CONFIG_DIR}/.secrets"

load_config() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    # shellcheck source=../config/shellcheck-env.sh
    set -o allexport
    # shellcheck disable=SC1090
    source "$file"
    set +o allexport
}

secret_store_path() {
    local key="$1"
    echo "${SECRET_STORE_DIR}/${key}"
}

persist_secret_value() {
    local key="$1" value="$2"
    [[ -n "$value" ]] || return 0
    mkdir -p "$SECRET_STORE_DIR"
    chmod 700 "$SECRET_STORE_DIR"
    local file
    file="$(secret_store_path "$key")"
    if [[ -f "$file" ]]; then
        secure_delete "$file"
    fi
    local old_umask
    old_umask=$(umask)
    umask 077
    local tmp
    tmp="$(mktemp "${file}.XXXXXX")"
    printf '%s' "$value" > "$tmp"
    chmod 600 "$tmp"
    mv "$tmp" "$file"
    umask "$old_umask"
}

load_secret_value() {
    local key="$1"
    local file
    file="$(secret_store_path "$key")"
    [[ -f "$file" ]] || return 1
    cat "$file"
}

ensure_persistent_secret() {
    local var="$1" key="$2" length="${3:-48}"
    local current="${!var:-}"
    if [[ -n "$current" ]]; then
        persist_secret_value "$key" "$current"
        record_credential_rotation "$key"
        audit_event "SECRET_PERSISTED" "key=${key},source=config"
        return
    fi
    local stored
    if stored="$(load_secret_value "$key")"; then
        eval "${var}=\"${stored}\""
        return
    fi
    local generated
    generated="$(generate_secret "$length")"
    persist_secret_value "$key" "$generated"
    eval "${var}=\"${generated}\""
    record_credential_rotation "$key"
    audit_event "SECRET_GENERATED" "key=${key}"
    log_info "Generated random value for ${key//-/ }"
}

ensure_internal_credentials() {
    ensure_persistent_secret DB_PASSWORD "db-password"
    ensure_persistent_secret DB_ROOT_PASSWORD "db-root-password"
    validate_password_strength "$DB_PASSWORD" "DB_PASSWORD"
    validate_password_strength "$DB_ROOT_PASSWORD" "DB_ROOT_PASSWORD"
    if [[ "${USE_EXTERNAL_BITCOIND}" == true ]]; then
        [[ -n "${BITCOIND_RPC_USER:-}" ]] || die "BITCOIND_RPC_USER required for external bitcoind"
        [[ -n "${BITCOIND_RPC_PASS:-}" ]] || die "BITCOIND_RPC_PASS required for external bitcoind"
        validate_password_strength "$BITCOIND_RPC_PASS" "BITCOIND_RPC_PASS"
    fi
}

credential_state_dir() {
    echo "${MEMPOOL_BASE_DIR}/.state/credentials"
}

record_credential_rotation() {
    local key="$1"
    local dir
    dir="$(credential_state_dir)"
    if ! mkdir -p "$dir"; then
        log_warn "Unable to create credential state directory ${dir}"
        return
    fi
    chmod 700 "$dir" || log_warn "Unable to set permissions on ${dir}"
    local file="${dir}/${key}"
    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    local old_umask
    old_umask=$(umask)
    umask 077
    if ! printf '%s\n' "$timestamp" > "$file"; then
        log_warn "Unable to write credential state for ${key}"
        umask "$old_umask"
        return
    fi
    chmod 600 "$file" || log_warn "Unable to secure credential state file ${file}"
    umask "$old_umask"
}

rotate_db_credentials() {
    local -n db_prev_ref="$1"
    local -n root_prev_ref="$2"
    db_prev_ref="$(load_secret_value "db-password" 2>/dev/null || echo "${DB_PASSWORD:-}")"
    root_prev_ref="$(load_secret_value "db-root-password" 2>/dev/null || echo "${DB_ROOT_PASSWORD:-}")"
    DB_PASSWORD="$(generate_secret 48)"
    DB_ROOT_PASSWORD="$(generate_secret 48)"
    persist_secret_value "db-password" "$DB_PASSWORD"
    persist_secret_value "db-root-password" "$DB_ROOT_PASSWORD"
    record_credential_rotation "db-password"
    record_credential_rotation "db-root-password"
    audit_event "DB_CREDENTIAL_ROTATED" "type=application"
    log_info "Generated new database credentials"
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

    local default_separate_ips="y"
    [[ -n "${MAINNET_BIND_ADDRESS}" && -n "${SIGNET_BIND_ADDRESS}" && "${MAINNET_BIND_ADDRESS}" == "${SIGNET_BIND_ADDRESS}" ]] && default_separate_ips="n"
    if prompt_yes_no "Use different host IPs for mainnet and signet?" "$default_separate_ips"; then
        read -r -p "Mainnet bind address (blank = all interfaces) [${MAINNET_BIND_ADDRESS}]: " ans || true
        MAINNET_BIND_ADDRESS="${ans:-$MAINNET_BIND_ADDRESS}"
        read -r -p "Signet bind address (blank = all interfaces) [${SIGNET_BIND_ADDRESS}]: " ans || true
        SIGNET_BIND_ADDRESS="${ans:-$SIGNET_BIND_ADDRESS}"
    else
        read -r -p "Shared bind address for both networks (blank = all interfaces) [${MAINNET_BIND_ADDRESS:-$SIGNET_BIND_ADDRESS}]: " ans || true
        local shared="${ans:-${MAINNET_BIND_ADDRESS:-$SIGNET_BIND_ADDRESS}}"
        MAINNET_BIND_ADDRESS="$shared"
        SIGNET_BIND_ADDRESS="$shared"
        log_warn "Mainnet and signet will share ${shared:-0.0.0.0}; ensure each network uses unique ports."
    fi

    read -r -p "Mainnet web port [${MAINNET_WEB_PORT}]: " ans || true
    MAINNET_WEB_PORT="${ans:-$MAINNET_WEB_PORT}"
    read -r -p "Mainnet API port [${MAINNET_API_PORT}]: " ans || true
    MAINNET_API_PORT="${ans:-$MAINNET_API_PORT}"

    read -r -p "Signet web port [${SIGNET_WEB_PORT}]: " ans || true
    SIGNET_WEB_PORT="${ans:-$SIGNET_WEB_PORT}"
    read -r -p "Signet API port [${SIGNET_API_PORT}]: " ans || true
    SIGNET_API_PORT="${ans:-$SIGNET_API_PORT}"

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
        if [[ -n "${BITCOIND_RPC_PASS:-}" ]] && prompt_yes_no "Keep existing external RPC password?" "y"; then
            :
        else
            prompt_secure_password "External RPC password" BITCOIND_RPC_PASS
        fi
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

    ensure_internal_credentials
    log_info "Database credentials stored securely under ${SECRET_STORE_DIR}"
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
        local upper
        upper="$(to_upper "$network")"
        local web_var="${upper}_WEB_PORT"
        local api_var="${upper}_API_PORT"
        local bind_var="${upper}_BIND_ADDRESS"
        local electrs_var="${upper}_ELECTRS_PORT"
        local p2p_var="${upper}_P2P_PORT"
        local rpc_var="${upper}_RPC_PORT"
        validate_port "${!web_var}" "${network} web port"
        validate_port "${!api_var}" "${network} api port"
        validate_port "${!electrs_var}" "${network} electrs port"
        validate_port "${!p2p_var}" "${network} p2p port"
        validate_port "${!rpc_var}" "${network} rpc port"
        validate_ip "${!bind_var}" "${network} bind address"
    done

    [[ "$ENABLE_SSL" == true ]] && validate_domain "$DOMAIN_MAINNET" "DOMAIN_MAINNET"
    [[ "$ENABLE_SSL" == true ]] && validate_domain "$DOMAIN_SIGNET" "DOMAIN_SIGNET"

    validate_port "$BITCOIND_RPC_PORT" "BITCOIND_RPC_PORT"
    if [[ "${USE_EXTERNAL_BITCOIND}" == true ]]; then
        [[ -n "${BITCOIND_RPC_USER}" ]] || die "BITCOIND_RPC_USER required for external bitcoind"
        [[ -n "${BITCOIND_RPC_PASS}" ]] || die "BITCOIND_RPC_PASS required for external bitcoind"
    fi

    IFS=',' read -ra __cidrs <<<"$RPC_ALLOWED_CIDRS"
    for cidr in "${__cidrs[@]}"; do
        cidr="${cidr// /}"
        [[ -z "$cidr" ]] && continue
        validate_cidr "$cidr" "RPC_ALLOWED_CIDRS"
    done
}

get_networks() {
    tr ',' ' ' <<<"$MEMPOOL_NETWORKS"
}
