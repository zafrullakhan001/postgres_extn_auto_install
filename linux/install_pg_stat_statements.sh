#!/bin/bash
# Install pg_stat_statements Extension
# This extension tracks execution statistics of SQL statements

echo "========================================"
echo "pg_stat_statements Installation"
echo "========================================"
echo ""

# Prompt for connection details
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

# Set password environment variable
export PGPASSWORD="$PG_PASSWORD"

# Test connection
echo "Testing connection..."
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "SELECT 1;" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "ERROR: Connection failed!"
    echo "Please check your connection details."
    unset PGPASSWORD
    exit 1
fi

echo "Connection successful!"
echo ""

# Install extension
echo "Installing pg_stat_statements..."
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;" 2>&1

if [ $? -eq 0 ]; then
    echo "[SUCCESS] pg_stat_statements installed!"
else
    echo "[FAILED] Installation failed!"
    unset PGPASSWORD
    exit 1
fi

# Verify installation
echo ""
echo "Verifying installation..."
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_stat_statements';"

# Cleanup
unset PGPASSWORD

echo ""
echo "========================================"
echo "Installation Complete!"
echo "========================================"
echo ""
echo "IMPORTANT: For full functionality, add to postgresql.conf:"
echo "  shared_preload_libraries = 'pg_stat_statements'"
echo "  pg_stat_statements.track = all"
echo ""
echo "Then restart PostgreSQL service:"
echo "  sudo systemctl restart postgresql"
echo ""
echo "Usage example:"
echo "  SELECT query, calls, total_exec_time"
echo "  FROM pg_stat_statements"
echo "  ORDER BY total_exec_time DESC LIMIT 10;"
