#!/bin/bash
# PostgreSQL Health Check Script for Linux
# Performs comprehensive health checks on PostgreSQL database

CONTAINER_NAME="PG-timescale"
DATABASE="postgres"
OUTPUT_DIR="./health_reports"
SEND_ALERT=false
ALERT_EMAIL=""

show_help() {
    cat << EOF
PostgreSQL Health Check Script
==============================

Usage: $0 [OPTIONS]

Options:
    -c, --container NAME    Docker container name (default: PG-timescale)
    -d, --database NAME     Database to check (default: postgres)
    -o, --output DIR        Output directory for reports (default: ./health_reports)
    -a, --alert             Send email alerts for critical issues
    -e, --email ADDRESS     Email address for alerts
    -h, --help              Show this help message

Examples:
    $0
    $0 -d mydb
    $0 --alert --email admin@example.com

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
        -d|--database)
            DATABASE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -a|--alert)
            SEND_ALERT=true
            shift
            ;;
        -e|--email)
            ALERT_EMAIL="$2"
            shift 2
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
REPORT_FILE="$OUTPUT_DIR/health_check_$TIMESTAMP.txt"
HEALTH_SCORE=100
CRITICAL_COUNT=0
WARNING_COUNT=0

declare -a ISSUES
declare -a WARNINGS

write_report() {
    echo "$1" | tee -a "$REPORT_FILE"
}

add_issue() {
    local severity="$1"
    local category="$2"
    local message="$3"
    local score_impact="${4:-0}"
    
    if [ "$severity" = "CRITICAL" ]; then
        ISSUES+=("[$category] $message")
        HEALTH_SCORE=$((HEALTH_SCORE - score_impact))
        CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
        write_report "❌ CRITICAL [$category]: $message"
    elif [ "$severity" = "WARNING" ]; then
        WARNINGS+=("[$category] $message")
        HEALTH_SCORE=$((HEALTH_SCORE - score_impact / 2))
        WARNING_COUNT=$((WARNING_COUNT + 1))
        write_report "⚠  WARNING [$category]: $message"
    else
        write_report "ℹ  INFO [$category]: $message"
    fi
}

execute_query() {
    local query="$1"
    docker exec -i "$CONTAINER_NAME" psql -U postgres -d "$DATABASE" -t -A -c "$query" 2>&1
}

write_report "╔════════════════════════════════════════════════════════════════════════════╗"
write_report "║          PostgreSQL Health Check Report                                   ║"
write_report "╚════════════════════════════════════════════════════════════════════════════╝"
write_report ""
write_report "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
write_report "Container: $CONTAINER_NAME"
write_report "Database: $DATABASE"
write_report "$(printf '=%.0s' {1..80})"

# 1. Check if container is running
write_report ""
write_report "[1/15] Checking Docker Container Status..."
container_status=$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>&1)
if [ $? -eq 0 ] && [ "$container_status" = "running" ]; then
    write_report "✓ Container is running"
else
    add_issue "CRITICAL" "Container" "Container is not running (Status: $container_status)" 20
    write_report ""
    write_report "❌ Health check cannot continue - container is not running"
    exit 1
fi

# 2. Check PostgreSQL connectivity
write_report ""
write_report "[2/15] Checking PostgreSQL Connectivity..."
version=$(execute_query "SELECT version();")
if [ $? -eq 0 ] && [ -n "$version" ]; then
    write_report "✓ PostgreSQL is accessible"
    write_report "  Version: $(echo "$version" | cut -d',' -f1)"
else
    add_issue "CRITICAL" "Connectivity" "Cannot connect to PostgreSQL" 20
    exit 1
fi

# 3. Check database existence
write_report ""
write_report "[3/15] Checking Database Existence..."
db_exists=$(execute_query "SELECT 1 FROM pg_database WHERE datname='$DATABASE';")
if [ "$db_exists" = "1" ]; then
    write_report "✓ Database '$DATABASE' exists"
else
    add_issue "CRITICAL" "Database" "Database '$DATABASE' does not exist" 15
fi

# 4. Check disk space
write_report ""
write_report "[4/15] Checking Disk Space..."
disk_usage=$(execute_query "SELECT pg_size_pretty(pg_database_size('$DATABASE')) || '|' || pg_database_size('$DATABASE') FROM pg_database WHERE datname='$DATABASE';")

if [ -n "$disk_usage" ]; then
    size_pretty=$(echo "$disk_usage" | cut -d'|' -f1)
    size_bytes=$(echo "$disk_usage" | cut -d'|' -f2)
    size_gb=$(echo "scale=2; $size_bytes / 1073741824" | bc)
    
    write_report "✓ Database size: $size_pretty ($size_gb GB)"
    
    if (( $(echo "$size_gb > 100" | bc -l) )); then
        add_issue "WARNING" "Disk Space" "Database size is large: $size_gb GB" 5
    fi
fi

# 5. Check connection limits
write_report ""
write_report "[5/15] Checking Connection Limits..."
conn_stats=$(execute_query "SELECT count(*) || '|' || (SELECT setting::int FROM pg_settings WHERE name='max_connections') FROM pg_stat_activity;")

if [ -n "$conn_stats" ]; then
    current=$(echo "$conn_stats" | cut -d'|' -f1)
    max=$(echo "$conn_stats" | cut -d'|' -f2)
    usage=$(echo "scale=1; ($current * 100) / $max" | bc)
    
    write_report "✓ Connections: $current / $max ($usage%)"
    
    if (( $(echo "$usage > 80" | bc -l) )); then
        add_issue "CRITICAL" "Connections" "Connection usage is critical: $usage%" 15
    elif (( $(echo "$usage > 60" | bc -l) )); then
        add_issue "WARNING" "Connections" "Connection usage is high: $usage%" 10
    fi
fi

# 6. Check for idle in transaction connections
write_report ""
write_report "[6/15] Checking Idle Transactions..."
idle_in_trans=$(execute_query "SELECT count(*) FROM pg_stat_activity WHERE state = 'idle in transaction' AND now() - state_change > interval '5 minutes';")

if [ -n "$idle_in_trans" ] && [ "$idle_in_trans" -gt 0 ]; then
    add_issue "WARNING" "Connections" "Found $idle_in_trans long-running idle transactions (>5 min)" 8
else
    write_report "✓ No long-running idle transactions"
fi

# 7. Check cache hit ratio
write_report ""
write_report "[7/15] Checking Cache Hit Ratio..."
cache_hit=$(execute_query "SELECT round((sum(heap_blks_hit) * 100.0 / NULLIF(sum(heap_blks_hit + heap_blks_read), 0))::numeric, 2) FROM pg_statio_user_tables;")

if [ -n "$cache_hit" ]; then
    ratio=$(echo "$cache_hit" | tr -d ' ')
    write_report "✓ Cache hit ratio: $ratio%"
    
    if (( $(echo "$ratio < 90" | bc -l) )); then
        add_issue "CRITICAL" "Performance" "Cache hit ratio is too low: $ratio% (target: >99%)" 15
    elif (( $(echo "$ratio < 95" | bc -l) )); then
        add_issue "WARNING" "Performance" "Cache hit ratio is suboptimal: $ratio% (target: >99%)" 10
    fi
fi

# 8. Check for table bloat
write_report ""
write_report "[8/15] Checking Table Bloat..."
bloated_tables=$(execute_query "SELECT count(*) FROM pg_stat_user_tables WHERE n_dead_tup > 10000 AND n_dead_tup > n_live_tup * 0.2;")

if [ -n "$bloated_tables" ] && [ "$bloated_tables" -gt 0 ]; then
    add_issue "WARNING" "Maintenance" "Found $bloated_tables tables with significant bloat (>20% dead tuples)" 10
    
    bloat_details=$(execute_query "SELECT tablename || ' (' || n_dead_tup || ' dead, ' || n_live_tup || ' live)' FROM pg_stat_user_tables WHERE n_dead_tup > 10000 AND n_dead_tup > n_live_tup * 0.2 ORDER BY n_dead_tup DESC LIMIT 5;")
    write_report "  Top bloated tables:"
    echo "$bloat_details" | while read line; do
        write_report "    $line"
    done
else
    write_report "✓ No significant table bloat detected"
fi

# 9. Check for unused indexes
write_report ""
write_report "[9/15] Checking Unused Indexes..."
unused_indexes=$(execute_query "SELECT count(*) FROM pg_stat_user_indexes WHERE idx_scan = 0 AND pg_relation_size(indexrelid) > 1048576;")

if [ -n "$unused_indexes" ] && [ "$unused_indexes" -gt 0 ]; then
    add_issue "WARNING" "Performance" "Found $unused_indexes unused indexes (>1MB, never scanned)" 5
else
    write_report "✓ No large unused indexes found"
fi

# 10. Check for missing indexes (high sequential scans)
write_report ""
write_report "[10/15] Checking for Missing Indexes..."
high_seq_scans=$(execute_query "SELECT count(*) FROM pg_stat_user_tables WHERE seq_scan > 1000 AND seq_scan > idx_scan AND pg_total_relation_size(schemaname||'.'||tablename) > 10485760;")

if [ -n "$high_seq_scans" ] && [ "$high_seq_scans" -gt 0 ]; then
    add_issue "WARNING" "Performance" "Found $high_seq_scans large tables with high sequential scans" 8
else
    write_report "✓ No tables with excessive sequential scans"
fi

# 11. Check replication status
write_report ""
write_report "[11/15] Checking Replication Status..."
replicas=$(execute_query "SELECT count(*) FROM pg_stat_replication;")

if [ -n "$replicas" ] && [ "$replicas" -gt 0 ]; then
    write_report "✓ Replication active: $replicas replica(s)"
    
    # Check replication lag
    rep_lag=$(execute_query "SELECT max(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)) FROM pg_stat_replication;")
    
    if [ -n "$rep_lag" ] && [ "$rep_lag" -gt 104857600 ]; then  # 100MB
        lag_mb=$(echo "scale=2; $rep_lag / 1048576" | bc)
        add_issue "WARNING" "Replication" "Replication lag is high: $lag_mb MB" 10
    fi
else
    write_report "ℹ  No replication configured"
fi

# 12. Check for locks
write_report ""
write_report "[12/15] Checking for Lock Contention..."
locks=$(execute_query "SELECT count(*) FROM pg_locks WHERE NOT granted;")

if [ -n "$locks" ] && [ "$locks" -gt 0 ]; then
    add_issue "WARNING" "Performance" "Found $locks blocked queries waiting for locks" 10
else
    write_report "✓ No lock contention detected"
fi

# 13. Check autovacuum status
write_report ""
write_report "[13/15] Checking Autovacuum Configuration..."
autovacuum=$(execute_query "SELECT setting FROM pg_settings WHERE name='autovacuum';")

if [ "$autovacuum" = "on" ]; then
    write_report "✓ Autovacuum is enabled"
    
    # Check when tables were last vacuumed
    old_vacuum=$(execute_query "SELECT count(*) FROM pg_stat_user_tables WHERE last_autovacuum < now() - interval '7 days' OR last_autovacuum IS NULL;")
    
    if [ -n "$old_vacuum" ] && [ "$old_vacuum" -gt 0 ]; then
        add_issue "WARNING" "Maintenance" "$old_vacuum tables haven't been vacuumed in 7+ days" 8
    fi
else
    add_issue "CRITICAL" "Configuration" "Autovacuum is disabled!" 15
fi

# 14. Check for long-running queries
write_report ""
write_report "[14/15] Checking for Long-Running Queries..."
long_queries=$(execute_query "SELECT count(*) FROM pg_stat_activity WHERE state != 'idle' AND query_start < now() - interval '10 minutes' AND pid <> pg_backend_pid();")

if [ -n "$long_queries" ] && [ "$long_queries" -gt 0 ]; then
    add_issue "WARNING" "Performance" "Found $long_queries queries running >10 minutes" 10
    
    query_details=$(execute_query "SELECT pid || ' | ' || usename || ' | ' || extract(epoch from (now() - query_start))::int || 's | ' || left(query, 60) FROM pg_stat_activity WHERE state != 'idle' AND query_start < now() - interval '10 minutes' AND pid <> pg_backend_pid() ORDER BY query_start LIMIT 3;")
    write_report "  Sample queries:"
    echo "$query_details" | while read line; do
        write_report "    $line"
    done
else
    write_report "✓ No long-running queries detected"
fi

# 15. Check WAL file accumulation
write_report ""
write_report "[15/15] Checking WAL File Status..."
wal_files=$(execute_query "SELECT count(*) FROM pg_ls_waldir() WHERE modification > now() - interval '1 hour';")

if [ -n "$wal_files" ]; then
    write_report "✓ WAL files generated in last hour: $wal_files"
    
    total_wal_size=$(execute_query "SELECT pg_size_pretty(sum(size)) FROM pg_ls_waldir();")
    
    if [ -n "$total_wal_size" ]; then
        write_report "  Total WAL directory size: $total_wal_size"
    fi
fi

# Calculate final health score
if [ $HEALTH_SCORE -lt 0 ]; then
    HEALTH_SCORE=0
fi

write_report ""
write_report "$(printf '=%.0s' {1..80})"
write_report "HEALTH CHECK SUMMARY"
write_report "$(printf '=%.0s' {1..80})"
write_report ""

# Display health score with visual indicator
score_bars=$((HEALTH_SCORE / 5))
score_bar=$(printf '█%.0s' $(seq 1 $score_bars))

write_report "Overall Health Score: $HEALTH_SCORE / 100"
write_report "[$score_bar]"
write_report ""

if [ $CRITICAL_COUNT -gt 0 ]; then
    write_report "❌ CRITICAL ISSUES: $CRITICAL_COUNT"
    for issue in "${ISSUES[@]}"; do
        write_report "   • $issue"
    done
    write_report ""
fi

if [ $WARNING_COUNT -gt 0 ]; then
    write_report "⚠  WARNINGS: $WARNING_COUNT"
    for warning in "${WARNINGS[@]}"; do
        write_report "   • $warning"
    done
    write_report ""
fi

if [ $CRITICAL_COUNT -eq 0 ] && [ $WARNING_COUNT -eq 0 ]; then
    write_report "✅ All health checks passed!"
fi

write_report ""
write_report "RECOMMENDATIONS:"
write_report "$(printf '=%.0s' {1..80})"

if [ $HEALTH_SCORE -lt 70 ]; then
    write_report "🔴 URGENT: Immediate action required!"
    write_report "   1. Review and address all CRITICAL issues immediately"
    write_report "   2. Consider scheduling maintenance window"
    write_report "   3. Monitor system closely"
elif [ $HEALTH_SCORE -lt 90 ]; then
    write_report "🟡 ATTENTION: Some issues need attention"
    write_report "   1. Address WARNING issues during next maintenance window"
    write_report "   2. Monitor trends to prevent degradation"
else
    write_report "🟢 HEALTHY: System is operating normally"
    write_report "   1. Continue regular monitoring"
    write_report "   2. Maintain current maintenance schedule"
fi

write_report ""
write_report "Report saved to: $REPORT_FILE"
write_report "$(printf '=%.0s' {1..80})"

# Send alert if requested and there are critical issues
if [ "$SEND_ALERT" = true ] && [ -n "$ALERT_EMAIL" ] && [ $CRITICAL_COUNT -gt 0 ]; then
    echo ""
    echo "📧 Sending alert email to $ALERT_EMAIL..."
    echo "⚠  Email alerting requires SMTP configuration (not implemented in this script)"
fi

# Exit with appropriate code
if [ $CRITICAL_COUNT -gt 0 ]; then
    exit 1
elif [ $WARNING_COUNT -gt 0 ]; then
    exit 2
else
    exit 0
fi
