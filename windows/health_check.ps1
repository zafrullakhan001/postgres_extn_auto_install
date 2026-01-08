# PostgreSQL Health Check Script for Windows
# Performs comprehensive health checks on PostgreSQL database

param(
    [string]$ContainerName = "PG-timescale",
    [string]$Database = "postgres",
    [string]$OutputDir = ".\health_reports",
    [switch]$SendAlert,
    [string]$AlertEmail = "",
    [switch]$Help
)

function Show-Help {
    Write-Host @"
PostgreSQL Health Check Script
==============================

Usage: .\health_check.ps1 [OPTIONS]

Options:
    -ContainerName    Docker container name (default: PG-timescale)
    -Database         Database to check (default: postgres)
    -OutputDir        Output directory for reports (default: .\health_reports)
    -SendAlert        Send email alerts for critical issues
    -AlertEmail       Email address for alerts
    -Help             Show this help message

Examples:
    .\health_check.ps1
    .\health_check.ps1 -Database mydb
    .\health_check.ps1 -SendAlert -AlertEmail admin@example.com

"@
    exit 0
}

if ($Help) { Show-Help }

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportFile = Join-Path $OutputDir "health_check_$timestamp.txt"
$issues = @()
$warnings = @()
$healthScore = 100

function Write-Report {
    param([string]$Message)
    Write-Host $Message
    Add-Content -Path $reportFile -Value $Message
}

function Add-Issue {
    param(
        [string]$Severity,  # CRITICAL, WARNING, INFO
        [string]$Category,
        [string]$Message,
        [int]$ScoreImpact = 0
    )
    
    $issue = @{
        Severity  = $Severity
        Category  = $Category
        Message   = $Message
        Timestamp = Get-Date
    }
    
    if ($Severity -eq "CRITICAL") {
        $script:issues += $issue
        $script:healthScore -= $ScoreImpact
        Write-Report "❌ CRITICAL [$Category]: $Message"
    }
    elseif ($Severity -eq "WARNING") {
        $script:warnings += $issue
        $script:healthScore -= ($ScoreImpact / 2)
        Write-Report "⚠  WARNING [$Category]: $Message"
    }
    else {
        Write-Report "ℹ  INFO [$Category]: $Message"
    }
}

function Execute-Query {
    param([string]$Query)
    
    try {
        $result = docker exec -i $ContainerName psql -U postgres -d $Database -t -A -c $Query 2>&1
        if ($LASTEXITCODE -eq 0) {
            return $result.Trim()
        }
        else {
            return $null
        }
    }
    catch {
        return $null
    }
}

Write-Report "╔════════════════════════════════════════════════════════════════════════════╗"
Write-Report "║          PostgreSQL Health Check Report                                   ║"
Write-Report "╚════════════════════════════════════════════════════════════════════════════╝"
Write-Report ""
Write-Report "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Report "Container: $ContainerName"
Write-Report "Database: $Database"
Write-Report ("=" * 80)

# 1. Check if container is running
Write-Report "`n[1/15] Checking Docker Container Status..."
try {
    $containerStatus = docker inspect -f '{{.State.Status}}' $ContainerName 2>&1
    if ($containerStatus -eq "running") {
        Write-Report "✓ Container is running"
    }
    else {
        Add-Issue "CRITICAL" "Container" "Container is not running (Status: $containerStatus)" 20
        Write-Report "`n❌ Health check cannot continue - container is not running"
        exit 1
    }
}
catch {
    Add-Issue "CRITICAL" "Container" "Container not found: $ContainerName" 20
    exit 1
}

# 2. Check PostgreSQL connectivity
Write-Report "`n[2/15] Checking PostgreSQL Connectivity..."
$version = Execute-Query "SELECT version();"
if ($version) {
    Write-Report "✓ PostgreSQL is accessible"
    Write-Report "  Version: $($version.Split(',')[0])"
}
else {
    Add-Issue "CRITICAL" "Connectivity" "Cannot connect to PostgreSQL" 20
    exit 1
}

# 3. Check database existence
Write-Report "`n[3/15] Checking Database Existence..."
$dbExists = Execute-Query "SELECT 1 FROM pg_database WHERE datname='$Database';"
if ($dbExists -eq "1") {
    Write-Report "✓ Database '$Database' exists"
}
else {
    Add-Issue "CRITICAL" "Database" "Database '$Database' does not exist" 15
}

# 4. Check disk space
Write-Report "`n[4/15] Checking Disk Space..."
$diskUsage = Execute-Query @"
SELECT 
    pg_size_pretty(pg_database_size('$Database')) as db_size,
    pg_database_size('$Database') as db_size_bytes
FROM pg_database WHERE datname='$Database';
"@

if ($diskUsage) {
    $parts = $diskUsage.Split('|')
    if ($parts.Count -ge 2) {
        $sizeBytes = [long]$parts[1]
        $sizeGB = [math]::Round($sizeBytes / 1GB, 2)
        Write-Report "✓ Database size: $($parts[0]) ($sizeGB GB)"
        
        # Check if database is growing too large (>80% of typical limit)
        if ($sizeGB -gt 100) {
            Add-Issue "WARNING" "Disk Space" "Database size is large: $sizeGB GB" 5
        }
    }
}

# 5. Check connection limits
Write-Report "`n[5/15] Checking Connection Limits..."
$connStats = Execute-Query @"
SELECT 
    count(*) as current,
    (SELECT setting::int FROM pg_settings WHERE name='max_connections') as max_conn
FROM pg_stat_activity;
"@

if ($connStats) {
    $parts = $connStats.Split('|')
    if ($parts.Count -ge 2) {
        $current = [int]$parts[0]
        $max = [int]$parts[1]
        $usage = [math]::Round(($current / $max) * 100, 1)
        
        Write-Report "✓ Connections: $current / $max ($usage%)"
        
        if ($usage -gt 80) {
            Add-Issue "CRITICAL" "Connections" "Connection usage is critical: $usage%" 15
        }
        elseif ($usage -gt 60) {
            Add-Issue "WARNING" "Connections" "Connection usage is high: $usage%" 10
        }
    }
}

# 6. Check for idle in transaction connections
Write-Report "`n[6/15] Checking Idle Transactions..."
$idleInTrans = Execute-Query @"
SELECT count(*) 
FROM pg_stat_activity 
WHERE state = 'idle in transaction' 
    AND now() - state_change > interval '5 minutes';
"@

if ($idleInTrans -and [int]$idleInTrans -gt 0) {
    Add-Issue "WARNING" "Connections" "Found $idleInTrans long-running idle transactions (>5 min)" 8
}
else {
    Write-Report "✓ No long-running idle transactions"
}

# 7. Check cache hit ratio
Write-Report "`n[7/15] Checking Cache Hit Ratio..."
$cacheHit = Execute-Query @"
SELECT round((sum(heap_blks_hit) * 100.0 / 
    NULLIF(sum(heap_blks_hit + heap_blks_read), 0))::numeric, 2)
FROM pg_statio_user_tables;
"@

if ($cacheHit) {
    $ratio = [double]$cacheHit
    Write-Report "✓ Cache hit ratio: $ratio%"
    
    if ($ratio -lt 90) {
        Add-Issue "CRITICAL" "Performance" "Cache hit ratio is too low: $ratio% (target: >99%)" 15
    }
    elseif ($ratio -lt 95) {
        Add-Issue "WARNING" "Performance" "Cache hit ratio is suboptimal: $ratio% (target: >99%)" 10
    }
}

# 8. Check for table bloat
Write-Report "`n[8/15] Checking Table Bloat..."
$bloatedTables = Execute-Query @"
SELECT count(*) 
FROM pg_stat_user_tables 
WHERE n_dead_tup > 10000 
    AND n_dead_tup > n_live_tup * 0.2;
"@

if ($bloatedTables -and [int]$bloatedTables -gt 0) {
    Add-Issue "WARNING" "Maintenance" "Found $bloatedTables tables with significant bloat (>20% dead tuples)" 10
    
    $bloatDetails = Execute-Query @"
SELECT tablename, n_dead_tup, n_live_tup,
    round((n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0))::numeric, 1) as dead_pct
FROM pg_stat_user_tables 
WHERE n_dead_tup > 10000 
    AND n_dead_tup > n_live_tup * 0.2
ORDER BY n_dead_tup DESC LIMIT 5;
"@
    Write-Report "  Top bloated tables:"
    Write-Report "  $bloatDetails"
}
else {
    Write-Report "✓ No significant table bloat detected"
}

# 9. Check for unused indexes
Write-Report "`n[9/15] Checking Unused Indexes..."
$unusedIndexes = Execute-Query @"
SELECT count(*) 
FROM pg_stat_user_indexes 
WHERE idx_scan = 0 
    AND pg_relation_size(indexrelid) > 1048576;
"@

if ($unusedIndexes -and [int]$unusedIndexes -gt 0) {
    Add-Issue "WARNING" "Performance" "Found $unusedIndexes unused indexes (>1MB, never scanned)" 5
}
else {
    Write-Report "✓ No large unused indexes found"
}

# 10. Check for missing indexes (high sequential scans)
Write-Report "`n[10/15] Checking for Missing Indexes..."
$highSeqScans = Execute-Query @"
SELECT count(*) 
FROM pg_stat_user_tables 
WHERE seq_scan > 1000 
    AND seq_scan > idx_scan 
    AND pg_total_relation_size(schemaname||'.'||tablename) > 10485760;
"@

if ($highSeqScans -and [int]$highSeqScans -gt 0) {
    Add-Issue "WARNING" "Performance" "Found $highSeqScans large tables with high sequential scans" 8
}
else {
    Write-Report "✓ No tables with excessive sequential scans"
}

# 11. Check replication status
Write-Report "`n[11/15] Checking Replication Status..."
$replicas = Execute-Query "SELECT count(*) FROM pg_stat_replication;"

if ($replicas -and [int]$replicas -gt 0) {
    Write-Report "✓ Replication active: $replicas replica(s)"
    
    # Check replication lag
    $repLag = Execute-Query @"
SELECT max(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)) as max_lag_bytes
FROM pg_stat_replication;
"@
    
    if ($repLag -and [long]$repLag -gt 104857600) {
        # 100MB
        $lagMB = [math]::Round([long]$repLag / 1MB, 2)
        Add-Issue "WARNING" "Replication" "Replication lag is high: $lagMB MB" 10
    }
}
else {
    Write-Report "ℹ  No replication configured"
}

# 12. Check for locks
Write-Report "`n[12/15] Checking for Lock Contention..."
$locks = Execute-Query @"
SELECT count(*) 
FROM pg_locks 
WHERE NOT granted;
"@

if ($locks -and [int]$locks -gt 0) {
    Add-Issue "WARNING" "Performance" "Found $locks blocked queries waiting for locks" 10
}
else {
    Write-Report "✓ No lock contention detected"
}

# 13. Check autovacuum status
Write-Report "`n[13/15] Checking Autovacuum Configuration..."
$autovacuum = Execute-Query "SELECT setting FROM pg_settings WHERE name='autovacuum';"

if ($autovacuum -eq "on") {
    Write-Report "✓ Autovacuum is enabled"
    
    # Check when tables were last vacuumed
    $oldVacuum = Execute-Query @"
SELECT count(*) 
FROM pg_stat_user_tables 
WHERE last_autovacuum < now() - interval '7 days' 
    OR last_autovacuum IS NULL;
"@
    
    if ($oldVacuum -and [int]$oldVacuum -gt 0) {
        Add-Issue "WARNING" "Maintenance" "$oldVacuum tables haven't been vacuumed in 7+ days" 8
    }
}
else {
    Add-Issue "CRITICAL" "Configuration" "Autovacuum is disabled!" 15
}

# 14. Check for long-running queries
Write-Report "`n[14/15] Checking for Long-Running Queries..."
$longQueries = Execute-Query @"
SELECT count(*) 
FROM pg_stat_activity 
WHERE state != 'idle' 
    AND query_start < now() - interval '10 minutes' 
    AND pid <> pg_backend_pid();
"@

if ($longQueries -and [int]$longQueries -gt 0) {
    Add-Issue "WARNING" "Performance" "Found $longQueries queries running >10 minutes" 10
    
    $queryDetails = Execute-Query @"
SELECT pid, usename, 
    extract(epoch from (now() - query_start))::int as seconds,
    left(query, 80) as query
FROM pg_stat_activity 
WHERE state != 'idle' 
    AND query_start < now() - interval '10 minutes' 
    AND pid <> pg_backend_pid()
ORDER BY query_start LIMIT 3;
"@
    Write-Report "  Sample queries:"
    Write-Report "  $queryDetails"
}
else {
    Write-Report "✓ No long-running queries detected"
}

# 15. Check WAL file accumulation
Write-Report "`n[15/15] Checking WAL File Status..."
$walFiles = Execute-Query @"
SELECT count(*) 
FROM pg_ls_waldir() 
WHERE modification > now() - interval '1 hour';
"@

if ($walFiles) {
    Write-Report "✓ WAL files generated in last hour: $walFiles"
    
    $totalWalSize = Execute-Query @"
SELECT pg_size_pretty(sum(size)) 
FROM pg_ls_waldir();
"@
    
    if ($totalWalSize) {
        Write-Report "  Total WAL directory size: $totalWalSize"
    }
}

# Calculate final health score
$healthScore = [math]::Max(0, $healthScore)

Write-Report "`n"
Write-Report ("=" * 80)
Write-Report "HEALTH CHECK SUMMARY"
Write-Report ("=" * 80)
Write-Report ""

# Display health score with visual indicator
$scoreBar = "█" * [math]::Floor($healthScore / 5)
$scoreColor = if ($healthScore -ge 90) { "Green" } 
elseif ($healthScore -ge 70) { "Yellow" } 
else { "Red" }

Write-Report "Overall Health Score: $healthScore / 100"
Write-Report "[$scoreBar]"
Write-Report ""

if ($issues.Count -gt 0) {
    Write-Report "❌ CRITICAL ISSUES: $($issues.Count)"
    foreach ($issue in $issues) {
        Write-Report "   • [$($issue.Category)] $($issue.Message)"
    }
    Write-Report ""
}

if ($warnings.Count -gt 0) {
    Write-Report "⚠  WARNINGS: $($warnings.Count)"
    foreach ($warning in $warnings) {
        Write-Report "   • [$($warning.Category)] $($warning.Message)"
    }
    Write-Report ""
}

if ($issues.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Report "✅ All health checks passed!"
}

Write-Report ""
Write-Report "RECOMMENDATIONS:"
Write-Report ("=" * 80)

if ($healthScore -lt 70) {
    Write-Report "🔴 URGENT: Immediate action required!"
    Write-Report "   1. Review and address all CRITICAL issues immediately"
    Write-Report "   2. Consider scheduling maintenance window"
    Write-Report "   3. Monitor system closely"
}
elseif ($healthScore -lt 90) {
    Write-Report "🟡 ATTENTION: Some issues need attention"
    Write-Report "   1. Address WARNING issues during next maintenance window"
    Write-Report "   2. Monitor trends to prevent degradation"
}
else {
    Write-Report "🟢 HEALTHY: System is operating normally"
    Write-Report "   1. Continue regular monitoring"
    Write-Report "   2. Maintain current maintenance schedule"
}

Write-Report ""
Write-Report "Report saved to: $reportFile"
Write-Report ("=" * 80)

# Send alert if requested and there are critical issues
if ($SendAlert -and $AlertEmail -and $issues.Count -gt 0) {
    Write-Host "`n📧 Sending alert email to $AlertEmail..."
    # Note: Email sending would require additional configuration
    Write-Host "⚠  Email alerting requires SMTP configuration (not implemented in this script)"
}

# Exit with appropriate code
if ($issues.Count -gt 0) {
    exit 1
}
elseif ($warnings.Count -gt 0) {
    exit 2
}
else {
    exit 0
}
