#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_suite() {
    local dir="$1"
    shopt -s nullglob
    for test in "$dir"/*.sh; do
        echo "Running $(basename "$test")"
        ( cd "$ROOT_DIR" && bash "$test" )
    done
}

run_suite "${ROOT_DIR}/tests/unit"
run_suite "${ROOT_DIR}/tests/integration"

echo "All tests passed"
