#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "${ROOT_DIR}/lib/common.sh"
# shellcheck source=/dev/null
source "${ROOT_DIR}/lib/config.sh"

load_config "${ROOT_DIR}/config/defaults.conf"

[[ "${MEMPOOL_BASE_DIR}" == "/opt/mempool" ]] || { echo "unexpected base dir"; exit 1; }

cat > "${ROOT_DIR}/.tmp-test.conf" <<EOF
MEMPOOL_BASE_DIR="/data/test"
EOF

load_config "${ROOT_DIR}/.tmp-test.conf"
[[ "${MEMPOOL_BASE_DIR}" == "/data/test" ]] || { echo "override failed"; exit 1; }
rm -f "${ROOT_DIR}/.tmp-test.conf"
