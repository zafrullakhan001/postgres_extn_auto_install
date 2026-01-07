#!/bin/bash
# Install TimescaleDB Extension
# Time-series database extension

echo "========================================"
echo "TimescaleDB Installation"
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

# Check if TimescaleDB is available
echo "Checking for TimescaleDB..."
AVAILABLE=$(psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -t -c "SELECT COUNT(*) FROM pg_available_extensions WHERE name = 'timescaledb';" 2>&1 | tr -d ' ')

if [ "$AVAILABLE" = "0" ]; then
    echo ""
    echo "WARNING: TimescaleDB not found!"
    echo ""
    echo "Please install TimescaleDB first:"
    echo ""
    echo "For Ubuntu/Debian:"
    echo "  sudo apt install gnupg postgresql-common apt-transport-https lsb-release wget"
    echo "  sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh"
    echo "  echo \"deb https://packagecloud.io/timescale/timescaledb/ubuntu/ \$(lsb_release -c -s) main\" | sudo tee /etc/apt/sources.list.d/timescaledb.list"
    echo "  wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | sudo apt-key add -"
    echo "  sudo apt update"
    echo "  sudo apt install timescaledb-2-postgresql-16"
    echo ""
    echo "For CentOS/RHEL:"
    echo "  sudo tee /etc/yum.repos.d/timescale_timescaledb.repo <<EOL"
    echo "  [timescale_timescaledb]"
    echo "  name=timescale_timescaledb"
    echo "  baseurl=https://packagecloud.io/timescale/timescaledb/el/\$(rpm -E %{rhel})/\$basearch"
    echo "  repo_gpgcheck=1"
    echo "  gpgcheck=0"
    echo "  enabled=1"
    echo "  gpgkey=https://packagecloud.io/timescale/timescaledb/gpgkey"
    echo "  EOL"
    echo "  sudo yum install timescaledb-2-postgresql-16"
    echo ""
    echo "Then run: sudo timescaledb-tune"
    echo "And restart PostgreSQL: sudo systemctl restart postgresql"
    unset PGPASSWORD
    exit 1
fi

echo "TimescaleDB found!"
echo ""

echo "Installing timescaledb..."
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "CREATE EXTENSION IF NOT EXISTS timescaledb;" 2>&1

if [ $? -eq 0 ]; then
    echo "[SUCCESS] timescaledb installed!"
else
    echo "[FAILED] Installation failed!"
    unset PGPASSWORD
    exit 1
fi

echo ""
echo "Verifying installation..."
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'timescaledb';"

unset PGPASSWORD

echo ""
echo "========================================"
echo "Installation Complete!"
echo "========================================"
echo ""
echo "Usage example:"
echo "  CREATE TABLE metrics ("
echo "    time TIMESTAMPTZ NOT NULL,"
echo "    device_id INTEGER,"
echo "    temperature DOUBLE PRECISION"
echo "  );"
echo "  SELECT create_hypertable('metrics', 'time');"
