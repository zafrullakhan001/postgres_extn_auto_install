# Install pg_stat_statements Extension
# This extension tracks execution statistics of SQL statements

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "pg_stat_statements Installation" -ForegroundColor Cyan
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
    Write-Host "Please ensure PostgreSQL is installed." -ForegroundColor Yellow
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
    Write-Host $test -ForegroundColor Yellow
    Remove-Item Env:\PGPASSWORD
    exit 1
}

Write-Host "Connection successful!" -ForegroundColor Green
Write-Host ""

# Install extension
Write-Host "Installing pg_stat_statements..." -ForegroundColor Yellow
$output = & $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] pg_stat_statements installed!" -ForegroundColor Green
}
else {
    Write-Host "[FAILED] Installation failed!" -ForegroundColor Red
    Write-Host $output -ForegroundColor Yellow
    Remove-Item Env:\PGPASSWORD
    exit 1
}

# Verify installation
Write-Host ""
Write-Host "Verifying installation..." -ForegroundColor Yellow
& $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_stat_statements';"

# Cleanup
Remove-Item Env:\PGPASSWORD

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANT: For full functionality, add to postgresql.conf:" -ForegroundColor Yellow
Write-Host "  shared_preload_libraries = 'pg_stat_statements'" -ForegroundColor White
Write-Host "  pg_stat_statements.track = all" -ForegroundColor White
Write-Host ""
Write-Host "Then restart PostgreSQL service." -ForegroundColor Yellow
Write-Host ""
Write-Host "Usage example:" -ForegroundColor Cyan
Write-Host "  SELECT query, calls, total_exec_time" -ForegroundColor White
Write-Host "  FROM pg_stat_statements" -ForegroundColor White
Write-Host "  ORDER BY total_exec_time DESC LIMIT 10;" -ForegroundColor White
