# PostgreSQL Extensions - Individual Installation Scripts

This directory contains individual installation scripts for each PostgreSQL extension, available for both Windows (PowerShell) and Linux (Bash).

## Directory Structure

```
postgres/
├── windows/           # Windows PowerShell scripts (.ps1)
│   ├── install_pg_stat_statements.ps1
│   ├── install_postgis.ps1
│   ├── install_postgres_fdw.ps1
│   ├── install_file_fdw.ps1
│   ├── install_mysql_fdw.ps1
│   ├── install_oracle_fdw.ps1
│   ├── install_intarray.ps1
│   ├── install_timescaledb.ps1
│   └── install_zombodb.ps1
│
└── linux/             # Linux Bash scripts (.sh)
    ├── install_pg_stat_statements.sh
    ├── install_postgis.sh
    ├── install_postgres_fdw.sh
    ├── install_file_fdw.sh
    ├── install_mysql_fdw.sh
    ├── install_oracle_fdw.sh
    ├── install_intarray.sh
    ├── install_timescaledb.sh
    └── install_zombodb.sh
```

## How to Use

### Windows

1. Open PowerShell
2. Navigate to the `windows` directory:
   ```powershell
   cd c:\xampp\htdocs\postgres\windows
   ```
3. Run the desired script:
   ```powershell
   powershell -ExecutionPolicy Bypass -File install_pg_stat_statements.ps1
   ```
4. Follow the prompts to enter:
   - PostgreSQL host (default: localhost)
   - PostgreSQL port (default: 5432)
   - Username (default: postgres)
   - Password
   - Database name (default: postgres)

### Linux

1. Open Terminal
2. Navigate to the `linux` directory:
   ```bash
   cd /path/to/postgres/linux
   ```
3. Make the script executable (if not already):
   ```bash
   chmod +x install_pg_stat_statements.sh
   ```
4. Run the script:
   ```bash
   ./install_pg_stat_statements.sh
   ```
5. Follow the prompts to enter connection details

## Extensions Overview

### ✅ Built-in Extensions (No Additional Installation Required)

These extensions are included with PostgreSQL and can be installed directly:

1. **pg_stat_statements** - Query performance tracking
2. **postgres_fdw** - Foreign data wrapper for remote PostgreSQL
3. **file_fdw** - Foreign data wrapper for reading files (CSV, text)
4. **intarray** - Integer array functions
5. **timescaledb** - Time-series database (may be pre-installed)

### 📦 Extensions Requiring Binary Installation

These extensions need additional binaries to be installed first:

6. **mysql_fdw** - Foreign data wrapper for MySQL/MariaDB
7. **oracle_fdw** - Foreign data wrapper for Oracle databases

#### PostGIS - Geographic Objects Support

**Windows Installation:**
1. Visit: https://postgis.net/windows_downloads/
2. Download the installer matching your PostgreSQL version
   - Example: `postgis-bundle-pg16-3.4.1-1-x64.exe` for PostgreSQL 16
3. Run the installer
4. Select your PostgreSQL installation directory
5. Complete the installation
6. Run the script: `install_postgis.ps1`

**Linux Installation:**
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install postgresql-16-postgis-3

# CentOS/RHEL
sudo yum install postgis34_16

# Fedora
sudo dnf install postgis

# Then run the script
./install_postgis.sh
```

#### ZomboDB - Elasticsearch Integration

**Prerequisites:**
- Elasticsearch must be installed and running
- Download Elasticsearch: https://www.elastic.co/downloads/elasticsearch

**Windows Installation:**
1. Install Elasticsearch first
2. Visit: https://github.com/zombodb/zombodb/releases
3. Download the ZIP for your PostgreSQL version
   - Example: `zombodb-pg16-3.1.0.zip`
4. Extract the ZIP file
5. Copy files to PostgreSQL directories:
   ```powershell
   # Copy DLL
   Copy-Item "zombodb.dll" "C:\Program Files\PostgreSQL\16\lib\"
   
   # Copy control and SQL files
   Copy-Item "zombodb.control" "C:\Program Files\PostgreSQL\16\share\extension\"
   Copy-Item "zombodb--*.sql" "C:\Program Files\PostgreSQL\16\share\extension\"
   ```
6. Restart PostgreSQL service
7. Run the script: `install_zombodb.ps1`

**Linux Installation:**
```bash
# Install Elasticsearch first
# Then install ZomboDB

# Method 1: From package (if available)
# Visit: https://github.com/zombodb/zombodb/releases

# Method 2: Build from source
sudo apt-get install build-essential libpq-dev postgresql-server-dev-16 curl git

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Install cargo-pgrx
cargo install --locked cargo-pgrx
cargo pgrx init --pg16 /usr/bin/pg_config

# Clone and build ZomboDB
git clone https://github.com/zombodb/zombodb.git
cd zombodb
cargo pgrx install --release

# Then run the script
./install_zombodb.sh
```

## Quick Installation Guide

### For Your Current Setup (localhost:5433)

To install all available extensions on your current PostgreSQL instance:

```powershell
# Windows PowerShell
cd c:\xampp\htdocs\postgres\windows

# Install built-in extensions
.\install_pg_stat_statements.ps1
.\install_postgres_fdw.ps1
.\install_intarray.ps1
.\install_timescaledb.ps1

# For PostGIS and ZomboDB, install binaries first (see above)
.\install_postgis.ps1
.\install_zombodb.ps1
```

## Troubleshooting

### Connection Issues
- Verify PostgreSQL is running
- Check the port number (default 5432, yours is 5433)
- Verify username and password
- Ensure the database exists

### Extension Not Found
- Check if binaries are installed: `SELECT * FROM pg_available_extensions WHERE name = 'extension_name';`
- For binary extensions (PostGIS, ZomboDB), install the binaries first
- Restart PostgreSQL after installing binaries

### Permission Errors
- Windows: Run PowerShell as Administrator
- Linux: Use `sudo` for package installations
- Ensure PostgreSQL user has CREATE EXTENSION privileges

### Version Mismatch
- Ensure extension version matches PostgreSQL version
- Example: PostgreSQL 16 requires pg16 extensions

## Extension Details

### pg_stat_statements
**Purpose:** Track execution statistics of SQL statements  
**Use Case:** Performance monitoring, query optimization  
**Configuration:** Add to `postgresql.conf`:
```ini
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all
```

### PostGIS
**Purpose:** Geographic objects and spatial queries  
**Use Case:** Location-based applications, GIS systems  
**Example:**
```sql
CREATE TABLE locations (
    id SERIAL PRIMARY KEY,
    name TEXT,
    geom GEOMETRY(Point, 4326)
);
```

### postgres_fdw
**Purpose:** Access remote PostgreSQL databases  
**Use Case:** Distributed databases, data federation  
**Example:**
```sql
CREATE SERVER remote_db
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host 'remote_host', dbname 'remote_db', port '5432');
```

### intarray
**Purpose:** Integer array operations  
**Use Case:** Working with sets of integers, tags, categories  
**Example:**
```sql
SELECT ARRAY[1,2,3] & ARRAY[2,3,4];  -- Returns {2,3}
```

### TimescaleDB
**Purpose:** Time-series data optimization  
**Use Case:** Metrics, IoT data, analytics  
**Example:**
```sql
CREATE TABLE metrics (
    time TIMESTAMPTZ NOT NULL,
    device_id INTEGER,
    value DOUBLE PRECISION
);
SELECT create_hypertable('metrics', 'time');
```

### ZomboDB
**Purpose:** Elasticsearch integration  
**Use Case:** Full-text search, analytics  
**Requirements:** Elasticsearch running  
**Example:**
```sql
CREATE INDEX idx_zdb ON documents
USING zombodb ((documents.*))
WITH (url='http://localhost:9200/');
```

## Download Links

- **PostgreSQL:** https://www.postgresql.org/download/
- **PostGIS:** https://postgis.net/windows_downloads/
- **ZomboDB:** https://github.com/zombodb/zombodb/releases
- **TimescaleDB:** https://www.timescale.com/download
- **Elasticsearch:** https://www.elastic.co/downloads/elasticsearch

## Support

For issues with specific extensions:
- **pg_stat_statements:** https://www.postgresql.org/docs/current/pgstatstatements.html
- **PostGIS:** https://postgis.net/documentation/
- **postgres_fdw:** https://www.postgresql.org/docs/current/postgres-fdw.html
- **intarray:** https://www.postgresql.org/docs/current/intarray.html
- **TimescaleDB:** https://docs.timescale.com/
- **ZomboDB:** https://github.com/zombodb/zombodb/wiki

## Notes

- All scripts prompt for connection details interactively
- Passwords are handled securely (hidden input on Linux, SecureString on Windows)
- Scripts verify connection before attempting installation
- Each script provides usage examples after successful installation
- Scripts check for binary availability before installation (PostGIS, ZomboDB)
