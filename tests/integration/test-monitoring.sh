#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

test -f "${ROOT_DIR}/templates/configs/prometheus.yml.tmpl"
