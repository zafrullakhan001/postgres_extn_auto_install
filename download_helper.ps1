# Download Helper for PostGIS and ZomboDB
# This script opens the download pages for required binaries

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PostgreSQL Extensions Download Helper" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Detect PostgreSQL version
Write-Host "Detecting PostgreSQL installation..." -ForegroundColor Yellow

$pgVersions = @()
$pgPaths = @(
    "C:\Program Files\PostgreSQL\16",
    "C:\Program Files\PostgreSQL\15",
    "C:\Program Files\PostgreSQL\14",
    "C:\Program Files\PostgreSQL\13"
)

foreach ($path in $pgPaths) {
    if (Test-Path $path) {
        $version = Split-Path $path -Leaf
        $pgVersions += $version
        Write-Host "  Found PostgreSQL $version at: $path" -ForegroundColor Green
    }
}

if ($pgVersions.Count -eq 0) {
    Write-Host "  No PostgreSQL installation detected in standard locations" -ForegroundColor Yellow
    $pgVersion = Read-Host "Enter your PostgreSQL version (e.g., 16, 15, 14)"
}
elseif ($pgVersions.Count -eq 1) {
    $pgVersion = $pgVersions[0]
    Write-Host "  Using PostgreSQL $pgVersion" -ForegroundColor Green
}
else {
    Write-Host "  Multiple PostgreSQL versions found: $($pgVersions -join ', ')" -ForegroundColor Yellow
    $pgVersion = Read-Host "Enter the version you want to use"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Download Links for PostgreSQL $pgVersion" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# PostGIS
Write-Host "1. PostGIS" -ForegroundColor Green
Write-Host "   Description: Geographic objects support" -ForegroundColor Gray
Write-Host "   Download: https://postgis.net/windows_downloads/" -ForegroundColor White
Write-Host "   Look for: postgis-bundle-pg$pgVersion-3.4.x-x64.exe" -ForegroundColor Yellow
Write-Host ""

$openPostGIS = Read-Host "   Open PostGIS download page? (y/n)"
if ($openPostGIS -eq "y") {
    Start-Process "https://postgis.net/windows_downloads/"
    Write-Host "   Opened in browser!" -ForegroundColor Green
}

Write-Host ""

# Elasticsearch (for ZomboDB)
Write-Host "2. Elasticsearch (Required for ZomboDB)" -ForegroundColor Green
Write-Host "   Description: Search and analytics engine" -ForegroundColor Gray
Write-Host "   Download: https://www.elastic.co/downloads/elasticsearch" -ForegroundColor White
Write-Host "   Recommended: Latest 8.x version" -ForegroundColor Yellow
Write-Host ""

$openElastic = Read-Host "   Open Elasticsearch download page? (y/n)"
if ($openElastic -eq "y") {
    Start-Process "https://www.elastic.co/downloads/elasticsearch"
    Write-Host "   Opened in browser!" -ForegroundColor Green
}

Write-Host ""

# ZomboDB
Write-Host "3. ZomboDB" -ForegroundColor Green
Write-Host "   Description: Elasticsearch integration for PostgreSQL" -ForegroundColor Gray
Write-Host "   Download: https://github.com/zombodb/zombodb/releases" -ForegroundColor White
Write-Host "   Look for: zombodb-pg$pgVersion-X.X.X.zip" -ForegroundColor Yellow
Write-Host ""

$openZomboDB = Read-Host "   Open ZomboDB releases page? (y/n)"
if ($openZomboDB -eq "y") {
    Start-Process "https://github.com/zombodb/zombodb/releases"
    Write-Host "   Opened in browser!" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installation Instructions" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "PostGIS Installation:" -ForegroundColor Yellow
Write-Host "  1. Download the PostGIS installer" -ForegroundColor White
Write-Host "  2. Run the .exe file" -ForegroundColor White
Write-Host "  3. Follow the installation wizard" -ForegroundColor White
Write-Host "  4. Run: .\windows\install_postgis.ps1" -ForegroundColor White
Write-Host ""

Write-Host "ZomboDB Installation:" -ForegroundColor Yellow
Write-Host "  1. Install Elasticsearch first" -ForegroundColor White
Write-Host "  2. Start Elasticsearch (verify at http://localhost:9200)" -ForegroundColor White
Write-Host "  3. Download ZomboDB ZIP file" -ForegroundColor White
Write-Host "  4. Extract the ZIP" -ForegroundColor White
Write-Host "  5. Copy files to PostgreSQL directories:" -ForegroundColor White
Write-Host "     - zombodb.dll -> C:\Program Files\PostgreSQL\$pgVersion\lib\" -ForegroundColor Gray
Write-Host "     - zombodb.control -> C:\Program Files\PostgreSQL\$pgVersion\share\extension\" -ForegroundColor Gray
Write-Host "     - zombodb--*.sql -> C:\Program Files\PostgreSQL\$pgVersion\share\extension\" -ForegroundColor Gray
Write-Host "  6. Restart PostgreSQL service" -ForegroundColor White
Write-Host "  7. Run: .\windows\install_zombodb.ps1" -ForegroundColor White
Write-Host ""

Write-Host "For detailed instructions, see:" -ForegroundColor Cyan
Write-Host "  BINARY_INSTALLATION_GUIDE.md" -ForegroundColor White
Write-Host ""

$openGuide = Read-Host "Open the detailed installation guide? (y/n)"
if ($openGuide -eq "y") {
    $guidePath = Join-Path $PSScriptRoot "BINARY_INSTALLATION_GUIDE.md"
    if (Test-Path $guidePath) {
        Start-Process notepad $guidePath
    }
    else {
        Write-Host "Guide not found at: $guidePath" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Quick Copy Commands for ZomboDB" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "After extracting ZomboDB, run these commands in PowerShell (as Administrator):" -ForegroundColor Yellow
Write-Host ""
Write-Host "`$ZOMBODB_PATH = `"C:\Users\YourUsername\Downloads\zombodb-pg$pgVersion-X.X.X`"" -ForegroundColor White
Write-Host "Copy-Item `"`$ZOMBODB_PATH\zombodb.dll`" `"C:\Program Files\PostgreSQL\$pgVersion\lib\`" -Force" -ForegroundColor White
Write-Host "Copy-Item `"`$ZOMBODB_PATH\zombodb.control`" `"C:\Program Files\PostgreSQL\$pgVersion\share\extension\`" -Force" -ForegroundColor White
Write-Host "Copy-Item `"`$ZOMBODB_PATH\zombodb--*.sql`" `"C:\Program Files\PostgreSQL\$pgVersion\share\extension\`" -Force" -ForegroundColor White
Write-Host "Restart-Service postgresql-x64-$pgVersion" -ForegroundColor White
Write-Host ""

Write-Host "Done! Download the required files and follow the installation instructions." -ForegroundColor Green
