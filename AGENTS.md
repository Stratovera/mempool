# Repository Guidelines

## Project Structure & Module Organization
`bin/mempool-deploy` is the CLI entry point; it sources ten focused libraries under `lib/` (common utilities, config, prerequisites, directories, bitcoind, mempool, docker-compose, firewall, monitoring, deployment). Runtime artifacts come from the `templates/` tree: docker-compose service YAML, config `.tmpl` files, helper script templates, and Grafana/Prometheus provisioning. User-editable settings live in `config/` (defaults plus `mempool-stack.conf`), while generated assets land inside `$MEMPOOL_BASE_DIR/<network>/`. Keep code contributions near the module they affect, and place docs inside `docs/`.

## Build, Test, and Development Commands
Primary workflow is Makefile-driven: `make install`, `make config`, `sudo make deploy`, plus `make start|stop|status|logs NETWORK=<net> [SERVICE=name]`. `make monitoring` re-renders Prometheus/Grafana files, and `make backup` calls the templated mysqldump helper. Always finish with `make test`, which runs unit + integration shell tests via `tests/test-runner.sh`.

## Coding Style & Naming Conventions
All scripts target Bash 5 with `#!/bin/bash` and `set -euo pipefail`. Use two-space indentation for YAML/templates, four spaces for Bash. Constants are uppercase snake case (`MEMPOOL_BASE_DIR`), functions use lowercase snake case verbs (`render_template`). Favor `[[ ... ]]`, quote expansions, and `local` scope. New modules should stay under 200 lines and include brief comments describing exported functions.

## Testing Guidelines
Lint every `.sh` file with `shellcheck`. Run `make test` locally; add targeted unit tests under `tests/unit` for helper logic (validation, config merging) and smoke checks under `tests/integration` (CLI invocations, template existence). Before shipping deployment changes, do a dry run on a disposable VM: `MEMPOOL_BASE_DIR=/tmp/mempool sudo make deploy` followed by `make status` and `make logs`.

## Commit & Pull Request Guidelines
Prefer Conventional Commits (`feat: add monitoring exporters`) and keep diffs scoped to one concern. PRs should call out affected modules, configuration knobs, and manual/automated test evidence. Attach screenshots or log excerpts for deployment regressions, and link relevant issues (Fix 1.1–3.5) when applicable.

## Security & Operational Notes
The tool runs with sudo, manages UFW, and exports RPC credentials only in memory—never persist secrets to git. When editing templates, ensure `${MEMPOOL_BASE_DIR}` is used instead of hardcoded paths. Avoid echoing credentials into logs, validate domain/port inputs, and gate destructive actions (e.g., cleanup scripts) with explicit prompts or flags.
