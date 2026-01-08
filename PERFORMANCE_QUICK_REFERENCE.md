# PostgreSQL Performance Scripts - Quick Reference

Quick reference guide for PostgreSQL performance analysis, health monitoring, tuning, and storage management scripts.

## 📋 Available Scripts

| Script | Windows | Linux | Purpose |
|--------|---------|-------|---------|
| Performance Analysis | `performance_analysis.ps1` | `performance_analysis.sh` | Analyze database performance metrics |
| Health Check | `health_check.ps1` | `health_check.sh` | 15-point health assessment with scoring |
| Tuning Recommendations | `tuning_recommendations.ps1` | `tuning_recommendations.sh` | Generate optimized configuration |
| Storage Analysis | `storage_analysis.ps1` | `storage_analysis.sh` | Analyze storage usage and bloat |

---

## 🚀 Quick Start

### Performance Analysis

**Windows:**
```powershell
.\windows\performance_analysis.ps1
.\windows\performance_analysis.ps1 -Database mydb -DetailedReport -ExportToCSV
```

**Linux:**
```bash
./linux/performance_analysis.sh
./linux/performance_analysis.sh -d mydb --detailed --export-csv
```

**What it does:**
- ✅ Cache hit ratios (target: >99%)
- ✅ Connection statistics
- ✅ Slow queries (requires pg_stat_statements)
- ✅ Table bloat analysis
- ✅ Index usage and efficiency
- ✅ Checkpoint statistics
- ✅ Replication lag
- ✅ Lock contention

---

### Health Check

**Windows:**
```powershell
.\windows\health_check.ps1
.\windows\health_check.ps1 -Database mydb
```

**Linux:**
```bash
./linux/health_check.sh
./linux/health_check.sh -d mydb
```

**Health Score:**
- 🟢 **90-100**: Healthy - Continue regular monitoring
- 🟡 **70-89**: Attention - Address warnings soon
- 🔴 **0-69**: Urgent - Immediate action required

**15 Check Points:**
1. Container status
2. PostgreSQL connectivity
3. Database existence
4. Disk space
5. Connection limits
6. Idle transactions
7. Cache hit ratio
8. Table bloat
9. Unused indexes
10. Missing indexes
11. Replication status
12. Lock contention
13. Autovacuum status
14. Long-running queries
15. WAL file status

---

### Tuning Recommendations

**Windows:**
```powershell
.\windows\tuning_recommendations.ps1
.\windows\tuning_recommendations.ps1 -WorkloadProfile Large -TotalRAM_GB 32
.\windows\tuning_recommendations.ps1 -ApplyChanges
```

**Linux:**
```bash
./linux/tuning_recommendations.sh
./linux/tuning_recommendations.sh --workload Large --ram 32
./linux/tuning_recommendations.sh --apply
```

**Workload Profiles:**
- **Small** (<4GB RAM): Light workload, development
- **Medium** (4-16GB RAM): Standard production
- **Large** (>16GB RAM): Enterprise, high-traffic

**Key Parameters Tuned:**
- Memory (shared_buffers, effective_cache_size, work_mem)
- Connections (max_connections)
- Parallelism (max_parallel_workers)
- WAL (wal_buffers, max_wal_size)
- Storage (random_page_cost for SSD)

---

### Storage Analysis

**Windows:**
```powershell
.\windows\storage_analysis.ps1
.\windows\storage_analysis.ps1 -Database mydb -DetailedAnalysis -ExportToCSV
```

**Linux:**
```bash
./linux/storage_analysis.sh
./linux/storage_analysis.sh -d mydb --detailed --export-csv
```

**What it analyzes:**
- 📊 Database and table sizes
- 📈 Storage growth trends
- 💾 Index storage and efficiency
- 🗑️ Unused indexes (potential savings)
- 💨 Table bloat estimation
- 🔄 TOAST table usage
- 📁 WAL directory size
- 📋 Schema distribution

---

## 🎯 Common Use Cases

### Daily Monitoring
```bash
# Run health check
./linux/health_check.sh -o /var/reports

# Check exit code
if [ $? -eq 1 ]; then
    echo "CRITICAL issues found!"
fi
```

### Weekly Performance Review
```bash
# Generate performance report with CSV export
./linux/performance_analysis.sh --detailed --export-csv -o /var/reports
```

### Monthly Optimization
```bash
# 1. Storage analysis
./linux/storage_analysis.sh --detailed --export-csv

# 2. Review tuning recommendations
./linux/tuning_recommendations.sh

# 3. Apply if needed (after review)
./linux/tuning_recommendations.sh --apply
```

### Before Production Deployment
```bash
# 1. Health check
./linux/health_check.sh

# 2. Tune for workload
./linux/tuning_recommendations.sh --workload Large --ram 32 --apply

# 3. Verify performance
./linux/performance_analysis.sh --detailed
```

---

## 📊 Performance Metrics Targets

| Metric | Target | Warning | Critical | Action |
|--------|--------|---------|----------|--------|
| **Cache Hit Ratio** | >99% | <99% | <95% | Increase shared_buffers |
| **Connection Usage** | <50% | 60-80% | >80% | Increase max_connections or use pooling |
| **Dead Tuples** | <10% | 10-20% | >20% | Run VACUUM ANALYZE |
| **Checkpoint Req %** | <10% | 10-20% | >20% | Increase max_wal_size |
| **Replication Lag** | <10MB | 10-100MB | >100MB | Check network/hardware |

---

## 🔧 Quick Fixes

### Low Cache Hit Ratio
```sql
-- Check current ratio
SELECT round((sum(heap_blks_hit) * 100.0 / 
       NULLIF(sum(heap_blks_hit + heap_blks_read), 0))::numeric, 2) as cache_hit_ratio
FROM pg_statio_user_tables;

-- If <99%, increase in postgresql.conf:
shared_buffers = 4GB              # 25% of RAM
effective_cache_size = 12GB       # 75% of RAM
```

### Table Bloat
```sql
-- Check bloat
SELECT schemaname, tablename, n_dead_tup, n_live_tup,
       round((n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0))::numeric, 2) as dead_pct
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;

-- Fix light bloat
VACUUM ANALYZE table_name;

-- Fix heavy bloat (requires lock)
VACUUM FULL table_name;
```

### Unused Indexes
```sql
-- Find unused indexes
SELECT schemaname, tablename, indexname, 
       pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
WHERE idx_scan = 0 
  AND indexrelname NOT LIKE '%_pkey'
  AND pg_relation_size(indexrelid) > 1048576
ORDER BY pg_relation_size(indexrelid) DESC;

-- Drop after verification
DROP INDEX CONCURRENTLY index_name;
```

### Long-Running Queries
```sql
-- Find long-running queries
SELECT pid, usename, now() - query_start as duration, query
FROM pg_stat_activity
WHERE state != 'idle' 
  AND query_start < now() - interval '10 minutes'
ORDER BY duration DESC;

-- Terminate if needed
SELECT pg_terminate_backend(pid);
```

---

## 📅 Automation Examples

### Windows Task Scheduler

**Daily Health Check (2 AM):**
```powershell
# Program: powershell.exe
# Arguments: -File "C:\xampp\htdocs\postgres\windows\health_check.ps1" -OutputDir "C:\reports"
```

### Linux Cron

**Daily Health Check (2 AM):**
```bash
0 2 * * * /path/to/postgres/linux/health_check.sh -o /var/reports
```

**Weekly Performance Analysis (Sunday 3 AM):**
```bash
0 3 * * 0 /path/to/postgres/linux/performance_analysis.sh -o /var/reports --export-csv
```

**Monthly Storage Analysis (1st of month, 4 AM):**
```bash
0 4 1 * * /path/to/postgres/linux/storage_analysis.sh -o /var/reports --detailed --export-csv
```

---

## 🔍 Essential SQL Queries

### Current Activity
```sql
SELECT pid, usename, state, query_start, 
       now() - query_start as duration, query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY query_start;
```

### Database Sizes
```sql
SELECT datname, pg_size_pretty(pg_database_size(datname)) as size
FROM pg_database
ORDER BY pg_database_size(datname) DESC;
```

### Top 10 Largest Tables
```sql
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
```

### Index Usage
```sql
SELECT schemaname, tablename, indexname, idx_scan, 
       pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
ORDER BY idx_scan;
```

### Enable pg_stat_statements
```sql
-- Add to postgresql.conf
shared_preload_libraries = 'pg_stat_statements'

-- Restart PostgreSQL, then:
CREATE EXTENSION pg_stat_statements;

-- Find slowest queries
SELECT round((total_exec_time / calls)::numeric, 2) as avg_ms,
       calls, query
FROM pg_stat_statements
ORDER BY avg_ms DESC
LIMIT 10;
```

---

## 📖 Configuration Templates

### Small System (<4GB RAM)
```ini
# postgresql.conf
shared_buffers = 512MB
effective_cache_size = 2GB
work_mem = 4MB
maintenance_work_mem = 64MB
max_connections = 100
max_parallel_workers_per_gather = 1
max_parallel_workers = 2
```

### Medium System (4-16GB RAM)
```ini
# postgresql.conf
shared_buffers = 2GB
effective_cache_size = 6GB
work_mem = 16MB
maintenance_work_mem = 512MB
max_connections = 200
max_parallel_workers_per_gather = 2
max_parallel_workers = 4
```

### Large System (>16GB RAM)
```ini
# postgresql.conf
shared_buffers = 4GB
effective_cache_size = 12GB
work_mem = 32MB
maintenance_work_mem = 2GB
max_connections = 300
max_parallel_workers_per_gather = 4
max_parallel_workers = 8

# WAL
wal_buffers = 16MB
max_wal_size = 8GB
min_wal_size = 2GB
checkpoint_completion_target = 0.9

# SSD
random_page_cost = 1.1
effective_io_concurrency = 200
```

---

## 🆘 Emergency Procedures

### Database Unresponsive

1. **Check container status:**
   ```bash
   docker ps -a | grep PG-timescale
   docker logs PG-timescale --tail 100
   ```

2. **Check connections:**
   ```sql
   SELECT count(*), state FROM pg_stat_activity GROUP BY state;
   ```

3. **Kill blocking queries:**
   ```sql
   SELECT pg_terminate_backend(pid) 
   FROM pg_stat_activity 
   WHERE state = 'active' 
     AND query_start < now() - interval '1 hour';
   ```

### Out of Disk Space

1. **Check WAL size:**
   ```sql
   SELECT pg_size_pretty(sum(size)) FROM pg_ls_waldir();
   ```

2. **Archive old WAL files** (if archiving enabled)

3. **Vacuum to reclaim space:**
   ```sql
   VACUUM FULL;  -- Use with caution, requires lock
   ```

4. **Drop unused indexes:**
   ```sql
   -- Find and drop unused indexes
   SELECT 'DROP INDEX ' || indexrelname || ';'
   FROM pg_stat_user_indexes
   WHERE idx_scan = 0;
   ```

### Replication Broken

1. **Check replication status:**
   ```sql
   SELECT * FROM pg_stat_replication;
   ```

2. **Check replication lag:**
   ```sql
   SELECT pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) / 1024 / 1024 as lag_mb
   FROM pg_stat_replication;
   ```

3. **Restart replication if needed**

---

## 📚 Additional Resources

- **Full Guide**: See `PERFORMANCE_MAINTENANCE_GUIDE.md` for comprehensive documentation
- **Backup Guide**: See `BACKUP_RESTORE_GUIDE.md` for backup procedures
- **FDW Guide**: See `FDW_GUIDE.md` for foreign data wrapper setup

---

## 🔗 Quick Links

| Task | Command |
|------|---------|
| **View all scripts** | `ls windows/` or `ls linux/` |
| **Make scripts executable (Linux)** | `chmod +x linux/*.sh` |
| **View script help** | `script.ps1 -Help` or `script.sh --help` |
| **Check PostgreSQL version** | `docker exec PG-timescale psql -U postgres -c "SELECT version();"` |
| **Access PostgreSQL** | `docker exec -it PG-timescale psql -U postgres` |

---

**Last Updated**: 2026-01-08  
**Version**: 1.0  
**For detailed documentation, see**: `PERFORMANCE_MAINTENANCE_GUIDE.md`
