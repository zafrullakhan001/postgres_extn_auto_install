#!/bin/bash
#
# Point-in-Time Recovery (PITR) for PostgreSQL
# Usage: ./restore_pitr.sh [base_backup] [wal_archive] [recovery_target]
#

set -e

# Parameters
BASE_BACKUP="$1"
WAL_ARCHIVE="$2"
RECOVERY_TARGET="$3"
CONTAINER="${4:-PG-timescale}"
USER="postgres"
RECOVERY_TARGET_TYPE="time"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Check parameters
if [ -z "$BASE_BACKUP" ] || [ -z "$WAL_ARCHIVE" ]; then
    log_error "Missing required parameters!"
    log_info "Usage: $0 [base_backup] [wal_archive] [recovery_target] [container_name]"
    log_info "Example: $0 ./backups/basebackup_20260108_120000 ./backups/wal '2026-01-08 14:30:00'"
    exit 1
fi

log_info "PostgreSQL Point-in-Time Recovery (PITR)"
log_info "========================================="
log_info "Base Backup: $BASE_BACKUP"
log_info "WAL Archive: $WAL_ARCHIVE"
if [ -n "$RECOVERY_TARGET" ]; then
    log_info "Recovery Target: $RECOVERY_TARGET"
fi
echo ""

# Validate inputs
if [ ! -e "$BASE_BACKUP" ]; then
    log_error "Base backup not found: $BASE_BACKUP"
    exit 1
fi

if [ ! -e "$WAL_ARCHIVE" ]; then
    log_error "WAL archive not found: $WAL_ARCHIVE"
    exit 1
fi

log_success "Backup sources validated"

# Check if container exists
if ! docker ps -a --filter "name=$CONTAINER" --format "{{.Names}}" | grep -q "^${CONTAINER}$"; then
    log_error "Container '$CONTAINER' not found!"
    exit 1
fi

# Warning
log_warning "Point-in-Time Recovery will REPLACE all current data!"
log_warning "This is an advanced operation that requires:"
echo "  1. A valid base backup (pg_basebackup)"
echo "  2. WAL archive files covering the recovery period"
echo "  3. Proper PostgreSQL configuration"
echo ""
echo -e "${YELLOW}Press Ctrl+C to cancel, or press Enter to continue...${NC}"
read -r

# Stop container
log_info "Stopping container..."
docker stop "$CONTAINER" > /dev/null
log_success "Container stopped"

# Create recovery directory
RECOVERY_DIR="./recovery_temp"
rm -rf "$RECOVERY_DIR"
mkdir -p "$RECOVERY_DIR"

# Extract base backup
log_info "Extracting base backup..."
cp -a "$BASE_BACKUP"/* "$RECOVERY_DIR/"
log_success "Base backup extracted"

# Create recovery.signal file (PostgreSQL 12+)
log_info "Creating recovery configuration..."
touch "$RECOVERY_DIR/recovery.signal"

# Create postgresql.auto.conf with recovery settings
cat > "$RECOVERY_DIR/postgresql.auto.conf" <<EOF
# Point-in-Time Recovery Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

restore_command = 'cp /var/lib/postgresql/wal_archive/%f %p'
recovery_target_action = 'promote'
EOF

if [ -n "$RECOVERY_TARGET" ]; then
    echo "recovery_target_time = '$RECOVERY_TARGET'" >> "$RECOVERY_DIR/postgresql.auto.conf"
fi

log_success "Recovery configuration created"

# Get container's data volume
VOLUME_NAME=$(docker inspect "$CONTAINER" --format='{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Name}}{{end}}{{end}}')

if [ -n "$VOLUME_NAME" ]; then
    log_info "Data volume: $VOLUME_NAME"
    
    # Backup current data (safety measure)
    BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    log_info "Creating safety backup of current data..."
    mkdir -p ./backups
    SAFETY_BACKUP="./backups/safety_backup_${BACKUP_TIMESTAMP}.tar.gz"
    docker run --rm -v "$VOLUME_NAME:/source" -v "$(pwd)/backups:/backup" alpine tar czf "/backup/safety_backup_${BACKUP_TIMESTAMP}.tar.gz" -C /source . 2>/dev/null
    log_success "Safety backup created: $SAFETY_BACKUP"
    
    # Clear current data directory
    log_info "Clearing current data directory..."
    docker run --rm -v "$VOLUME_NAME:/data" alpine sh -c "rm -rf /data/*"
    log_success "Data directory cleared"
    
    # Copy recovery data to volume
    log_info "Copying recovery data to volume..."
    docker run --rm -v "$VOLUME_NAME:/target" -v "$(realpath "$RECOVERY_DIR"):/source" alpine sh -c "cp -a /source/* /target/"
    log_success "Recovery data copied"
    
    # Copy WAL archive to container
    log_info "Setting up WAL archive..."
    docker run --rm -v "$VOLUME_NAME:/target" -v "$(realpath "$WAL_ARCHIVE"):/wal" alpine sh -c "mkdir -p /target/wal_archive && cp -a /wal/* /target/wal_archive/"
    log_success "WAL archive configured"
fi

# Start container for recovery
log_info "Starting container for recovery..."
docker start "$CONTAINER" > /dev/null
log_success "Container started"

# Monitor recovery progress
log_info "PostgreSQL is now performing point-in-time recovery..."
log_info "This may take several minutes depending on the amount of WAL data"
echo ""

# Wait for recovery to complete
MAX_WAIT_SECONDS=300
WAITED_SECONDS=0
RECOVERY_COMPLETE=false

while [ $WAITED_SECONDS -lt $MAX_WAIT_SECONDS ] && [ "$RECOVERY_COMPLETE" = "false" ]; do
    sleep 5
    WAITED_SECONDS=$((WAITED_SECONDS + 5))
    
    # Check if PostgreSQL is accepting connections
    if docker exec "$CONTAINER" pg_isready -U "$USER" 2>/dev/null | grep -q "accepting connections"; then
        RECOVERY_COMPLETE=true
        log_success "Recovery completed! PostgreSQL is accepting connections"
        break
    else
        echo -n "."
    fi
done

echo ""

if [ "$RECOVERY_COMPLETE" = "true" ]; then
    # Verify recovery
    log_info "Verifying recovery..."
    
    PG_VERSION=$(docker exec "$CONTAINER" psql -U "$USER" -t -c "SELECT version();" 2>/dev/null | xargs)
    CURRENT_TIME=$(docker exec "$CONTAINER" psql -U "$USER" -t -c "SELECT now();" 2>/dev/null | xargs)
    
    echo ""
    log_success "Point-in-Time Recovery completed successfully!"
    log_info "PostgreSQL version: $PG_VERSION"
    log_info "Current database time: $CURRENT_TIME"
    
    if [ -n "$RECOVERY_TARGET" ]; then
        log_info "Recovery target was: $RECOVERY_TARGET"
    fi
    
    # List databases
    log_info "Verifying databases..."
    docker exec "$CONTAINER" psql -U "$USER" -c "\l"
    
    # Cleanup
    log_info "Cleaning up temporary files..."
    rm -rf "$RECOVERY_DIR"
    log_success "Cleanup completed"
else
    log_error "Recovery did not complete within $MAX_WAIT_SECONDS seconds"
    log_info "Check container logs: docker logs $CONTAINER"
    log_info "You may need to wait longer or check for errors"
fi

echo ""
log_info "Recovery Summary"
log_info "================"
log_info "Base Backup: $BASE_BACKUP"
log_info "WAL Archive: $WAL_ARCHIVE"
if [ -n "$RECOVERY_TARGET" ]; then
    log_info "Recovery Target: $RECOVERY_TARGET ($RECOVERY_TARGET_TYPE)"
fi
log_info "Safety Backup: $SAFETY_BACKUP"
echo ""
log_success "PITR operation completed!"
log_warning "Please verify your data thoroughly before using in production"
