#!/bin/bash
# PostgreSQL Tuning Script for Linux
# Analyzes current configuration and provides tuning recommendations

CONTAINER_NAME="PG-timescale"
OUTPUT_DIR="./tuning_reports"
WORKLOAD_PROFILE="Auto"
TOTAL_RAM_GB=0
APPLY_CHANGES=false

show_help() {
    cat << EOF
PostgreSQL Tuning Script
========================

Usage: $0 [OPTIONS]

Options:
    -c, --container NAME    Docker container name (default: PG-timescale)
    -o, --output DIR        Output directory for reports (default: ./tuning_reports)
    -w, --workload PROFILE  Workload type: Small, Medium, Large, Auto (default: Auto)
    -r, --ram GB            Total RAM in GB (auto-detect if not specified)
    -A, --apply             Apply recommended changes (requires confirmation)
    -h, --help              Show this help message

Workload Profiles:
    Small   - <4GB RAM, light workload
    Medium  - 4-16GB RAM, moderate workload
    Large   - >16GB RAM, heavy workload
    Auto    - Automatically detect based on system resources

Examples:
    $0
    $0 --workload Large --ram 32
    $0 --apply

EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--container)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -w|--workload)
            WORKLOAD_PROFILE="$2"
            shift 2
            ;;
        -r|--ram)
            TOTAL_RAM_GB="$2"
            shift 2
            ;;
        -A|--apply)
            APPLY_CHANGES=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# Create output directory
mkdir -p "$OUTPUT_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$OUTPUT_DIR/tuning_recommendations_$TIMESTAMP.txt"
CONFIG_FILE="$OUTPUT_DIR/postgresql_tuned_$TIMESTAMP.conf"

write_report() {
    echo "$1" | tee -a "$REPORT_FILE"
}

execute_query() {
    local query="$1"
    docker exec -i "$CONTAINER_NAME" psql -U postgres -t -A -c "$query" 2>&1
}

# Auto-detect RAM if not specified
if [ "$TOTAL_RAM_GB" -eq 0 ]; then
    if [ -f /proc/meminfo ]; then
        total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        TOTAL_RAM_GB=$((total_ram_kb / 1024 / 1024))
        echo "Auto-detected system RAM: $TOTAL_RAM_GB GB"
    else
        TOTAL_RAM_GB=8  # Default fallback
        echo "Could not detect RAM, using default: $TOTAL_RAM_GB GB"
    fi
fi

# Determine workload profile
if [ "$WORKLOAD_PROFILE" = "Auto" ]; then
    if [ $TOTAL_RAM_GB -lt 4 ]; then
        WORKLOAD_PROFILE="Small"
    elif [ $TOTAL_RAM_GB -lt 16 ]; then
        WORKLOAD_PROFILE="Medium"
    else
        WORKLOAD_PROFILE="Large"
    fi
    echo "Auto-selected workload profile: $WORKLOAD_PROFILE"
fi

write_report "╔════════════════════════════════════════════════════════════════════════════╗"
write_report "║          PostgreSQL Tuning Recommendations                                 ║"
write_report "╚════════════════════════════════════════════════════════════════════════════╝"
write_report ""
write_report "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
write_report "Container: $CONTAINER_NAME"
write_report "System RAM: $TOTAL_RAM_GB GB"
write_report "Workload Profile: $WORKLOAD_PROFILE"
write_report "$(printf '=%.0s' {1..80})"

# Get current PostgreSQL version
version=$(execute_query "SHOW server_version;")
write_report ""
write_report "PostgreSQL Version: $version"

# Calculate recommended values based on workload profile
declare -A recommendations

case $WORKLOAD_PROFILE in
    Small)
        # For systems with <4GB RAM
        recommendations[shared_buffers]=$((TOTAL_RAM_GB * 1024 * 25 / 100))  # 25% of RAM in MB
        [ ${recommendations[shared_buffers]} -lt 128 ] && recommendations[shared_buffers]=128
        recommendations[effective_cache_size]=$((TOTAL_RAM_GB * 1024 * 50 / 100))  # 50% of RAM
        recommendations[maintenance_work_mem]=64
        recommendations[work_mem]=4
        recommendations[max_connections]=100
        recommendations[max_parallel_workers_per_gather]=1
        recommendations[max_parallel_workers]=2
        recommendations[max_worker_processes]=2
        ;;
    Medium)
        # For systems with 4-16GB RAM
        recommendations[shared_buffers]=$((TOTAL_RAM_GB * 1024 * 25 / 100))  # 25% of RAM
        recommendations[effective_cache_size]=$((TOTAL_RAM_GB * 1024 * 75 / 100))  # 75% of RAM
        recommendations[maintenance_work_mem]=$((TOTAL_RAM_GB * 1024 * 5 / 100))  # 5% of RAM
        [ ${recommendations[maintenance_work_mem]} -gt 2048 ] && recommendations[maintenance_work_mem]=2048
        recommendations[work_mem]=16
        recommendations[max_connections]=200
        recommendations[max_parallel_workers_per_gather]=2
        recommendations[max_parallel_workers]=4
        recommendations[max_worker_processes]=4
        ;;
    Large)
        # For systems with >16GB RAM
        recommendations[shared_buffers]=$((TOTAL_RAM_GB * 1024 * 25 / 100))  # 25% of RAM
        [ ${recommendations[shared_buffers]} -gt 16384 ] && recommendations[shared_buffers]=16384  # max 16GB
        recommendations[effective_cache_size]=$((TOTAL_RAM_GB * 1024 * 75 / 100))  # 75% of RAM
        recommendations[maintenance_work_mem]=2048  # 2GB
        recommendations[work_mem]=32
        recommendations[max_connections]=300
        recommendations[max_parallel_workers_per_gather]=4
        recommendations[max_parallel_workers]=8
        recommendations[max_worker_processes]=8
        ;;
esac

# Additional recommendations (workload-independent)
recommendations[wal_buffers]=$((recommendations[shared_buffers] / 32))
[ ${recommendations[wal_buffers]} -lt 1 ] && recommendations[wal_buffers]=1
[ ${recommendations[wal_buffers]} -gt 16 ] && recommendations[wal_buffers]=16

recommendations[max_wal_size]=$((recommendations[shared_buffers] * 2))
[ ${recommendations[max_wal_size]} -lt 1024 ] && recommendations[max_wal_size]=1024

recommendations[min_wal_size]=$((recommendations[max_wal_size] / 4))

# Get current settings and compare
write_report ""
write_report "$(printf '=%.0s' {1..80})"
write_report "CURRENT vs RECOMMENDED SETTINGS"
write_report "$(printf '=%.0s' {1..80})"
write_report ""
printf "%-35s %-20s %-20s\n" "Parameter" "Current" "Recommended" | tee -a "$REPORT_FILE"
write_report "$(printf -- '-%.0s' {1..80})"

declare -a config_changes

for param in $(echo "${!recommendations[@]}" | tr ' ' '\n' | sort); do
    current=$(execute_query "SHOW $param;" | tr -d ' ')
    recommended=${recommendations[$param]}
    
    # Determine unit
    unit=""
    if [[ $param == *"mem"* ]] || [[ $param == *"buffers"* ]] || [[ $param == *"wal_size"* ]]; then
        unit="MB"
    fi
    
    current_display=${current:-N/A}
    recommended_display="$recommended$unit"
    
    # Check if change is needed
    needs_change=false
    if [ -n "$current" ]; then
        current_value=$(echo "$current" | sed 's/[^0-9.]//g')
        if [ -n "$current_value" ] && [ "$current_value" != "$recommended" ]; then
            needs_change=true
        fi
    fi
    
    marker="✓"
    [ "$needs_change" = true ] && marker="⚠"
    
    printf "%s %-33s %-20s %-20s\n" "$marker" "$param" "$current_display" "$recommended_display" | tee -a "$REPORT_FILE"
    
    if [ "$needs_change" = true ]; then
        config_changes+=("$param|$current_display|$recommended_display|$recommended|$unit")
    fi
done

# Generate postgresql.conf snippet
write_report ""
write_report "$(printf '=%.0s' {1..80})"
write_report "CONFIGURATION FILE SNIPPET"
write_report "$(printf '=%.0s' {1..80})"
write_report ""
write_report "Add the following to your postgresql.conf:"
write_report ""

cat > "$CONFIG_FILE" << EOF
# PostgreSQL Tuning Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Workload Profile: $WORKLOAD_PROFILE
# System RAM: $TOTAL_RAM_GB GB

# Memory Settings
shared_buffers = ${recommendations[shared_buffers]}MB
effective_cache_size = ${recommendations[effective_cache_size]}MB
maintenance_work_mem = ${recommendations[maintenance_work_mem]}MB
work_mem = ${recommendations[work_mem]}MB

# Connection Settings
max_connections = ${recommendations[max_connections]}

# Parallel Query Settings
max_parallel_workers_per_gather = ${recommendations[max_parallel_workers_per_gather]}
max_parallel_workers = ${recommendations[max_parallel_workers]}
max_worker_processes = ${recommendations[max_worker_processes]}

# WAL Settings
wal_buffers = ${recommendations[wal_buffers]}MB
checkpoint_completion_target = 0.9
max_wal_size = ${recommendations[max_wal_size]}MB
min_wal_size = ${recommendations[min_wal_size]}MB

# Storage Settings (for SSD)
random_page_cost = 1.1
effective_io_concurrency = 200

# Autovacuum Settings
autovacuum_max_workers = 3
autovacuum_naptime = 10s

# Query Planner Settings
default_statistics_target = 100

# Logging (for performance monitoring)
log_min_duration_statement = 1000  # Log queries slower than 1 second
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_temp_files = 0

# Extensions for monitoring
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all
pg_stat_statements.max = 10000
EOF

cat "$CONFIG_FILE" | tee -a "$REPORT_FILE"

write_report ""
write_report "Configuration saved to: $CONFIG_FILE"

# Performance analysis based on current state
write_report ""
write_report "$(printf '=%.0s' {1..80})"
write_report "PERFORMANCE ANALYSIS"
write_report "$(printf '=%.0s' {1..80})"

# Check cache hit ratio
cache_hit=$(execute_query "SELECT round((sum(heap_blks_hit) * 100.0 / NULLIF(sum(heap_blks_hit + heap_blks_read), 0))::numeric, 2) FROM pg_statio_user_tables;")

if [ -n "$cache_hit" ]; then
    write_report ""
    write_report "Cache Hit Ratio: $cache_hit%"
    if (( $(echo "$cache_hit < 99" | bc -l) )); then
        write_report "  ⚠ Low cache hit ratio - consider increasing shared_buffers"
    else
        write_report "  ✓ Good cache hit ratio"
    fi
fi

# Check checkpoint frequency
checkpoints=$(execute_query "SELECT checkpoints_timed || '|' || checkpoints_req || '|' || round((checkpoints_req * 100.0 / NULLIF(checkpoints_timed + checkpoints_req, 0))::numeric, 2) FROM pg_stat_bgwriter;")

if [ -n "$checkpoints" ]; then
    timed=$(echo "$checkpoints" | cut -d'|' -f1)
    requested=$(echo "$checkpoints" | cut -d'|' -f2)
    req_pct=$(echo "$checkpoints" | cut -d'|' -f3)
    
    write_report ""
    write_report "Checkpoint Statistics:"
    write_report "  Timed checkpoints: $timed"
    write_report "  Requested checkpoints: $requested ($req_pct%)"
    
    if (( $(echo "$req_pct > 10" | bc -l) )); then
        write_report "  ⚠ High percentage of requested checkpoints - consider increasing max_wal_size"
    else
        write_report "  ✓ Checkpoint frequency is good"
    fi
fi

# Additional recommendations
write_report ""
write_report "$(printf '=%.0s' {1..80})"
write_report "ADDITIONAL RECOMMENDATIONS"
write_report "$(printf '=%.0s' {1..80})"
write_report ""

write_report "1. MONITORING:"
write_report "   • Enable pg_stat_statements extension for query analysis"
write_report "   • Set up regular health checks and performance monitoring"
write_report "   • Monitor slow query log (log_min_duration_statement)"
write_report ""

write_report "2. MAINTENANCE:"
write_report "   • Ensure autovacuum is running regularly"
write_report "   • Schedule ANALYZE after bulk data loads"
write_report "   • Monitor table bloat and run VACUUM FULL if needed"
write_report "   • Regularly update statistics with ANALYZE"
write_report ""

write_report "3. INDEXING:"
write_report "   • Review query patterns and add missing indexes"
write_report "   • Remove unused indexes to reduce write overhead"
write_report "   • Consider partial indexes for filtered queries"
write_report "   • Use EXPLAIN ANALYZE to optimize query plans"
write_report ""

write_report "4. HARDWARE:"
write_report "   • Use SSD storage for better I/O performance"
write_report "   • Ensure adequate RAM for caching"
write_report "   • Consider connection pooling (PgBouncer) for high connection counts"
write_report ""

write_report "5. BACKUP & RECOVERY:"
write_report "   • Configure WAL archiving for point-in-time recovery"
write_report "   • Test restore procedures regularly"
write_report "   • Monitor backup completion and size"
write_report ""

# Apply changes if requested
if [ "$APPLY_CHANGES" = true ]; then
    echo ""
    echo "$(printf '=%.0s' {1..80})"
    echo "WARNING: Applying configuration changes"
    echo "$(printf '=%.0s' {1..80})"
    echo ""
    echo "This will modify PostgreSQL configuration and require a restart."
    echo "The following parameters will be changed:"
    echo ""
    
    for change in "${config_changes[@]}"; do
        IFS='|' read -r param current recommended value unit <<< "$change"
        echo "  • $param: $current → $recommended"
    done
    
    echo ""
    read -p "Do you want to proceed? (yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        echo ""
        echo "Applying changes..."
        
        # Copy config file to container
        echo "  1. Copying configuration to container..."
        docker cp "$CONFIG_FILE" "$CONTAINER_NAME:/tmp/postgresql_tuned.conf"
        
        echo "  2. Appending to postgresql.conf..."
        docker exec "$CONTAINER_NAME" bash -c "cat /tmp/postgresql_tuned.conf >> /var/lib/postgresql/data/postgresql.conf"
        
        echo "  3. Restarting PostgreSQL..."
        docker restart "$CONTAINER_NAME"
        
        echo ""
        echo "✅ Configuration applied successfully!"
        echo "⚠  Please verify the changes and monitor performance."
    else
        echo ""
        echo "❌ Changes not applied."
    fi
fi

write_report ""
write_report "$(printf '=%.0s' {1..80})"
write_report "Report saved to: $REPORT_FILE"
write_report "Configuration file: $CONFIG_FILE"
write_report "$(printf '=%.0s' {1..80})"

if [ "$APPLY_CHANGES" = false ]; then
    echo ""
    echo "💡 Tip: Use --apply flag to automatically apply these settings"
fi

echo ""
echo "✅ Tuning analysis complete!"
