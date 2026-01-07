#!/bin/bash
# Install postgres_fdw Extension
# Foreign Data Wrapper for accessing remote PostgreSQL servers

echo "========================================"
echo "postgres_fdw Installation"
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

echo "Installing postgres_fdw..."
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "CREATE EXTENSION IF NOT EXISTS postgres_fdw;" 2>&1

if [ $? -eq 0 ]; then
    echo "[SUCCESS] postgres_fdw installed!"
else
    echo "[FAILED] Installation failed!"
    unset PGPASSWORD
    exit 1
fi

echo ""
echo "Verifying installation..."
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'postgres_fdw';"

unset PGPASSWORD

echo ""
echo "========================================"
echo "Installation Complete!"
echo "========================================"
echo ""
echo "Usage example:"
echo "  CREATE SERVER foreign_server"
echo "  FOREIGN DATA WRAPPER postgres_fdw"
echo "  OPTIONS (host 'remote_host', dbname 'remote_db', port '5432');"
