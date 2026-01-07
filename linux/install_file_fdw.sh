#!/bin/bash
# Install file_fdw Extension
# Foreign Data Wrapper for reading files as tables

echo "========================================"
echo "file_fdw Installation"
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

echo "Installing file_fdw..."
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "CREATE EXTENSION IF NOT EXISTS file_fdw;" 2>&1

if [ $? -eq 0 ]; then
    echo "[SUCCESS] file_fdw installed!"
else
    echo "[FAILED] Installation failed!"
    unset PGPASSWORD
    exit 1
fi

echo ""
echo "Verifying installation..."
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'file_fdw';"

unset PGPASSWORD

echo ""
echo "========================================"
echo "Installation Complete!"
echo "========================================"
echo ""
echo "Usage example:"
echo "  -- Create server"
echo "  CREATE SERVER file_server FOREIGN DATA WRAPPER file_fdw;"
echo ""
echo "  -- Create foreign table from CSV file"
echo "  CREATE FOREIGN TABLE my_csv ("
echo "    id INTEGER,"
echo "    name TEXT,"
echo "    value NUMERIC"
echo "  ) SERVER file_server"
echo "  OPTIONS (filename '/data/myfile.csv', format 'csv', header 'true');"
echo ""
echo "  -- Query the file"
echo "  SELECT * FROM my_csv;"
