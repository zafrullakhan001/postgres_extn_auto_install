#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Incremental PostgreSQL backup using WAL archiving
.DESCRIPTION
    Configures and performs incremental backups using PostgreSQL WAL (Write-Ahead Logging)
.PARAMETER Container
    Docker container name (default: PG-timescale)
.PARAMETER BackupDir
    Backup directory path (default: .\backups\wal)
.PARAMETER Action
    Action to perform: 'setup', 'backup', or 'archive'
.EXAMPLE
    .\backup_incremental.ps1 -Action setup
    .\backup_incremental.ps1 -Action backup
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('setup', 'backup', 'archive', 'status')]
    [string]$Action = 'backup',
    
    [Parameter(Mandatory = $false)]
    [string]$Container = 'PG-timescale',
    
    [Parameter(Mandatory = $false)]
    [string]$BackupDir = '.\backups\wal',
    
    [Parameter(Mandatory = $false)]
    [string]$User = 'postgres'
)

# Color output functions
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }

Write-Info "PostgreSQL Incremental Backup Script"
Write-Info "====================================="
Write-Info "Action: $Action"
Write-Info "Container: $Container"
Write-Host ""

# Check if container is running
$containerStatus = docker ps --filter "name=$Container" --format "{{.Status}}" 2>$null
if (-not $containerStatus) {
    Write-Error "Container '$Container' is not running!"
    exit 1
}

if ($Action -eq 'setup') {
    Write-Info "Setting up WAL archiving for incremental backups..."
    
    # Create WAL archive directory
    if (-not (Test-Path $BackupDir)) {
        New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
        Write-Success "Created WAL archive directory: $BackupDir"
    }
    
    # Create archive directory inside container
    docker exec $Container mkdir -p /var/lib/postgresql/wal_archive 2>$null
    
    Write-Info "Configuring PostgreSQL for WAL archiving..."
    Write-Warning "Note: This requires PostgreSQL restart and proper configuration"
    
    # Display configuration instructions
    Write-Host ""
    Write-Info "Manual Configuration Required:"
    Write-Host "1. Edit postgresql.conf in the container:"
    Write-Host "   docker exec -it $Container bash"
    Write-Host "   vi /var/lib/postgresql/data/postgresql.conf"
    Write-Host ""
    Write-Host "2. Add/modify these settings:"
    Write-Host "   wal_level = replica"
    Write-Host "   archive_mode = on"
    Write-Host "   archive_command = 'cp %p /var/lib/postgresql/wal_archive/%f'"
    Write-Host "   max_wal_senders = 3"
    Write-Host "   wal_keep_size = 1GB"
    Write-Host ""
    Write-Host "3. Restart PostgreSQL:"
    Write-Host "   docker restart $Container"
    Write-Host ""
    Write-Success "Setup instructions displayed"
    
}
elseif ($Action -eq 'status') {
    Write-Info "Checking WAL archiving status..."
    
    # Check archive mode
    $archiveMode = docker exec $Container psql -U $User -t -c "SHOW archive_mode;" 2>$null
    $walLevel = docker exec $Container psql -U $User -t -c "SHOW wal_level;" 2>$null
    $archiveCommand = docker exec $Container psql -U $User -t -c "SHOW archive_command;" 2>$null
    
    Write-Host ""
    Write-Info "Current Configuration:"
    Write-Host "  Archive Mode: $($archiveMode.Trim())"
    Write-Host "  WAL Level: $($walLevel.Trim())"
    Write-Host "  Archive Command: $($archiveCommand.Trim())"
    Write-Host ""
    
    # Check archiver statistics
    $archiverStats = docker exec $Container psql -U $User -t -c "SELECT archived_count, failed_count, last_archived_wal, last_archived_time FROM pg_stat_archiver;" 2>$null
    Write-Info "Archiver Statistics:"
    Write-Host "$archiverStats"
    
}
elseif ($Action -eq 'backup') {
    Write-Info "Creating incremental backup (WAL segments)..."
    
    # Generate timestamp
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    
    # Create backup directory for this run
    $incrementalDir = Join-Path $BackupDir "incremental_${timestamp}"
    New-Item -ItemType Directory -Force -Path $incrementalDir | Out-Null
    
    # Force WAL segment switch to ensure current data is archived
    Write-Info "Forcing WAL segment switch..."
    docker exec $Container psql -U $User -c "SELECT pg_switch_wal();" 2>$null
    
    # Copy WAL files from container
    Write-Info "Copying WAL archive files..."
    docker cp "${Container}:/var/lib/postgresql/wal_archive/." $incrementalDir
    
    if ($LASTEXITCODE -eq 0) {
        $walCount = (Get-ChildItem -Path $incrementalDir -File).Count
        $walSize = (Get-ChildItem -Path $incrementalDir -Recurse | Measure-Object -Property Length -Sum).Sum
        
        Write-Success "Incremental backup completed"
        Write-Info "WAL files copied: $walCount"
        Write-Info "Total size: $([math]::Round($walSize/1MB, 2)) MB"
        
        # Create metadata
        $metadata = @{
            backup_type = "incremental"
            timestamp   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            wal_files   = $walCount
            size_bytes  = $walSize
            backup_path = $incrementalDir
        }
        
        $metadataFile = Join-Path $incrementalDir "metadata.json"
        $metadata | ConvertTo-Json | Out-File -FilePath $metadataFile -Encoding UTF8
        
        # Optional: Clean up archived WAL files from container
        Write-Warning "Consider cleaning up WAL archive in container after verification"
        Write-Info "To clean up: docker exec $Container rm -f /var/lib/postgresql/wal_archive/*"
    }
    else {
        Write-Error "Failed to copy WAL files"
        exit 1
    }
    
}
elseif ($Action -eq 'archive') {
    Write-Info "Archiving current WAL files..."
    
    # This is typically called by PostgreSQL's archive_command
    # For manual archiving, we'll copy current WAL files
    
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $archiveDir = Join-Path $BackupDir "archive_${timestamp}"
    New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null
    
    # Copy WAL files
    docker cp "${Container}:/var/lib/postgresql/data/pg_wal/." $archiveDir
    
    Write-Success "WAL files archived to: $archiveDir"
}

Write-Host ""
Write-Success "Incremental backup operation completed!"
