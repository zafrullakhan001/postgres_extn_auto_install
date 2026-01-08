# PostgreSQL Backup and Restore Guide

Complete guide for backing up and restoring PostgreSQL databases running in Docker containers.

## Table of Contents

1. [Overview](#overview)
2. [Backup Strategies](#backup-strategies)
3. [Full Backups](#full-backups)
4. [Incremental Backups](#incremental-backups)
5. [Point-in-Time Recovery (PITR)](#point-in-time-recovery-pitr)
6. [Restore Operations](#restore-operations)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)

## Overview

This repository includes comprehensive backup and restore scripts for PostgreSQL:

### Available Scripts

#### Windows (PowerShell)
- `windows/backup_full.ps1` - Full database backups
- `windows/backup_incremental.ps1` - Incremental backups using WAL
- `windows/restore_full.ps1` - Full database restoration
- `windows/restore_pitr.ps1` - Point-in-Time Recovery

#### Linux (Bash)
- `linux/backup_full.sh` - Full database backups
- `linux/backup_incremental.sh` - Incremental backups using WAL
- `linux/restore_full.sh` - Full database restoration
- `linux/restore_pitr.sh` - Point-in-Time Recovery

## Backup Strategies

### 1. Logical Backups (pg_dumpall)

**Pros:**
- Easy to use and understand
- Platform-independent
- Can restore to different PostgreSQL versions
- Human-readable SQL format
- Selective restore possible

**Cons:**
- Slower for large databases
- Requires more storage space
- Cannot do point-in-time recovery alone

**Use Cases:**
- Small to medium databases
- Cross-platform migrations
- Version upgrades
- Development/testing environments

### 2. Physical Backups (pg_basebackup)

**Pros:**
- Faster for large databases
- Smaller backup size (with compression)
- Enables point-in-time recovery
- Binary format

**Cons:**
- Platform-specific
- Requires same PostgreSQL version
- More complex setup
- All-or-nothing restore

**Use Cases:**
- Large production databases
- High-availability setups
- Disaster recovery
- When PITR is required

### 3. Incremental Backups (WAL Archiving)

**Pros:**
- Minimal storage for changes
- Enables point-in-time recovery
- Continuous protection
- Low performance impact

**Cons:**
- Requires initial base backup
- More complex setup
- Requires WAL management
- Storage accumulates over time

**Use Cases:**
- Production environments
- Compliance requirements
- When minimal data loss is critical
- 24/7 operations

## Full Backups

### Logical Backup (Recommended for Most Users)

#### Windows
```powershell
# Basic usage
.\windows\backup_full.ps1 -BackupType logical

# With custom parameters
.\windows\backup_full.ps1 -BackupType logical -Container PG-timescale -BackupDir .\backups

# Set retention period
.\windows\backup_full.ps1 -BackupType logical -RetentionDays 60
```

#### Linux
```bash
# Make script executable
chmod +x linux/backup_full.sh

# Basic usage
./linux/backup_full.sh logical

# With custom parameters
./linux/backup_full.sh logical PG-timescale ./backups
```

### Physical Backup (For Large Databases)

#### Windows
```powershell
# Requires WAL archiving configured
.\windows\backup_full.ps1 -BackupType physical
```

#### Linux
```bash
./linux/backup_full.sh physical PG-timescale ./backups
```

### Automated Backups

#### Windows (Task Scheduler)
```powershell
# Create scheduled task for daily backups at 2 AM
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-File "C:\xampp\htdocs\postgres\windows\backup_full.ps1" -BackupType logical'
$trigger = New-ScheduledTaskTrigger -Daily -At 2am
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "PostgreSQL Daily Backup" -Description "Daily PostgreSQL backup"
```

#### Linux (Cron)
```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /path/to/postgres/linux/backup_full.sh logical >> /var/log/pg_backup.log 2>&1
```

## Incremental Backups

Incremental backups use PostgreSQL's Write-Ahead Logging (WAL) to capture all changes.

### Setup WAL Archiving

#### Windows
```powershell
# Step 1: Setup WAL archiving
.\windows\backup_incremental.ps1 -Action setup

# Step 2: Follow the displayed instructions to configure PostgreSQL

# Step 3: Check status
.\windows\backup_incremental.ps1 -Action status
```

#### Linux
```bash
# Step 1: Setup WAL archiving
./linux/backup_incremental.sh setup

# Step 2: Configure PostgreSQL as instructed

# Step 3: Check status
./linux/backup_incremental.sh status
```

### PostgreSQL Configuration

Edit `postgresql.conf` in the container:

```bash
docker exec -it PG-timescale bash
vi /var/lib/postgresql/data/postgresql.conf
```

Add these settings:

```conf
# WAL Configuration for Incremental Backups
wal_level = replica
archive_mode = on
archive_command = 'cp %p /var/lib/postgresql/wal_archive/%f'
max_wal_senders = 3
wal_keep_size = 1GB
```

Restart PostgreSQL:

```bash
docker restart PG-timescale
```

### Performing Incremental Backups

#### Windows
```powershell
# Create incremental backup
.\windows\backup_incremental.ps1 -Action backup

# Schedule hourly incremental backups
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-File "C:\xampp\htdocs\postgres\windows\backup_incremental.ps1" -Action backup'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "PostgreSQL Incremental Backup"
```

#### Linux
```bash
# Create incremental backup
./linux/backup_incremental.sh backup

# Schedule hourly backups (cron)
0 * * * * /path/to/postgres/linux/backup_incremental.sh backup >> /var/log/pg_incremental.log 2>&1
```

## Point-in-Time Recovery (PITR)

PITR allows you to restore your database to any point in time, down to the second.

### Prerequisites

1. A base backup (physical backup)
2. WAL archive files covering the desired time period
3. Knowledge of the target recovery time

### Performing PITR

#### Windows
```powershell
# Restore to specific time
.\windows\restore_pitr.ps1 `
    -BaseBackup ".\backups\basebackup_20260108_120000" `
    -WALArchive ".\backups\wal" `
    -RecoveryTarget "2026-01-08 14:30:00"

# Restore to latest available point
.\windows\restore_pitr.ps1 `
    -BaseBackup ".\backups\basebackup_20260108_120000" `
    -WALArchive ".\backups\wal"
```

#### Linux
```bash
# Restore to specific time
./linux/restore_pitr.sh \
    ./backups/basebackup_20260108_120000 \
    ./backups/wal \
    "2026-01-08 14:30:00"

# Restore to latest available point
./linux/restore_pitr.sh \
    ./backups/basebackup_20260108_120000 \
    ./backups/wal
```

### Recovery Target Options

You can specify different recovery targets:

```powershell
# Time-based recovery
-RecoveryTarget "2026-01-08 14:30:00" -RecoveryTargetType time

# Transaction ID recovery
-RecoveryTarget "12345" -RecoveryTargetType xid

# Named restore point
-RecoveryTarget "before_migration" -RecoveryTargetType name

# LSN-based recovery
-RecoveryTarget "0/3000000" -RecoveryTargetType lsn
```

## Restore Operations

### Full Restore from Logical Backup

#### Windows
```powershell
# Basic restore
.\windows\restore_full.ps1 -BackupFile ".\backups\full_backup_20260108_102817.sql" -RestoreType logical

# Force restore without confirmation
.\windows\restore_full.ps1 -BackupFile ".\backups\full_backup_20260108_102817.sql" -RestoreType logical -Force
```

#### Linux
```bash
# Basic restore
./linux/restore_full.sh ./backups/full_backup_20260108_102817.sql logical

# Specify container
./linux/restore_full.sh ./backups/full_backup_20260108_102817.sql logical PG-timescale
```

### Full Restore from Physical Backup

#### Windows
```powershell
.\windows\restore_full.ps1 -BackupFile ".\backups\basebackup_20260108_120000" -RestoreType physical
```

#### Linux
```bash
./linux/restore_full.sh ./backups/basebackup_20260108_120000 physical
```

## Best Practices

### 1. Backup Strategy

**3-2-1 Rule:**
- Keep **3** copies of your data
- Store backups on **2** different media types
- Keep **1** copy offsite

**Recommended Schedule:**
- **Full backup:** Daily (logical) or weekly (physical)
- **Incremental backup:** Hourly or continuous (WAL archiving)
- **Retention:** 30 days minimum, 90 days recommended

### 2. Testing Backups

```powershell
# Regular restore testing (monthly recommended)
# 1. Create test container
docker run -d --name PG-test -e POSTGRES_PASSWORD=password -p 5434:5432 timescale/timescaledb:latest-pg18

# 2. Restore to test container
.\windows\restore_full.ps1 -BackupFile ".\backups\full_backup_YYYYMMDD_HHMMSS.sql" -Container PG-test

# 3. Verify data
docker exec PG-test psql -U postgres -c "\dt"

# 4. Cleanup
docker stop PG-test && docker rm PG-test
```

### 3. Monitoring

```powershell
# Check backup status
Get-ChildItem .\backups\*.sql | Select-Object Name, Length, LastWriteTime | Sort-Object LastWriteTime -Descending

# Verify WAL archiving
.\windows\backup_incremental.ps1 -Action status

# Check disk space
Get-PSDrive C | Select-Object Used, Free
```

### 4. Security

```powershell
# Encrypt backups (Windows)
# Using 7-Zip
7z a -p -mhe=on backup_encrypted.7z .\backups\full_backup_20260108_102817.sql

# Using GPG
gpg --symmetric --cipher-algo AES256 .\backups\full_backup_20260108_102817.sql
```

```bash
# Encrypt backups (Linux)
# Using GPG
gpg --symmetric --cipher-algo AES256 ./backups/full_backup_20260108_102817.sql

# Using OpenSSL
openssl enc -aes-256-cbc -salt -in backup.sql -out backup.sql.enc
```

### 5. Offsite Backups

```powershell
# Upload to cloud storage (example with AWS S3)
aws s3 cp .\backups\full_backup_20260108_102817.sql s3://my-bucket/postgres-backups/

# Upload to Azure Blob Storage
az storage blob upload --account-name mystorageaccount --container-name backups --file .\backups\full_backup_20260108_102817.sql
```

## Backup Comparison

| Feature | Logical | Physical | Incremental |
|---------|---------|----------|-------------|
| Speed (Backup) | Slow | Fast | Very Fast |
| Speed (Restore) | Slow | Fast | Medium |
| Size | Large | Medium | Small |
| PITR Support | No | Yes | Yes |
| Cross-Version | Yes | No | No |
| Selective Restore | Yes | No | No |
| Complexity | Low | Medium | High |
| Best For | Dev/Test | Production | 24/7 Systems |

## Troubleshooting

### Backup Issues

#### "Container not running"
```bash
# Check container status
docker ps -a --filter "name=PG-timescale"

# Start container
docker start PG-timescale
```

#### "Permission denied"
```bash
# Windows: Run PowerShell as Administrator
# Linux: Check file permissions
chmod +x linux/*.sh
```

#### "Disk space full"
```bash
# Check disk space
df -h  # Linux
Get-PSDrive  # Windows

# Clean old backups
find ./backups -type f -mtime +30 -delete  # Linux
Get-ChildItem .\backups -File | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-30)} | Remove-Item  # Windows
```

### Restore Issues

#### "Restore fails with errors"
```bash
# Check PostgreSQL logs
docker logs PG-timescale

# Verify backup integrity
head -n 100 ./backups/full_backup_20260108_102817.sql
tail -n 100 ./backups/full_backup_20260108_102817.sql
```

#### "Database already exists"
```bash
# Drop existing database first (careful!)
docker exec PG-timescale psql -U postgres -c "DROP DATABASE IF EXISTS mydb;"

# Or use --clean option in restore
```

### PITR Issues

#### "WAL files not found"
```bash
# Check WAL archive
ls -la ./backups/wal/

# Verify archive_command is working
docker exec PG-timescale psql -U postgres -c "SELECT * FROM pg_stat_archiver;"
```

#### "Recovery target not reached"
```bash
# Check available WAL range
# Ensure WAL files cover the target time
# Adjust recovery target to available range
```

## Recovery Time Objectives (RTO)

Estimated recovery times for a 10GB database:

| Backup Type | Recovery Time | Data Loss (RPO) |
|-------------|---------------|-----------------|
| Logical Backup | 30-60 minutes | Last backup |
| Physical Backup | 10-20 minutes | Last backup |
| PITR | 15-30 minutes | Seconds |

## Storage Requirements

Example for a 10GB database:

| Backup Type | Storage per Backup | Monthly Storage |
|-------------|-------------------|-----------------|
| Logical (Daily) | ~12GB | ~360GB |
| Physical (Weekly) | ~8GB | ~32GB |
| Incremental (Hourly) | ~100MB | ~72GB |

**Recommended:** Combine weekly physical + hourly incremental = ~104GB/month

## Additional Resources

- [PostgreSQL Backup Documentation](https://www.postgresql.org/docs/current/backup.html)
- [pg_dump Documentation](https://www.postgresql.org/docs/current/app-pgdump.html)
- [pg_basebackup Documentation](https://www.postgresql.org/docs/current/app-pgbasebackup.html)
- [WAL Archiving](https://www.postgresql.org/docs/current/continuous-archiving.html)
- [Point-in-Time Recovery](https://www.postgresql.org/docs/current/continuous-archiving.html#BACKUP-PITR-RECOVERY)

## Support

For issues or questions:
- Check the [Troubleshooting](#troubleshooting) section
- Review PostgreSQL logs: `docker logs PG-timescale`
- Consult PostgreSQL documentation
- Open an issue in the repository

---

**Last Updated:** 2026-01-08
**PostgreSQL Version:** 18.1
**TimescaleDB Version:** 2.24.0
