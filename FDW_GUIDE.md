# Foreign Data Wrapper (FDW) Extensions Guide

## Overview

Foreign Data Wrappers (FDWs) allow PostgreSQL to access data from external sources as if they were regular PostgreSQL tables. This guide covers all available FDW extensions and their installation.

## Available FDW Extensions

### 1. postgres_fdw ✅ Built-in
**Purpose:** Access remote PostgreSQL databases  
**Status:** Included with PostgreSQL  
**Use Case:** Distributed PostgreSQL databases, data federation

#### Installation
```powershell
# Windows
.\windows\install_postgres_fdw.ps1

# Linux
./linux/install_postgres_fdw.sh
```

#### Usage Example
```sql
-- Create server connection
CREATE SERVER remote_pg
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host 'remote.example.com', dbname 'remote_db', port '5432');

-- Create user mapping
CREATE USER MAPPING FOR postgres
SERVER remote_pg
OPTIONS (user 'remote_user', password 'remote_password');

-- Import entire schema
IMPORT FOREIGN SCHEMA public
FROM SERVER remote_pg INTO public;

-- Or create specific foreign table
CREATE FOREIGN TABLE remote_users (
    id INTEGER,
    username TEXT,
    email TEXT
) SERVER remote_pg
OPTIONS (schema_name 'public', table_name 'users');

-- Query remote data
SELECT * FROM remote_users WHERE id > 100;
```

---

### 2. file_fdw ✅ Built-in
**Purpose:** Read files (CSV, text) as database tables  
**Status:** Included with PostgreSQL  
**Use Case:** Import/query CSV files, log files, data exports

#### Installation
```powershell
# Windows
.\windows\install_file_fdw.ps1

# Linux
./linux/install_file_fdw.sh
```

#### Usage Example
```sql
-- Create server
CREATE SERVER file_server
FOREIGN DATA WRAPPER file_fdw;

-- Create foreign table for CSV file
CREATE FOREIGN TABLE sales_data (
    date DATE,
    product TEXT,
    quantity INTEGER,
    revenue NUMERIC(10,2)
) SERVER file_server
OPTIONS (
    filename 'C:/data/sales.csv',  -- Windows path
    -- filename '/data/sales.csv',  -- Linux path
    format 'csv',
    header 'true',
    delimiter ','
);

-- Query the CSV file
SELECT product, SUM(revenue) as total_revenue
FROM sales_data
WHERE date >= '2024-01-01'
GROUP BY product
ORDER BY total_revenue DESC;

-- Read log file
CREATE FOREIGN TABLE app_logs (
    log_line TEXT
) SERVER file_server
OPTIONS (
    filename '/var/log/app.log',
    format 'text'
);
```

---

### 3. mysql_fdw 📦 Requires Installation
**Purpose:** Access MySQL/MariaDB databases  
**Status:** Requires separate installation  
**Use Case:** MySQL to PostgreSQL migration, hybrid database queries

#### Installation

**Windows:**
1. Install MySQL client libraries
2. Download mysql_fdw from https://github.com/EnterpriseDB/mysql_fdw
3. Compile or get pre-built binaries
4. Run script:
```powershell
.\windows\install_mysql_fdw.ps1
```

**Linux:**
```bash
# Ubuntu/Debian
sudo apt-get install postgresql-16-mysql-fdw

# Or compile from source
sudo apt-get install libmysqlclient-dev postgresql-server-dev-16
git clone https://github.com/EnterpriseDB/mysql_fdw.git
cd mysql_fdw
make USE_PGXS=1
sudo make USE_PGXS=1 install

# Run script
./linux/install_mysql_fdw.sh
```

#### Usage Example
```sql
-- Create server
CREATE SERVER mysql_server
FOREIGN DATA WRAPPER mysql_fdw
OPTIONS (host 'mysql.example.com', port '3306');

-- Create user mapping
CREATE USER MAPPING FOR postgres
SERVER mysql_server
OPTIONS (username 'mysql_user', password 'mysql_password');

-- Import entire MySQL database
IMPORT FOREIGN SCHEMA mysql_database
FROM SERVER mysql_server INTO public;

-- Or create specific table
CREATE FOREIGN TABLE mysql_products (
    id INT,
    name VARCHAR(100),
    price DECIMAL(10,2)
) SERVER mysql_server
OPTIONS (dbname 'shop', table_name 'products');

-- Join PostgreSQL and MySQL data
SELECT p.name, o.quantity
FROM local_orders o
JOIN mysql_products p ON o.product_id = p.id;
```

---

### 4. oracle_fdw 📦 Requires Installation
**Purpose:** Access Oracle databases  
**Status:** Requires Oracle Instant Client + compilation  
**Use Case:** Oracle to PostgreSQL migration, enterprise integration

#### Installation

**Prerequisites:**
- Oracle Instant Client installed
- ORACLE_HOME environment variable set

**Windows:**
1. Install Oracle Instant Client
2. Download oracle_fdw from https://github.com/laurenz/oracle_fdw
3. Compile with Visual Studio
4. Run script:
```powershell
.\windows\install_oracle_fdw.ps1
```

**Linux:**
```bash
# Install Oracle Instant Client
# Download from: https://www.oracle.com/database/technologies/instant-client/downloads.html
# Extract to /opt/oracle/instantclient

# Set environment
export ORACLE_HOME=/opt/oracle/instantclient
export LD_LIBRARY_PATH=$ORACLE_HOME:$LD_LIBRARY_PATH

# Install oracle_fdw
sudo apt-get install postgresql-server-dev-16 libaio1
git clone https://github.com/laurenz/oracle_fdw.git
cd oracle_fdw
make
sudo make install

# Run script
./linux/install_oracle_fdw.sh
```

#### Usage Example
```sql
-- Create server
CREATE SERVER oracle_server
FOREIGN DATA WRAPPER oracle_fdw
OPTIONS (dbserver '//oracle.example.com:1521/ORCL');

-- Create user mapping
CREATE USER MAPPING FOR postgres
SERVER oracle_server
OPTIONS (user 'oracle_user', password 'oracle_password');

-- Create foreign table
CREATE FOREIGN TABLE oracle_customers (
    customer_id NUMBER,
    customer_name VARCHAR2(100),
    email VARCHAR2(100)
) SERVER oracle_server
OPTIONS (schema 'SALES', table 'CUSTOMERS');

-- Query Oracle data
SELECT * FROM oracle_customers
WHERE customer_name LIKE 'A%';
```

---

## Common FDW Operations

### Importing Schemas
```sql
-- Import entire schema
IMPORT FOREIGN SCHEMA remote_schema
FROM SERVER my_server INTO local_schema;

-- Import specific tables only
IMPORT FOREIGN SCHEMA remote_schema
LIMIT TO (table1, table2, table3)
FROM SERVER my_server INTO local_schema;

-- Import all except specific tables
IMPORT FOREIGN SCHEMA remote_schema
EXCEPT (temp_table, log_table)
FROM SERVER my_server INTO local_schema;
```

### Managing User Mappings
```sql
-- Create user mapping
CREATE USER MAPPING FOR local_user
SERVER my_server
OPTIONS (user 'remote_user', password 'remote_password');

-- Alter user mapping
ALTER USER MAPPING FOR local_user
SERVER my_server
OPTIONS (SET password 'new_password');

-- Drop user mapping
DROP USER MAPPING FOR local_user SERVER my_server;
```

### Managing Servers
```sql
-- Create server
CREATE SERVER my_server
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host 'example.com', dbname 'mydb', port '5432');

-- Alter server options
ALTER SERVER my_server
OPTIONS (SET host 'new.example.com');

-- Drop server (cascade removes dependent objects)
DROP SERVER my_server CASCADE;
```

### Managing Foreign Tables
```sql
-- Create foreign table
CREATE FOREIGN TABLE remote_table (
    id INTEGER,
    data TEXT
) SERVER my_server
OPTIONS (schema_name 'public', table_name 'source_table');

-- Alter foreign table
ALTER FOREIGN TABLE remote_table
OPTIONS (SET table_name 'new_source_table');

-- Drop foreign table
DROP FOREIGN TABLE remote_table;
```

## Performance Considerations

### 1. Use WHERE Clauses
FDWs push down WHERE clauses to remote servers when possible:
```sql
-- Good: Filter pushed to remote server
SELECT * FROM remote_table WHERE id = 100;

-- Less efficient: All data fetched, then filtered
SELECT * FROM remote_table WHERE custom_function(id) = 100;
```

### 2. Limit Columns
Only select needed columns:
```sql
-- Good: Only fetch needed columns
SELECT id, name FROM remote_table;

-- Less efficient: Fetch all columns
SELECT * FROM remote_table;
```

### 3. Use EXPLAIN
Check query execution plans:
```sql
EXPLAIN (VERBOSE, COSTS)
SELECT * FROM remote_table WHERE id > 100;
```

### 4. Batch Operations
For postgres_fdw, use batch inserts:
```sql
-- Enable batch insert (PostgreSQL 14+)
ALTER SERVER my_server OPTIONS (ADD batch_size '1000');
```

### 5. Connection Pooling
Reuse connections with postgres_fdw:
```sql
-- Keep connections alive
ALTER SERVER my_server OPTIONS (ADD keep_connections 'on');
```

## Security Best Practices

### 1. Use User Mappings
Never hardcode credentials in foreign table definitions:
```sql
-- Bad: Credentials in table definition
CREATE FOREIGN TABLE bad_example (...)
SERVER my_server
OPTIONS (user 'admin', password 'secret123');

-- Good: Use user mapping
CREATE USER MAPPING FOR postgres
SERVER my_server
OPTIONS (user 'admin', password 'secret123');
```

### 2. Restrict Permissions
Grant minimal necessary permissions:
```sql
-- Grant SELECT only
GRANT SELECT ON FOREIGN TABLE remote_table TO app_user;

-- Revoke unnecessary permissions
REVOKE INSERT, UPDATE, DELETE ON FOREIGN TABLE remote_table FROM app_user;
```

### 3. Use SSL Connections
For postgres_fdw:
```sql
CREATE SERVER secure_server
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (
    host 'remote.example.com',
    dbname 'mydb',
    port '5432',
    sslmode 'require'
);
```

## Troubleshooting

### Connection Issues
```sql
-- Test server connection
SELECT * FROM pg_foreign_server WHERE srvname = 'my_server';

-- Check user mappings
SELECT * FROM pg_user_mappings;

-- Verify foreign tables
SELECT * FROM information_schema.foreign_tables;
```

### Permission Errors
```sql
-- Check current user's permissions
SELECT * FROM information_schema.role_table_grants
WHERE table_name = 'foreign_table_name';
```

### Performance Issues
```sql
-- Check query plan
EXPLAIN ANALYZE
SELECT * FROM remote_table WHERE condition;

-- Monitor foreign server stats
SELECT * FROM pg_stat_foreign_server;
```

## Additional Resources

- **postgres_fdw:** https://www.postgresql.org/docs/current/postgres-fdw.html
- **file_fdw:** https://www.postgresql.org/docs/current/file-fdw.html
- **mysql_fdw:** https://github.com/EnterpriseDB/mysql_fdw
- **oracle_fdw:** https://github.com/laurenz/oracle_fdw
- **FDW Documentation:** https://www.postgresql.org/docs/current/fdwhandler.html

## Quick Reference

| FDW | Built-in | Use Case | Complexity |
|-----|----------|----------|------------|
| postgres_fdw | ✅ | Remote PostgreSQL | Easy |
| file_fdw | ✅ | CSV/Text files | Easy |
| mysql_fdw | ❌ | MySQL/MariaDB | Medium |
| oracle_fdw | ❌ | Oracle Database | Hard |

## Summary

Foreign Data Wrappers are powerful tools for:
- **Data Federation:** Query multiple databases as one
- **Migration:** Gradually move data between systems
- **Integration:** Connect heterogeneous data sources
- **ETL:** Extract and transform data from various sources

All scripts are located in:
- Windows: `c:\xampp\htdocs\postgres\windows\`
- Linux: `c:\xampp\htdocs\postgres\linux\`
