#!/bin/bash
# Install intarray Extension
# Functions and operators for integer arrays

echo "========================================"
echo "intarray Installation"
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

echo "Installing intarray..."
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "CREATE EXTENSION IF NOT EXISTS intarray;" 2>&1

if [ $? -eq 0 ]; then
    echo "[SUCCESS] intarray installed!"
else
    echo "[FAILED] Installation failed!"
    unset PGPASSWORD
    exit 1
fi

echo ""
echo "Verifying installation..."
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'intarray';"

unset PGPASSWORD

echo ""
echo "========================================"
echo "Installation Complete!"
echo "========================================"
echo ""
echo "Usage example:"
echo "  SELECT ARRAY[1,2,3,4] & ARRAY[3,4,5,6];  -- Intersection"
echo "  SELECT ARRAY[1,2,3] @> ARRAY[2,3];       -- Contains"
