# PostgreSQL Performance & Maintenance Guide

Complete guide for PostgreSQL performance analysis, tuning, health monitoring, and storage management.

## Table of Contents

1. [Overview](#overview)
2. [Available Scripts](#available-scripts)
3. [Performance Analysis](#performance-analysis)
4. [Health Checks](#health-checks)
5. [Tuning Recommendations](#tuning-recommendations)
6. [Storage Analysis](#storage-analysis)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)
9. [Automation & Scheduling](#automation--scheduling)

---

## Overview

This collection provides comprehensive tools for monitoring, analyzing, and optimizing PostgreSQL database performance. All scripts are available for both Windows (PowerShell) and Linux (Bash) environments.

### Key Features

- **Performance Analysis**: Detailed metrics on queries, cache, connections, and more
- **Health Monitoring**: 15-point health check with scoring system
- **Intelligent Tuning**: Workload-based configuration recommendations
- **Storage Management**: Size analysis, bloat detection, and cleanup suggestions
- **Cross-Platform**: Identical functionality on Windows and Linux
- **Docker Support**: Designed for containerized PostgreSQL deployments

---

## Available Scripts

### Windows (PowerShell)

| Script | Purpose | Location |
|--------|---------|----------|
| `performance_analysis.ps1` | Analyze database performance metrics | `windows/` |
| `health_check.ps1` | Comprehensive health assessment | `windows/` |
| `tuning_recommendations.ps1` | Generate tuning configurations | `windows/` |
| `storage_analysis.ps1` | Analyze storage usage and bloat | `windows/` |

### Linux (Bash)

| Script | Purpose | Location |
|--------|---------|----------|
| `performance_analysis.sh` | Analyze database performance metrics | `linux/` |
| `health_check.sh` | Comprehensive health assessment | `linux/` |
| `tuning_recommendations.sh` | Generate tuning configurations | `linux/` |
| `storage_analysis.sh` | Analyze storage usage and bloat | `linux/` |

---

## Performance Analysis

### Purpose

Analyzes PostgreSQL performance metrics including:
- Cache hit ratios (index and table)
- Connection statistics and limits
- Long-running and slow queries
- Table bloat and dead tuples
- Index usage and efficiency
- Checkpoint statistics
- Replication lag
- Lock contention
- Configuration parameters

### Usage

**Windows:**
```powershell
# Basic analysis
.\performance_analysis.ps1

# Detailed report with CSV export
.\performance_analysis.ps1 -Database mydb -DetailedReport -ExportToCSV

# Custom output directory
.\performance_analysis.ps1 -OutputDir "C:\reports" -ContainerName PG-timescale
```

**Linux:**
```bash
# Basic analysis
./performance_analysis.sh

# Detailed report with CSV export
./performance_analysis.sh -d mydb --detailed --export-csv

# Custom output directory
./performance_analysis.sh -o /var/reports -c PG-timescale
```

### Key Metrics Analyzed

#### 1. Cache Hit Ratio
- **Target**: >99%
- **Low ratio indicates**: Insufficient shared_buffers or effective_cache_size
- **Action**: Increase memory allocation if consistently low

#### 2. Connection Statistics
- **Monitor**: Active, idle, and idle-in-transaction connections
- **Warning**: >60% of max_connections
- **Critical**: >80% of max_connections
- **Action**: Increase max_connections or implement connection pooling

#### 3. Slow Queries
Requires `pg_stat_statements` extension:
```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```

Shows:
- Average execution time
- Total execution time
- Call count
- Percentage of total query time

#### 4. Table Bloat
- **Indicator**: High dead tuple count
- **Threshold**: >20% dead tuples
- **Action**: Run VACUUM ANALYZE or VACUUM FULL

#### 5. Index Usage
Identifies:
- Unused indexes (never scanned)
- Missing indexes (high sequential scans)
- Index efficiency

### Output Files

- **Text Report**: `performance_analysis_YYYYMMDD_HHMMSS.txt`
- **CSV Files** (if enabled):
  - `table_sizes_YYYYMMDD_HHMMSS.csv`
  - `connections_YYYYMMDD_HHMMSS.csv`

---

## Health Checks

### Purpose

Performs a comprehensive 15-point health assessment and generates a health score (0-100).

### Health Check Points

1. **Docker Container Status** - Verify container is running
2. **PostgreSQL Connectivity** - Test database connection
3. **Database Existence** - Confirm target database exists
4. **Disk Space** - Check database size and growth
5. **Connection Limits** - Monitor connection usage
6. **Idle Transactions** - Detect long-running idle transactions
7. **Cache Hit Ratio** - Verify cache performance
8. **Table Bloat** - Identify bloated tables
9. **Unused Indexes** - Find wasted index space
10. **Missing Indexes** - Detect tables needing indexes
11. **Replication Status** - Check replication lag (if applicable)
12. **Lock Contention** - Monitor blocked queries
13. **Autovacuum Status** - Verify autovacuum is enabled
14. **Long-Running Queries** - Find queries running >10 minutes
15. **WAL File Status** - Monitor WAL accumulation

### Usage

**Windows:**
```powershell
# Basic health check
.\health_check.ps1

# Check specific database
.\health_check.ps1 -Database mydb

# Enable email alerts (requires SMTP configuration)
.\health_check.ps1 -SendAlert -AlertEmail admin@example.com
```

**Linux:**
```bash
# Basic health check
./health_check.sh

# Check specific database
./health_check.sh -d mydb

# Enable email alerts
./health_check.sh --alert --email admin@example.com
```

### Health Score Interpretation

| Score | Status | Action Required |
|-------|--------|-----------------|
| 90-100 | 🟢 Healthy | Continue regular monitoring |
| 70-89 | 🟡 Attention | Address warnings in next maintenance window |
| 0-69 | 🔴 Urgent | Immediate action required |

### Exit Codes

- `0`: All checks passed
- `1`: Critical issues found
- `2`: Warnings found

### Integration with Monitoring

Use exit codes for monitoring integration:

**Windows (Task Scheduler):**
```powershell
.\health_check.ps1
if ($LASTEXITCODE -eq 1) {
    # Send critical alert
}
```

**Linux (Cron):**
```bash
./health_check.sh
if [ $? -eq 1 ]; then
    # Send critical alert
fi
```

---

## Tuning Recommendations

### Purpose

Analyzes system resources and workload to generate optimized PostgreSQL configuration parameters.

### Workload Profiles

#### Small (<4GB RAM)
- Light workload
- Limited concurrent connections
- Minimal parallel processing

**Recommended for:**
- Development environments
- Small applications
- Testing instances

#### Medium (4-16GB RAM)
- Moderate workload
- Standard concurrent connections
- Balanced parallel processing

**Recommended for:**
- Production applications
- Medium-sized databases
- Standard web applications

#### Large (>16GB RAM)
- Heavy workload
- High concurrent connections
- Maximum parallel processing

**Recommended for:**
- Enterprise applications
- Large databases
- High-traffic systems
- Data warehouses

### Usage

**Windows:**
```powershell
# Auto-detect system resources
.\tuning_recommendations.ps1

# Specify workload profile
.\tuning_recommendations.ps1 -WorkloadProfile Large -TotalRAM_GB 32

# Apply changes automatically (requires confirmation)
.\tuning_recommendations.ps1 -ApplyChanges
```

**Linux:**
```bash
# Auto-detect system resources
./tuning_recommendations.sh

# Specify workload profile
./tuning_recommendations.sh --workload Large --ram 32

# Apply changes automatically
./tuning_recommendations.sh --apply
```

### Key Parameters Tuned

#### Memory Settings

| Parameter | Small | Medium | Large | Purpose |
|-----------|-------|--------|-------|---------|
| `shared_buffers` | 25% RAM (min 128MB) | 25% RAM | 25% RAM (max 16GB) | Database cache |
| `effective_cache_size` | 50% RAM | 75% RAM | 75% RAM | Query planner estimate |
| `work_mem` | 4MB | 16MB | 32MB | Per-operation memory |
| `maintenance_work_mem` | 64MB | 5% RAM (max 2GB) | 2GB | Maintenance operations |

#### Connection Settings

| Parameter | Small | Medium | Large |
|-----------|-------|--------|-------|
| `max_connections` | 100 | 200 | 300 |

#### Parallel Query Settings

| Parameter | Small | Medium | Large |
|-----------|-------|--------|-------|
| `max_parallel_workers_per_gather` | 1 | 2 | 4 |
| `max_parallel_workers` | 2 | 4 | 8 |
| `max_worker_processes` | 2 | 4 | 8 |

#### WAL Settings

| Parameter | Formula | Purpose |
|-----------|---------|---------|
| `wal_buffers` | shared_buffers / 32 (1-16MB) | WAL write buffer |
| `max_wal_size` | shared_buffers * 2 (min 1GB) | Checkpoint trigger |
| `min_wal_size` | max_wal_size / 4 | WAL retention |
| `checkpoint_completion_target` | 0.9 | Checkpoint spread |

#### Storage Settings (SSD)

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `random_page_cost` | 1.1 | SSD random access cost |
| `effective_io_concurrency` | 200 | Concurrent I/O operations |

### Applying Changes

The script can automatically apply changes to your PostgreSQL configuration:

1. **Review Recommendations**: Check the generated configuration file
2. **Confirm Changes**: Script will prompt for confirmation
3. **Automatic Application**: 
   - Copies configuration to container
   - Appends to `postgresql.conf`
   - Restarts PostgreSQL
4. **Verification**: Monitor performance after changes

**⚠️ Warning**: Applying changes requires PostgreSQL restart and may cause brief downtime.

### Manual Application

If you prefer manual application:

1. Review the generated `postgresql_tuned_YYYYMMDD_HHMMSS.conf`
2. Copy relevant settings to your `postgresql.conf`
3. Reload or restart PostgreSQL:
   ```sql
   SELECT pg_reload_conf();  -- For some settings
   -- OR restart for memory settings
   ```

---

## Storage Analysis

### Purpose

Comprehensive analysis of database storage usage, including:
- Database and table sizes
- Index storage and efficiency
- TOAST table usage
- WAL directory size
- Bloat estimation
- Storage growth trends

### Usage

**Windows:**
```powershell
# Basic storage analysis
.\storage_analysis.ps1

# Detailed analysis with system catalogs
.\storage_analysis.ps1 -Database mydb -DetailedAnalysis -IncludeSystemCatalogs

# Export to CSV
.\storage_analysis.ps1 -ExportToCSV -OutputDir "C:\reports"
```

**Linux:**
```bash
# Basic storage analysis
./storage_analysis.sh

# Detailed analysis with system catalogs
./storage_analysis.sh -d mydb --detailed --system

# Export to CSV
./storage_analysis.sh --export-csv -o /var/reports
```

### Analysis Sections

#### 1. Database Sizes
Overview of all databases with:
- Total size
- Active connections
- Size ranking

#### 2. Object Type Breakdown
Storage distribution across:
- Tables
- Indexes
- TOAST tables

#### 3. Largest Tables
Top 30 tables by size with:
- Total size (table + indexes)
- Table size only
- Index size
- Percentage of total storage

#### 4. Row Statistics
For each table:
- Live row count
- Dead row count
- Bytes per row
- Last vacuum/autovacuum timestamp

#### 5. Index Analysis
- Size of each index
- Usage statistics (scans, tuples read/fetched)
- Usage status (UNUSED, LOW USAGE, ACTIVE)

#### 6. Unused Indexes
Identifies indexes that:
- Have never been scanned
- Are larger than 1MB
- Are not primary keys
- **Action**: Consider dropping after verification

#### 7. Duplicate Indexes
Finds indexes with identical definitions on the same table:
- **Wasted space**: Total size of duplicates
- **Action**: Drop redundant indexes

#### 8. TOAST Table Storage
Analysis of TOAST (The Oversized-Attribute Storage Technique):
- TOAST size vs main table size
- TOAST percentage
- Identifies tables with large out-of-line storage

#### 9. Table Bloat
Estimates bloat based on dead tuples:
- Dead tuple count and percentage
- Estimated bloat size
- Last vacuum timestamp
- **Action**: VACUUM ANALYZE or VACUUM FULL

#### 10. Schema Distribution
Storage breakdown by schema:
- Table count
- Total size
- Average table size
- Largest table

### Storage Optimization Recommendations

#### Unused Indexes
```sql
-- Review unused index
SELECT indexdef FROM pg_indexes WHERE indexname = 'index_name';

-- Drop if confirmed unused
DROP INDEX index_name;
```

#### Table Bloat
```sql
-- Light bloat (<20%)
VACUUM ANALYZE table_name;

-- Moderate bloat (20-50%)
VACUUM FULL table_name;  -- Requires exclusive lock

-- Alternative: pg_repack (no lock required)
pg_repack -t table_name database_name
```

#### Index Bloat
```sql
-- Rebuild bloated index
REINDEX INDEX index_name;

-- Rebuild all indexes on table
REINDEX TABLE table_name;

-- Rebuild all indexes in database (use with caution)
REINDEX DATABASE database_name;
```

---

## Best Practices

### Regular Monitoring Schedule

#### Daily
- Run health checks
- Monitor connection usage
- Check for long-running queries
- Review error logs

#### Weekly
- Performance analysis
- Review slow query log
- Check table bloat
- Monitor storage growth

#### Monthly
- Comprehensive storage analysis
- Review and update tuning parameters
- Analyze index usage
- Plan capacity upgrades

### Performance Optimization Workflow

1. **Baseline**: Establish current performance metrics
2. **Analyze**: Run performance analysis script
3. **Identify**: Focus on top issues (cache hit ratio, slow queries, bloat)
4. **Tune**: Apply tuning recommendations
5. **Monitor**: Track improvements over 1-2 weeks
6. **Iterate**: Refine based on results

### Maintenance Best Practices

#### Autovacuum
```sql
-- Verify autovacuum is enabled
SHOW autovacuum;

-- Check autovacuum activity
SELECT schemaname, tablename, last_autovacuum, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY last_autovacuum DESC NULLS LAST;

-- Tune autovacuum for specific table
ALTER TABLE table_name SET (
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05
);
```

#### Statistics
```sql
-- Update statistics after bulk operations
ANALYZE table_name;

-- Update all statistics
ANALYZE;

-- Check statistics freshness
SELECT schemaname, tablename, last_analyze, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY last_analyze DESC NULLS LAST;
```

#### Index Maintenance
```sql
-- Find missing indexes (high sequential scans)
SELECT schemaname, tablename, seq_scan, seq_tup_read, idx_scan
FROM pg_stat_user_tables
WHERE seq_scan > 1000 AND seq_scan > idx_scan
ORDER BY seq_tup_read DESC;

-- Create index for frequently scanned columns
CREATE INDEX CONCURRENTLY idx_name ON table_name(column_name);

-- Remove unused index
DROP INDEX CONCURRENTLY index_name;
```

### Query Optimization

#### Enable pg_stat_statements
```sql
-- Add to postgresql.conf
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all
pg_stat_statements.max = 10000

-- Restart PostgreSQL, then create extension
CREATE EXTENSION pg_stat_statements;

-- Find slowest queries
SELECT 
    round((total_exec_time / calls)::numeric, 2) as avg_time_ms,
    calls,
    query
FROM pg_stat_statements
ORDER BY avg_time_ms DESC
LIMIT 10;

-- Reset statistics
SELECT pg_stat_statements_reset();
```

#### Use EXPLAIN ANALYZE
```sql
-- Analyze query execution
EXPLAIN ANALYZE SELECT * FROM table_name WHERE condition;

-- Check for sequential scans on large tables
-- Look for "Seq Scan" in output
-- Consider adding indexes if found
```

---

## Troubleshooting

### Common Issues

#### 1. Low Cache Hit Ratio (<99%)

**Symptoms:**
- Slow query performance
- High disk I/O

**Diagnosis:**
```sql
SELECT 
    sum(heap_blks_read) as heap_read,
    sum(heap_blks_hit) as heap_hit,
    round(sum(heap_blks_hit) * 100.0 / 
          NULLIF(sum(heap_blks_hit + heap_blks_read), 0), 2) as ratio
FROM pg_statio_user_tables;
```

**Solutions:**
1. Increase `shared_buffers` (25% of RAM)
2. Increase `effective_cache_size` (75% of RAM)
3. Add more RAM to system
4. Optimize queries to reduce data access

#### 2. Connection Limit Reached

**Symptoms:**
- "FATAL: sorry, too many clients already"
- Application connection errors

**Diagnosis:**
```sql
SELECT count(*), max_connections 
FROM pg_stat_activity, 
     (SELECT setting::int as max_connections FROM pg_settings WHERE name='max_connections') s
GROUP BY max_connections;
```

**Solutions:**
1. Increase `max_connections` in postgresql.conf
2. Implement connection pooling (PgBouncer, pgpool)
3. Close idle connections in application
4. Investigate connection leaks

#### 3. Table Bloat

**Symptoms:**
- Tables larger than expected
- Slow queries despite indexes
- High dead tuple count

**Diagnosis:**
```sql
SELECT 
    schemaname, tablename,
    n_dead_tup, n_live_tup,
    round((n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0))::numeric, 2) as dead_pct
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;
```

**Solutions:**
```sql
-- Light bloat
VACUUM ANALYZE table_name;

-- Heavy bloat (requires exclusive lock)
VACUUM FULL table_name;

-- Alternative: pg_repack (online)
pg_repack -t table_name database_name
```

#### 4. Checkpoint Too Frequent

**Symptoms:**
- High checkpoint_req count
- Performance spikes

**Diagnosis:**
```sql
SELECT 
    checkpoints_timed,
    checkpoints_req,
    round((checkpoints_req * 100.0 / 
           NULLIF(checkpoints_timed + checkpoints_req, 0))::numeric, 2) as req_pct
FROM pg_stat_bgwriter;
```

**Solutions:**
- Increase `max_wal_size` (target <10% requested checkpoints)
- Adjust `checkpoint_completion_target` to 0.9
- Monitor WAL generation rate

#### 5. Replication Lag

**Symptoms:**
- Stale data on replicas
- High replay_lag

**Diagnosis:**
```sql
SELECT 
    client_addr,
    state,
    pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) / 1024 / 1024 as lag_mb
FROM pg_stat_replication;
```

**Solutions:**
1. Check network bandwidth
2. Increase `wal_sender_timeout`
3. Tune `max_wal_senders`
4. Consider synchronous replication settings
5. Upgrade replica hardware

#### 6. Lock Contention

**Symptoms:**
- Queries waiting indefinitely
- Application timeouts

**Diagnosis:**
```sql
SELECT 
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_statement,
    blocking_activity.query AS blocking_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks 
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
```

**Solutions:**
1. Identify and optimize long-running queries
2. Use `LOCK TIMEOUT` in applications
3. Minimize transaction duration
4. Consider `SELECT FOR UPDATE SKIP LOCKED`
5. Terminate blocking query if necessary:
   ```sql
   SELECT pg_terminate_backend(blocking_pid);
   ```

---

## Automation & Scheduling

### Windows Task Scheduler

#### Create Scheduled Health Check

1. Open Task Scheduler
2. Create Basic Task
3. Configure:
   - **Trigger**: Daily at 2:00 AM
   - **Action**: Start a program
   - **Program**: `powershell.exe`
   - **Arguments**: `-File "C:\path\to\health_check.ps1" -OutputDir "C:\reports"`

#### PowerShell Script for Automation
```powershell
# scheduled_maintenance.ps1
$ErrorActionPreference = "Stop"
$ScriptDir = "C:\xampp\htdocs\postgres\windows"
$ReportDir = "C:\reports\postgres"

# Ensure report directory exists
New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null

# Run health check
& "$ScriptDir\health_check.ps1" -OutputDir $ReportDir

# Run performance analysis weekly (Sunday)
if ((Get-Date).DayOfWeek -eq 'Sunday') {
    & "$ScriptDir\performance_analysis.ps1" -OutputDir $ReportDir -ExportToCSV
}

# Run storage analysis monthly (1st of month)
if ((Get-Date).Day -eq 1) {
    & "$ScriptDir\storage_analysis.ps1" -OutputDir $ReportDir -DetailedAnalysis -ExportToCSV
}

# Clean up old reports (>30 days)
Get-ChildItem $ReportDir -Recurse | 
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | 
    Remove-Item -Force
```

### Linux Cron

#### Create Crontab Entries

```bash
# Edit crontab
crontab -e

# Add entries:

# Daily health check at 2 AM
0 2 * * * /path/to/postgres/linux/health_check.sh -o /var/reports/postgres

# Weekly performance analysis (Sunday at 3 AM)
0 3 * * 0 /path/to/postgres/linux/performance_analysis.sh -o /var/reports/postgres --export-csv

# Monthly storage analysis (1st of month at 4 AM)
0 4 1 * * /path/to/postgres/linux/storage_analysis.sh -o /var/reports/postgres --detailed --export-csv

# Daily cleanup of old reports (>30 days)
0 5 * * * find /var/reports/postgres -type f -mtime +30 -delete
```

#### Bash Script for Automation
```bash
#!/bin/bash
# scheduled_maintenance.sh

SCRIPT_DIR="/path/to/postgres/linux"
REPORT_DIR="/var/reports/postgres"

# Ensure report directory exists
mkdir -p "$REPORT_DIR"

# Run health check
"$SCRIPT_DIR/health_check.sh" -o "$REPORT_DIR"
health_exit=$?

# Send alert if critical issues
if [ $health_exit -eq 1 ]; then
    echo "CRITICAL: PostgreSQL health check failed" | mail -s "PostgreSQL Alert" admin@example.com
fi

# Run performance analysis weekly (Sunday)
if [ $(date +%u) -eq 7 ]; then
    "$SCRIPT_DIR/performance_analysis.sh" -o "$REPORT_DIR" --export-csv
fi

# Run storage analysis monthly (1st of month)
if [ $(date +%d) -eq 01 ]; then
    "$SCRIPT_DIR/storage_analysis.sh" -o "$REPORT_DIR" --detailed --export-csv
fi

# Clean up old reports (>30 days)
find "$REPORT_DIR" -type f -mtime +30 -delete
```

Make executable:
```bash
chmod +x scheduled_maintenance.sh
```

### Docker Integration

#### Health Check in Docker Compose

```yaml
version: '3.8'

services:
  postgres:
    image: timescale/timescaledb:latest-pg16
    container_name: PG-timescale
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts:/scripts
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}

  maintenance:
    image: postgres:16
    container_name: PG-maintenance
    depends_on:
      - postgres
    volumes:
      - ./linux:/scripts
      - ./reports:/reports
    command: >
      sh -c "
        while true; do
          sleep 86400;
          /scripts/health_check.sh -c PG-timescale -o /reports;
        done
      "

volumes:
  postgres_data:
```

### Monitoring Integration

#### Prometheus Exporter

Use `postgres_exporter` for Prometheus integration:

```yaml
# docker-compose.yml
services:
  postgres-exporter:
    image: prometheuscommunity/postgres-exporter
    container_name: postgres-exporter
    environment:
      DATA_SOURCE_NAME: "postgresql://postgres:password@PG-timescale:5432/postgres?sslmode=disable"
    ports:
      - "9187:9187"
    depends_on:
      - postgres
```

#### Grafana Dashboard

Import PostgreSQL dashboard:
- Dashboard ID: 9628 (PostgreSQL Database)
- Dashboard ID: 455 (PostgreSQL Overview)

---

## Quick Reference

### Performance Metrics Targets

| Metric | Target | Warning | Critical |
|--------|--------|---------|----------|
| Cache Hit Ratio | >99% | <99% | <95% |
| Connection Usage | <50% | 60-80% | >80% |
| Dead Tuple % | <10% | 10-20% | >20% |
| Checkpoint Req % | <10% | 10-20% | >20% |
| Replication Lag | <10MB | 10-100MB | >100MB |

### Common SQL Queries

```sql
-- Current activity
SELECT pid, usename, state, query_start, query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY query_start;

-- Database sizes
SELECT datname, pg_size_pretty(pg_database_size(datname))
FROM pg_database
ORDER BY pg_database_size(datname) DESC;

-- Table sizes
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;

-- Index usage
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
ORDER BY idx_scan;

-- Bloat check
SELECT schemaname, tablename, n_dead_tup, n_live_tup
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;

-- Kill query
SELECT pg_terminate_backend(pid);

-- Cancel query
SELECT pg_cancel_backend(pid);
```

### Configuration Quick Tuning

```ini
# postgresql.conf - Quick tuning for 16GB RAM system

# Memory
shared_buffers = 4GB
effective_cache_size = 12GB
work_mem = 32MB
maintenance_work_mem = 2GB

# Connections
max_connections = 200

# Parallelism
max_parallel_workers_per_gather = 4
max_parallel_workers = 8
max_worker_processes = 8

# WAL
wal_buffers = 16MB
max_wal_size = 8GB
min_wal_size = 2GB
checkpoint_completion_target = 0.9

# SSD
random_page_cost = 1.1
effective_io_concurrency = 200

# Monitoring
shared_preload_libraries = 'pg_stat_statements'
log_min_duration_statement = 1000
```

---

## Additional Resources

### Official Documentation
- [PostgreSQL Performance Tips](https://www.postgresql.org/docs/current/performance-tips.html)
- [Server Configuration](https://www.postgresql.org/docs/current/runtime-config.html)
- [Monitoring](https://www.postgresql.org/docs/current/monitoring.html)

### Tools
- **pgBadger**: PostgreSQL log analyzer
- **pg_repack**: Online table/index reorganization
- **PgBouncer**: Connection pooler
- **pgAdmin**: GUI administration tool

### Community
- [PostgreSQL Mailing Lists](https://www.postgresql.org/list/)
- [PostgreSQL Wiki](https://wiki.postgresql.org/)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/postgresql)

---

**Last Updated**: 2026-01-08
**Version**: 1.0
**Maintainer**: Database Administration Team
