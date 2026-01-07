# Install ZomboDB Extension
# Elasticsearch integration for PostgreSQL

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ZomboDB Installation" -ForegroundColor Cyan
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

# Check if ZomboDB binaries are installed
Write-Host "Checking for ZomboDB binaries..." -ForegroundColor Yellow
$checkAvailable = & $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -t -c "SELECT COUNT(*) FROM pg_available_extensions WHERE name = 'zombodb';" 2>&1

if ($checkAvailable -match "0") {
    Write-Host ""
    Write-Host "WARNING: ZomboDB binaries not found!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please install ZomboDB binaries first:" -ForegroundColor Yellow
    Write-Host "1. Visit: https://github.com/zombodb/zombodb/releases" -ForegroundColor White
    Write-Host "2. Download the ZIP for your PostgreSQL version" -ForegroundColor White
    Write-Host "3. Extract and copy files to PostgreSQL directories:" -ForegroundColor White
    Write-Host "   - zombodb.dll -> PostgreSQL\16\lib\" -ForegroundColor Gray
    Write-Host "   - zombodb.control -> PostgreSQL\16\share\extension\" -ForegroundColor Gray
    Write-Host "   - zombodb--*.sql -> PostgreSQL\16\share\extension\" -ForegroundColor Gray
    Write-Host "4. Ensure Elasticsearch is running" -ForegroundColor White
    Write-Host "5. Re-run this script" -ForegroundColor White
    Write-Host ""
    
    $download = Read-Host "Would you like to open the download page? (y/n)"
    if ($download -eq "y") {
        Start-Process "https://github.com/zombodb/zombodb/releases"
    }
    
    Remove-Item Env:\PGPASSWORD
    exit 1
}

Write-Host "ZomboDB binaries found!" -ForegroundColor Green
Write-Host ""

Write-Host "Installing zombodb..." -ForegroundColor Yellow
$output = & $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c "CREATE EXTENSION IF NOT EXISTS zombodb;" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] zombodb installed!" -ForegroundColor Green
}
else {
    Write-Host "[FAILED] Installation failed!" -ForegroundColor Red
    Write-Host $output -ForegroundColor Yellow
    Remove-Item Env:\PGPASSWORD
    exit 1
}

Write-Host ""
Write-Host "Verifying installation..." -ForegroundColor Yellow
& $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'zombodb';"

Remove-Item Env:\PGPASSWORD

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANT: Ensure Elasticsearch is running!" -ForegroundColor Yellow
Write-Host ""
Write-Host "Usage example:" -ForegroundColor Cyan
Write-Host "  CREATE INDEX idx_zdb ON mytable" -ForegroundColor White
Write-Host "  USING zombodb ((mytable.*))" -ForegroundColor White
Write-Host "  WITH (url='http://localhost:9200/');" -ForegroundColor White
