#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "${ROOT_DIR}/lib/common.sh"
# shellcheck source=/dev/null
source "${ROOT_DIR}/lib/config.sh"

load_config "${ROOT_DIR}/config/defaults.conf"
[[ -f "${ROOT_DIR}/config/mempool-stack.conf" ]] && load_config "${ROOT_DIR}/config/mempool-stack.conf"

validate_config

echo "Configuration valid"
