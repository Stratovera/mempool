#!/bin/bash

set -euo pipefail

create_prometheus_config() {
    local network="$1"
    local template="templates/configs/prometheus.yml.tmpl"
    local output="${MEMPOOL_BASE_DIR}/${network}/monitoring/prometheus/prometheus.yml"
    NETWORK="$network" \
    NODE_EXPORTER_PORT="$NODE_EXPORTER_PORT" \
    envsubst < "$template" > "$output"
}

create_grafana_config() {
    local network="$1"
    local datasources_template="templates/grafana/datasources.yml.tmpl"
    local dashboards_template="templates/grafana/dashboards.yml.tmpl"
    local base_dir="${MEMPOOL_BASE_DIR}/${network}/monitoring/grafana/provisioning"
    local prom_var="${network^^}_PROMETHEUS_PORT"
    local prometheus_port="${!prom_var}"

    NETWORK="$network" \
    PROMETHEUS_PORT="$prometheus_port" \
    envsubst < "$datasources_template" > "${base_dir}/datasources/datasources.yml"

    NETWORK="$network" \
    envsubst < "$dashboards_template" > "${base_dir}/dashboards/dashboards.yml"
}

setup_monitoring() {
    [[ "${MONITORING_ENABLED}" == true ]] || { log_info "Monitoring disabled"; return; }
    local network
    for network in $(get_networks); do
        create_prometheus_config "$network"
        create_grafana_config "$network"
    done
    log_success "Monitoring artifacts rendered"
}
