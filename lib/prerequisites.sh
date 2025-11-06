#!/bin/bash

set -euo pipefail

check_prerequisites() {
    require_root
    local missing=()
    for bin in docker envsubst git openssl; do
        if ! command_exists "$bin"; then
            missing+=("$bin")
        fi
    done
    if (( ${#missing[@]} > 0 )); then
        die "Missing required commands: ${missing[*]}"
    fi

    if ! docker compose version >/dev/null 2>&1; then
        die "Docker Compose V2 plugin not available"
    fi

    if command_exists systemctl; then
        if ! systemctl is-active --quiet docker; then
            log_warn "Docker service not running; attempting to start"
            systemctl start docker || die "Unable to start docker service"
        fi
    else
        log_warn "systemctl not available; ensure Docker is running"
    fi

    log_success "Prerequisites satisfied"
}
