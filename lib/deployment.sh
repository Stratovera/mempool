#!/bin/bash

set -euo pipefail

render_management_scripts() {
    local template

    shopt -s nullglob
    for template in templates/scripts/*.tmpl; do
        local filename
        filename="$(basename "$template" .tmpl)"
        local target="${MEMPOOL_BASE_DIR}/${filename}"
        MEMPOOL_BASE_DIR="$MEMPOOL_BASE_DIR" \
        MEMPOOL_NETWORKS="$MEMPOOL_NETWORKS" \
        envsubst < "$template" > "$target"
        chmod +x "$target"
    done

    log_success "Management scripts rendered in ${MEMPOOL_BASE_DIR}"
}

deploy_network() {
    local network="$1"
    log_info "Deploying ${network}"

    if [[ "${USE_EXTERNAL_BITCOIND}" != true ]]; then
        create_bitcoind_config "$network"
    fi

    create_mempool_config "$network"
    generate_docker_compose "$network"

    (cd "${MEMPOOL_BASE_DIR}/${network}" && docker compose pull && docker compose up -d)
    log_success "${network} stack running"
}

deploy_stack() {
    create_directories
    setup_monitoring
    local network
    for network in $(get_networks); do
        deploy_network "$network"
    done
    render_management_scripts
    configure_firewall
    log_success "Deployment completed"
}

start_stack() {
    local network
    for network in $(get_networks); do
        local dir="${MEMPOOL_BASE_DIR}/${network}"
        [[ -d "$dir" ]] || { log_warn "${network} not deployed"; continue; }
        (cd "$dir" && docker compose up -d)
    done
}

stop_stack() {
    local network
    for network in $(get_networks); do
        local dir="${MEMPOOL_BASE_DIR}/${network}"
        [[ -d "$dir" ]] || continue
        (cd "$dir" && docker compose down)
    done
}

show_status() {
    local network
    for network in $(get_networks); do
        echo "=== ${network} ==="
        local dir="${MEMPOOL_BASE_DIR}/${network}"
        if [[ -d "$dir" ]]; then
            (cd "$dir" && docker compose ps)
        else
            echo "Not deployed"
        fi
    done
}

show_logs() {
    local network="${1:-mainnet}"
    local service="${2:-}"
    local compose_file="${MEMPOOL_BASE_DIR}/${network}/docker-compose.yml"
    [[ -f "$compose_file" ]] || die "No compose file for ${network}"
    if [[ -n "$service" ]]; then
        docker compose -f "$compose_file" logs -f "$service"
    else
        docker compose -f "$compose_file" logs -f
    fi
}

create_backup() {
    local script="${MEMPOOL_BASE_DIR}/backup.sh"
    [[ -x "$script" ]] || die "backup.sh missing. Run deploy first."
    bash "$script"
}

run_tests() {
    bash tests/test-runner.sh
}
