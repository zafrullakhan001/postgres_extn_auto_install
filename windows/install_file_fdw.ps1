# Install file_fdw Extension
# Foreign Data Wrapper for reading files as tables

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "file_fdw Installation" -ForegroundColor Cyan
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

Write-Host "Installing file_fdw..." -ForegroundColor Yellow
$output = & $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c "CREATE EXTENSION IF NOT EXISTS file_fdw;" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] file_fdw installed!" -ForegroundColor Green
}
else {
    Write-Host "[FAILED] Installation failed!" -ForegroundColor Red
    Write-Host $output -ForegroundColor Yellow
    Remove-Item Env:\PGPASSWORD
    exit 1
}

Write-Host ""
Write-Host "Verifying installation..." -ForegroundColor Yellow
& $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'file_fdw';"

Remove-Item Env:\PGPASSWORD

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Usage example:" -ForegroundColor Cyan
Write-Host "  -- Create server" -ForegroundColor White
Write-Host "  CREATE SERVER file_server FOREIGN DATA WRAPPER file_fdw;" -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "  -- Create foreign table from CSV file" -ForegroundColor White
Write-Host "  CREATE FOREIGN TABLE my_csv (" -ForegroundColor White
Write-Host "    id INTEGER," -ForegroundColor White
Write-Host "    name TEXT," -ForegroundColor White
Write-Host "    value NUMERIC" -ForegroundColor White
Write-Host "  ) SERVER file_server" -ForegroundColor White
Write-Host "  OPTIONS (filename 'C:/data/myfile.csv', format 'csv', header 'true');" -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "  -- Query the file" -ForegroundColor White
Write-Host "  SELECT * FROM my_csv;" -ForegroundColor White
