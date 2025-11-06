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
        verify_checksum_file "${net_dir}/docker-compose.yml" || log_warn "Compose file integrity check failed for ${network}"
        if [[ -f "${net_dir}/bitcoin.conf" ]]; then
            verify_checksum_file "${net_dir}/bitcoin.conf" || log_warn "bitcoin.conf integrity check failed for ${network}"
        fi
        if [[ -f "${net_dir}/mempool-config.json" ]]; then
            verify_checksum_file "${net_dir}/mempool-config.json" || log_warn "mempool-config.json integrity check failed for ${network}"
        fi
    fi
}

determine_bitcoind_ids() {
    [[ "${USE_EXTERNAL_BITCOIND}" == true ]] && return
    if [[ -n "${BITCOIND_UID:-}" && -n "${BITCOIND_GID:-}" ]]; then
        return
    fi
    if command_exists docker; then
        local id_output
        if id_output="$(docker run --rm "${BITCOIND_IMAGE}" sh -c 'id -u && id -g' 2>/dev/null)"; then
            BITCOIND_UID="$(echo "$id_output" | sed -n '1p')"
            BITCOIND_GID="$(echo "$id_output" | sed -n '2p')"
            return
        fi
    fi
    log_warn "Could not determine bitcoind UID/GID; defaulting to 1000"
    BITCOIND_UID=1000
    BITCOIND_GID=1000
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
        if ! chown -R "${BITCOIND_UID:-1000}:${BITCOIND_GID:-1000}" "${data_dir}/bitcoin"; then
            log_warn "Failed to set ownership on ${data_dir}/bitcoin (requires root?)"
        else
            assert_owner "${data_dir}/bitcoin" "${BITCOIND_UID:-1000}" "${BITCOIND_GID:-1000}"
        fi
    fi

    if ! chown -R 999:999 "${data_dir}/mysql"; then
        log_warn "Failed to set ownership on ${data_dir}/mysql"
    else
        assert_owner "${data_dir}/mysql" 999 999
    fi
    if ! chown -R 1000:1000 "${data_dir}/api" "${data_dir}/electrs"; then
        log_warn "Failed to set ownership on API/Electrs directories"
    else
        assert_owner "${data_dir}/api" 1000 1000
        assert_owner "${data_dir}/electrs" 1000 1000
    fi
    if ! chmod 750 "${net_dir}"; then
        log_warn "Failed to set permissions on ${net_dir}"
    else
        assert_permissions "${net_dir}" 750
    fi

    mkdir -p "${net_dir}/monitoring/prometheus"
    mkdir -p "${net_dir}/monitoring/grafana/provisioning/datasources"
    mkdir -p "${net_dir}/monitoring/grafana/provisioning/dashboards"
    rm -f "${net_dir}/mempool-config.json"

    log_info "Prepared directories for ${network}"
}

create_directories() {
    check_disk_space
    determine_bitcoind_ids
    local network
    for network in $(get_networks); do
        create_network_directories "$network"
    done
    log_success "Directory structure ready at ${MEMPOOL_BASE_DIR}"
}
