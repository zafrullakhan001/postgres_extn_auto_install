#!/bin/bash
#
# Full restore of PostgreSQL database from backup
# Usage: ./restore_full.sh [backup_file] [logical|physical] [container_name]
#

set -e

# Parameters
BACKUP_FILE="$1"
RESTORE_TYPE="${2:-logical}"
CONTAINER="${3:-PG-timescale}"
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

# Check if backup file provided
if [ -z "$BACKUP_FILE" ]; then
    log_error "Backup file not specified!"
    log_info "Usage: $0 [backup_file] [logical|physical] [container_name]"
    exit 1
fi

log_info "PostgreSQL Full Restore Script"
log_info "==============================="
log_info "Restore Type: $RESTORE_TYPE"
log_info "Backup Source: $BACKUP_FILE"
log_info "Container: $CONTAINER"
echo ""

# Check if backup file/directory exists
if [ ! -e "$BACKUP_FILE" ]; then
    log_error "Backup file/directory not found: $BACKUP_FILE"
    exit 1
fi
log_success "Backup source found"

# Check if container is running
if ! docker ps --filter "name=$CONTAINER" --format "{{.Names}}" | grep -q "^${CONTAINER}$"; then
    log_error "Container '$CONTAINER' is not running!"
    log_info "Start the container first: docker start $CONTAINER"
    exit 1
fi
log_success "Container '$CONTAINER' is running"

# Warning prompt
log_warning "This will REPLACE all data in the database!"
echo -e "${YELLOW}Press Ctrl+C to cancel, or press Enter to continue...${NC}"
read -r

if [ "$RESTORE_TYPE" = "logical" ]; then
    log_info "Starting logical restore from SQL backup..."
    
    # Get file size
    FILE_SIZE=$(stat -f%z "$BACKUP_FILE" 2>/dev/null || stat -c%s "$BACKUP_FILE" 2>/dev/null)
    FILE_SIZE_MB=$(echo "scale=2; $FILE_SIZE / 1048576" | bc)
    log_info "Backup file size: ${FILE_SIZE_MB} MB"
    
    # Wait for PostgreSQL to be ready
    log_info "Waiting for PostgreSQL to be ready..."
    sleep 5
    
    # Perform restore
    log_info "Restoring database (this may take several minutes)..."
    if cat "$BACKUP_FILE" | docker exec -i "$CONTAINER" psql -U "$USER" > /dev/null 2>&1; then
        log_success "Logical restore completed successfully!"
        
        # Verify databases
        log_info "Verifying restored databases..."
        echo ""
        log_info "Restored Databases:"
        docker exec "$CONTAINER" psql -U "$USER" -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;"
        
        # Verify tables
        echo ""
        log_info "Verifying tables in 'postgres' database..."
        docker exec "$CONTAINER" psql -U "$USER" -c "\dt"
    else
        log_error "Restore failed!"
        exit 1
    fi
    
elif [ "$RESTORE_TYPE" = "physical" ]; then
    log_info "Starting physical restore from base backup..."
    
    # Check if directory exists
    if [ ! -d "$BACKUP_FILE" ]; then
        log_error "Backup directory not found: $BACKUP_FILE"
        exit 1
    fi
    
    log_warning "Physical restore requires stopping the container and replacing data directory"
    log_warning "This is an advanced operation. Consider using logical restore instead."
    
    # Stop container
    log_info "Stopping container..."
    docker stop "$CONTAINER" > /dev/null
    log_success "Container stopped"
    
    # Get container's data volume
    VOLUME_NAME=$(docker inspect "$CONTAINER" --format='{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Name}}{{end}}{{end}}')
    
    if [ -n "$VOLUME_NAME" ]; then
        log_info "Data volume: $VOLUME_NAME"
        
        # Backup current data (safety measure)
        BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        log_info "Creating safety backup of current data..."
        mkdir -p ./backups
        docker run --rm -v "$VOLUME_NAME:/source" -v "$(pwd)/backups:/backup" alpine tar czf "/backup/data_backup_${BACKUP_TIMESTAMP}.tar.gz" -C /source .
        log_success "Safety backup created: backups/data_backup_${BACKUP_TIMESTAMP}.tar.gz"
        
        # Clear current data
        log_info "Clearing current data directory..."
        docker run --rm -v "$VOLUME_NAME:/data" alpine sh -c "rm -rf /data/*"
        
        # Restore from backup
        log_info "Restoring data from backup..."
        docker run --rm -v "$VOLUME_NAME:/target" -v "$(realpath "$BACKUP_FILE"):/backup" alpine sh -c "cp -a /backup/* /target/"
        
        log_success "Data restored"
    else
        log_warning "No data volume found, attempting direct restore..."
    fi
    
    # Start container
    log_info "Starting container..."
    docker start "$CONTAINER" > /dev/null
    log_success "Container started"
    
    # Wait for PostgreSQL to be ready
    log_info "Waiting for PostgreSQL to start..."
    sleep 10
    
    # Verify
    PG_VERSION=$(docker exec "$CONTAINER" psql -U "$USER" -t -c "SELECT version();" 2>/dev/null | xargs)
    if [ -n "$PG_VERSION" ]; then
        log_success "Physical restore completed successfully!"
        log_info "PostgreSQL version: $PG_VERSION"
    else
        log_error "PostgreSQL may not have started correctly"
        log_info "Check logs: docker logs $CONTAINER"
    fi
else
    log_error "Invalid restore type: $RESTORE_TYPE"
    log_info "Usage: $0 [backup_file] [logical|physical] [container_name]"
    exit 1
fi

echo ""
log_success "Restore operation completed!"
log_info "Please verify your data and test your applications"
