#!/bin/bash
# PostgreSQL Storage Analysis Script for Linux
# Analyzes database storage usage, growth trends, and provides cleanup recommendations

CONTAINER_NAME="PG-timescale"
DATABASE="postgres"
OUTPUT_DIR="./storage_reports"
DETAILED_ANALYSIS=false
INCLUDE_SYSTEM_CATALOGS=false
EXPORT_CSV=false

show_help() {
    cat << EOF
PostgreSQL Storage Analysis Script
==================================

Usage: $0 [OPTIONS]

Options:
    -c, --container NAME    Docker container name (default: PG-timescale)
    -d, --database NAME     Database to analyze (default: postgres)
    -o, --output DIR        Output directory for reports (default: ./storage_reports)
    -D, --detailed          Include detailed column and index analysis
    -s, --system            Include system catalogs in analysis
    -e, --export-csv        Export results to CSV files
    -h, --help              Show this help message

Examples:
    $0
    $0 -d mydb --detailed
    $0 --export-csv -o /var/reports

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
        -D|--detailed)
            DETAILED_ANALYSIS=true
            shift
            ;;
        -s|--system)
            INCLUDE_SYSTEM_CATALOGS=true
            shift
            ;;
        -e|--export-csv)
            EXPORT_CSV=true
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
REPORT_FILE="$OUTPUT_DIR/storage_analysis_$TIMESTAMP.txt"

write_report() {
    echo "$1" | tee -a "$REPORT_FILE"
}

execute_query() {
    local query="$1"
    local description="$2"
    
    if [ -n "$description" ]; then
        write_report ""
        write_report "=== $description ==="
        write_report "$(printf '=%.0s' {1..80})"
    fi
    
    result=$(docker exec -i "$CONTAINER_NAME" psql -U postgres -d "$DATABASE" -c "$query" 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        write_report "$result"
        echo "$result"
    else
        write_report "ERROR: $result"
        return 1
    fi
}

format_bytes() {
    local bytes=$1
    
    if [ $bytes -ge 1099511627776 ]; then
        echo "$(echo "scale=2; $bytes / 1099511627776" | bc) TB"
    elif [ $bytes -ge 1073741824 ]; then
        echo "$(echo "scale=2; $bytes / 1073741824" | bc) GB"
    elif [ $bytes -ge 1048576 ]; then
        echo "$(echo "scale=2; $bytes / 1048576" | bc) MB"
    elif [ $bytes -ge 1024 ]; then
        echo "$(echo "scale=2; $bytes / 1024" | bc) KB"
    else
        echo "$bytes bytes"
    fi
}

write_report "╔════════════════════════════════════════════════════════════════════════════╗"
write_report "║          PostgreSQL Storage Analysis Report                                ║"
write_report "╚════════════════════════════════════════════════════════════════════════════╝"
write_report ""
write_report "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
write_report "Container: $CONTAINER_NAME"
write_report "Database: $DATABASE"
write_report "$(printf '=%.0s' {1..80})"

# 1. Overall Database Sizes
execute_query "
SELECT 
    datname as \"Database\",
    pg_size_pretty(pg_database_size(datname)) as \"Size\",
    pg_database_size(datname) as size_bytes,
    (SELECT count(*) FROM pg_stat_activity WHERE datname = d.datname) as \"Connections\"
FROM pg_database d
WHERE datistemplate = false
ORDER BY pg_database_size(datname) DESC;
" "All Database Sizes"

# 2. Current Database Detailed Size Breakdown
execute_query "
SELECT 
    'Tables' as object_type,
    count(*) as count,
    pg_size_pretty(sum(pg_total_relation_size(schemaname||'.'||tablename))) as total_size,
    sum(pg_total_relation_size(schemaname||'.'||tablename)) as size_bytes
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
UNION ALL
SELECT 
    'Indexes' as object_type,
    count(*) as count,
    pg_size_pretty(sum(pg_relation_size(indexrelid))) as total_size,
    sum(pg_relation_size(indexrelid)) as size_bytes
FROM pg_stat_user_indexes
UNION ALL
SELECT 
    'TOAST Tables' as object_type,
    count(*) as count,
    pg_size_pretty(sum(pg_total_relation_size(reltoastrelid))) as total_size,
    sum(pg_total_relation_size(reltoastrelid)) as size_bytes
FROM pg_class
WHERE reltoastrelid != 0
ORDER BY size_bytes DESC;
" "Storage Breakdown by Object Type"

# 3. Top 30 Largest Tables
schema_filter=""
if [ "$INCLUDE_SYSTEM_CATALOGS" = false ]; then
    schema_filter="WHERE schemaname NOT IN ('pg_catalog', 'information_schema')"
fi

execute_query "
SELECT 
    schemaname as \"Schema\",
    tablename as \"Table\",
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as \"Total Size\",
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as \"Table Size\",
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as \"Indexes Size\",
    round(100.0 * pg_total_relation_size(schemaname||'.'||tablename) / 
        NULLIF(sum(pg_total_relation_size(schemaname||'.'||tablename)) OVER (), 0), 2) as \"% of Total\"
FROM pg_tables
$schema_filter
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 30;
" "Top 30 Largest Tables"

# 4. Table Size with Row Counts
execute_query "
SELECT 
    schemaname as \"Schema\",
    tablename as \"Table\",
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as \"Total Size\",
    n_live_tup as \"Live Rows\",
    n_dead_tup as \"Dead Rows\",
    CASE 
        WHEN n_live_tup = 0 THEN 0
        ELSE round(pg_total_relation_size(schemaname||'.'||tablename)::numeric / n_live_tup, 2)
    END as \"Bytes per Row\",
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
WHERE n_live_tup > 0
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;
" "Table Size with Row Statistics"

# 5. Index Size Analysis
execute_query "
SELECT 
    schemaname as \"Schema\",
    tablename as \"Table\",
    indexname as \"Index\",
    pg_size_pretty(pg_relation_size(indexrelid)) as \"Index Size\",
    idx_scan as \"Index Scans\",
    idx_tup_read as \"Tuples Read\",
    idx_tup_fetch as \"Tuples Fetched\",
    CASE 
        WHEN idx_scan = 0 THEN 'UNUSED'
        WHEN idx_scan < 100 THEN 'LOW USAGE'
        ELSE 'ACTIVE'
    END as \"Usage Status\"
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 30;
" "Top 30 Largest Indexes"

# 6. Unused Indexes (Potential for Removal)
execute_query "
SELECT 
    schemaname as \"Schema\",
    tablename as \"Table\",
    indexname as \"Index\",
    pg_size_pretty(pg_relation_size(indexrelid)) as \"Wasted Space\",
    pg_relation_size(indexrelid) as size_bytes,
    indexdef as \"Definition\"
FROM pg_stat_user_indexes
JOIN pg_indexes USING (schemaname, tablename, indexname)
WHERE idx_scan = 0
    AND indexrelname NOT LIKE '%_pkey'  -- Exclude primary keys
    AND pg_relation_size(indexrelid) > 1048576  -- > 1MB
ORDER BY pg_relation_size(indexrelid) DESC;
" "Unused Indexes (Candidates for Removal)"

# 7. Duplicate Indexes
execute_query "
SELECT 
    pg_size_pretty(sum(pg_relation_size(idx))::bigint) as \"Wasted Space\",
    string_agg(indexrelname, ', ') as \"Duplicate Indexes\",
    tablename as \"Table\"
FROM (
    SELECT 
        indexrelid::regclass as idx,
        indrelid::regclass as tablename,
        (indrelid::text ||E'\n'|| indclass::text ||E'\n'|| indkey::text ||E'\n'||
         coalesce(indexprs::text,'')||E'\n' || coalesce(indpred::text,'')) as key
    FROM pg_index
) sub
GROUP BY tablename, key
HAVING count(*) > 1
ORDER BY sum(pg_relation_size(idx)) DESC;
" "Duplicate Indexes (Potential Waste)"

# 8. TOAST Table Analysis
execute_query "
SELECT 
    n.nspname as \"Schema\",
    c.relname as \"Table\",
    pg_size_pretty(pg_total_relation_size(c.reltoastrelid)) as \"TOAST Size\",
    pg_total_relation_size(c.reltoastrelid) as toast_bytes,
    pg_size_pretty(pg_relation_size(c.oid)) as \"Main Table Size\",
    round(100.0 * pg_total_relation_size(c.reltoastrelid) / 
        NULLIF(pg_relation_size(c.oid) + pg_total_relation_size(c.reltoastrelid), 0), 2) as \"TOAST %\"
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.reltoastrelid != 0
    AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(c.reltoastrelid) DESC
LIMIT 20;
" "TOAST Table Storage"

# 9. Tablespace Usage
execute_query "
SELECT 
    spcname as \"Tablespace\",
    pg_size_pretty(pg_tablespace_size(spcname)) as \"Size\",
    pg_tablespace_location(oid) as \"Location\"
FROM pg_tablespace
ORDER BY pg_tablespace_size(spcname) DESC;
" "Tablespace Usage"

# 10. WAL Directory Size
execute_query "
SELECT 
    count(*) as \"WAL Files\",
    pg_size_pretty(sum(size)) as \"Total WAL Size\",
    pg_size_pretty(avg(size)) as \"Avg File Size\",
    min(modification) as \"Oldest WAL\",
    max(modification) as \"Newest WAL\"
FROM pg_ls_waldir();
" "WAL Directory Statistics"

# 11. Table Bloat Estimation
execute_query "
SELECT 
    schemaname as \"Schema\",
    tablename as \"Table\",
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as \"Total Size\",
    n_dead_tup as \"Dead Tuples\",
    n_live_tup as \"Live Tuples\",
    CASE 
        WHEN n_live_tup + n_dead_tup = 0 THEN 0
        ELSE round((n_dead_tup * 100.0 / (n_live_tup + n_dead_tup))::numeric, 2)
    END as \"Dead Tuple %\",
    pg_size_pretty(n_dead_tup * 
        CASE 
            WHEN n_live_tup = 0 THEN 0
            ELSE (pg_relation_size(schemaname||'.'||tablename) / NULLIF(n_live_tup, 0))
        END::bigint) as \"Est. Bloat Size\",
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC
LIMIT 20;
" "Table Bloat Analysis"

# 12. Schema Size Distribution
execute_query "
SELECT 
    schemaname as \"Schema\",
    count(*) as \"Tables\",
    pg_size_pretty(sum(pg_total_relation_size(schemaname||'.'||tablename))) as \"Total Size\",
    pg_size_pretty(avg(pg_total_relation_size(schemaname||'.'||tablename))) as \"Avg Table Size\",
    pg_size_pretty(max(pg_total_relation_size(schemaname||'.'||tablename))) as \"Largest Table\"
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
GROUP BY schemaname
ORDER BY sum(pg_total_relation_size(schemaname||'.'||tablename)) DESC;
" "Storage by Schema"

if [ "$DETAILED_ANALYSIS" = true ]; then
    # 13. Column Storage Analysis
    execute_query "
SELECT 
    schemaname as \"Schema\",
    tablename as \"Table\",
    attname as \"Column\",
    format_type(atttypid, atttypmod) as \"Data Type\",
    CASE 
        WHEN attstorage = 'p' THEN 'PLAIN'
        WHEN attstorage = 'e' THEN 'EXTERNAL'
        WHEN attstorage = 'm' THEN 'MAIN'
        WHEN attstorage = 'x' THEN 'EXTENDED'
    END as \"Storage\",
    avg_width as \"Avg Width (bytes)\",
    n_distinct as \"Distinct Values\",
    null_frac as \"Null Fraction\"
FROM pg_stats
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
    AND avg_width > 100  -- Focus on wide columns
ORDER BY avg_width DESC
LIMIT 30;
" "Wide Column Analysis"

    # 14. Index Bloat Estimation
    execute_query "
SELECT 
    schemaname as \"Schema\",
    tablename as \"Table\",
    indexname as \"Index\",
    pg_size_pretty(pg_relation_size(indexrelid)) as \"Index Size\",
    idx_scan as \"Scans\",
    idx_tup_read as \"Tuples Read\",
    idx_tup_fetch as \"Tuples Fetched\",
    CASE 
        WHEN idx_tup_read = 0 THEN 0
        ELSE round((idx_tup_fetch * 100.0 / idx_tup_read)::numeric, 2)
    END as \"Fetch %\"
FROM pg_stat_user_indexes
WHERE pg_relation_size(indexrelid) > 10485760  -- > 10MB
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 20;
" "Large Index Efficiency"
fi

# 15. Growth Trend Analysis
execute_query "
SELECT 
    datname as \"Database\",
    xact_commit as \"Commits\",
    xact_rollback as \"Rollbacks\",
    tup_inserted as \"Rows Inserted\",
    tup_updated as \"Rows Updated\",
    tup_deleted as \"Rows Deleted\",
    tup_inserted + tup_updated + tup_deleted as \"Total Modifications\"
FROM pg_stat_database
WHERE datname = '$DATABASE';
" "Database Activity Statistics"

# Generate Storage Recommendations
write_report ""
write_report ""
write_report "$(printf '=%.0s' {1..80})"
write_report "STORAGE OPTIMIZATION RECOMMENDATIONS"
write_report "$(printf '=%.0s' {1..80})"
write_report ""

# Calculate total database size
db_size_bytes=$(docker exec -i "$CONTAINER_NAME" psql -U postgres -d "$DATABASE" -t -A -c "SELECT pg_database_size('$DATABASE');" 2>/dev/null)

if [ -n "$db_size_bytes" ]; then
    db_size_formatted=$(format_bytes $db_size_bytes)
    write_report "📊 Current Database Size: $db_size_formatted"
    write_report ""
fi

# Check for unused indexes
unused_index_size=$(docker exec -i "$CONTAINER_NAME" psql -U postgres -d "$DATABASE" -t -A -c "
SELECT pg_size_pretty(sum(pg_relation_size(indexrelid)))
FROM pg_stat_user_indexes
WHERE idx_scan = 0
    AND indexrelname NOT LIKE '%_pkey'
    AND pg_relation_size(indexrelid) > 1048576;
" 2>/dev/null)

if [ -n "$unused_index_size" ] && [ "$unused_index_size" != "" ]; then
    write_report "🗑️  UNUSED INDEXES:"
    write_report "   Potential space savings: $unused_index_size"
    write_report "   → Run the 'Unused Indexes' query above to identify candidates"
    write_report "   → Use DROP INDEX to remove after verification"
    write_report ""
fi

# Check for bloated tables
bloat_result=$(docker exec -i "$CONTAINER_NAME" psql -U postgres -d "$DATABASE" -t -A -c "
SELECT count(*) || '|' || pg_size_pretty(sum(n_dead_tup * 
    CASE WHEN n_live_tup = 0 THEN 100 
    ELSE (pg_relation_size(schemaname||'.'||tablename) / NULLIF(n_live_tup, 0)) 
    END::bigint))
FROM pg_stat_user_tables
WHERE n_dead_tup > n_live_tup * 0.2 AND n_dead_tup > 1000;
" 2>/dev/null)

if [ -n "$bloat_result" ]; then
    bloated_count=$(echo "$bloat_result" | cut -d'|' -f1)
    bloated_size=$(echo "$bloat_result" | cut -d'|' -f2)
    
    if [ "$bloated_count" -gt 0 ]; then
        write_report "💨 TABLE BLOAT:"
        write_report "   Tables with significant bloat: $bloated_count"
        write_report "   Estimated bloat size: $bloated_size"
        write_report "   → Run VACUUM ANALYZE on affected tables"
        write_report "   → Consider VACUUM FULL for severe cases (requires table lock)"
        write_report ""
    fi
fi

write_report "📋 GENERAL RECOMMENDATIONS:"
write_report ""
write_report "1. VACUUM & ANALYZE:"
write_report "   • Run VACUUM ANALYZE regularly to reclaim space and update statistics"
write_report "   • Enable autovacuum (should be on by default)"
write_report "   • Monitor autovacuum activity in pg_stat_user_tables"
write_report ""

write_report "2. INDEX MANAGEMENT:"
write_report "   • Remove unused indexes to save space and improve write performance"
write_report "   • Reindex bloated indexes: REINDEX INDEX index_name"
write_report "   • Consider partial indexes for filtered queries"
write_report ""

write_report "3. PARTITIONING:"
write_report "   • Consider table partitioning for very large tables (>100GB)"
write_report "   • Use time-based partitioning for time-series data"
write_report "   • Archive old partitions to reduce active dataset size"
write_report ""

write_report "4. DATA ARCHIVAL:"
write_report "   • Archive historical data to separate tables or databases"
write_report "   • Use pg_dump for selective data export"
write_report "   • Consider external storage for infrequently accessed data"
write_report ""

write_report "5. COMPRESSION:"
write_report "   • Use TOAST compression for large text/bytea columns"
write_report "   • Consider pg_compress extension for additional compression"
write_report "   • Evaluate column storage types (MAIN, EXTERNAL, EXTENDED)"
write_report ""

# Export to CSV if requested
if [ "$EXPORT_CSV" = true ]; then
    echo ""
    echo "📁 Exporting data to CSV files..."
    
    # Export table sizes
    csv_file="$OUTPUT_DIR/table_sizes_detailed_$TIMESTAMP.csv"
    docker exec -i "$CONTAINER_NAME" psql -U postgres -d "$DATABASE" -c "COPY (
        SELECT 
            schemaname,
            tablename,
            pg_total_relation_size(schemaname||'.'||tablename) as total_bytes,
            pg_relation_size(schemaname||'.'||tablename) as table_bytes,
            pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename) as indexes_bytes,
            n_live_tup,
            n_dead_tup
        FROM pg_tables
        JOIN pg_stat_user_tables USING (schemaname, tablename)
        WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
        ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
    ) TO STDOUT WITH CSV HEADER" > "$csv_file"
    echo "  ✓ Table sizes: $csv_file"
    
    # Export index sizes
    csv_file="$OUTPUT_DIR/index_sizes_$TIMESTAMP.csv"
    docker exec -i "$CONTAINER_NAME" psql -U postgres -d "$DATABASE" -c "COPY (
        SELECT 
            schemaname,
            tablename,
            indexname,
            pg_relation_size(indexrelid) as size_bytes,
            idx_scan,
            idx_tup_read,
            idx_tup_fetch
        FROM pg_stat_user_indexes
        ORDER BY pg_relation_size(indexrelid) DESC
    ) TO STDOUT WITH CSV HEADER" > "$csv_file"
    echo "  ✓ Index sizes: $csv_file"
fi

write_report ""
write_report "$(printf '=%.0s' {1..80})"
write_report "📊 Report saved to: $REPORT_FILE"
write_report "$(printf '=%.0s' {1..80})"

echo ""
echo "✅ Storage analysis complete!"
