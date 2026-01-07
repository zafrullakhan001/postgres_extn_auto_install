#!/bin/bash
# Install oracle_fdw Extension
# Foreign Data Wrapper for accessing Oracle databases

echo "========================================"
echo "oracle_fdw Installation"
echo "========================================"
echo ""

read -p "Enter PostgreSQL host (default: localhost): " PG_HOST
PG_HOST=${PG_HOST:-localhost}

read -p "Enter PostgreSQL port (default: 5432): " PG_PORT
PG_PORT=${PG_PORT:-5432}

read -p "Enter PostgreSQL username (default: postgres): " PG_USER
PG_USER=${PG_USER:-postgres}

read -sp "Enter PostgreSQL password: " PG_PASSWORD
echo ""

read -p "Enter database name (default: postgres): " PG_DB
PG_DB=${PG_DB:-postgres}

echo ""

export PGPASSWORD="$PG_PASSWORD"

echo "Testing connection..."
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "SELECT 1;" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "ERROR: Connection failed!"
    unset PGPASSWORD
    exit 1
fi

echo "Connection successful!"
echo ""

# Check if oracle_fdw is available
echo "Checking for oracle_fdw..."
AVAILABLE=$(psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -t -c "SELECT COUNT(*) FROM pg_available_extensions WHERE name = 'oracle_fdw';" 2>&1 | tr -d ' ')

if [ "$AVAILABLE" = "0" ]; then
    echo ""
    echo "WARNING: oracle_fdw not found!"
    echo ""
    echo "oracle_fdw requires Oracle Instant Client and compilation:"
    echo ""
    echo "1. Install Oracle Instant Client:"
    echo "   Download from: https://www.oracle.com/database/technologies/instant-client/downloads.html"
    echo "   Extract to /opt/oracle/instantclient"
    echo ""
    echo "2. Set environment variables:"
    echo "   export ORACLE_HOME=/opt/oracle/instantclient"
    echo "   export LD_LIBRARY_PATH=\$ORACLE_HOME:\$LD_LIBRARY_PATH"
    echo ""
    echo "3. Install oracle_fdw:"
    echo "   sudo apt-get install postgresql-server-dev-16 libaio1"
    echo "   git clone https://github.com/laurenz/oracle_fdw.git"
    echo "   cd oracle_fdw"
    echo "   make"
    echo "   sudo make install"
    echo ""
    unset PGPASSWORD
    exit 1
fi

echo "oracle_fdw found!"
echo ""

echo "Installing oracle_fdw..."
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "CREATE EXTENSION IF NOT EXISTS oracle_fdw;" 2>&1

if [ $? -eq 0 ]; then
    echo "[SUCCESS] oracle_fdw installed!"
else
    echo "[FAILED] Installation failed!"
    unset PGPASSWORD
    exit 1
fi

echo ""
echo "Verifying installation..."
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'oracle_fdw';"

unset PGPASSWORD

echo ""
echo "========================================"
echo "Installation Complete!"
echo "========================================"
echo ""
echo "Usage example:"
echo "  -- Create server"
echo "  CREATE SERVER oracle_server"
echo "  FOREIGN DATA WRAPPER oracle_fdw"
echo "  OPTIONS (dbserver '//oracle_host:1521/ORCL');"
echo ""
echo "  -- Create user mapping"
echo "  CREATE USER MAPPING FOR postgres"
echo "  SERVER oracle_server"
echo "  OPTIONS (user 'oracle_user', password 'oracle_password');"
echo ""
echo "  -- Create foreign table"
echo "  CREATE FOREIGN TABLE oracle_table ("
echo "    id INTEGER,"
echo "    name VARCHAR(100)"
echo "  ) SERVER oracle_server"
echo "  OPTIONS (schema 'SCHEMA_NAME', table 'TABLE_NAME');"
