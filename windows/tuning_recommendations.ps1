# PostgreSQL Tuning Script for Windows
# Analyzes current configuration and provides tuning recommendations

param(
    [string]$ContainerName = "PG-timescale",
    [string]$OutputDir = ".\tuning_reports",
    [ValidateSet("Small", "Medium", "Large", "Auto")]
    [string]$WorkloadProfile = "Auto",
    [int]$TotalRAM_GB = 0,  # Auto-detect if 0
    [switch]$ApplyChanges,
    [switch]$Help
)

function Show-Help {
    Write-Host @"
PostgreSQL Tuning Script
========================

Usage: .\tuning_recommendations.ps1 [OPTIONS]

Options:
    -ContainerName     Docker container name (default: PG-timescale)
    -OutputDir         Output directory for reports (default: .\tuning_reports)
    -WorkloadProfile   Workload type: Small, Medium, Large, Auto (default: Auto)
    -TotalRAM_GB       Total RAM in GB (auto-detect if not specified)
    -ApplyChanges      Apply recommended changes (requires confirmation)
    -Help              Show this help message

Workload Profiles:
    Small   - <4GB RAM, light workload
    Medium  - 4-16GB RAM, moderate workload
    Large   - >16GB RAM, heavy workload
    Auto    - Automatically detect based on system resources

Examples:
    .\tuning_recommendations.ps1
    .\tuning_recommendations.ps1 -WorkloadProfile Large -TotalRAM_GB 32
    .\tuning_recommendations.ps1 -ApplyChanges

"@
    exit 0
}

if ($Help) { Show-Help }

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportFile = Join-Path $OutputDir "tuning_recommendations_$timestamp.txt"
$configFile = Join-Path $OutputDir "postgresql_tuned_$timestamp.conf"

function Write-Report {
    param([string]$Message)
    Write-Host $Message
    Add-Content -Path $reportFile -Value $Message
}

function Execute-Query {
    param([string]$Query)
    
    try {
        $result = docker exec -i $ContainerName psql -U postgres -t -A -c $Query 2>&1
        if ($LASTEXITCODE -eq 0) {
            return $result.Trim()
        }
        return $null
    }
    catch {
        return $null
    }
}

# Auto-detect RAM if not specified
if ($TotalRAM_GB -eq 0) {
    try {
        $totalRAM = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).Sum
        $TotalRAM_GB = [math]::Round($totalRAM / 1GB)
        Write-Host "Auto-detected system RAM: $TotalRAM_GB GB"
    }
    catch {
        $TotalRAM_GB = 8  # Default fallback
        Write-Host "Could not detect RAM, using default: $TotalRAM_GB GB"
    }
}

# Determine workload profile
if ($WorkloadProfile -eq "Auto") {
    if ($TotalRAM_GB -lt 4) {
        $WorkloadProfile = "Small"
    }
    elseif ($TotalRAM_GB -lt 16) {
        $WorkloadProfile = "Medium"
    }
    else {
        $WorkloadProfile = "Large"
    }
    Write-Host "Auto-selected workload profile: $WorkloadProfile"
}

Write-Report "╔════════════════════════════════════════════════════════════════════════════╗"
Write-Report "║          PostgreSQL Tuning Recommendations                                 ║"
Write-Report "╚════════════════════════════════════════════════════════════════════════════╝"
Write-Report ""
Write-Report "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Report "Container: $ContainerName"
Write-Report "System RAM: $TotalRAM_GB GB"
Write-Report "Workload Profile: $WorkloadProfile"
Write-Report ("=" * 80)

# Get current PostgreSQL version
$version = Execute-Query "SHOW server_version;"
Write-Report "`nPostgreSQL Version: $version"

# Calculate recommended values based on workload profile
$recommendations = @{}

switch ($WorkloadProfile) {
    "Small" {
        # For systems with <4GB RAM
        $recommendations["shared_buffers"] = [math]::Max(128, [math]::Floor($TotalRAM_GB * 1024 * 0.25))  # 25% of RAM
        $recommendations["effective_cache_size"] = [math]::Floor($TotalRAM_GB * 1024 * 0.5)  # 50% of RAM
        $recommendations["maintenance_work_mem"] = 64  # MB
        $recommendations["work_mem"] = 4  # MB
        $recommendations["max_connections"] = 100
        $recommendations["max_parallel_workers_per_gather"] = 1
        $recommendations["max_parallel_workers"] = 2
        $recommendations["max_worker_processes"] = 2
    }
    "Medium" {
        # For systems with 4-16GB RAM
        $recommendations["shared_buffers"] = [math]::Floor($TotalRAM_GB * 1024 * 0.25)  # 25% of RAM
        $recommendations["effective_cache_size"] = [math]::Floor($TotalRAM_GB * 1024 * 0.75)  # 75% of RAM
        $recommendations["maintenance_work_mem"] = [math]::Min(2048, [math]::Floor($TotalRAM_GB * 1024 * 0.05))  # 5% of RAM, max 2GB
        $recommendations["work_mem"] = 16  # MB
        $recommendations["max_connections"] = 200
        $recommendations["max_parallel_workers_per_gather"] = 2
        $recommendations["max_parallel_workers"] = 4
        $recommendations["max_worker_processes"] = 4
    }
    "Large" {
        # For systems with >16GB RAM
        $recommendations["shared_buffers"] = [math]::Min(16384, [math]::Floor($TotalRAM_GB * 1024 * 0.25))  # 25% of RAM, max 16GB
        $recommendations["effective_cache_size"] = [math]::Floor($TotalRAM_GB * 1024 * 0.75)  # 75% of RAM
        $recommendations["maintenance_work_mem"] = 2048  # 2GB
        $recommendations["work_mem"] = 32  # MB
        $recommendations["max_connections"] = 300
        $recommendations["max_parallel_workers_per_gather"] = 4
        $recommendations["max_parallel_workers"] = 8
        $recommendations["max_worker_processes"] = 8
    }
}

# Additional recommendations (workload-independent)
$recommendations["wal_buffers"] = [math]::Min(16, [math]::Max(1, [math]::Floor($recommendations["shared_buffers"] / 32)))  # MB
$recommendations["checkpoint_completion_target"] = 0.9
$recommendations["max_wal_size"] = [math]::Max(1024, [math]::Floor($recommendations["shared_buffers"] * 2))  # MB
$recommendations["min_wal_size"] = [math]::Floor($recommendations["max_wal_size"] / 4)  # MB
$recommendations["random_page_cost"] = 1.1  # For SSD
$recommendations["effective_io_concurrency"] = 200  # For SSD
$recommendations["autovacuum_max_workers"] = 3
$recommendations["autovacuum_naptime"] = 10  # seconds

# Get current settings
Write-Report "`n"
Write-Report ("=" * 80)
Write-Report "CURRENT vs RECOMMENDED SETTINGS"
Write-Report ("=" * 80)
Write-Report ""
Write-Report ('{0,-35} {1,-20} {2,-20}' -f "Parameter", "Current", "Recommended")
Write-Report ("-" * 80)

$configChanges = @()

foreach ($param in $recommendations.Keys | Sort-Object) {
    $current = Execute-Query "SHOW $param;"
    $recommended = $recommendations[$param]
    
    # Determine unit
    $unit = ""
    if ($param -match "mem|buffers|wal_size") {
        $unit = "MB"
    }
    
    $currentDisplay = if ($current) { $current } else { "N/A" }
    $recommendedDisplay = "$recommended$unit"
    
    # Check if change is needed
    $needsChange = $false
    if ($current) {
        # Parse current value (remove units)
        $currentValue = $current -replace '[^0-9.]', ''
        if ($currentValue -and [double]$currentValue -ne [double]$recommended) {
            $needsChange = $true
        }
    }
    
    $marker = if ($needsChange) { "⚠" } else { "✓" }
    
    Write-Report ('{0} {1,-33} {2,-20} {3,-20}' -f $marker, $param, $currentDisplay, $recommendedDisplay)
    
    if ($needsChange) {
        $configChanges += @{
            Parameter   = $param
            Current     = $currentDisplay
            Recommended = $recommendedDisplay
            Value       = $recommended
            Unit        = $unit
        }
    }
}

# Generate postgresql.conf snippet
Write-Report "`n"
Write-Report ("=" * 80)
Write-Report "CONFIGURATION FILE SNIPPET"
Write-Report ("=" * 80)
Write-Report ""
Write-Report "Add the following to your postgresql.conf:"
Write-Report ""

$confContent = @"
# PostgreSQL Tuning Configuration
# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Workload Profile: $WorkloadProfile
# System RAM: $TotalRAM_GB GB

# Memory Settings
shared_buffers = $($recommendations["shared_buffers"])MB
effective_cache_size = $($recommendations["effective_cache_size"])MB
maintenance_work_mem = $($recommendations["maintenance_work_mem"])MB
work_mem = $($recommendations["work_mem"])MB

# Connection Settings
max_connections = $($recommendations["max_connections"])

# Parallel Query Settings
max_parallel_workers_per_gather = $($recommendations["max_parallel_workers_per_gather"])
max_parallel_workers = $($recommendations["max_parallel_workers"])
max_worker_processes = $($recommendations["max_worker_processes"])

# WAL Settings
wal_buffers = $($recommendations["wal_buffers"])MB
checkpoint_completion_target = $($recommendations["checkpoint_completion_target"])
max_wal_size = $($recommendations["max_wal_size"])MB
min_wal_size = $($recommendations["min_wal_size"])MB

# Storage Settings (for SSD)
random_page_cost = $($recommendations["random_page_cost"])
effective_io_concurrency = $($recommendations["effective_io_concurrency"])

# Autovacuum Settings
autovacuum_max_workers = $($recommendations["autovacuum_max_workers"])
autovacuum_naptime = $($recommendations["autovacuum_naptime"])s

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
"@

Write-Report $confContent
Add-Content -Path $configFile -Value $confContent

Write-Report ""
Write-Report "Configuration saved to: $configFile"

# Performance analysis based on current state
Write-Report "`n"
Write-Report ("=" * 80)
Write-Report "PERFORMANCE ANALYSIS"
Write-Report ("=" * 80)

# Check cache hit ratio
$cacheHit = Execute-Query @"
SELECT round((sum(heap_blks_hit) * 100.0 / 
    NULLIF(sum(heap_blks_hit + heap_blks_read), 0))::numeric, 2)
FROM pg_statio_user_tables;
"@

if ($cacheHit) {
    Write-Report "`nCache Hit Ratio: $cacheHit%"
    if ([double]$cacheHit -lt 99) {
        Write-Report "  ⚠ Low cache hit ratio - consider increasing shared_buffers"
    }
    else {
        Write-Report "  ✓ Good cache hit ratio"
    }
}

# Check checkpoint frequency
$checkpoints = Execute-Query @"
SELECT 
    checkpoints_timed,
    checkpoints_req,
    round((checkpoints_req * 100.0 / NULLIF(checkpoints_timed + checkpoints_req, 0))::numeric, 2) as req_pct
FROM pg_stat_bgwriter;
"@

if ($checkpoints) {
    $parts = $checkpoints.Split('|')
    if ($parts.Count -ge 3) {
        Write-Report "`nCheckpoint Statistics:"
        Write-Report "  Timed checkpoints: $($parts[0])"
        Write-Report "  Requested checkpoints: $($parts[1]) ($($parts[2])%)"
        
        if ([double]$parts[2] -gt 10) {
            Write-Report "  ⚠ High percentage of requested checkpoints - consider increasing max_wal_size"
        }
        else {
            Write-Report "  ✓ Checkpoint frequency is good"
        }
    }
}

# Additional recommendations
Write-Report "`n"
Write-Report ("=" * 80)
Write-Report "ADDITIONAL RECOMMENDATIONS"
Write-Report ("=" * 80)
Write-Report ""

Write-Report "1. MONITORING:"
Write-Report "   • Enable pg_stat_statements extension for query analysis"
Write-Report "   • Set up regular health checks and performance monitoring"
Write-Report "   • Monitor slow query log (log_min_duration_statement)"
Write-Report ""

Write-Report "2. MAINTENANCE:"
Write-Report "   • Ensure autovacuum is running regularly"
Write-Report "   • Schedule ANALYZE after bulk data loads"
Write-Report "   • Monitor table bloat and run VACUUM FULL if needed"
Write-Report "   • Regularly update statistics with ANALYZE"
Write-Report ""

Write-Report "3. INDEXING:"
Write-Report "   • Review query patterns and add missing indexes"
Write-Report "   • Remove unused indexes to reduce write overhead"
Write-Report "   • Consider partial indexes for filtered queries"
Write-Report "   • Use EXPLAIN ANALYZE to optimize query plans"
Write-Report ""

Write-Report "4. HARDWARE:"
Write-Report "   • Use SSD storage for better I/O performance"
Write-Report "   • Ensure adequate RAM for caching"
Write-Report "   • Consider connection pooling (PgBouncer) for high connection counts"
Write-Report ""

Write-Report "5. BACKUP & RECOVERY:"
Write-Report "   • Configure WAL archiving for point-in-time recovery"
Write-Report "   • Test restore procedures regularly"
Write-Report "   • Monitor backup completion and size"
Write-Report ""

# Apply changes if requested
if ($ApplyChanges) {
    Write-Host "`n"
    Write-Host ("=" * 80) -ForegroundColor Yellow
    Write-Host "WARNING: Applying configuration changes" -ForegroundColor Yellow
    Write-Host ("=" * 80) -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This will modify PostgreSQL configuration and require a restart."
    Write-Host "The following parameters will be changed:"
    Write-Host ""
    
    foreach ($change in $configChanges) {
        Write-Host "  • $($change.Parameter): $($change.Current) → $($change.Recommended)" -ForegroundColor Cyan
    }
    
    Write-Host ""
    $confirm = Read-Host "Do you want to proceed? (yes/no)"
    
    if ($confirm -eq "yes") {
        Write-Host "`nApplying changes..."
        
        # Copy config file to container
        Write-Host "  1. Copying configuration to container..."
        docker cp $configFile "${ContainerName}:/tmp/postgresql_tuned.conf"
        
        Write-Host "  2. Appending to postgresql.conf..."
        docker exec $ContainerName bash -c "cat /tmp/postgresql_tuned.conf >> /var/lib/postgresql/data/postgresql.conf"
        
        Write-Host "  3. Restarting PostgreSQL..."
        docker restart $ContainerName
        
        Write-Host "`n✅ Configuration applied successfully!" -ForegroundColor Green
        Write-Host "⚠  Please verify the changes and monitor performance." -ForegroundColor Yellow
    }
    else {
        Write-Host "`n❌ Changes not applied." -ForegroundColor Red
    }
}

Write-Report "`n"
Write-Report ("=" * 80)
Write-Report "Report saved to: $reportFile"
Write-Report "Configuration file: $configFile"
Write-Report ("=" * 80)

if (-not $ApplyChanges) {
    Write-Host "`n💡 Tip: Use -ApplyChanges flag to automatically apply these settings" -ForegroundColor Cyan
}

Write-Host "`n✅ Tuning analysis complete!"
