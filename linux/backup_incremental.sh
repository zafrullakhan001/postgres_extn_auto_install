#!/bin/bash
#
# Incremental PostgreSQL backup using WAL archiving
# Usage: ./backup_incremental.sh [setup|backup|archive|status] [container_name] [backup_dir]
#

set -e

# Default parameters
ACTION="${1:-backup}"
CONTAINER="${2:-PG-timescale}"
BACKUP_DIR="${3:-./backups/wal}"
USER="postgres"

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

log_info "PostgreSQL Incremental Backup Script"
log_info "====================================="
log_info "Action: $ACTION"
log_info "Container: $CONTAINER"
echo ""

# Check if container is running
if ! docker ps --filter "name=$CONTAINER" --format "{{.Names}}" | grep -q "^${CONTAINER}$"; then
    log_error "Container '$CONTAINER' is not running!"
    exit 1
fi

case "$ACTION" in
    setup)
        log_info "Setting up WAL archiving for incremental backups..."
        
        # Create WAL archive directory
        mkdir -p "$BACKUP_DIR"
        log_success "Created WAL archive directory: $BACKUP_DIR"
        
        # Create archive directory inside container
        docker exec "$CONTAINER" mkdir -p /var/lib/postgresql/wal_archive 2>/dev/null || true
        
        log_info "Configuring PostgreSQL for WAL archiving..."
        log_warning "Note: This requires PostgreSQL restart and proper configuration"
        
        # Display configuration instructions
        echo ""
        log_info "Manual Configuration Required:"
        echo "1. Edit postgresql.conf in the container:"
        echo "   docker exec -it $CONTAINER bash"
        echo "   vi /var/lib/postgresql/data/postgresql.conf"
        echo ""
        echo "2. Add/modify these settings:"
        echo "   wal_level = replica"
        echo "   archive_mode = on"
        echo "   archive_command = 'cp %p /var/lib/postgresql/wal_archive/%f'"
        echo "   max_wal_senders = 3"
        echo "   wal_keep_size = 1GB"
        echo ""
        echo "3. Restart PostgreSQL:"
        echo "   docker restart $CONTAINER"
        echo ""
        log_success "Setup instructions displayed"
        ;;
        
    status)
        log_info "Checking WAL archiving status..."
        
        # Check archive mode
        ARCHIVE_MODE=$(docker exec "$CONTAINER" psql -U "$USER" -t -c "SHOW archive_mode;" 2>/dev/null | xargs)
        WAL_LEVEL=$(docker exec "$CONTAINER" psql -U "$USER" -t -c "SHOW wal_level;" 2>/dev/null | xargs)
        ARCHIVE_CMD=$(docker exec "$CONTAINER" psql -U "$USER" -t -c "SHOW archive_command;" 2>/dev/null | xargs)
        
        echo ""
        log_info "Current Configuration:"
        echo "  Archive Mode: $ARCHIVE_MODE"
        echo "  WAL Level: $WAL_LEVEL"
        echo "  Archive Command: $ARCHIVE_CMD"
        echo ""
        
        # Check archiver statistics
        log_info "Archiver Statistics:"
        docker exec "$CONTAINER" psql -U "$USER" -c "SELECT archived_count, failed_count, last_archived_wal, last_archived_time FROM pg_stat_archiver;"
        ;;
        
    backup)
        log_info "Creating incremental backup (WAL segments)..."
        
        # Generate timestamp
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        
        # Create backup directory for this run
        INCREMENTAL_DIR="$BACKUP_DIR/incremental_${TIMESTAMP}"
        mkdir -p "$INCREMENTAL_DIR"
        
        # Force WAL segment switch
        log_info "Forcing WAL segment switch..."
        docker exec "$CONTAINER" psql -U "$USER" -c "SELECT pg_switch_wal();" 2>/dev/null || true
        
        # Copy WAL files from container
        log_info "Copying WAL archive files..."
        docker cp "${CONTAINER}:/var/lib/postgresql/wal_archive/." "$INCREMENTAL_DIR" 2>/dev/null || true
        
        WAL_COUNT=$(find "$INCREMENTAL_DIR" -type f | wc -l)
        WAL_SIZE=$(du -sb "$INCREMENTAL_DIR" 2>/dev/null | cut -f1)
        WAL_SIZE_MB=$(echo "scale=2; $WAL_SIZE / 1048576" | bc)
        
        log_success "Incremental backup completed"
        log_info "WAL files copied: $WAL_COUNT"
        log_info "Total size: ${WAL_SIZE_MB} MB"
        
        # Create metadata
        cat > "$INCREMENTAL_DIR/metadata.json" <<EOF
{
  "backup_type": "incremental",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')",
  "wal_files": $WAL_COUNT,
  "size_bytes": $WAL_SIZE,
  "backup_path": "$INCREMENTAL_DIR"
}
EOF
        
        log_warning "Consider cleaning up WAL archive in container after verification"
        log_info "To clean up: docker exec $CONTAINER rm -f /var/lib/postgresql/wal_archive/*"
        ;;
        
    archive)
        log_info "Archiving current WAL files..."
        
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        ARCHIVE_DIR="$BACKUP_DIR/archive_${TIMESTAMP}"
        mkdir -p "$ARCHIVE_DIR"
        
        # Copy WAL files
        docker cp "${CONTAINER}:/var/lib/postgresql/data/pg_wal/." "$ARCHIVE_DIR"
        
        log_success "WAL files archived to: $ARCHIVE_DIR"
        ;;
        
    *)
        log_error "Invalid action: $ACTION"
        log_info "Usage: $0 [setup|backup|archive|status] [container_name] [backup_dir]"
        exit 1
        ;;
esac

echo ""
log_success "Incremental backup operation completed!"
