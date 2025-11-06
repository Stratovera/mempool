#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Skipping permission test (needs root)"
    exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "${ROOT_DIR}/lib/common.sh"

tmpdir="$(mktemp -d)"
ensure_directory "${tmpdir}/data" "0" "0" 700

[[ -d "${tmpdir}/data" ]] || { echo "directory missing"; exit 1; }

rm -rf "$tmpdir"
