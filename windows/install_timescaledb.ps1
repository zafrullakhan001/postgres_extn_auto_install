# Install TimescaleDB Extension
# Time-series database extension

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "TimescaleDB Installation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

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

$env:PGPASSWORD = $pgPasswordPlain

Write-Host "Testing connection..." -ForegroundColor Yellow
$test = & $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c "SELECT 1;" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Connection failed!" -ForegroundColor Red
    Remove-Item Env:\PGPASSWORD
    exit 1
}

Write-Host "Connection successful!" -ForegroundColor Green
Write-Host ""

Write-Host "Installing timescaledb..." -ForegroundColor Yellow
$output = & $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c "CREATE EXTENSION IF NOT EXISTS timescaledb;" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] timescaledb installed!" -ForegroundColor Green
}
else {
    Write-Host "[FAILED] Installation failed!" -ForegroundColor Red
    Write-Host $output -ForegroundColor Yellow
    Write-Host ""
    Write-Host "If TimescaleDB is not available, install it from:" -ForegroundColor Yellow
    Write-Host "https://www.timescale.com/download" -ForegroundColor White
    Remove-Item Env:\PGPASSWORD
    exit 1
}

Write-Host ""
Write-Host "Verifying installation..." -ForegroundColor Yellow
& $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'timescaledb';"

Remove-Item Env:\PGPASSWORD

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Usage example:" -ForegroundColor Cyan
Write-Host "  CREATE TABLE metrics (" -ForegroundColor White
Write-Host "    time TIMESTAMPTZ NOT NULL," -ForegroundColor White
Write-Host "    device_id INTEGER," -ForegroundColor White
Write-Host "    temperature DOUBLE PRECISION" -ForegroundColor White
Write-Host "  );" -ForegroundColor White
Write-Host "  SELECT create_hypertable('metrics', 'time');" -ForegroundColor White
