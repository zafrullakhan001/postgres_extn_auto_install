# Install oracle_fdw Extension
# Foreign Data Wrapper for accessing Oracle databases

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "oracle_fdw Installation" -ForegroundColor Cyan
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

# Check if oracle_fdw is available
Write-Host "Checking for oracle_fdw..." -ForegroundColor Yellow
$checkAvailable = & $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -t -c "SELECT COUNT(*) FROM pg_available_extensions WHERE name = 'oracle_fdw';" 2>&1

if ($checkAvailable -match "0") {
    Write-Host ""
    Write-Host "WARNING: oracle_fdw binaries not found!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "oracle_fdw requires:" -ForegroundColor Yellow
    Write-Host "1. Oracle Instant Client installed" -ForegroundColor White
    Write-Host "   Download: https://www.oracle.com/database/technologies/instant-client/downloads.html" -ForegroundColor Gray
    Write-Host "2. oracle_fdw extension compiled and installed" -ForegroundColor White
    Write-Host "   GitHub: https://github.com/laurenz/oracle_fdw" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Installation steps:" -ForegroundColor Yellow
    Write-Host "1. Install Oracle Instant Client" -ForegroundColor White
    Write-Host "2. Set ORACLE_HOME environment variable" -ForegroundColor White
    Write-Host "3. Download oracle_fdw source" -ForegroundColor White
    Write-Host "4. Compile with Visual Studio (Windows)" -ForegroundColor White
    Write-Host "5. Copy files to PostgreSQL directories" -ForegroundColor White
    Write-Host ""
    
    $download = Read-Host "Would you like to open the oracle_fdw GitHub page? (y/n)"
    if ($download -eq "y") {
        Start-Process "https://github.com/laurenz/oracle_fdw"
    }
    
    Remove-Item Env:\PGPASSWORD
    exit 1
}

Write-Host "oracle_fdw found!" -ForegroundColor Green
Write-Host ""

Write-Host "Installing oracle_fdw..." -ForegroundColor Yellow
$output = & $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c "CREATE EXTENSION IF NOT EXISTS oracle_fdw;" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] oracle_fdw installed!" -ForegroundColor Green
}
else {
    Write-Host "[FAILED] Installation failed!" -ForegroundColor Red
    Write-Host $output -ForegroundColor Yellow
    Remove-Item Env:\PGPASSWORD
    exit 1
}

Write-Host ""
Write-Host "Verifying installation..." -ForegroundColor Yellow
& $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'oracle_fdw';"

Remove-Item Env:\PGPASSWORD

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Usage example:" -ForegroundColor Cyan
Write-Host "  -- Create server" -ForegroundColor White
Write-Host "  CREATE SERVER oracle_server" -ForegroundColor White
Write-Host "  FOREIGN DATA WRAPPER oracle_fdw" -ForegroundColor White
Write-Host "  OPTIONS (dbserver '//oracle_host:1521/ORCL');" -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "  -- Create user mapping" -ForegroundColor White
Write-Host "  CREATE USER MAPPING FOR postgres" -ForegroundColor White
Write-Host "  SERVER oracle_server" -ForegroundColor White
Write-Host "  OPTIONS (user 'oracle_user', password 'oracle_password');" -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "  -- Create foreign table" -ForegroundColor White
Write-Host "  CREATE FOREIGN TABLE oracle_table (" -ForegroundColor White
Write-Host "    id INTEGER," -ForegroundColor White
Write-Host "    name VARCHAR(100)" -ForegroundColor White
Write-Host "  ) SERVER oracle_server" -ForegroundColor White
Write-Host "  OPTIONS (schema 'SCHEMA_NAME', table 'TABLE_NAME');" -ForegroundColor White
