#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Full restore of PostgreSQL database from backup
.DESCRIPTION
    Restores PostgreSQL databases from logical (SQL) or physical (basebackup) backups
.PARAMETER BackupFile
    Path to backup file or directory
.PARAMETER Container
    Docker container name (default: PG-timescale)
.PARAMETER RestoreType
    Type of restore: 'logical' or 'physical'
.EXAMPLE
    .\restore_full.ps1 -BackupFile .\backups\full_backup_20260108_102817.sql -RestoreType logical
    .\restore_full.ps1 -BackupFile .\backups\basebackup_20260108_120000 -RestoreType physical
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$BackupFile,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('logical', 'physical')]
    [string]$RestoreType = 'logical',
    
    [Parameter(Mandatory = $false)]
    [string]$Container = 'PG-timescale',
    
    [Parameter(Mandatory = $false)]
    [string]$User = 'postgres',
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Color output functions
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }

Write-Info "PostgreSQL Full Restore Script"
Write-Info "==============================="
Write-Info "Restore Type: $RestoreType"
Write-Info "Backup Source: $BackupFile"
Write-Info "Container: $Container"
Write-Host ""

# Check if backup file/directory exists
if (-not (Test-Path $BackupFile)) {
    Write-Error "Backup file/directory not found: $BackupFile"
    exit 1
}
Write-Success "Backup source found"

# Check if container is running
$containerStatus = docker ps --filter "name=$Container" --format "{{.Status}}" 2>$null
if (-not $containerStatus) {
    Write-Error "Container '$Container' is not running!"
    Write-Info "Start the container first: docker start $Container"
    exit 1
}
Write-Success "Container '$Container' is running"

# Warning prompt
if (-not $Force) {
    Write-Warning "This will REPLACE all data in the database!"
    Write-Host "Press Ctrl+C to cancel, or press Enter to continue..." -ForegroundColor Yellow
    Read-Host
}

if ($RestoreType -eq 'logical') {
    Write-Info "Starting logical restore from SQL backup..."
    
    # Check if file is SQL
    if (-not $BackupFile.EndsWith('.sql')) {
        Write-Warning "Backup file doesn't have .sql extension"
    }
    
    # Get file size
    $fileSize = (Get-Item $BackupFile).Length
    Write-Info "Backup file size: $([math]::Round($fileSize/1MB, 2)) MB"
    
    # Wait for PostgreSQL to be ready
    Write-Info "Waiting for PostgreSQL to be ready..."
    Start-Sleep -Seconds 5
    
    # Perform restore
    Write-Info "Restoring database (this may take several minutes)..."
    try {
        Get-Content $BackupFile | docker exec -i $Container psql -U $User 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Logical restore completed successfully!"
            
            # Verify databases
            Write-Info "Verifying restored databases..."
            $databases = docker exec $Container psql -U $User -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;"
            Write-Host ""
            Write-Info "Restored Databases:"
            Write-Host $databases
            
            # Verify tables in postgres database
            Write-Info "Verifying tables in 'postgres' database..."
            $tables = docker exec $Container psql -U $User -c "\dt"
            Write-Host $tables
            
        }
        else {
            Write-Error "Restore failed with exit code: $LASTEXITCODE"
            exit 1
        }
    }
    catch {
        Write-Error "Restore failed: $_"
        exit 1
    }
    
}
elseif ($RestoreType -eq 'physical') {
    Write-Info "Starting physical restore from base backup..."
    
    # Check if directory exists
    if (-not (Test-Path $BackupFile -PathType Container)) {
        Write-Error "Backup directory not found: $BackupFile"
        exit 1
    }
    
    Write-Warning "Physical restore requires stopping the container and replacing data directory"
    Write-Warning "This is an advanced operation. Consider using logical restore instead."
    
    # Stop container
    Write-Info "Stopping container..."
    docker stop $Container | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to stop container"
        exit 1
    }
    Write-Success "Container stopped"
    
    # Get container's data volume
    $volumeInfo = docker inspect $Container --format='{{json .Mounts}}' | ConvertFrom-Json
    $dataVolume = $volumeInfo | Where-Object { $_.Destination -eq '/var/lib/postgresql/data' } | Select-Object -First 1
    
    if ($dataVolume) {
        Write-Info "Data volume: $($dataVolume.Name)"
        
        # Backup current data (safety measure)
        $backupTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        Write-Info "Creating safety backup of current data..."
        docker run --rm -v "$($dataVolume.Name):/source" -v "${PWD}/backups:/backup" alpine tar czf "/backup/data_backup_${backupTimestamp}.tar.gz" -C /source .
        Write-Success "Safety backup created: backups/data_backup_${backupTimestamp}.tar.gz"
        
        # Clear current data
        Write-Info "Clearing current data directory..."
        docker run --rm -v "$($dataVolume.Name):/data" alpine sh -c "rm -rf /data/*"
        
        # Restore from backup
        Write-Info "Restoring data from backup..."
        docker run --rm -v "$($dataVolume.Name):/target" -v "${BackupFile}:/backup" alpine sh -c "cp -a /backup/* /target/"
        
        Write-Success "Data restored"
    }
    else {
        Write-Warning "No data volume found, attempting direct restore..."
    }
    
    # Start container
    Write-Info "Starting container..."
    docker start $Container | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Container started"
        
        # Wait for PostgreSQL to be ready
        Write-Info "Waiting for PostgreSQL to start..."
        Start-Sleep -Seconds 10
        
        # Verify
        $version = docker exec $Container psql -U $User -t -c "SELECT version();" 2>$null
        if ($version) {
            Write-Success "Physical restore completed successfully!"
            Write-Info "PostgreSQL version: $($version.Trim())"
        }
        else {
            Write-Error "PostgreSQL may not have started correctly"
            Write-Info "Check logs: docker logs $Container"
        }
    }
    else {
        Write-Error "Failed to start container"
        exit 1
    }
}

Write-Host ""
Write-Success "Restore operation completed!"
Write-Info "Please verify your data and test your applications"
