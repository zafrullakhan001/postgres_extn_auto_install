# Install mysql_fdw Extension
# Foreign Data Wrapper for accessing MySQL/MariaDB databases

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "mysql_fdw Installation" -ForegroundColor Cyan
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

# Check if mysql_fdw is available
Write-Host "Checking for mysql_fdw..." -ForegroundColor Yellow
$checkAvailable = & $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -t -c "SELECT COUNT(*) FROM pg_available_extensions WHERE name = 'mysql_fdw';" 2>&1

if ($checkAvailable -match "0") {
    Write-Host ""
    Write-Host "WARNING: mysql_fdw binaries not found!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "mysql_fdw requires separate installation:" -ForegroundColor Yellow
    Write-Host "1. Visit: https://github.com/EnterpriseDB/mysql_fdw" -ForegroundColor White
    Write-Host "2. Download or compile the extension" -ForegroundColor White
    Write-Host "3. Install MySQL client libraries" -ForegroundColor White
    Write-Host "4. Copy files to PostgreSQL directories" -ForegroundColor White
    Write-Host "5. Re-run this script" -ForegroundColor White
    Write-Host ""
    
    $download = Read-Host "Would you like to open the GitHub page? (y/n)"
    if ($download -eq "y") {
        Start-Process "https://github.com/EnterpriseDB/mysql_fdw"
    }
    
    Remove-Item Env:\PGPASSWORD
    exit 1
}

Write-Host "mysql_fdw found!" -ForegroundColor Green
Write-Host ""

Write-Host "Installing mysql_fdw..." -ForegroundColor Yellow
$output = & $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c "CREATE EXTENSION IF NOT EXISTS mysql_fdw;" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] mysql_fdw installed!" -ForegroundColor Green
}
else {
    Write-Host "[FAILED] Installation failed!" -ForegroundColor Red
    Write-Host $output -ForegroundColor Yellow
    Remove-Item Env:\PGPASSWORD
    exit 1
}

Write-Host ""
Write-Host "Verifying installation..." -ForegroundColor Yellow
& $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'mysql_fdw';"

Remove-Item Env:\PGPASSWORD

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Usage example:" -ForegroundColor Cyan
Write-Host "  -- Create server" -ForegroundColor White
Write-Host "  CREATE SERVER mysql_server" -ForegroundColor White
Write-Host "  FOREIGN DATA WRAPPER mysql_fdw" -ForegroundColor White
Write-Host "  OPTIONS (host 'mysql_host', port '3306');" -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "  -- Create user mapping" -ForegroundColor White
Write-Host "  CREATE USER MAPPING FOR postgres" -ForegroundColor White
Write-Host "  SERVER mysql_server" -ForegroundColor White
Write-Host "  OPTIONS (username 'mysql_user', password 'mysql_password');" -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "  -- Import foreign schema" -ForegroundColor White
Write-Host "  IMPORT FOREIGN SCHEMA mysql_db" -ForegroundColor White
Write-Host "  FROM SERVER mysql_server INTO public;" -ForegroundColor White
