# PostgreSQL 17 to 18 Upgrade Guide for PG-timescale Container

This guide will help you upgrade your TimescaleDB container from PostgreSQL 17 to PostgreSQL 18.

## Current Configuration
- **Container Name**: PG-timescale
- **Current Image**: timescale/timescaledb:latest-pg17
- **Current PostgreSQL Version**: 17.7
- **Port Mapping**: 5433:5432
- **User**: postgres
- **Password**: password
- **Data Volume**: cd3b2c136b992e36eb6dd14446c7b80d45d9482ee1ab6fb127ad56b0a1ed6bf9

## Prerequisites
- Docker installed and running
- Sufficient disk space for backup
- No active connections to the database during upgrade

## Upgrade Steps

### Step 1: Backup Your Current Database

Create a full backup of all databases:

```powershell
# Create a backup directory
New-Item -ItemType Directory -Force -Path ".\backups"

# Backup all databases
docker exec PG-timescale pg_dumpall -U postgres > ".\backups\pg17_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').sql"
```

### Step 2: Backup Individual Databases (Optional but Recommended)

List all databases and backup individually:

```powershell
# List all databases
docker exec PG-timescale psql -U postgres -c "\l"

# Backup specific database (replace 'your_database' with actual database name)
docker exec PG-timescale pg_dump -U postgres -Fc your_database > ".\backups\your_database_$(Get-Date -Format 'yyyyMMdd_HHmmss').dump"
```

### Step 3: Export Container Configuration

```powershell
# Export current container configuration for reference
docker inspect PG-timescale > ".\backups\container_config_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
```

### Step 4: Stop and Remove the Old Container

```powershell
# Stop the container
docker stop PG-timescale

# Remove the container (data volume will be preserved)
docker rm PG-timescale
```

### Step 5: Pull the PostgreSQL 18 Image

```powershell
# Pull the latest TimescaleDB image with PostgreSQL 18
docker pull timescale/timescaledb:latest-pg18
```

### Step 6: Create New Container with PostgreSQL 18

**Option A: Using the Same Volume (Requires pg_upgrade)**

⚠️ **WARNING**: This approach requires running `pg_upgrade` inside the container, which is more complex. We recommend Option B instead.

**Option B: Create New Container with Fresh Volume (Recommended)**

```powershell
# Create a new container with PostgreSQL 18
docker run -d `
  --name PG-timescale `
  -e POSTGRES_PASSWORD=password `
  -p 5433:5432 `
  timescale/timescaledb:latest-pg18
```

### Step 7: Verify New Container is Running

```powershell
# Check container status
docker ps -a --filter "name=PG-timescale"

# Verify PostgreSQL version
docker exec PG-timescale psql -U postgres -c "SELECT version();"
```

### Step 8: Restore Your Data

```powershell
# Wait for PostgreSQL to be ready
Start-Sleep -Seconds 10

# Restore from the backup (replace with your actual backup filename)
Get-Content ".\backups\pg17_backup_YYYYMMDD_HHMMSS.sql" | docker exec -i PG-timescale psql -U postgres
```

### Step 9: Verify Data Restoration

```powershell
# List all databases
docker exec PG-timescale psql -U postgres -c "\l"

# Connect and verify your data
docker exec -it PG-timescale psql -U postgres -d your_database
```

### Step 10: Update TimescaleDB Extension (if applicable)

If you're using TimescaleDB features:

```powershell
docker exec PG-timescale psql -U postgres -d your_database -c "ALTER EXTENSION timescaledb UPDATE;"
```

### Step 11: Clean Up Old Volume (Optional)

After verifying everything works:

```powershell
# List volumes
docker volume ls

# Remove old volume (replace with actual volume name)
docker volume rm cd3b2c136b992e36eb6dd14446c7b80d45d9482ee1ab6fb127ad56b0a1ed6bf9
```

## Alternative: In-Place Upgrade Using pg_upgrade

If you want to preserve the exact same volume and perform an in-place upgrade:

### Step 1: Create a Temporary PG18 Container

```powershell
docker run -d --name PG-timescale-pg18-temp `
  -e POSTGRES_PASSWORD=password `
  timescale/timescaledb:latest-pg18

# Initialize and stop it
Start-Sleep -Seconds 10
docker stop PG-timescale-pg18-temp
```

### Step 2: Use pg_upgrade

This is a more advanced process that requires:
1. Mounting both old and new data directories
2. Running pg_upgrade utility
3. Careful handling of TimescaleDB extensions

**Note**: This approach is complex and error-prone. We strongly recommend the backup/restore method above.

## Rollback Plan

If something goes wrong:

```powershell
# Stop the new container
docker stop PG-timescale
docker rm PG-timescale

# Recreate the old container with the old image
docker run -d `
  --name PG-timescale `
  -e POSTGRES_PASSWORD=password `
  -p 5433:5432 `
  -v cd3b2c136b992e36eb6dd14446c7b80d45d9482ee1ab6fb127ad56b0a1ed6bf9:/var/lib/postgresql/data `
  timescale/timescaledb:latest-pg17
```

## Post-Upgrade Checklist

- [ ] Verify PostgreSQL version is 18.x
- [ ] All databases are present
- [ ] All tables and data are intact
- [ ] All extensions are updated
- [ ] Application connections work correctly
- [ ] Performance is acceptable
- [ ] Backup files are safely stored

## Troubleshooting

### Issue: Container won't start
- Check logs: `docker logs PG-timescale`
- Verify port 5433 is not in use: `netstat -an | findstr 5433`

### Issue: Data restore fails
- Check backup file integrity
- Verify PostgreSQL is fully started before restore
- Check disk space

### Issue: Extension compatibility
- Update all extensions after restore
- Check TimescaleDB compatibility with PG18

## Additional Resources

- [TimescaleDB Documentation](https://docs.timescale.com/)
- [PostgreSQL 18 Release Notes](https://www.postgresql.org/docs/18/release-18.html)
- [pg_upgrade Documentation](https://www.postgresql.org/docs/current/pgupgrade.html)
