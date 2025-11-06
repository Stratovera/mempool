#!/bin/bash

set -euo pipefail

configure_firewall() {
    [[ "${ENABLE_UFW}" == true ]] || { log_info "UFW disabled"; return; }
    command_exists ufw || die "ufw not available but ENABLE_UFW=true"

    log_info "Configuring UFW rules"
    local network
    for network in $(get_networks); do
        local upper
        upper="$(to_upper "$network")"
        local web_port_var="${upper}_WEB_PORT"
        local api_port_var="${upper}_API_PORT"
        if ! ufw allow "${!web_port_var}" comment "mempool ${network} web"; then
            log_warn "Failed to set UFW rule for ${network} web port ${!web_port_var}"
        fi
        if ! ufw allow "${!api_port_var}" comment "mempool ${network} api"; then
            log_warn "Failed to set UFW rule for ${network} API port ${!api_port_var}"
        fi
    done

    if [[ "${MONITORING_ENABLED}" == true ]]; then
        if ! ufw allow "${PROMETHEUS_PORT}" comment "Prometheus"; then
            log_warn "Failed to set UFW rule for Prometheus port ${PROMETHEUS_PORT}"
        fi
        if ! ufw allow "${GRAFANA_PORT}" comment "Grafana"; then
            log_warn "Failed to set UFW rule for Grafana port ${GRAFANA_PORT}"
        fi
    fi
}
