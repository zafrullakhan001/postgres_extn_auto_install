# PostgreSQL Performance Analysis Script for Windows
# This script analyzes PostgreSQL performance metrics and provides recommendations

param(
    [string]$ContainerName = "PG-timescale",
    [string]$Database = "postgres",
    [string]$OutputDir = ".\performance_reports",
    [switch]$DetailedReport,
    [switch]$ExportToCSV,
    [switch]$Help
)

function Show-Help {
    Write-Host @"
PostgreSQL Performance Analysis Script
======================================

Usage: .\performance_analysis.ps1 [OPTIONS]

Options:
    -ContainerName    Docker container name (default: PG-timescale)
    -Database         Database to analyze (default: postgres)
    -OutputDir        Output directory for reports (default: .\performance_reports)
    -DetailedReport   Generate detailed performance report
    -ExportToCSV      Export results to CSV files
    -Help             Show this help message

Examples:
    .\performance_analysis.ps1
    .\performance_analysis.ps1 -Database mydb -DetailedReport
    .\performance_analysis.ps1 -ExportToCSV -OutputDir "C:\reports"

"@
    exit 0
}

if ($Help) { Show-Help }

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportFile = Join-Path $OutputDir "performance_analysis_$timestamp.txt"

function Write-Report {
    param([string]$Message)
    Write-Host $Message
    Add-Content -Path $reportFile -Value $Message
}

function Execute-Query {
    param(
        [string]$Query,
        [string]$Description = ""
    )
    
    if ($Description) {
        Write-Report "`n=== $Description ==="
        Write-Report ("=" * 80)
    }
    
    try {
        $result = docker exec -i $ContainerName psql -U postgres -d $Database -c $Query 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Report $result
            return $result
        }
        else {
            Write-Report "ERROR: $result"
            return $null
        }
    }
    catch {
        Write-Report "ERROR: $_"
        return $null
    }
}

Write-Report "PostgreSQL Performance Analysis Report"
Write-Report "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Report "Container: $ContainerName"
Write-Report "Database: $Database"
Write-Report ("=" * 80)

# 1. Database Version and Uptime
Execute-Query "SELECT version();" "PostgreSQL Version"
Execute-Query "SELECT pg_postmaster_start_time() as server_start, current_timestamp - pg_postmaster_start_time() as uptime;" "Server Uptime"

# 2. Database Size and Growth
Execute-Query @"
SELECT 
    datname as database_name,
    pg_size_pretty(pg_database_size(datname)) as size,
    pg_database_size(datname) as size_bytes
FROM pg_database
WHERE datistemplate = false
ORDER BY pg_database_size(datname) DESC;
"@ "Database Sizes"

# 3. Top 20 Largest Tables
Execute-Query @"
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as indexes_size,
    pg_total_relation_size(schemaname||'.'||tablename) as total_bytes
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;
"@ "Top 20 Largest Tables"

# 4. Cache Hit Ratio (should be > 99%)
Execute-Query @"
SELECT 
    'Index Hit Rate' as metric,
    CASE 
        WHEN sum(idx_blks_hit) = 0 THEN 0
        ELSE round((sum(idx_blks_hit) * 100.0 / nullif(sum(idx_blks_hit + idx_blks_read), 0))::numeric, 2)
    END as percentage
FROM pg_statio_user_indexes
UNION ALL
SELECT 
    'Table Hit Rate' as metric,
    CASE 
        WHEN sum(heap_blks_hit) = 0 THEN 0
        ELSE round((sum(heap_blks_hit) * 100.0 / nullif(sum(heap_blks_hit + heap_blks_read), 0))::numeric, 2)
    END as percentage
FROM pg_statio_user_tables;
"@ "Cache Hit Ratio (Target: >99%)"

# 5. Connection Statistics
Execute-Query @"
SELECT 
    count(*) as total_connections,
    count(*) FILTER (WHERE state = 'active') as active,
    count(*) FILTER (WHERE state = 'idle') as idle,
    count(*) FILTER (WHERE state = 'idle in transaction') as idle_in_transaction,
    count(*) FILTER (WHERE wait_event_type IS NOT NULL) as waiting
FROM pg_stat_activity
WHERE pid <> pg_backend_pid();
"@ "Current Connection Statistics"

Execute-Query @"
SELECT 
    datname,
    count(*) as connections,
    max(setting::int) as max_connections
FROM pg_stat_activity, pg_settings
WHERE name = 'max_connections'
GROUP BY datname, setting
ORDER BY connections DESC;
"@ "Connections by Database"

# 6. Long Running Queries (> 1 minute)
Execute-Query @"
SELECT 
    pid,
    usename,
    datname,
    state,
    now() - query_start as duration,
    wait_event_type,
    wait_event,
    left(query, 100) as query_preview
FROM pg_stat_activity
WHERE state != 'idle'
    AND query_start < now() - interval '1 minute'
    AND pid <> pg_backend_pid()
ORDER BY duration DESC;
"@ "Long Running Queries (>1 minute)"

# 7. Slow Queries (from pg_stat_statements if available)
Execute-Query @"
SELECT EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements'
) as pg_stat_statements_installed;
"@ "Checking pg_stat_statements Extension"

Execute-Query @"
SELECT 
    round((total_exec_time / calls)::numeric, 2) as avg_time_ms,
    calls,
    round(total_exec_time::numeric, 2) as total_time_ms,
    round((100 * total_exec_time / sum(total_exec_time) OVER ())::numeric, 2) as percent_total,
    left(query, 100) as query_preview
FROM pg_stat_statements
WHERE calls > 10
ORDER BY avg_time_ms DESC
LIMIT 20;
"@ "Top 20 Slowest Queries by Average Time (requires pg_stat_statements)"

# 8. Table Bloat Analysis
Execute-Query @"
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    n_dead_tup as dead_tuples,
    n_live_tup as live_tuples,
    CASE 
        WHEN n_live_tup = 0 THEN 0
        ELSE round((n_dead_tup * 100.0 / (n_live_tup + n_dead_tup))::numeric, 2)
    END as dead_tuple_percent,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC
LIMIT 20;
"@ "Tables with High Dead Tuple Count (Potential Bloat)"

# 9. Index Usage Statistics
Execute-Query @"
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
    AND pg_relation_size(indexrelid) > 1024 * 1024  -- > 1MB
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 20;
"@ "Unused Indexes (>1MB, Never Scanned)"

# 10. Missing Indexes (Sequential Scans on Large Tables)
Execute-Query @"
SELECT 
    schemaname,
    tablename,
    seq_scan as sequential_scans,
    seq_tup_read as rows_read_sequentially,
    idx_scan as index_scans,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as table_size,
    CASE 
        WHEN seq_scan = 0 THEN 0
        ELSE round((seq_tup_read::numeric / seq_scan), 0)
    END as avg_rows_per_seq_scan
FROM pg_stat_user_tables
WHERE seq_scan > 0
    AND pg_total_relation_size(schemaname||'.'||tablename) > 10 * 1024 * 1024  -- > 10MB
    AND seq_scan > idx_scan
ORDER BY seq_tup_read DESC
LIMIT 20;
"@ "Tables with High Sequential Scans (Potential Missing Indexes)"

# 11. Checkpoint Statistics
Execute-Query @"
SELECT 
    checkpoints_timed,
    checkpoints_req,
    checkpoint_write_time,
    checkpoint_sync_time,
    buffers_checkpoint,
    buffers_clean,
    buffers_backend,
    buffers_alloc
FROM pg_stat_bgwriter;
"@ "Checkpoint and Background Writer Statistics"

# 12. Replication Lag (if applicable)
Execute-Query @"
SELECT 
    client_addr,
    state,
    sync_state,
    pg_wal_lsn_diff(pg_current_wal_lsn(), sent_lsn) as send_lag_bytes,
    pg_wal_lsn_diff(pg_current_wal_lsn(), write_lsn) as write_lag_bytes,
    pg_wal_lsn_diff(pg_current_wal_lsn(), flush_lsn) as flush_lag_bytes,
    pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) as replay_lag_bytes
FROM pg_stat_replication;
"@ "Replication Status and Lag"

# 13. Lock Statistics
Execute-Query @"
SELECT 
    locktype,
    database,
    relation::regclass as relation,
    mode,
    count(*) as lock_count
FROM pg_locks
WHERE NOT granted
GROUP BY locktype, database, relation, mode
ORDER BY lock_count DESC;
"@ "Current Lock Waits"

# 14. Vacuum Progress
Execute-Query @"
SELECT 
    pid,
    datname,
    relid::regclass as table_name,
    phase,
    heap_blks_total,
    heap_blks_scanned,
    heap_blks_vacuumed,
    index_vacuum_count,
    max_dead_tuples,
    num_dead_tuples
FROM pg_stat_progress_vacuum;
"@ "Active Vacuum Operations"

# 15. Configuration Settings (Important Performance Parameters)
Execute-Query @"
SELECT 
    name,
    setting,
    unit,
    source,
    short_desc
FROM pg_settings
WHERE name IN (
    'shared_buffers',
    'effective_cache_size',
    'work_mem',
    'maintenance_work_mem',
    'max_connections',
    'random_page_cost',
    'effective_io_concurrency',
    'max_worker_processes',
    'max_parallel_workers_per_gather',
    'max_parallel_workers',
    'wal_buffers',
    'checkpoint_completion_target',
    'max_wal_size',
    'min_wal_size',
    'autovacuum',
    'autovacuum_max_workers',
    'autovacuum_naptime'
)
ORDER BY name;
"@ "Key Performance Configuration Parameters"

# 16. Transaction Statistics
Execute-Query @"
SELECT 
    datname,
    xact_commit as commits,
    xact_rollback as rollbacks,
    CASE 
        WHEN (xact_commit + xact_rollback) = 0 THEN 0
        ELSE round((xact_rollback * 100.0 / (xact_commit + xact_rollback))::numeric, 2)
    END as rollback_ratio,
    blks_read as blocks_read,
    blks_hit as blocks_hit,
    tup_returned as tuples_returned,
    tup_fetched as tuples_fetched,
    tup_inserted as tuples_inserted,
    tup_updated as tuples_updated,
    tup_deleted as tuples_deleted
FROM pg_stat_database
WHERE datname NOT IN ('template0', 'template1')
ORDER BY datname;
"@ "Transaction and Activity Statistics by Database"

if ($DetailedReport) {
    # Additional detailed queries
    
    Execute-Query @"
SELECT 
    schemaname,
    tablename,
    attname as column_name,
    n_distinct,
    correlation,
    most_common_vals,
    most_common_freqs
FROM pg_stats
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
    AND n_distinct < -0.5  -- Highly distinct columns
ORDER BY schemaname, tablename, attname
LIMIT 50;
"@ "Column Statistics (High Cardinality Columns)"

    Execute-Query @"
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schemaname, tablename, indexname;
"@ "All Index Definitions"
}

# Generate Performance Recommendations
Write-Report "`n`n"
Write-Report "=== PERFORMANCE RECOMMENDATIONS ==="
Write-Report ("=" * 80)

# Analyze cache hit ratio
$cacheHitResult = Execute-Query @"
SELECT 
    CASE 
        WHEN sum(heap_blks_hit) = 0 THEN 0
        ELSE round((sum(heap_blks_hit) * 100.0 / nullif(sum(heap_blks_hit + heap_blks_read), 0))::numeric, 2)
    END as cache_hit_ratio
FROM pg_statio_user_tables;
"@

if ($cacheHitResult -match "(\d+\.?\d*)") {
    $ratio = [double]$matches[1]
    if ($ratio -lt 99) {
        Write-Report "⚠ Cache hit ratio is $ratio% (target: >99%)"
        Write-Report "  → Consider increasing shared_buffers"
        Write-Report "  → Review effective_cache_size setting"
    }
    else {
        Write-Report "✓ Cache hit ratio is healthy: $ratio%"
    }
}

Write-Report "`n📊 Report saved to: $reportFile"

if ($ExportToCSV) {
    Write-Host "`n📁 Exporting data to CSV files..."
    
    # Export table sizes
    $csvFile = Join-Path $OutputDir "table_sizes_$timestamp.csv"
    docker exec -i $ContainerName psql -U postgres -d $Database -c "COPY (
        SELECT 
            schemaname,
            tablename,
            pg_total_relation_size(schemaname||'.'||tablename) as total_bytes,
            pg_relation_size(schemaname||'.'||tablename) as table_bytes,
            pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename) as indexes_bytes
        FROM pg_tables
        WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
        ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
    ) TO STDOUT WITH CSV HEADER" > $csvFile
    Write-Host "  ✓ Table sizes exported to: $csvFile"
    
    # Export connection stats
    $csvFile = Join-Path $OutputDir "connections_$timestamp.csv"
    docker exec -i $ContainerName psql -U postgres -d $Database -c "COPY (
        SELECT 
            datname,
            usename,
            application_name,
            client_addr,
            state,
            query_start,
            state_change
        FROM pg_stat_activity
        WHERE pid <> pg_backend_pid()
    ) TO STDOUT WITH CSV HEADER" > $csvFile
    Write-Host "  ✓ Connection stats exported to: $csvFile"
}

Write-Host "`n✅ Performance analysis complete!"
Write-Host "📊 Full report: $reportFile"
