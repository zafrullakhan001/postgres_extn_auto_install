#!/bin/bash
# Install ZomboDB Extension
# Elasticsearch integration for PostgreSQL

echo "========================================"
echo "ZomboDB Installation"
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

# Check if ZomboDB is available
echo "Checking for ZomboDB..."
AVAILABLE=$(psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -t -c "SELECT COUNT(*) FROM pg_available_extensions WHERE name = 'zombodb';" 2>&1 | tr -d ' ')

if [ "$AVAILABLE" = "0" ]; then
    echo ""
    echo "WARNING: ZomboDB not found!"
    echo ""
    echo "Please install ZomboDB first:"
    echo ""
    echo "Method 1: From Package (if available for your distro)"
    echo "  Visit: https://github.com/zombodb/zombodb/releases"
    echo "  Download the appropriate .deb or .rpm package"
    echo ""
    echo "Method 2: Build from source"
    echo "  # Install dependencies"
    echo "  sudo apt-get install build-essential libpq-dev postgresql-server-dev-16 curl git"
    echo "  "
    echo "  # Install Rust"
    echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    echo "  source \$HOME/.cargo/env"
    echo "  "
    echo "  # Install cargo-pgrx"
    echo "  cargo install --locked cargo-pgrx"
    echo "  cargo pgrx init --pg16 /usr/bin/pg_config"
    echo "  "
    echo "  # Clone and build ZomboDB"
    echo "  git clone https://github.com/zombodb/zombodb.git"
    echo "  cd zombodb"
    echo "  cargo pgrx install --release"
    echo ""
    echo "IMPORTANT: Ensure Elasticsearch is installed and running!"
    echo "  Download from: https://www.elastic.co/downloads/elasticsearch"
    echo ""
    unset PGPASSWORD
    exit 1
fi

echo "ZomboDB found!"
echo ""

echo "Installing zombodb..."
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "CREATE EXTENSION IF NOT EXISTS zombodb;" 2>&1

if [ $? -eq 0 ]; then
    echo "[SUCCESS] zombodb installed!"
else
    echo "[FAILED] Installation failed!"
    unset PGPASSWORD
    exit 1
fi

echo ""
echo "Verifying installation..."
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'zombodb';"

unset PGPASSWORD

echo ""
echo "========================================"
echo "Installation Complete!"
echo "========================================"
echo ""
echo "IMPORTANT: Ensure Elasticsearch is running!"
echo ""
echo "Usage example:"
echo "  CREATE INDEX idx_zdb ON mytable"
echo "  USING zombodb ((mytable.*))"
echo "  WITH (url='http://localhost:9200/');"
