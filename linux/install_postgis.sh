#!/bin/bash
# Install PostGIS Extension
# This extension adds support for geographic objects

echo "========================================"
echo "PostGIS Installation"
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
    unset PGPASSWORD
    exit 1
fi

echo "Connection successful!"
echo ""

# Check if PostGIS is available
echo "Checking for PostGIS binaries..."
AVAILABLE=$(psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -t -c "SELECT COUNT(*) FROM pg_available_extensions WHERE name = 'postgis';" 2>&1 | tr -d ' ')

if [ "$AVAILABLE" = "0" ]; then
    echo ""
    echo "WARNING: PostGIS binaries not found!"
    echo ""
    echo "Please install PostGIS binaries first:"
    echo ""
    echo "For Ubuntu/Debian:"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install postgresql-16-postgis-3"
    echo ""
    echo "For CentOS/RHEL:"
    echo "  sudo yum install postgis34_16"
    echo ""
    echo "For Fedora:"
    echo "  sudo dnf install postgis"
    echo ""
    echo "Then re-run this script."
    unset PGPASSWORD
    exit 1
fi

echo "PostGIS binaries found!"
echo ""

# Install extension
echo "Installing PostGIS..."
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "CREATE EXTENSION IF NOT EXISTS postgis;" 2>&1

if [ $? -eq 0 ]; then
    echo "[SUCCESS] PostGIS installed!"
else
    echo "[FAILED] Installation failed!"
    unset PGPASSWORD
    exit 1
fi

# Install optional extensions
echo ""
echo "Installing optional PostGIS extensions..."

for ext in postgis_topology postgis_raster postgis_sfcgal; do
    echo -n "  Installing $ext..."
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "CREATE EXTENSION IF NOT EXISTS $ext;" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo " [OK]"
    else
        echo " [SKIP]"
    fi
done

# Verify installation
echo ""
echo "Verifying installation..."
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "SELECT PostGIS_Version();"
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "SELECT extname, extversion FROM pg_extension WHERE extname LIKE 'postgis%';"

# Cleanup
unset PGPASSWORD

echo ""
echo "========================================"
echo "Installation Complete!"
echo "========================================"
echo ""
echo "Usage example:"
echo "  -- Create table with geometry column"
echo "  CREATE TABLE locations ("
echo "    id SERIAL PRIMARY KEY,"
echo "    name TEXT,"
echo "    geom GEOMETRY(Point, 4326)"
echo "  );"
echo ""
echo "  -- Insert a point"
echo "  INSERT INTO locations (name, geom)"
echo "  VALUES ('New York', ST_SetSRID(ST_MakePoint(-74.006, 40.7128), 4326));"
