#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Full PostgreSQL database backup script for Docker container
.DESCRIPTION
    Creates a full backup of PostgreSQL databases using pg_dumpall or pg_basebackup
.PARAMETER BackupType
    Type of backup: 'logical' (pg_dumpall) or 'physical' (pg_basebackup)
.PARAMETER Container
    Docker container name (default: PG-timescale)
.PARAMETER BackupDir
    Backup directory path (default: .\backups)
.EXAMPLE
    .\backup_full.ps1 -BackupType logical
    .\backup_full.ps1 -BackupType physical -Container PG-timescale
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('logical', 'physical')]
    [string]$BackupType = 'logical',
    
    [Parameter(Mandatory = $false)]
    [string]$Container = 'PG-timescale',
    
    [Parameter(Mandatory = $false)]
    [string]$BackupDir = '.\backups',
    
    [Parameter(Mandatory = $false)]
    [string]$User = 'postgres',
    
    [Parameter(Mandatory = $false)]
    [int]$RetentionDays = 30
)

# Color output functions
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }

# Script start
Write-Info "PostgreSQL Full Backup Script"
Write-Info "=============================="
Write-Info "Backup Type: $BackupType"
Write-Info "Container: $Container"
Write-Info "Backup Directory: $BackupDir"
Write-Host ""

# Check if container is running
$containerStatus = docker ps --filter "name=$Container" --format "{{.Status}}" 2>$null
if (-not $containerStatus) {
    Write-Error "Container '$Container' is not running!"
    exit 1
}
Write-Success "Container '$Container' is running"

# Create backup directory
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
    Write-Success "Created backup directory: $BackupDir"
}

# Generate timestamp
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

# Create backup metadata
$metadata = @{
    backup_type      = $BackupType
    timestamp        = $date
    container        = $Container
    postgres_version = ""
    backup_size      = 0
    status           = "in_progress"
}

if ($BackupType -eq 'logical') {
    Write-Info "Starting logical backup (pg_dumpall)..."
    
    # Get PostgreSQL version
    $pgVersion = docker exec $Container psql -U $User -t -c "SELECT version();" 2>$null
    $metadata.postgres_version = $pgVersion.Trim()
    
    # Backup file path
    $backupFile = Join-Path $BackupDir "full_backup_${timestamp}.sql"
    $metadataFile = Join-Path $BackupDir "full_backup_${timestamp}.json"
    
    Write-Info "Backup file: $backupFile"
    
    # Perform backup
    try {
        docker exec $Container pg_dumpall -U $User > $backupFile 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $backupSize = (Get-Item $backupFile).Length
            $metadata.backup_size = $backupSize
            $metadata.status = "completed"
            
            Write-Success "Logical backup completed successfully"
            Write-Info "Backup size: $([math]::Round($backupSize/1MB, 2)) MB"
        }
        else {
            $metadata.status = "failed"
            Write-Error "Backup failed with exit code: $LASTEXITCODE"
        }
    }
    catch {
        $metadata.status = "failed"
        Write-Error "Backup failed: $_"
    }
    
    # Save metadata
    $metadata | ConvertTo-Json | Out-File -FilePath $metadataFile -Encoding UTF8
    Write-Success "Metadata saved: $metadataFile"
    
}
elseif ($BackupType -eq 'physical') {
    Write-Info "Starting physical backup (pg_basebackup)..."
    
    # Get PostgreSQL version
    $pgVersion = docker exec $Container psql -U $User -t -c "SELECT version();" 2>$null
    $metadata.postgres_version = $pgVersion.Trim()
    
    # Backup directory path
    $backupPath = Join-Path $BackupDir "basebackup_${timestamp}"
    $metadataFile = Join-Path $BackupDir "basebackup_${timestamp}.json"
    
    Write-Info "Backup path: $backupPath"
    
    # Create backup directory
    New-Item -ItemType Directory -Force -Path $backupPath | Out-Null
    
    # Perform base backup
    try {
        # Note: This requires proper PostgreSQL configuration for replication
        docker exec $Container pg_basebackup -U $User -D "/tmp/basebackup_${timestamp}" -Ft -z -P 2>&1
        
        # Copy from container to host
        docker cp "${Container}:/tmp/basebackup_${timestamp}" $backupPath
        
        # Clean up container
        docker exec $Container rm -rf "/tmp/basebackup_${timestamp}"
        
        if ($LASTEXITCODE -eq 0) {
            $backupSize = (Get-ChildItem -Path $backupPath -Recurse | Measure-Object -Property Length -Sum).Sum
            $metadata.backup_size = $backupSize
            $metadata.status = "completed"
            
            Write-Success "Physical backup completed successfully"
            Write-Info "Backup size: $([math]::Round($backupSize/1MB, 2)) MB"
        }
        else {
            $metadata.status = "failed"
            Write-Error "Backup failed with exit code: $LASTEXITCODE"
        }
    }
    catch {
        $metadata.status = "failed"
        Write-Error "Backup failed: $_"
        Write-Warning "Note: Physical backups require WAL archiving to be configured"
    }
    
    # Save metadata
    $metadata | ConvertTo-Json | Out-File -FilePath $metadataFile -Encoding UTF8
    Write-Success "Metadata saved: $metadataFile"
}

# Cleanup old backups
Write-Info "Cleaning up backups older than $RetentionDays days..."
$cutoffDate = (Get-Date).AddDays(-$RetentionDays)
$oldBackups = Get-ChildItem -Path $BackupDir -File | Where-Object { $_.LastWriteTime -lt $cutoffDate }

if ($oldBackups) {
    foreach ($file in $oldBackups) {
        Remove-Item $file.FullName -Force
        Write-Info "Removed old backup: $($file.Name)"
    }
    Write-Success "Cleanup completed: $($oldBackups.Count) old backup(s) removed"
}
else {
    Write-Info "No old backups to remove"
}

# Summary
Write-Host ""
Write-Info "Backup Summary"
Write-Info "=============="
Write-Info "Status: $($metadata.status)"
Write-Info "Backup Type: $BackupType"
Write-Info "Timestamp: $($metadata.timestamp)"
Write-Info "Size: $([math]::Round($metadata.backup_size/1MB, 2)) MB"
Write-Host ""

if ($metadata.status -eq "completed") {
    Write-Success "Full backup completed successfully!"
    exit 0
}
else {
    Write-Error "Backup failed!"
    exit 1
}
