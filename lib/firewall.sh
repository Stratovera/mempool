#!/bin/bash

set -euo pipefail

configure_firewall() {
    [[ "${ENABLE_UFW}" == true ]] || { log_info "UFW disabled"; return; }
    command_exists ufw || die "ufw not available but ENABLE_UFW=true"

    log_info "Configuring UFW rules"
    local network
    for network in $(get_networks); do
        local upper="${network^^}"
        local web_port_var="${upper}_WEB_PORT"
        local api_port_var="${upper}_API_PORT"
        ufw allow "${!web_port_var}" comment "mempool ${network} web" || true
        ufw allow "${!api_port_var}" comment "mempool ${network} api" || true
    done

    if [[ "${MONITORING_ENABLED}" == true ]]; then
        ufw allow "${PROMETHEUS_PORT}" comment "Prometheus" || true
        ufw allow "${GRAFANA_PORT}" comment "Grafana" || true
    fi
}
