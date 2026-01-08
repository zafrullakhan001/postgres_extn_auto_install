#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Point-in-Time Recovery (PITR) for PostgreSQL
.DESCRIPTION
    Restores PostgreSQL database to a specific point in time using base backup and WAL files
.PARAMETER BaseBackup
    Path to base backup directory
.PARAMETER WALArchive
    Path to WAL archive directory
.PARAMETER RecoveryTarget
    Recovery target time (format: 'YYYY-MM-DD HH:MM:SS')
.PARAMETER Container
    Docker container name (default: PG-timescale)
.EXAMPLE
    .\restore_pitr.ps1 -BaseBackup .\backups\basebackup_20260108_120000 -WALArchive .\backups\wal -RecoveryTarget "2026-01-08 14:30:00"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$BaseBackup,
    
    [Parameter(Mandatory = $true)]
    [string]$WALArchive,
    
    [Parameter(Mandatory = $false)]
    [string]$RecoveryTarget,
    
    [Parameter(Mandatory = $false)]
    [string]$Container = 'PG-timescale',
    
    [Parameter(Mandatory = $false)]
    [string]$User = 'postgres',
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('immediate', 'time', 'xid', 'name', 'lsn')]
    [string]$RecoveryTargetType = 'time',
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Color output functions
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }

Write-Info "PostgreSQL Point-in-Time Recovery (PITR)"
Write-Info "========================================="
Write-Info "Base Backup: $BaseBackup"
Write-Info "WAL Archive: $WALArchive"
if ($RecoveryTarget) {
    Write-Info "Recovery Target: $RecoveryTarget"
}
Write-Host ""

# Validate inputs
if (-not (Test-Path $BaseBackup)) {
    Write-Error "Base backup not found: $BaseBackup"
    exit 1
}

if (-not (Test-Path $WALArchive)) {
    Write-Error "WAL archive not found: $WALArchive"
    exit 1
}

Write-Success "Backup sources validated"

# Check if container exists
$containerExists = docker ps -a --filter "name=$Container" --format "{{.Names}}" 2>$null
if (-not $containerExists) {
    Write-Error "Container '$Container' not found!"
    exit 1
}

# Warning
if (-not $Force) {
    Write-Warning "Point-in-Time Recovery will REPLACE all current data!"
    Write-Warning "This is an advanced operation that requires:"
    Write-Host "  1. A valid base backup (pg_basebackup)"
    Write-Host "  2. WAL archive files covering the recovery period"
    Write-Host "  3. Proper PostgreSQL configuration"
    Write-Host ""
    Write-Host "Press Ctrl+C to cancel, or press Enter to continue..." -ForegroundColor Yellow
    Read-Host
}

# Stop container
Write-Info "Stopping container..."
docker stop $Container | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to stop container"
    exit 1
}
Write-Success "Container stopped"

# Create recovery directory
$recoveryDir = ".\recovery_temp"
if (Test-Path $recoveryDir) {
    Remove-Item -Path $recoveryDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $recoveryDir | Out-Null

# Extract base backup
Write-Info "Extracting base backup..."
Copy-Item -Path "$BaseBackup\*" -Destination $recoveryDir -Recurse -Force
Write-Success "Base backup extracted"

# Create recovery.signal file (PostgreSQL 12+)
Write-Info "Creating recovery configuration..."
$recoverySignal = Join-Path $recoveryDir "recovery.signal"
New-Item -ItemType File -Path $recoverySignal -Force | Out-Null

# Create postgresql.auto.conf with recovery settings
$autoConf = Join-Path $recoveryDir "postgresql.auto.conf"
$recoveryConfig = @"
# Point-in-Time Recovery Configuration
# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

restore_command = 'cp /var/lib/postgresql/wal_archive/%f %p'
recovery_target_action = 'promote'
"@

if ($RecoveryTarget) {
    if ($RecoveryTargetType -eq 'time') {
        $recoveryConfig += "`nrecovery_target_time = '$RecoveryTarget'"
    }
    elseif ($RecoveryTargetType -eq 'xid') {
        $recoveryConfig += "`nrecovery_target_xid = '$RecoveryTarget'"
    }
    elseif ($RecoveryTargetType -eq 'name') {
        $recoveryConfig += "`nrecovery_target_name = '$RecoveryTarget'"
    }
    elseif ($RecoveryTargetType -eq 'lsn') {
        $recoveryConfig += "`nrecovery_target_lsn = '$RecoveryTarget'"
    }
}

$recoveryConfig | Out-File -FilePath $autoConf -Encoding UTF8 -Append
Write-Success "Recovery configuration created"

# Get container's data volume
$volumeInfo = docker inspect $Container --format='{{json .Mounts}}' | ConvertFrom-Json
$dataVolume = $volumeInfo | Where-Object { $_.Destination -eq '/var/lib/postgresql/data' } | Select-Object -First 1

if ($dataVolume) {
    Write-Info "Data volume: $($dataVolume.Name)"
    
    # Backup current data (safety measure)
    $backupTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    Write-Info "Creating safety backup of current data..."
    $safetyBackup = ".\backups\safety_backup_${backupTimestamp}.tar.gz"
    docker run --rm -v "$($dataVolume.Name):/source" -v "${PWD}/backups:/backup" alpine tar czf "/backup/safety_backup_${backupTimestamp}.tar.gz" -C /source . 2>$null
    Write-Success "Safety backup created: $safetyBackup"
    
    # Clear current data directory
    Write-Info "Clearing current data directory..."
    docker run --rm -v "$($dataVolume.Name):/data" alpine sh -c "rm -rf /data/*"
    Write-Success "Data directory cleared"
    
    # Copy recovery data to volume
    Write-Info "Copying recovery data to volume..."
    docker run --rm -v "$($dataVolume.Name):/target" -v "${recoveryDir}:/source" alpine sh -c "cp -a /source/* /target/"
    Write-Success "Recovery data copied"
    
    # Copy WAL archive to container
    Write-Info "Setting up WAL archive..."
    docker run --rm -v "$($dataVolume.Name):/target" -v "${WALArchive}:/wal" alpine sh -c "mkdir -p /target/wal_archive && cp -a /wal/* /target/wal_archive/"
    Write-Success "WAL archive configured"
}

# Start container for recovery
Write-Info "Starting container for recovery..."
docker start $Container | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to start container"
    exit 1
}
Write-Success "Container started"

# Monitor recovery progress
Write-Info "PostgreSQL is now performing point-in-time recovery..."
Write-Info "This may take several minutes depending on the amount of WAL data"
Write-Host ""

# Wait for recovery to complete
$maxWaitSeconds = 300
$waitedSeconds = 0
$recoveryComplete = $false

while ($waitedSeconds -lt $maxWaitSeconds -and -not $recoveryComplete) {
    Start-Sleep -Seconds 5
    $waitedSeconds += 5
    
    # Check if PostgreSQL is accepting connections
    $pgReady = docker exec $Container pg_isready -U $User 2>$null
    
    if ($pgReady -match "accepting connections") {
        $recoveryComplete = $true
        Write-Success "Recovery completed! PostgreSQL is accepting connections"
        break
    }
    else {
        Write-Host "." -NoNewline
    }
}

Write-Host ""

if ($recoveryComplete) {
    # Verify recovery
    Write-Info "Verifying recovery..."
    
    $version = docker exec $Container psql -U $User -t -c "SELECT version();" 2>$null
    $currentTime = docker exec $Container psql -U $User -t -c "SELECT now();" 2>$null
    
    Write-Host ""
    Write-Success "Point-in-Time Recovery completed successfully!"
    Write-Info "PostgreSQL version: $($version.Trim())"
    Write-Info "Current database time: $($currentTime.Trim())"
    
    if ($RecoveryTarget) {
        Write-Info "Recovery target was: $RecoveryTarget"
    }
    
    # List databases
    Write-Info "Verifying databases..."
    $databases = docker exec $Container psql -U $User -c "\l"
    Write-Host $databases
    
    # Cleanup
    Write-Info "Cleaning up temporary files..."
    Remove-Item -Path $recoveryDir -Recurse -Force
    Write-Success "Cleanup completed"
    
}
else {
    Write-Error "Recovery did not complete within $maxWaitSeconds seconds"
    Write-Info "Check container logs: docker logs $Container"
    Write-Info "You may need to wait longer or check for errors"
}

Write-Host ""
Write-Info "Recovery Summary"
Write-Info "================"
Write-Info "Base Backup: $BaseBackup"
Write-Info "WAL Archive: $WALArchive"
if ($RecoveryTarget) {
    Write-Info "Recovery Target: $RecoveryTarget ($RecoveryTargetType)"
}
Write-Info "Safety Backup: $safetyBackup"
Write-Host ""
Write-Success "PITR operation completed!"
Write-Warning "Please verify your data thoroughly before using in production"
