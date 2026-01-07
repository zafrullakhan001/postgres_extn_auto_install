# Install PostGIS Extension
# This extension adds support for geographic objects

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PostGIS Installation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Prompt for connection details
$pgHost = Read-Host "Enter PostgreSQL host (default: localhost)"
if ([string]::IsNullOrWhiteSpace($pgHost)) { $pgHost = "localhost" }

$pgPort = Read-Host "Enter PostgreSQL port (default: 5432)"
if ([string]::IsNullOrWhiteSpace($pgPort)) { $pgPort = "5432" }

$pgUser = Read-Host "Enter PostgreSQL username (default: postgres)"
if ([string]::IsNullOrWhiteSpace($pgUser)) { $pgUser = "postgres" }

$pgPassword = Read-Host "Enter PostgreSQL password" -AsSecureString
$pgPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pgPassword))

$pgDb = Read-Host "Enter database name (default: postgres)"
if ([string]::IsNullOrWhiteSpace($pgDb)) { $pgDb = "postgres" }

Write-Host ""

# Find psql
$psqlPath = $null
$possiblePaths = @(
    "C:\Program Files\PostgreSQL\16\bin\psql.exe",
    "C:\Program Files\PostgreSQL\15\bin\psql.exe",
    "C:\Program Files\PostgreSQL\14\bin\psql.exe",
    "C:\Program Files\pgAdmin 4\runtime\psql.exe"
)

foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $psqlPath = $path
        break
    }
}

if (-not $psqlPath) {
    Write-Host "ERROR: psql.exe not found!" -ForegroundColor Red
    exit 1
}

Write-Host "Using psql: $psqlPath" -ForegroundColor Gray
Write-Host ""

# Set password
$env:PGPASSWORD = $pgPasswordPlain

# Test connection
Write-Host "Testing connection..." -ForegroundColor Yellow
$test = & $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c "SELECT 1;" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Connection failed!" -ForegroundColor Red
    Remove-Item Env:\PGPASSWORD
    exit 1
}

Write-Host "Connection successful!" -ForegroundColor Green
Write-Host ""

# Check if PostGIS binaries are installed
Write-Host "Checking for PostGIS binaries..." -ForegroundColor Yellow
$checkAvailable = & $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -t -c "SELECT COUNT(*) FROM pg_available_extensions WHERE name = 'postgis';" 2>&1

if ($checkAvailable -match "0") {
    Write-Host ""
    Write-Host "WARNING: PostGIS binaries not found!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please install PostGIS binaries first:" -ForegroundColor Yellow
    Write-Host "1. Visit: https://postgis.net/windows_downloads/" -ForegroundColor White
    Write-Host "2. Download the installer for your PostgreSQL version" -ForegroundColor White
    Write-Host "3. Run the installer" -ForegroundColor White
    Write-Host "4. Re-run this script" -ForegroundColor White
    Write-Host ""
    
    $download = Read-Host "Would you like to open the download page? (y/n)"
    if ($download -eq "y") {
        Start-Process "https://postgis.net/windows_downloads/"
    }
    
    Remove-Item Env:\PGPASSWORD
    exit 1
}

Write-Host "PostGIS binaries found!" -ForegroundColor Green
Write-Host ""

# Install extension
Write-Host "Installing PostGIS..." -ForegroundColor Yellow
$output = & $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c "CREATE EXTENSION IF NOT EXISTS postgis;" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] PostGIS installed!" -ForegroundColor Green
}
else {
    Write-Host "[FAILED] Installation failed!" -ForegroundColor Red
    Write-Host $output -ForegroundColor Yellow
    Remove-Item Env:\PGPASSWORD
    exit 1
}

# Install optional extensions
Write-Host ""
Write-Host "Installing optional PostGIS extensions..." -ForegroundColor Yellow

$optionalExts = @("postgis_topology", "postgis_raster", "postgis_sfcgal")

foreach ($ext in $optionalExts) {
    Write-Host "  Installing $ext..." -ForegroundColor Gray -NoNewline
    $result = & $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c "CREATE EXTENSION IF NOT EXISTS $ext;" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host " [OK]" -ForegroundColor Green
    }
    else {
        Write-Host " [SKIP]" -ForegroundColor Yellow
    }
}

# Verify installation
Write-Host ""
Write-Host "Verifying installation..." -ForegroundColor Yellow
& $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c "SELECT PostGIS_Version();"
& $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c "SELECT extname, extversion FROM pg_extension WHERE extname LIKE 'postgis%';"

# Cleanup
Remove-Item Env:\PGPASSWORD

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Usage example:" -ForegroundColor Cyan
Write-Host "  -- Create table with geometry column" -ForegroundColor White
Write-Host "  CREATE TABLE locations (" -ForegroundColor White
Write-Host "    id SERIAL PRIMARY KEY," -ForegroundColor White
Write-Host "    name TEXT," -ForegroundColor White
Write-Host "    geom GEOMETRY(Point, 4326)" -ForegroundColor White
Write-Host "  );" -ForegroundColor White
Write-Host ""
Write-Host "  -- Insert a point" -ForegroundColor White
Write-Host "  INSERT INTO locations (name, geom)" -ForegroundColor White
Write-Host "  VALUES ('New York', ST_SetSRID(ST_MakePoint(-74.006, 40.7128), 4326));" -ForegroundColor White
