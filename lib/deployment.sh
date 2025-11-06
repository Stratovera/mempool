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

    (
        cd "${MEMPOOL_BASE_DIR}/${network}" \
        && docker compose pull \
        && docker compose up -d --force-recreate --remove-orphans
    )
    log_success "${network} stack running"
}

update_database_credentials() {
    local network="$1" old_root_password="$2" new_db_password="$3" new_root_password="$4"
    local compose_path="${MEMPOOL_BASE_DIR}/${network}/docker-compose.yml"
    [[ -f "$compose_path" ]] || { log_warn "No compose file for ${network}; skipping database credential update"; return; }
    [[ -n "$old_root_password" ]] || die "Cannot rotate database credentials without existing root password"
    local statement
    statement="ALTER USER '${DB_USER}'@'%' IDENTIFIED BY '${new_db_password}'; "
    statement+="ALTER USER 'root'@'%' IDENTIFIED BY '${new_root_password}'; "
    statement+="FLUSH PRIVILEGES;"
    if ! docker compose -f "$compose_path" exec -T database mysql -uroot -p"${old_root_password}" -e "$statement"; then
        die "Failed to update database credentials for ${network}"
    fi
    audit_event "DB_CREDENTIAL_APPLIED" "network=${network}"
}

rotate_credentials() {
    require_root
    ensure_internal_credentials
    audit_event "CREDENTIAL_ROTATION_STARTED" "networks=$(get_networks)"
    local old_db_password
    local old_root_password
    old_db_password="$(load_secret_value "db-password" 2>/dev/null || echo "${DB_PASSWORD:-}")"
    old_root_password="$(load_secret_value "db-root-password" 2>/dev/null || echo "${DB_ROOT_PASSWORD:-}")"
    [[ -n "$old_db_password" ]] || die "Missing existing database password"
    [[ -n "$old_root_password" ]] || die "Missing existing root password"

    local new_db_password
    local new_root_password
    new_db_password="$(generate_secret 48)"
    new_root_password="$(generate_secret 48)"

    local network
    for network in $(get_networks); do
        rotate_rpc_credentials "$network"
    done

    for network in $(get_networks); do
        update_database_credentials "$network" "$old_root_password" "$new_db_password" "$new_root_password"
    done

    DB_PASSWORD="$new_db_password"
    DB_ROOT_PASSWORD="$new_root_password"
    persist_secret_value "db-password" "$DB_PASSWORD"
    persist_secret_value "db-root-password" "$DB_ROOT_PASSWORD"
    record_credential_rotation "db-password"
    record_credential_rotation "db-root-password"
    audit_event "DB_CREDENTIAL_ROTATED" "type=application"

    for network in $(get_networks); do
        deploy_network "$network"
    done

    audit_event "CREDENTIAL_ROTATION_COMPLETED" "networks=$(get_networks)"
    log_success "Credential rotation complete"
}

deploy_stack() {
    create_directories
    ensure_internal_credentials
    render_management_scripts
    setup_monitoring
    local network
    for network in $(get_networks); do
        deploy_network "$network"
    done
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
