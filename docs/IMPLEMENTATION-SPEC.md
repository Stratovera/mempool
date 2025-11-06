# Implementation Specification: Persistent Data Storage for Mempool Stack

**Version:** 1.0
**Date:** 2025-11-05
**Status:** Ready for Implementation
**Deployment Type:** Fresh Installation (Resync from Scratch)

## Executive Summary

Modify `deploy-mempool.sh` to use filesystem bind mounts instead of Docker named volumes, ensuring blockchain and application data persists across VM rebuilds and Docker reinstallations.

**Deployment Strategy:** This specification is designed for a **fresh deployment** that will sync Bitcoin blockchain data from scratch. No migration of existing data is required.

### Expected Timeline

- **Script modification:** 30 minutes
- **Deployment execution:** 10-15 minutes
- **Mainnet blockchain sync:** 3-7 days (depends on hardware/network)
- **Signet blockchain sync:** 2-4 hours
- **Total time to full operation (mainnet):** ~1 week

## Problem Statement

The current script uses Docker named volumes stored in `/var/lib/docker/volumes/`. This creates three critical issues:

1. **Data loss on VM rebuild** - Volumes are stored in VM ephemeral storage
2. **Difficult backup/migration** - Data locked in Docker's internal filesystem
3. **Poor visibility** - Unclear where data is stored and how much space is used

**Current approach:**
```yaml
volumes:
  mysql-data:
    name: mempool-mysql-mainnet
  # ... Docker manages these internally
```

**Target approach:**
```yaml
volumes:
  - ./data/mysql:/var/lib/mysql  # Direct filesystem bind mount
```

## Solution Architecture

### Directory Structure

```
/opt/mempool/                          # $MEMPOOL_BASE_DIR (configurable)
├── mainnet/
│   ├── docker-compose.yml
│   ├── mempool-config.json
│   ├── bitcoin.conf
│   ├── data/                          # ← NEW: Persistent data directory
│   │   ├── mysql/                     # ← MariaDB data (~50GB mainnet)
│   │   ├── api/                       # ← API cache (~1GB)
│   │   ├── electrs/                   # ← Electrs index (~100GB mainnet)
│   │   └── bitcoin/                   # ← Bitcoin blockchain (~600GB mainnet)
│   └── [existing files...]
├── signet/
│   ├── docker-compose.yml
│   ├── data/
│   │   ├── mysql/                     # ← ~1GB signet
│   │   ├── api/
│   │   ├── electrs/                   # ← ~2GB signet
│   │   └── bitcoin/                   # ← ~5GB signet
│   └── [existing files...]
└── [management scripts...]
```

**Alternative for large deployments:** Mount persistent disks at `/mnt/mempool-storage/` and update `MEMPOOL_BASE_DIR`.

### Docker Compose Changes

#### Current Configuration (Named Volumes)
```yaml
services:
  database:
    volumes:
      - mysql-data:/var/lib/mysql

  api:
    volumes:
      - api-data:/backend/cache

  electrs:
    volumes:
      - electrs-data:/data

  bitcoind:
    volumes:
      - bitcoin-data:/home/bitcoin/.bitcoin

volumes:
  mysql-data:
    name: mempool-mysql-mainnet
  electrs-data:
    name: mempool-electrs-mainnet
  api-data:
    name: mempool-api-mainnet
  bitcoin-data:
    name: mempool-bitcoin-mainnet
```

#### Target Configuration (Bind Mounts)
```yaml
services:
  database:
    volumes:
      - ./data/mysql:/var/lib/mysql

  api:
    volumes:
      - ./data/api:/backend/cache

  electrs:
    volumes:
      - ./data/electrs:/data

  bitcoind:
    volumes:
      - ./data/bitcoin:/home/bitcoin/.bitcoin

# No volumes section needed - bind mounts are direct filesystem mappings
```

## Implementation Steps

### Step 1: Modify `create_directories()` Function

**Location:** `deploy-mempool.sh` around line 161

**Current code:**
```bash
create_directories() {
    print_header "Creating directory structure..."

    mkdir -p "$MEMPOOL_BASE_DIR"

    if [[ "$DEPLOY_MAINNET" == true ]]; then
        mkdir -p "$MEMPOOL_BASE_DIR/mainnet/data"
        mkdir -p "$MEMPOOL_BASE_DIR/mainnet/mysql"
        mkdir -p "$MEMPOOL_BASE_DIR/mainnet/nginx"
    fi

    if [[ "$DEPLOY_SIGNET" == true ]]; then
        mkdir -p "$MEMPOOL_BASE_DIR/signet/data"
        mkdir -p "$MEMPOOL_BASE_DIR/signet/mysql"
        mkdir -p "$MEMPOOL_BASE_DIR/signet/nginx"
    fi

    print_success "Directory structure created"
}
```

**Modified code:**
```bash
create_directories() {
    print_header "Creating directory structure..."

    mkdir -p "$MEMPOOL_BASE_DIR"

    if [[ "$DEPLOY_MAINNET" == true ]]; then
        mkdir -p "$MEMPOOL_BASE_DIR/mainnet/nginx"
        # Create persistent data directories
        mkdir -p "$MEMPOOL_BASE_DIR/mainnet/data/mysql"
        mkdir -p "$MEMPOOL_BASE_DIR/mainnet/data/api"
        mkdir -p "$MEMPOOL_BASE_DIR/mainnet/data/electrs"
        if [[ "$USE_EXTERNAL_BITCOIND" == false ]]; then
            mkdir -p "$MEMPOOL_BASE_DIR/mainnet/data/bitcoin"
        fi
    fi

    if [[ "$DEPLOY_SIGNET" == true ]]; then
        mkdir -p "$MEMPOOL_BASE_DIR/signet/nginx"
        # Create persistent data directories
        mkdir -p "$MEMPOOL_BASE_DIR/signet/data/mysql"
        mkdir -p "$MEMPOOL_BASE_DIR/signet/data/api"
        mkdir -p "$MEMPOOL_BASE_DIR/signet/data/electrs"
        if [[ "$USE_EXTERNAL_BITCOIND" == false ]]; then
            mkdir -p "$MEMPOOL_BASE_DIR/signet/data/bitcoin"
        fi
    fi

    print_success "Directory structure created"
    print_status "Data will be stored in: $MEMPOOL_BASE_DIR/<network>/data/"
}
```

### Step 2: Modify `create_docker_compose()` Function - API Service

**Location:** `deploy-mempool.sh` lines 398-400

**Find:**
```bash
    volumes:
      - ./mempool-config.json:/backend/mempool-config.json:ro
      - api-data:/backend/cache
```

**Replace with:**
```bash
    volumes:
      - ./mempool-config.json:/backend/mempool-config.json:ro
      - ./data/api:/backend/cache
```

### Step 3: Modify `create_docker_compose()` Function - Database Service

**Location:** `deploy-mempool.sh` lines 426-427

**Find:**
```bash
    volumes:
      - mysql-data:/var/lib/mysql
```

**Replace with:**
```bash
    volumes:
      - ./data/mysql:/var/lib/mysql
```

### Step 4: Modify `create_docker_compose()` Function - Electrs Service

**Location:** `deploy-mempool.sh` lines 452-453

**Find:**
```bash
    volumes:
      - electrs-data:/data
```

**Replace with:**
```bash
    volumes:
      - ./data/electrs:/data
```

### Step 5: Modify `create_docker_compose()` Function - Bitcoind Service

**Location:** `deploy-mempool.sh` lines 509-510

**Find:**
```bash
    volumes:
      - bitcoin-data:/home/bitcoin/.bitcoin
```

**Replace with:**
```bash
    volumes:
      - ./data/bitcoin:/home/bitcoin/.bitcoin
```

### Step 6: Remove Named Volumes Section

**Location:** `deploy-mempool.sh` lines 520-536

**Delete this entire section:**
```bash
cat >> "$config_dir/docker-compose.yml" << EOF

volumes:
  mysql-data:
    name: mempool-mysql-$network
  electrs-data:
    name: mempool-electrs-$network
  api-data:
    name: mempool-api-$network
EOF

if [[ "$USE_EXTERNAL_BITCOIND" == false ]]; then
    cat >> "$config_dir/docker-compose.yml" << EOF
  bitcoin-data:
    name: mempool-bitcoin-$network
EOF
fi
```

**No replacement needed** - bind mounts don't require volume declarations.

### Step 7: Update `show_deployment_summary()` Function

**Location:** `deploy-mempool.sh` around line 959

**Add after the "Bitcoin Core Information" section:**
```bash
    print_status "Data Storage Locations:"
    if [[ "$DEPLOY_MAINNET" == true ]]; then
        echo "  Mainnet data: $MEMPOOL_BASE_DIR/mainnet/data/"
        echo "    - Bitcoin blockchain: $MEMPOOL_BASE_DIR/mainnet/data/bitcoin/"
        echo "    - Electrs index: $MEMPOOL_BASE_DIR/mainnet/data/electrs/"
        echo "    - MariaDB: $MEMPOOL_BASE_DIR/mainnet/data/mysql/"
        echo "    - API cache: $MEMPOOL_BASE_DIR/mainnet/data/api/"
    fi
    if [[ "$DEPLOY_SIGNET" == true ]]; then
        echo "  Signet data: $MEMPOOL_BASE_DIR/signet/data/"
    fi
    echo
```

### Step 8: Update `create_backup_script()` Function

**Location:** `deploy-mempool.sh` lines 1095-1147

**Find the database backup section (around lines 1129-1136):**
```bash
# Export Docker volumes (database only - Bitcoin data is too large)
echo "Backing up databases..."
if docker volume ls | grep -q "mempool-mysql-mainnet"; then
    docker run --rm -v mempool-mysql-mainnet:/data -v "$BACKUP_DIR":/backup alpine tar czf /backup/mysql-mainnet.tar.gz -C /data .
fi

if docker volume ls | grep -q "mempool-mysql-signet"; then
    docker run --rm -v mempool-mysql-signet:/data -v "$BACKUP_DIR":/backup alpine tar czf /backup/mysql-signet.tar.gz -C /data .
fi
```

**Replace with:**
```bash
# Backup databases (now using bind mounts)
echo "Backing up databases..."
if [[ -d "/opt/mempool/mainnet/data/mysql" ]]; then
    tar czf "$BACKUP_DIR/mysql-mainnet.tar.gz" -C /opt/mempool/mainnet/data mysql
fi

if [[ -d "/opt/mempool/signet/data/mysql" ]]; then
    tar czf "$BACKUP_DIR/mysql-signet.tar.gz" -C /opt/mempool/signet/data mysql
fi

# Backup API cache
if [[ -d "/opt/mempool/mainnet/data/api" ]]; then
    tar czf "$BACKUP_DIR/api-mainnet.tar.gz" -C /opt/mempool/mainnet/data api
fi

if [[ -d "/opt/mempool/signet/data/api" ]]; then
    tar czf "$BACKUP_DIR/api-signet.tar.gz" -C /opt/mempool/signet/data api
fi
```

## Handling Existing Deployments

**If you have an existing deployment with the old script:**

1. **Backup important data** (if needed):
   ```bash
   # Export configurations only
   cp /opt/mempool/mainnet/mempool-config.json ~/backup/
   cp /opt/mempool/mainnet/bitcoin.conf ~/backup/
   ```

2. **Stop and remove old deployment**:
   ```bash
   cd /opt/mempool/mainnet && docker compose down
   cd /opt/mempool/signet && docker compose down

   # Remove old deployment directory
   sudo rm -rf /opt/mempool

   # Clean up old Docker volumes (optional)
   docker volume prune
   ```

3. **Proceed with fresh deployment** using the modified script

**Note:** Since we're resyncing from scratch, there's no need to migrate existing blockchain data. Bitcoin Core mainnet will take several days to sync, signet will take a few hours.

## Testing Checklist

After implementation, verify:

- [ ] New deployments create `data/` directories correctly
- [ ] Docker Compose files reference `./data/*` bind mounts
- [ ] Docker Compose files have no `volumes:` section at bottom
- [ ] Services start successfully: `docker compose ps`
- [ ] Data directories populate as services run: `ls -lh /opt/mempool/mainnet/data/`
- [ ] Bitcoin Core syncs: `/opt/mempool/bitcoin-cli.sh mainnet getblockchaininfo`
- [ ] Web interface accessible: `http://localhost:8080`
- [ ] API responds: `curl http://localhost:8999/api/v1/statistics`
- [ ] Backup script works: `/opt/mempool/backup.sh`
- [ ] Data persists after restart: `docker compose down && docker compose up -d`

## Configuration Options

### Using a Custom Base Directory

To store data on a different disk or partition:

**Before running the script, edit line 18:**
```bash
# Default
MEMPOOL_BASE_DIR="/opt/mempool"

# Custom examples
MEMPOOL_BASE_DIR="/mnt/mempool-storage"      # Persistent disk
MEMPOOL_BASE_DIR="$HOME/mempool-data"        # User's home directory
MEMPOOL_BASE_DIR="/srv/mempool"              # Alternative system location
```

**For cloud deployments with attached persistent disks:**
```bash
# Mount disk first
sudo mkfs.ext4 /dev/sdb
sudo mkdir -p /mnt/mempool-storage
sudo mount /dev/sdb /mnt/mempool-storage
echo "/dev/sdb /mnt/mempool-storage ext4 defaults 0 0" | sudo tee -a /etc/fstab

# Update script
MEMPOOL_BASE_DIR="/mnt/mempool-storage"
```

## Storage Requirements

| Network | Bitcoin Data | Electrs Index | MySQL DB | API Cache | Total  |
|---------|-------------|---------------|----------|-----------|--------|
| Mainnet | ~600 GB     | ~100 GB       | ~50 GB   | ~1 GB     | ~750 GB |
| Signet  | ~5 GB       | ~2 GB         | ~1 GB    | <1 GB     | ~10 GB  |

**Ensure sufficient disk space before deployment.**

## Rollback Plan

If issues arise after implementation:

**Option 1: Fix and restart**
1. Stop services: `cd /opt/mempool/mainnet && docker compose down`
2. Fix the issue (permissions, disk space, config error)
3. Restart services: `docker compose up -d`

**Option 2: Start over**
1. Remove deployment: `sudo rm -rf /opt/mempool`
2. Fix the modified `deploy-mempool.sh` script
3. Rerun deployment: `sudo ./deploy-mempool.sh`

**Note:** Since this is a fresh deployment, no data will be lost by starting over - blockchain will just resync from the beginning.

## Success Criteria

Implementation is successful when:

1. ✅ All services start and run normally
2. ✅ Data directories created at `/opt/mempool/<network>/data/`
3. ✅ Data persists after container restart (`docker compose down && docker compose up -d`)
4. ✅ Backups complete successfully (`/opt/mempool/backup.sh`)
5. ✅ No Docker named volumes in use (`docker volume ls | grep mempool` returns nothing)
6. ✅ Blockchain sync begins and progresses (check with `/opt/mempool/bitcoin-cli.sh mainnet getblockchaininfo`)
7. ✅ Web interface accessible after initial sync begins

## Support Notes

- **Permissions issues:** Check container UID with `docker run --rm <image> id`
- **Missing data:** Verify bind mount paths in docker-compose.yml
- **Sync restarts:** Normal if containers couldn't access existing data
- **Space issues:** Check with `df -h /opt/mempool`

## Deliverables

After implementation, the following files should be modified:

1. `deploy-mempool.sh` - All changes above applied
2. Generated `docker-compose.yml` files - Will use bind mounts automatically
3. `backup.sh` - Updated to backup bind-mounted directories

## Pre-Implementation Checklist

Before starting, confirm:

1. ✅ **Deployment type confirmed:** Fresh installation with resync from scratch
2. ⚠️ **Disk space verified:** Minimum 750GB available for mainnet (10GB for signet)
3. ⚠️ **Target directory confirmed:** Default is `/opt/mempool` (customize in line 18 if needed)
4. ⚠️ **Sync time understood:** Mainnet will take 3-7 days, signet takes 2-4 hours
5. ⚠️ **Old deployment handled:** If exists, backed up and removed per above section

---

**End of Implementation Specification**

**Note to implementer:** This spec consolidates recommendations from Claude, Gemini, and Codex. Follow steps sequentially, test at each stage, and verify success criteria before proceeding to production.
