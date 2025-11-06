#!/bin/bash

set -euo pipefail

DOCKER_SERVICE_TEMPLATES=(
    bitcoind
    electrs
    database
    api
    web
)

MONITORING_SERVICE_TEMPLATES=(
    monitoring/prometheus
    monitoring/grafana
    monitoring/node-exporter
    monitoring/bitcoin-exporter
    monitoring/mariadb-exporter
)

ensure_secret_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        chmod 700 "$dir"
    fi
}

write_secret_file() {
    local network="$1" name="$2" value="$3"
    local dir="${MEMPOOL_BASE_DIR}/${network}/secrets"
    ensure_secret_dir "$dir"
    local file="${dir}/${name}"
    local old_umask
    old_umask=$(umask)
    umask 077
    if [[ -f "$file" ]]; then
        secure_delete "$file"
    fi
    # Avoid partially-written files if interrupted
    local tmp_file
    tmp_file="$(mktemp "${file}.XXXXXX")"
    printf '%s' "$value" > "$tmp_file"
    chmod 600 "$tmp_file"
    mv "$tmp_file" "$file"
    umask "$old_umask"
    echo "$file"
}

prepare_network_env() {
    local network="$1"
    ensure_rpc_credentials "$network"
    local upper
    upper="$(to_upper "$network")"
    export NETWORK="$network"
    export NETWORK_UPPER="$upper"
    export MEMPOOL_NETWORK_NAME="mempool-${network}"
    export MEMPOOL_DATA_DIR="${MEMPOOL_BASE_DIR}/${network}/data"
    export MEMPOOL_LOG_DIR="${MEMPOOL_BASE_DIR}/${network}/logs"
    export ELECTRS_HOST="electrs-${network}"
    export BITCOIN_DATA_DIR="${MEMPOOL_DATA_DIR}/bitcoin"
    export MYSQL_DATA_DIR="${MEMPOOL_DATA_DIR}/mysql"
    export API_DATA_DIR="${MEMPOOL_DATA_DIR}/api"
    export ELECTRS_DATA_DIR="${MEMPOOL_DATA_DIR}/electrs"
    export WEB_PORT_VAR="${upper}_WEB_PORT"
    export API_PORT_VAR="${upper}_API_PORT"
    export WEB_PORT="${!WEB_PORT_VAR}"
    export API_PORT="${!API_PORT_VAR}"
    local electrs_var="${upper}_ELECTRS_PORT"
    export ELECTRS_PORT="${!electrs_var}"
    local p2p_var="${upper}_P2P_PORT"
    export P2P_PORT="${!p2p_var}"
    local rpc_user
    rpc_user="$(get_rpc_user "$network")"
    export CORE_RPC_USER="$rpc_user"
    local rpc_pass
    rpc_pass="$(get_rpc_password "$network")"
    export CORE_RPC_PASS="$rpc_pass"
    export DB_PASSWORD_SECRET_NAME="db-password-${network}"
    export DB_PASSWORD_SECRET_FILE
    DB_PASSWORD_SECRET_FILE="$(write_secret_file "$network" "${DB_PASSWORD_SECRET_NAME}" "${DB_PASSWORD}")"
    export DB_ROOT_PASSWORD_SECRET_NAME="db-root-password-${network}"
    export DB_ROOT_PASSWORD_SECRET_FILE
    DB_ROOT_PASSWORD_SECRET_FILE="$(write_secret_file "$network" "${DB_ROOT_PASSWORD_SECRET_NAME}" "${DB_ROOT_PASSWORD}")"
    export MARIADB_EXPORTER_DSN_SECRET_NAME="db-exporter-dsn-${network}"
    export MARIADB_EXPORTER_DSN_SECRET_FILE
    MARIADB_EXPORTER_DSN_SECRET_FILE="$(write_secret_file "$network" "${MARIADB_EXPORTER_DSN_SECRET_NAME}" "${DB_USER}:${DB_PASSWORD}@(database:3306)/")"
    if [[ "${USE_EXTERNAL_BITCOIND}" == true ]]; then
        export CORE_RPC_HOST="$BITCOIND_RPC_HOST"
    else
        export CORE_RPC_HOST="bitcoind"
    fi
    local rpc_var="${upper}_RPC_PORT"
    export CORE_RPC_PORT="${!rpc_var}"
    local bind_var="${upper}_BIND_ADDRESS"
    local bind_address="${!bind_var}"
    export HOST_BIND_PREFIX="${bind_address:+${bind_address}:}"
    local prom_var="${upper}_PROMETHEUS_PORT"
    local graf_var="${upper}_GRAFANA_PORT"
    export PROMETHEUS_HOST_PORT="${!prom_var}"
    export GRAFANA_HOST_PORT="${!graf_var}"
    if [[ "${USE_EXTERNAL_BITCOIND}" == true ]]; then
        export BITCOIND_DEPENDS_LINE=""
    else
        export BITCOIND_DEPENDS_LINE="    - bitcoind"
    fi
}

render_template() {
    local template="$1" indent="${2:-}"
    if [[ -n "$indent" ]]; then
        envsubst < "$template" | sed "s/^/${indent}/"
    else
        envsubst < "$template"
    fi
}

generate_docker_compose() {
    local network="$1"
    local compose_path="${MEMPOOL_BASE_DIR}/${network}/docker-compose.yml"
    prepare_network_env "$network"

    {
        render_template "templates/docker-compose/base.yml"
        echo "services:"
        local template
        for template in "${DOCKER_SERVICE_TEMPLATES[@]}"; do
            if [[ "$template" == "bitcoind" && "${USE_EXTERNAL_BITCOIND}" == true ]]; then
                continue
            fi
            echo
            render_template "templates/docker-compose/services/${template}.yml" "  "
        done

        if [[ "${MONITORING_ENABLED}" == true ]]; then
            for template in "${MONITORING_SERVICE_TEMPLATES[@]}"; do
                if [[ "$template" == "monitoring/node-exporter" && "$network" != "mainnet" ]]; then
                    continue
                fi
                echo
                render_template "templates/docker-compose/services/${template}.yml" "  "
            done
        fi
    } > "$compose_path"

    write_checksum_file "$compose_path"
    log_success "Generated docker-compose.yml for ${network}"
}
