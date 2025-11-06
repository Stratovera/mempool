#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "${ROOT_DIR}/lib/common.sh"

validate_port 8080 "unit-test"
if ( validate_port "abc" "unit-test" ); then
    echo "validate_port accepted invalid data"
    exit 1
fi

validate_domain "example.com" "unit-test"
if ( validate_domain "bad_domain" "unit-test" ); then
    echo "validate_domain accepted bad host"
    exit 1
fi

validate_path "/tmp" "unit-test"
if ( validate_path "relative/path" "unit-test" ); then
    echo "validate_path accepted relative path"
    exit 1
fi
