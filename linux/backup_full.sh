#!/bin/bash
#
# Full PostgreSQL database backup script for Docker container
# Usage: ./backup_full.sh [logical|physical] [container_name] [backup_dir]
#

set -e

# Default parameters
BACKUP_TYPE="${1:-logical}"
CONTAINER="${2:-PG-timescale}"
BACKUP_DIR="${3:-./backups}"
USER="postgres"
RETENTION_DAYS=30

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

# Script start
log_info "PostgreSQL Full Backup Script"
log_info "=============================="
log_info "Backup Type: $BACKUP_TYPE"
log_info "Container: $CONTAINER"
log_info "Backup Directory: $BACKUP_DIR"
echo ""

# Check if container is running
if ! docker ps --filter "name=$CONTAINER" --format "{{.Names}}" | grep -q "^${CONTAINER}$"; then
    log_error "Container '$CONTAINER' is not running!"
    exit 1
fi
log_success "Container '$CONTAINER' is running"

# Create backup directory
mkdir -p "$BACKUP_DIR"
log_success "Backup directory ready: $BACKUP_DIR"

# Generate timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Get PostgreSQL version
PG_VERSION=$(docker exec "$CONTAINER" psql -U "$USER" -t -c "SELECT version();" 2>/dev/null | xargs)

if [ "$BACKUP_TYPE" = "logical" ]; then
    log_info "Starting logical backup (pg_dumpall)..."
    
    BACKUP_FILE="$BACKUP_DIR/full_backup_${TIMESTAMP}.sql"
    METADATA_FILE="$BACKUP_DIR/full_backup_${TIMESTAMP}.json"
    
    log_info "Backup file: $BACKUP_FILE"
    
    # Perform backup
    if docker exec "$CONTAINER" pg_dumpall -U "$USER" > "$BACKUP_FILE" 2>&1; then
        BACKUP_SIZE=$(stat -f%z "$BACKUP_FILE" 2>/dev/null || stat -c%s "$BACKUP_FILE" 2>/dev/null)
        BACKUP_SIZE_MB=$(echo "scale=2; $BACKUP_SIZE / 1048576" | bc)
        
        log_success "Logical backup completed successfully"
        log_info "Backup size: ${BACKUP_SIZE_MB} MB"
        
        # Create metadata
        cat > "$METADATA_FILE" <<EOF
{
  "backup_type": "logical",
  "timestamp": "$DATE",
  "container": "$CONTAINER",
  "postgres_version": "$PG_VERSION",
  "backup_size": $BACKUP_SIZE,
  "status": "completed"
}
EOF
        log_success "Metadata saved: $METADATA_FILE"
    else
        log_error "Backup failed!"
        exit 1
    fi
    
elif [ "$BACKUP_TYPE" = "physical" ]; then
    log_info "Starting physical backup (pg_basebackup)..."
    
    BACKUP_PATH="$BACKUP_DIR/basebackup_${TIMESTAMP}"
    METADATA_FILE="$BACKUP_DIR/basebackup_${TIMESTAMP}.json"
    
    log_info "Backup path: $BACKUP_PATH"
    
    mkdir -p "$BACKUP_PATH"
    
    # Perform base backup
    if docker exec "$CONTAINER" pg_basebackup -U "$USER" -D "/tmp/basebackup_${TIMESTAMP}" -Ft -z -P 2>&1; then
        # Copy from container to host
        docker cp "${CONTAINER}:/tmp/basebackup_${TIMESTAMP}" "$BACKUP_PATH"
        
        # Clean up container
        docker exec "$CONTAINER" rm -rf "/tmp/basebackup_${TIMESTAMP}"
        
        BACKUP_SIZE=$(du -sb "$BACKUP_PATH" | cut -f1)
        BACKUP_SIZE_MB=$(echo "scale=2; $BACKUP_SIZE / 1048576" | bc)
        
        log_success "Physical backup completed successfully"
        log_info "Backup size: ${BACKUP_SIZE_MB} MB"
        
        # Create metadata
        cat > "$METADATA_FILE" <<EOF
{
  "backup_type": "physical",
  "timestamp": "$DATE",
  "container": "$CONTAINER",
  "postgres_version": "$PG_VERSION",
  "backup_size": $BACKUP_SIZE,
  "status": "completed"
}
EOF
        log_success "Metadata saved: $METADATA_FILE"
    else
        log_error "Backup failed!"
        log_warning "Note: Physical backups require WAL archiving to be configured"
        exit 1
    fi
else
    log_error "Invalid backup type: $BACKUP_TYPE"
    log_info "Usage: $0 [logical|physical] [container_name] [backup_dir]"
    exit 1
fi

# Cleanup old backups
log_info "Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
log_success "Cleanup completed"

# Summary
echo ""
log_info "Backup Summary"
log_info "=============="
log_info "Status: completed"
log_info "Backup Type: $BACKUP_TYPE"
log_info "Timestamp: $DATE"
log_info "Size: ${BACKUP_SIZE_MB} MB"
echo ""

log_success "Full backup completed successfully!"
