# PostgreSQL Storage Analysis Script for Windows
# Analyzes database storage usage, growth trends, and provides cleanup recommendations

param(
    [string]$ContainerName = "PG-timescale",
    [string]$Database = "postgres",
    [string]$OutputDir = ".\storage_reports",
    [switch]$DetailedAnalysis,
    [switch]$IncludeSystemCatalogs,
    [switch]$ExportToCSV,
    [switch]$Help
)

function Show-Help {
    Write-Host @"
PostgreSQL Storage Analysis Script
==================================

Usage: .\storage_analysis.ps1 [OPTIONS]

Options:
    -ContainerName          Docker container name (default: PG-timescale)
    -Database               Database to analyze (default: postgres)
    -OutputDir              Output directory for reports (default: .\storage_reports)
    -DetailedAnalysis       Include detailed column and index analysis
    -IncludeSystemCatalogs  Include system catalogs in analysis
    -ExportToCSV            Export results to CSV files
    -Help                   Show this help message

Examples:
    .\storage_analysis.ps1
    .\storage_analysis.ps1 -Database mydb -DetailedAnalysis
    .\storage_analysis.ps1 -ExportToCSV -OutputDir "C:\reports"

"@
    exit 0
}

if ($Help) { Show-Help }

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportFile = Join-Path $OutputDir "storage_analysis_$timestamp.txt"

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

function Format-Bytes {
    param([long]$Bytes)
    
    if ($Bytes -ge 1TB) {
        return "{0:N2} TB" -f ($Bytes / 1TB)
    }
    elseif ($Bytes -ge 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    }
    elseif ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    }
    elseif ($Bytes -ge 1KB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    }
    else {
        return "$Bytes bytes"
    }
}

Write-Report "╔════════════════════════════════════════════════════════════════════════════╗"
Write-Report "║          PostgreSQL Storage Analysis Report                                ║"
Write-Report "╚════════════════════════════════════════════════════════════════════════════╝"
Write-Report ""
Write-Report "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Report "Container: $ContainerName"
Write-Report "Database: $Database"
Write-Report ("=" * 80)

# 1. Overall Database Sizes
Execute-Query @"
SELECT 
    datname as "Database",
    pg_size_pretty(pg_database_size(datname)) as "Size",
    pg_database_size(datname) as size_bytes,
    (SELECT count(*) FROM pg_stat_activity WHERE datname = d.datname) as "Connections"
FROM pg_database d
WHERE datistemplate = false
ORDER BY pg_database_size(datname) DESC;
"@ "All Database Sizes"

# 2. Current Database Detailed Size Breakdown
Execute-Query @"
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
"@ "Storage Breakdown by Object Type"

# 3. Top 30 Largest Tables
$schemaFilter = if ($IncludeSystemCatalogs) { "" } else { "WHERE schemaname NOT IN ('pg_catalog', 'information_schema')" }

Execute-Query @"
SELECT 
    schemaname as "Schema",
    tablename as "Table",
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as "Total Size",
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as "Table Size",
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as "Indexes Size",
    round(100.0 * pg_total_relation_size(schemaname||'.'||tablename) / 
        NULLIF(sum(pg_total_relation_size(schemaname||'.'||tablename)) OVER (), 0), 2) as "% of Total"
FROM pg_tables
$schemaFilter
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 30;
"@ "Top 30 Largest Tables"

# 4. Table Size with Row Counts
Execute-Query @"
SELECT 
    schemaname as "Schema",
    tablename as "Table",
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as "Total Size",
    n_live_tup as "Live Rows",
    n_dead_tup as "Dead Rows",
    CASE 
        WHEN n_live_tup = 0 THEN 0
        ELSE round(pg_total_relation_size(schemaname||'.'||tablename)::numeric / n_live_tup, 2)
    END as "Bytes per Row",
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
WHERE n_live_tup > 0
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;
"@ "Table Size with Row Statistics"

# 5. Index Size Analysis
Execute-Query @"
SELECT 
    schemaname as "Schema",
    tablename as "Table",
    indexname as "Index",
    pg_size_pretty(pg_relation_size(indexrelid)) as "Index Size",
    idx_scan as "Index Scans",
    idx_tup_read as "Tuples Read",
    idx_tup_fetch as "Tuples Fetched",
    CASE 
        WHEN idx_scan = 0 THEN 'UNUSED'
        WHEN idx_scan < 100 THEN 'LOW USAGE'
        ELSE 'ACTIVE'
    END as "Usage Status"
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 30;
"@ "Top 30 Largest Indexes"

# 6. Unused Indexes (Potential for Removal)
Execute-Query @"
SELECT 
    schemaname as "Schema",
    tablename as "Table",
    indexname as "Index",
    pg_size_pretty(pg_relation_size(indexrelid)) as "Wasted Space",
    pg_relation_size(indexrelid) as size_bytes,
    indexdef as "Definition"
FROM pg_stat_user_indexes
JOIN pg_indexes USING (schemaname, tablename, indexname)
WHERE idx_scan = 0
    AND indexrelname NOT LIKE '%_pkey'  -- Exclude primary keys
    AND pg_relation_size(indexrelid) > 1048576  -- > 1MB
ORDER BY pg_relation_size(indexrelid) DESC;
"@ "Unused Indexes (Candidates for Removal)"

# 7. Duplicate Indexes
Execute-Query @"
SELECT 
    pg_size_pretty(sum(pg_relation_size(idx))::bigint) as "Wasted Space",
    string_agg(indexrelname, ', ') as "Duplicate Indexes",
    tablename as "Table"
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
"@ "Duplicate Indexes (Potential Waste)"

# 8. TOAST Table Analysis
Execute-Query @"
SELECT 
    n.nspname as "Schema",
    c.relname as "Table",
    pg_size_pretty(pg_total_relation_size(c.reltoastrelid)) as "TOAST Size",
    pg_total_relation_size(c.reltoastrelid) as toast_bytes,
    pg_size_pretty(pg_relation_size(c.oid)) as "Main Table Size",
    round(100.0 * pg_total_relation_size(c.reltoastrelid) / 
        NULLIF(pg_relation_size(c.oid) + pg_total_relation_size(c.reltoastrelid), 0), 2) as "TOAST %"
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.reltoastrelid != 0
    AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(c.reltoastrelid) DESC
LIMIT 20;
"@ "TOAST Table Storage"

# 9. Tablespace Usage
Execute-Query @"
SELECT 
    spcname as "Tablespace",
    pg_size_pretty(pg_tablespace_size(spcname)) as "Size",
    pg_tablespace_location(oid) as "Location"
FROM pg_tablespace
ORDER BY pg_tablespace_size(spcname) DESC;
"@ "Tablespace Usage"

# 10. WAL Directory Size
Execute-Query @"
SELECT 
    count(*) as "WAL Files",
    pg_size_pretty(sum(size)) as "Total WAL Size",
    pg_size_pretty(avg(size)) as "Avg File Size",
    min(modification) as "Oldest WAL",
    max(modification) as "Newest WAL"
FROM pg_ls_waldir();
"@ "WAL Directory Statistics"

# 11. Table Bloat Estimation
Execute-Query @"
SELECT 
    schemaname as "Schema",
    tablename as "Table",
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as "Total Size",
    n_dead_tup as "Dead Tuples",
    n_live_tup as "Live Tuples",
    CASE 
        WHEN n_live_tup + n_dead_tup = 0 THEN 0
        ELSE round((n_dead_tup * 100.0 / (n_live_tup + n_dead_tup))::numeric, 2)
    END as "Dead Tuple %",
    pg_size_pretty(n_dead_tup * 
        CASE 
            WHEN n_live_tup = 0 THEN 0
            ELSE (pg_relation_size(schemaname||'.'||tablename) / NULLIF(n_live_tup, 0))
        END::bigint) as "Est. Bloat Size",
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC
LIMIT 20;
"@ "Table Bloat Analysis"

# 12. Schema Size Distribution
Execute-Query @"
SELECT 
    schemaname as "Schema",
    count(*) as "Tables",
    pg_size_pretty(sum(pg_total_relation_size(schemaname||'.'||tablename))) as "Total Size",
    pg_size_pretty(avg(pg_total_relation_size(schemaname||'.'||tablename))) as "Avg Table Size",
    pg_size_pretty(max(pg_total_relation_size(schemaname||'.'||tablename))) as "Largest Table"
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
GROUP BY schemaname
ORDER BY sum(pg_total_relation_size(schemaname||'.'||tablename)) DESC;
"@ "Storage by Schema"

if ($DetailedAnalysis) {
    # 13. Column Storage Analysis
    Execute-Query @"
SELECT 
    schemaname as "Schema",
    tablename as "Table",
    attname as "Column",
    format_type(atttypid, atttypmod) as "Data Type",
    CASE 
        WHEN attstorage = 'p' THEN 'PLAIN'
        WHEN attstorage = 'e' THEN 'EXTERNAL'
        WHEN attstorage = 'm' THEN 'MAIN'
        WHEN attstorage = 'x' THEN 'EXTENDED'
    END as "Storage",
    avg_width as "Avg Width (bytes)",
    n_distinct as "Distinct Values",
    null_frac as "Null Fraction"
FROM pg_stats
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
    AND avg_width > 100  -- Focus on wide columns
ORDER BY avg_width DESC
LIMIT 30;
"@ "Wide Column Analysis"

    # 14. Index Bloat Estimation
    Execute-Query @"
SELECT 
    schemaname as "Schema",
    tablename as "Table",
    indexname as "Index",
    pg_size_pretty(pg_relation_size(indexrelid)) as "Index Size",
    idx_scan as "Scans",
    idx_tup_read as "Tuples Read",
    idx_tup_fetch as "Tuples Fetched",
    CASE 
        WHEN idx_tup_read = 0 THEN 0
        ELSE round((idx_tup_fetch * 100.0 / idx_tup_read)::numeric, 2)
    END as "Fetch %"
FROM pg_stat_user_indexes
WHERE pg_relation_size(indexrelid) > 10485760  -- > 10MB
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 20;
"@ "Large Index Efficiency"
}

# 15. Growth Trend Analysis (if statistics available)
Execute-Query @"
SELECT 
    datname as "Database",
    xact_commit as "Commits",
    xact_rollback as "Rollbacks",
    tup_inserted as "Rows Inserted",
    tup_updated as "Rows Updated",
    tup_deleted as "Rows Deleted",
    tup_inserted + tup_updated + tup_deleted as "Total Modifications"
FROM pg_stat_database
WHERE datname = '$Database';
"@ "Database Activity Statistics"

# Generate Storage Recommendations
Write-Report "`n`n"
Write-Report ("=" * 80)
Write-Report "STORAGE OPTIMIZATION RECOMMENDATIONS"
Write-Report ("=" * 80)
Write-Report ""

# Calculate total database size
$dbSizeResult = Execute-Query "SELECT pg_database_size('$Database');"
if ($dbSizeResult -match "(\d+)") {
    $dbSizeBytes = [long]$matches[1]
    $dbSizeFormatted = Format-Bytes $dbSizeBytes
    
    Write-Report "📊 Current Database Size: $dbSizeFormatted"
    Write-Report ""
}

# Check for unused indexes
$unusedIndexResult = Execute-Query @"
SELECT pg_size_pretty(sum(pg_relation_size(indexrelid)))
FROM pg_stat_user_indexes
WHERE idx_scan = 0
    AND indexrelname NOT LIKE '%_pkey'
    AND pg_relation_size(indexrelid) > 1048576;
"@

if ($unusedIndexResult -and $unusedIndexResult -ne "") {
    Write-Report "🗑️  UNUSED INDEXES:"
    Write-Report "   Potential space savings: $unusedIndexResult"
    Write-Report "   → Run the 'Unused Indexes' query above to identify candidates"
    Write-Report "   → Use DROP INDEX to remove after verification"
    Write-Report ""
}

# Check for bloated tables
$bloatResult = Execute-Query @"
SELECT count(*), pg_size_pretty(sum(n_dead_tup * 
    CASE WHEN n_live_tup = 0 THEN 100 
    ELSE (pg_relation_size(schemaname||'.'||tablename) / NULLIF(n_live_tup, 0)) 
    END::bigint))
FROM pg_stat_user_tables
WHERE n_dead_tup > n_live_tup * 0.2 AND n_dead_tup > 1000;
"@

if ($bloatResult -and $bloatResult -match "(\d+)\|(.+)") {
    $bloatedCount = $matches[1]
    $bloatedSize = $matches[2]
    
    if ([int]$bloatedCount -gt 0) {
        Write-Report "💨 TABLE BLOAT:"
        Write-Report "   Tables with significant bloat: $bloatedCount"
        Write-Report "   Estimated bloat size: $bloatedSize"
        Write-Report "   → Run VACUUM ANALYZE on affected tables"
        Write-Report "   → Consider VACUUM FULL for severe cases (requires table lock)"
        Write-Report ""
    }
}

Write-Report "📋 GENERAL RECOMMENDATIONS:"
Write-Report ""
Write-Report "1. VACUUM & ANALYZE:"
Write-Report "   • Run VACUUM ANALYZE regularly to reclaim space and update statistics"
Write-Report "   • Enable autovacuum (should be on by default)"
Write-Report "   • Monitor autovacuum activity in pg_stat_user_tables"
Write-Report ""

Write-Report "2. INDEX MANAGEMENT:"
Write-Report "   • Remove unused indexes to save space and improve write performance"
Write-Report "   • Reindex bloated indexes: REINDEX INDEX index_name"
Write-Report "   • Consider partial indexes for filtered queries"
Write-Report ""

Write-Report "3. PARTITIONING:"
Write-Report "   • Consider table partitioning for very large tables (>100GB)"
Write-Report "   • Use time-based partitioning for time-series data"
Write-Report "   • Archive old partitions to reduce active dataset size"
Write-Report ""

Write-Report "4. DATA ARCHIVAL:"
Write-Report "   • Archive historical data to separate tables or databases"
Write-Report "   • Use pg_dump for selective data export"
Write-Report "   • Consider external storage for infrequently accessed data"
Write-Report ""

Write-Report "5. COMPRESSION:"
Write-Report "   • Use TOAST compression for large text/bytea columns"
Write-Report "   • Consider pg_compress extension for additional compression"
Write-Report "   • Evaluate column storage types (MAIN, EXTERNAL, EXTENDED)"
Write-Report ""

# Export to CSV if requested
if ($ExportToCSV) {
    Write-Host "`n📁 Exporting data to CSV files..."
    
    # Export table sizes
    $csvFile = Join-Path $OutputDir "table_sizes_detailed_$timestamp.csv"
    docker exec -i $ContainerName psql -U postgres -d $Database -c "COPY (
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
    ) TO STDOUT WITH CSV HEADER" > $csvFile
    Write-Host "  ✓ Table sizes: $csvFile"
    
    # Export index sizes
    $csvFile = Join-Path $OutputDir "index_sizes_$timestamp.csv"
    docker exec -i $ContainerName psql -U postgres -d $Database -c "COPY (
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
    ) TO STDOUT WITH CSV HEADER" > $csvFile
    Write-Host "  ✓ Index sizes: $csvFile"
}

Write-Report "`n"
Write-Report ("=" * 80)
Write-Report "📊 Report saved to: $reportFile"
Write-Report ("=" * 80)

Write-Host "`n✅ Storage analysis complete!"
