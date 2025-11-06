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

audit_event() {
    local event="$1" details="${2:-}"
    local base="${MEMPOOL_BASE_DIR:-}"
    [[ -n "$base" ]] || return
    local log_dir="${base}/logs"
    if ! mkdir -p "$log_dir"; then
        return
    fi
    local log_file="${log_dir}/audit.log"
    local timestamp user host
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    user="$(id -un 2>/dev/null || echo "unknown")"
    host="$(hostname 2>/dev/null || echo "unknown")"
    local entry="${timestamp}|${user}@${host}|${event}"
    if [[ -n "$details" ]]; then
        entry+="|${details}"
    fi
    local old_umask
    old_umask=$(umask)
    umask 077
    if printf '%s\n' "$entry" >> "$log_file"; then
        chmod 600 "$log_file" || true
    fi
    umask "$old_umask"
}

secure_delete() {
    local path="$1"
    [[ -f "$path" ]] || return 0
    if command_exists shred; then
        shred -u -n 3 -z "$path" && return 0
    elif command_exists srm; then
        srm -f "$path" && return 0
    fi
    rm -f "$path"
    log_warn "Secure deletion tools unavailable; removed ${path} with standard rm"
    return 1
}

get_file_mode() {
    local path="$1"
    if command_exists stat; then
        stat -c %a "$path" 2>/dev/null || stat -f %Lp "$path" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

assert_permissions() {
    local path="$1" expected="$2"
    [[ -e "$path" ]] || { log_warn "Cannot verify permissions for missing path ${path}"; return; }
    local mode
    mode="$(get_file_mode "$path")"
    [[ -z "$mode" ]] && { log_warn "Unable to determine permissions for ${path}"; return; }
    if [[ "$mode" != "$expected" ]]; then
        log_warn "Permission mismatch for ${path}: expected ${expected}, found ${mode}"
    fi
}

get_file_owner() {
    local path="$1"
    if command_exists stat; then
        stat -c %u:%g "$path" 2>/dev/null || stat -f %u:%g "$path" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

assert_owner() {
    local path="$1" expected_uid="$2" expected_gid="$3"
    [[ -e "$path" ]] || { log_warn "Cannot verify owner for missing path ${path}"; return; }
    local owner
    owner="$(get_file_owner "$path")"
    [[ -z "$owner" ]] && { log_warn "Unable to determine owner for ${path}"; return; }
    local uid="${owner%%:*}"
    local gid="${owner##*:}"
    if [[ "$uid" != "$expected_uid" || "$gid" != "$expected_gid" ]]; then
        log_warn "Ownership mismatch for ${path}: expected ${expected_uid}:${expected_gid}, found ${uid}:${gid}"
    fi
}

compute_sha256() {
    local path="$1"
    if command_exists sha256sum; then
        sha256sum "$path" 2>/dev/null | awk '{print $1}'
    elif command_exists shasum; then
        shasum -a 256 "$path" 2>/dev/null | awk '{print $1}'
    else
        return 1
    fi
}

write_checksum_file() {
    local path="$1"
    local hash
    hash="$(compute_sha256 "$path")" || { log_warn "Unable to compute checksum for ${path} (missing sha256 tool)"; return; }
    local checksum_file="${path}.sha256"
    local old_umask
    old_umask=$(umask)
    umask 077
    if printf '%s\n' "$hash" > "$checksum_file"; then
        chmod 600 "$checksum_file" || true
    fi
    umask "$old_umask"
}

verify_checksum_file() {
    local path="$1"
    local checksum_file="${path}.sha256"
    [[ -f "$path" ]] || { log_warn "Cannot verify checksum; file missing: ${path}"; return 1; }
    [[ -f "$checksum_file" ]] || { log_warn "Checksum file missing for ${path}"; return 1; }
    local expected actual
    expected="$(tr -d '[:space:]' < "$checksum_file")"
    actual="$(compute_sha256 "$path")" || { log_warn "Unable to compute checksum for ${path}"; return 1; }
    if [[ "$expected" != "$actual" ]]; then
        log_warn "Checksum mismatch for ${path}"
        return 1
    fi
    return 0
}

require_root() {
    [[ $EUID -eq 0 ]] || die "Run as root or with sudo"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

generate_secret() {
    local bytes="${1:-32}"
    openssl rand -base64 "$bytes" | tr -d '\n'
}

password_is_strong() {
    local password="$1" min="${2:-16}"
    [[ ${#password} -ge $min ]] || return 1
    [[ "$password" =~ [A-Z] ]] || return 1
    [[ "$password" =~ [a-z] ]] || return 1
    [[ "$password" =~ [0-9] ]] || return 1
    return 0
}

validate_password_strength() {
    local password="$1" context="${2:-password}" min="${3:-16}"
    password_is_strong "$password" "$min" || die "${context} must be at least ${min} characters and include upper, lower, and numeric characters"
}

prompt_secure_password() {
    local prompt="$1" var_name="$2" min="${3:-16}"
    local first second
    while true; do
        read -rs -p "${prompt}: " first || true
        echo
        read -rs -p "Confirm password: " second || true
        echo
        if [[ "$first" != "$second" ]]; then
            log_warn "Passwords do not match"
            continue
        fi
        if ! password_is_strong "$first" "$min"; then
            log_warn "Password must be at least ${min} characters and include upper, lower, and numeric characters"
            continue
        fi
        eval "${var_name}=\"\${first}\""
        break
    done
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

validate_cidr() {
    local value="$1" context="${2:-cidr}"
    [[ -z "$value" ]] && return 0
    if [[ ! "$value" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$ ]]; then
        die "Invalid ${context}: ${value}"
    fi
    local ip="${value%/*}"
    validate_ip "$ip" "${context} base IP"
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

to_upper() {
    local value="$1"
    printf '%s\n' "$value" | tr '[:lower:]' '[:upper:]'
}
