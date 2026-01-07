# PostgreSQL Extensions Installer
$env:PGPASSWORD = 'password'
$pgHost = 'localhost'
$pgPort = '5433'
$pgUser = 'postgres'
$pgDb = 'postgres'

# Set psql path
$psqlPath = 'C:\Program Files\pgAdmin 4\runtime\psql.exe'

if (-not (Test-Path $psqlPath)) {
    Write-Host 'psql.exe not found at expected location!' -ForegroundColor Red
    Write-Host 'Please update the script with the correct path to psql.exe' -ForegroundColor Yellow
    exit 1
}

Write-Host 'PostgreSQL Extensions Installer' -ForegroundColor Cyan
Write-Host '================================' -ForegroundColor Cyan
Write-Host ''

# Test connection
Write-Host 'Testing connection...' -ForegroundColor Yellow
& $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c 'SELECT version();'

if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host 'Connection failed!' -ForegroundColor Red
    Write-Host 'Please ensure:' -ForegroundColor Yellow
    Write-Host '  - PostgreSQL is running on port 5433' -ForegroundColor Yellow
    Write-Host '  - User postgres exists with password: password' -ForegroundColor Yellow
    exit 1
}

Write-Host ''
Write-Host 'Connection successful!' -ForegroundColor Green
Write-Host ''

# Install extensions
$extensions = @(
    'pg_stat_statements',
    'postgis',
    'postgres_fdw',
    'intarray',
    'zombodb',
    'timescaledb',
    'postpic',
    'pg_sphere'
)

$results = @()

Write-Host 'Installing extensions...' -ForegroundColor Cyan
Write-Host ''

foreach ($ext in $extensions) {
    Write-Host \"  Installing $ext...\" -ForegroundColor Yellow -NoNewline
    $output = & $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c \"CREATE EXTENSION IF NOT EXISTS $ext;\" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host \" [OK]\" -ForegroundColor Green
        $results += [PSCustomObject]@{Extension=$ext; Status='Installed'}
    } else {
        Write-Host \" [FAIL]\" -ForegroundColor Red
        $results += [PSCustomObject]@{Extension=$ext; Status='Failed'}
    }
}

Write-Host ''
Write-Host '================================' -ForegroundColor Cyan
Write-Host 'Installation Summary' -ForegroundColor Cyan
Write-Host '================================' -ForegroundColor Cyan
$results | Format-Table -AutoSize

Write-Host ''
Write-Host 'All Installed Extensions:' -ForegroundColor Cyan
Write-Host '================================' -ForegroundColor Cyan
& $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $pgDb -c 'SELECT extname, extversion FROM pg_extension ORDER BY extname;'

Remove-Item Env:\PGPASSWORD
Write-Host ''
Write-Host 'Done!' -ForegroundColor Green
