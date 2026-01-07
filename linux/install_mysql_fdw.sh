#!/bin/bash
# Install mysql_fdw Extension
# Foreign Data Wrapper for accessing MySQL/MariaDB databases

echo "========================================"
echo "mysql_fdw Installation"
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

# Check if mysql_fdw is available
echo "Checking for mysql_fdw..."
AVAILABLE=$(psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -t -c "SELECT COUNT(*) FROM pg_available_extensions WHERE name = 'mysql_fdw';" 2>&1 | tr -d ' ')

if [ "$AVAILABLE" = "0" ]; then
    echo ""
    echo "WARNING: mysql_fdw not found!"
    echo ""
    echo "Please install mysql_fdw first:"
    echo ""
    echo "For Ubuntu/Debian:"
    echo "  sudo apt-get install postgresql-16-mysql-fdw"
    echo "  # Or compile from source:"
    echo "  sudo apt-get install libmysqlclient-dev postgresql-server-dev-16"
    echo "  git clone https://github.com/EnterpriseDB/mysql_fdw.git"
    echo "  cd mysql_fdw"
    echo "  make USE_PGXS=1"
    echo "  sudo make USE_PGXS=1 install"
    echo ""
    echo "For CentOS/RHEL:"
    echo "  sudo yum install mysql-devel postgresql16-devel"
    echo "  git clone https://github.com/EnterpriseDB/mysql_fdw.git"
    echo "  cd mysql_fdw"
    echo "  make USE_PGXS=1"
    echo "  sudo make USE_PGXS=1 install"
    echo ""
    unset PGPASSWORD
    exit 1
fi

echo "mysql_fdw found!"
echo ""

echo "Installing mysql_fdw..."
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "CREATE EXTENSION IF NOT EXISTS mysql_fdw;" 2>&1

if [ $? -eq 0 ]; then
    echo "[SUCCESS] mysql_fdw installed!"
else
    echo "[FAILED] Installation failed!"
    unset PGPASSWORD
    exit 1
fi

echo ""
echo "Verifying installation..."
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'mysql_fdw';"

unset PGPASSWORD

echo ""
echo "========================================"
echo "Installation Complete!"
echo "========================================"
echo ""
echo "Usage example:"
echo "  -- Create server"
echo "  CREATE SERVER mysql_server"
echo "  FOREIGN DATA WRAPPER mysql_fdw"
echo "  OPTIONS (host 'mysql_host', port '3306');"
echo ""
echo "  -- Create user mapping"
echo "  CREATE USER MAPPING FOR postgres"
echo "  SERVER mysql_server"
echo "  OPTIONS (username 'mysql_user', password 'mysql_password');"
echo ""
echo "  -- Import foreign schema"
echo "  IMPORT FOREIGN SCHEMA mysql_db"
echo "  FROM SERVER mysql_server INTO public;"
