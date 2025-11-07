# Changelog

## 1.0.0
- Restructured repository into modular libraries and templates
- Added Makefile UX and `bin/mempool-deploy` CLI
- Implemented monitoring stack, tests, CI, and helper docs
- **Credential & Secret Handling**
  - Hardened RPC/MariaDB secret storage (`config/.secrets`, per-network secret mounts, no plaintext files)
  - `sudo bin/mempool-deploy rotate-credentials` now rotates DB + RPC secrets atomically and logs every change
  - Restored RPC username/password flow for services lacking cookie support, while keeping secrets out of templates
- **Deployment & Ops Reliability**
  - `sudo make deploy` force-recreates Compose projects so config/secret changes take effect immediately
  - API receives DB credentials via env/secrets, plus legacy fallbacks for existing installs
  - Bitcoind UID detection, directory prep, and cleanup routines now validate permissions instead of masking errors
  - MariaDB containers expose a `mysql` client alias, enabling rotation scripts and on-box maintenance
- **Networking & Configuration**
  - Added per-network bitcoind tuning overrides and bind-address prompts
  - Frontend/backend service wiring cleaned up (per-network hosts, TLS disabled by default for electrs, service names used throughout)
  - Documentation updated with networking guidance, credential rotation steps, and troubleshooting notes
