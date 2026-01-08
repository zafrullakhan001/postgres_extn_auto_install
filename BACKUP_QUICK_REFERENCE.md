# PostgreSQL Backup & Restore - Quick Reference

## 🚀 Quick Start

### Full Backup (Recommended)
```powershell
# Windows
.\windows\backup_full.ps1 -BackupType logical

# Linux
./linux/backup_full.sh logical
```

### Full Restore
```powershell
# Windows
.\windows\restore_full.ps1 -BackupFile ".\backups\full_backup_YYYYMMDD_HHMMSS.sql"

# Linux
./linux/restore_full.sh ./backups/full_backup_YYYYMMDD_HHMMSS.sql logical
```

---

## 📋 Command Reference

### Windows (PowerShell)

#### Backups
```powershell
# Full logical backup
.\windows\backup_full.ps1 -BackupType logical

# Full physical backup
.\windows\backup_full.ps1 -BackupType physical

# Setup incremental backups
.\windows\backup_incremental.ps1 -Action setup

# Create incremental backup
.\windows\backup_incremental.ps1 -Action backup

# Check WAL status
.\windows\backup_incremental.ps1 -Action status
```

#### Restores
```powershell
# Restore from logical backup
.\windows\restore_full.ps1 -BackupFile ".\backups\full_backup_20260108_102817.sql" -RestoreType logical

# Restore from physical backup
.\windows\restore_full.ps1 -BackupFile ".\backups\basebackup_20260108_120000" -RestoreType physical

# Point-in-Time Recovery
.\windows\restore_pitr.ps1 -BaseBackup ".\backups\basebackup_20260108_120000" -WALArchive ".\backups\wal" -RecoveryTarget "2026-01-08 14:30:00"
```

### Linux (Bash)

#### Backups
```bash
# Make scripts executable (first time only)
chmod +x linux/*.sh

# Full logical backup
./linux/backup_full.sh logical

# Full physical backup
./linux/backup_full.sh physical

# Setup incremental backups
./linux/backup_incremental.sh setup

# Create incremental backup
./linux/backup_incremental.sh backup

# Check WAL status
./linux/backup_incremental.sh status
```

#### Restores
```bash
# Restore from logical backup
./linux/restore_full.sh ./backups/full_backup_20260108_102817.sql logical

# Restore from physical backup
./linux/restore_full.sh ./backups/basebackup_20260108_120000 physical

# Point-in-Time Recovery
./linux/restore_pitr.sh ./backups/basebackup_20260108_120000 ./backups/wal "2026-01-08 14:30:00"
```

---

## 🔍 Verification Commands

```bash
# Check container status
docker ps --filter "name=PG-timescale"

# List databases
docker exec PG-timescale psql -U postgres -c "\l"

# List tables
docker exec PG-timescale psql -U postgres -c "\dt"

# Check PostgreSQL version
docker exec PG-timescale psql -U postgres -c "SELECT version();"

# Check backup files
ls -lh backups/  # Linux
Get-ChildItem .\backups\ | Format-Table Name, Length, LastWriteTime  # Windows
```

---

## ⚙️ PostgreSQL Configuration for WAL Archiving

Edit `postgresql.conf`:
```bash
docker exec -it PG-timescale bash
vi /var/lib/postgresql/data/postgresql.conf
```

Add these lines:
```conf
wal_level = replica
archive_mode = on
archive_command = 'cp %p /var/lib/postgresql/wal_archive/%f'
max_wal_senders = 3
wal_keep_size = 1GB
```

Restart:
```bash
docker restart PG-timescale
```

---

## 📅 Recommended Backup Schedule

| Backup Type | Frequency | Retention | Script |
|-------------|-----------|-----------|--------|
| Full Logical | Daily 2 AM | 30 days | `backup_full.ps1 -BackupType logical` |
| Incremental | Hourly | 7 days | `backup_incremental.ps1 -Action backup` |
| Physical | Weekly | 4 weeks | `backup_full.ps1 -BackupType physical` |

---

## 🔧 Automated Scheduling

### Windows Task Scheduler
```powershell
# Daily full backup at 2 AM
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-File "C:\xampp\htdocs\postgres\windows\backup_full.ps1" -BackupType logical'
$trigger = New-ScheduledTaskTrigger -Daily -At 2am
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "PostgreSQL Daily Backup"

# Hourly incremental backup
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-File "C:\xampp\htdocs\postgres\windows\backup_incremental.ps1" -Action backup'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "PostgreSQL Incremental Backup"
```

### Linux Cron
```bash
# Edit crontab
crontab -e

# Add these lines:
# Daily full backup at 2 AM
0 2 * * * /path/to/postgres/linux/backup_full.sh logical >> /var/log/pg_backup.log 2>&1

# Hourly incremental backup
0 * * * * /path/to/postgres/linux/backup_incremental.sh backup >> /var/log/pg_incremental.log 2>&1
```

---

## 🚨 Emergency Recovery

### Quick Restore (Last Backup)
```powershell
# Windows - Find latest backup
$latest = Get-ChildItem .\backups\*.sql | Sort-Object LastWriteTime -Descending | Select-Object -First 1
.\windows\restore_full.ps1 -BackupFile $latest.FullName -Force

# Linux - Find latest backup
latest=$(ls -t backups/*.sql | head -1)
./linux/restore_full.sh "$latest" logical
```

### Disaster Recovery Checklist
- [ ] Stop application connections
- [ ] Identify last known good backup
- [ ] Verify backup file integrity
- [ ] Create safety backup of current state
- [ ] Perform restore
- [ ] Verify data integrity
- [ ] Test application functionality
- [ ] Resume operations

---

## 📊 Backup Comparison

| Type | Speed | Size | PITR | Cross-Version | Use Case |
|------|-------|------|------|---------------|----------|
| **Logical** | ⭐⭐ | ⭐ | ❌ | ✅ | Dev/Test, Migrations |
| **Physical** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ✅ | ❌ | Production, Large DBs |
| **Incremental** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ✅ | ❌ | 24/7 Systems |

---

## 🛠️ Troubleshooting

### Container Not Running
```bash
docker start PG-timescale
```

### Check Logs
```bash
docker logs PG-timescale
docker logs --tail 100 PG-timescale
```

### Disk Space
```bash
# Linux
df -h

# Windows
Get-PSDrive C
```

### Clean Old Backups
```bash
# Linux - Remove backups older than 30 days
find ./backups -type f -mtime +30 -delete

# Windows - Remove backups older than 30 days
Get-ChildItem .\backups -File | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-30)} | Remove-Item
```

### Test Backup Integrity
```bash
# Check if SQL file is valid
head -n 10 backups/full_backup_20260108_102817.sql
tail -n 10 backups/full_backup_20260108_102817.sql

# Check file size
ls -lh backups/full_backup_20260108_102817.sql  # Linux
Get-Item .\backups\full_backup_20260108_102817.sql | Select-Object Length  # Windows
```

---

## 📞 Support

- **Documentation:** See `BACKUP_RESTORE_GUIDE.md` for detailed information
- **PostgreSQL Docs:** https://www.postgresql.org/docs/current/backup.html
- **Container Logs:** `docker logs PG-timescale`

---

## 🔐 Security Best Practices

1. **Encrypt backups** before storing offsite
2. **Restrict access** to backup files (chmod 600)
3. **Test restores** regularly (monthly minimum)
4. **Store offsite** copies in different location
5. **Monitor** backup success/failure
6. **Document** recovery procedures

---

**Container:** PG-timescale  
**Port:** 5433:5432  
**User:** postgres  
**Password:** password  

**Last Updated:** 2026-01-08
