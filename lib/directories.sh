#!/bin/bash

set -euo pipefail

check_disk_space() {
    local target="$MEMPOOL_BASE_DIR"
    mkdir -p "$target"
    local available_mb
    available_mb=$(df -Pm "$target" | awk 'NR==2 {print $4}')
    local required_mb=$(( MIN_DISK_GB * 1024 ))
    (( available_mb >= required_mb )) || die "Insufficient disk space: need ${MIN_DISK_GB}G free"
    log_success "Disk space check ok (${available_mb} MB available)"
}

ensure_fresh_network() {
    local network="$1"
    local net_dir="${MEMPOOL_BASE_DIR}/${network}"
    if [[ -f "${net_dir}/docker-compose.yml" ]]; then
        log_info "Reusing existing deployment directory for ${network}"
    fi
}

create_network_directories() {
    local network="$1"
    ensure_fresh_network "$network"

    local net_dir="${MEMPOOL_BASE_DIR}/${network}"
    local data_dir="${net_dir}/data"
    mkdir -p "${net_dir}/nginx"
    mkdir -p "${data_dir}/mysql"
    mkdir -p "${data_dir}/api"
    mkdir -p "${data_dir}/electrs/db"
    mkdir -p "${net_dir}/logs"

    if [[ "${USE_EXTERNAL_BITCOIND}" != true ]]; then
        mkdir -p "${data_dir}/bitcoin"
        chown -R 101:101 "${data_dir}/bitcoin"
    fi

    chown -R 999:999 "${data_dir}/mysql"
    chown -R 1000:1000 "${data_dir}/api" "${data_dir}/electrs"
    chmod -R 750 "${net_dir}"

    mkdir -p "${net_dir}/monitoring/prometheus"
    mkdir -p "${net_dir}/monitoring/grafana/provisioning/datasources"
    mkdir -p "${net_dir}/monitoring/grafana/provisioning/dashboards"
    rm -f "${net_dir}/mempool-config.json"

    log_info "Prepared directories for ${network}"
}

create_directories() {
    check_disk_space
    local network
    for network in $(get_networks); do
        create_network_directories "$network"
    done
    log_success "Directory structure ready at ${MEMPOOL_BASE_DIR}"
}
