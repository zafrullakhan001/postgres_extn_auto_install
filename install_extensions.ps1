# PostgreSQL Extensions Installer
# Configuration
$pgHost = "localhost"
$pgPort = "5433"
$pgUser = "postgres"
$pgPassword = "password"
$pgDb = "postgres"
$psqlPath = "C:\Program Files\pgAdmin 4\runtime\psql.exe"

# Set password environment variable
$env:PGPASSWORD = $pgPassword

Write-Host "PostgreSQL Extensions Installer" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Test connection
Write-Host "Testing connection..." -ForegroundColor Yellow
$test = & $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c "SELECT 1;" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "Connection failed!" -ForegroundColor Red
    Write-Host $test -ForegroundColor Yellow
    exit 1
}

Write-Host "Connection successful!" -ForegroundColor Green
Write-Host ""

# Extensions list
$extensions = @(
    "pg_stat_statements",
    "postgis",
    "postgres_fdw",
    "intarray",
    "zombodb",
    "timescaledb",
    "postpic",
    "pg_sphere"
)

$results = @()

Write-Host "Installing extensions..." -ForegroundColor Cyan
Write-Host ""

foreach ($ext in $extensions) {
    Write-Host "  [$ext]..." -ForegroundColor Yellow -NoNewline
    
    $output = & $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c "CREATE EXTENSION IF NOT EXISTS $ext;" 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host " [OK]" -ForegroundColor Green
        $results += [PSCustomObject]@{Extension = $ext; Status = "Installed" }
    }
    else {
        if ($output -match "could not open extension control file") {
            Write-Host " [NOT AVAILABLE]" -ForegroundColor Yellow
            $results += [PSCustomObject]@{Extension = $ext; Status = "Not Available" }
        }
        else {
            Write-Host " [FAILED]" -ForegroundColor Red
            $results += [PSCustomObject]@{Extension = $ext; Status = "Failed" }
        }
    }
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
$results | Format-Table -AutoSize

Write-Host ""
Write-Host "All Installed Extensions:" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
& $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c "SELECT extname, extversion FROM pg_extension ORDER BY extname;"

# Cleanup
Remove-Item Env:\PGPASSWORD

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
Write-Host ""
Write-Host "Note: Extensions marked 'Not Available' need separate installation:" -ForegroundColor Yellow
Write-Host "  - PostGIS: https://postgis.net/windows_downloads/" -ForegroundColor Gray
Write-Host "  - ZomboDB: https://github.com/zombodb/zombodb" -ForegroundColor Gray
Write-Host "  - TimescaleDB: https://www.timescale.com/download" -ForegroundColor Gray
