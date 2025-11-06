#!/bin/bash
# Common helpers: logging, validation, utilities

set -euo pipefail

COLOR_BLUE="\033[0;34m"
COLOR_YELLOW="\033[1;33m"
COLOR_GREEN="\033[0;32m"
COLOR_RED="\033[0;31m"
COLOR_RESET="\033[0m"

log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}

log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*"
}

log_success() {
    echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} $*"
}

log_error() {
    echo -e "${COLOR_RED}[ERR]${COLOR_RESET} $*" >&2
}

die() {
    log_error "$*"
    exit 1
}

require_root() {
    [[ $EUID -eq 0 ]] || die "Run as root or with sudo"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

validate_port() {
    local value="$1" context="${2:-port}"
    [[ "$value" =~ ^[0-9]+$ ]] || die "Invalid ${context}: must be numeric"
    (( value >= 1024 && value <= 65535 )) || die "Invalid ${context}: must be 1024-65535"
}

validate_domain() {
    local value="$1" context="${2:-domain}"
    [[ -z "$value" || "$value" =~ ^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$ ]] || die "Invalid ${context}: $value"
}

validate_path() {
    local value="$1" context="${2:-path}"
    [[ "$value" =~ ^/ ]] || die "${context} must be an absolute path"
}

validate_ip() {
    local value="$1" context="${2:-ip}"
    [[ -z "$value" ]] && return 0
    if [[ ! "$value" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        die "Invalid ${context}: ${value}"
    fi
    local IFS='.'
    read -r o1 o2 o3 o4 <<<"$value"
    for octet in "$o1" "$o2" "$o3" "$o4"; do
        (( octet >= 0 && octet <= 255 )) || die "Invalid ${context}: ${value}"
    done
}

ensure_directory() {
    local dir="$1" owner="$2" group="$3" mode="${4:-750}"
    mkdir -p "$dir"
    chown "$owner":"$group" "$dir"
    chmod "$mode" "$dir"
}

prompt_yes_no() {
    local prompt="$1" default="${2:-y}"
    local default_hint="[Y/n]"
    if [[ "$default" =~ ^[Nn]$ ]]; then
        default_hint="[y/N]"
    fi
    read -r -p "${prompt} ${default_hint}: " answer || true
    answer="${answer:-$default}"
    [[ "$answer" =~ ^[Yy]$ ]]
}
