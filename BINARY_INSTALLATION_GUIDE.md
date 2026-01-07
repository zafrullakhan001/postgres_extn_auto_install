# Installing PostGIS and ZomboDB Binaries

This guide provides step-by-step instructions for installing PostGIS and ZomboDB binaries on Windows.

## PostGIS Installation (Windows)

### Step 1: Download PostGIS

1. Visit the PostGIS download page: **https://postgis.net/windows_downloads/**
2. Look for the "PostGIS Bundle" for your PostgreSQL version
3. Download the appropriate installer:
   - For PostgreSQL 16: `postgis-bundle-pg16-3.4.x-x64.exe`
   - For PostgreSQL 15: `postgis-bundle-pg15-3.4.x-x64.exe`
   - For PostgreSQL 14: `postgis-bundle-pg14-3.4.x-x64.exe`

### Step 2: Run the Installer

1. Double-click the downloaded `.exe` file
2. Click "Next" on the welcome screen
3. Accept the license agreement
4. **Important:** Select your PostgreSQL installation directory
   - Common locations:
     - `C:\Program Files\PostgreSQL\16`
     - `C:\Program Files\PostgreSQL\15`
   - The installer should auto-detect this
5. Select components to install (recommended: all)
6. Click "Next" and then "Install"
7. Wait for installation to complete
8. Click "Finish"

### Step 3: Verify Installation

Open PowerShell and run:
```powershell
$env:PGPASSWORD="password"
& "C:\Program Files\pgAdmin 4\runtime\psql.exe" -h localhost -p 5433 -U postgres -d postgres -c "SELECT name FROM pg_available_extensions WHERE name = 'postgis';"
```

If PostGIS appears in the output, the binaries are installed correctly.

### Step 4: Install the Extension

Run the installation script:
```powershell
cd c:\xampp\htdocs\postgres\windows
powershell -ExecutionPolicy Bypass -File install_postgis.ps1
```

Enter your connection details when prompted:
- Host: localhost
- Port: 5433
- Username: postgres
- Password: password
- Database: postgres

---

## ZomboDB Installation (Windows)

### Prerequisites

ZomboDB requires Elasticsearch to be running. Install Elasticsearch first:

#### Install Elasticsearch

1. Visit: **https://www.elastic.co/downloads/elasticsearch**
2. Download Elasticsearch for Windows (ZIP or MSI)
3. For ZIP installation:
   ```powershell
   # Extract the ZIP to a location like C:\elasticsearch
   # Open PowerShell in that directory and run:
   .\bin\elasticsearch.bat
   ```
4. For MSI installation:
   - Run the installer
   - Follow the wizard
   - Start Elasticsearch service

5. Verify Elasticsearch is running:
   - Open browser to: http://localhost:9200
   - You should see JSON response with cluster information

### Step 1: Download ZomboDB

1. Visit: **https://github.com/zombodb/zombodb/releases**
2. Find the latest release
3. Download the ZIP file for your PostgreSQL version:
   - For PostgreSQL 16: `zombodb-pg16-X.X.X.zip`
   - For PostgreSQL 15: `zombodb-pg15-X.X.X.zip`
   - For PostgreSQL 14: `zombodb-pg14-X.X.X.zip`

### Step 2: Extract ZomboDB Files

1. Extract the downloaded ZIP file
2. You should see files like:
   - `zombodb.dll`
   - `zombodb.control`
   - `zombodb--X.X.X.sql`
   - Other SQL files

### Step 3: Copy Files to PostgreSQL Directories

Open PowerShell **as Administrator** and run:

```powershell
# Set your PostgreSQL version (change 16 to your version)
$PG_VERSION = "16"
$PG_PATH = "C:\Program Files\PostgreSQL\$PG_VERSION"

# Set the path where you extracted ZomboDB
$ZOMBODB_PATH = "C:\Users\YourUsername\Downloads\zombodb-pg16-X.X.X"

# Copy DLL file
Copy-Item "$ZOMBODB_PATH\zombodb.dll" "$PG_PATH\lib\" -Force

# Copy control file
Copy-Item "$ZOMBODB_PATH\zombodb.control" "$PG_PATH\share\extension\" -Force

# Copy SQL files
Copy-Item "$ZOMBODB_PATH\zombodb--*.sql" "$PG_PATH\share\extension\" -Force

Write-Host "ZomboDB files copied successfully!" -ForegroundColor Green
```

### Step 4: Restart PostgreSQL

Restart the PostgreSQL service:

```powershell
# Find your PostgreSQL service name
Get-Service | Where-Object {$_.Name -like "*postgres*"}

# Restart the service (replace with your actual service name)
Restart-Service postgresql-x64-16
```

Or restart manually:
1. Open Services (Win + R, type `services.msc`)
2. Find "postgresql-x64-16" (or similar)
3. Right-click → Restart

### Step 5: Verify Installation

```powershell
$env:PGPASSWORD="password"
& "C:\Program Files\pgAdmin 4\runtime\psql.exe" -h localhost -p 5433 -U postgres -d postgres -c "SELECT name FROM pg_available_extensions WHERE name = 'zombodb';"
```

If ZomboDB appears, the binaries are installed correctly.

### Step 6: Install the Extension

Run the installation script:
```powershell
cd c:\xampp\htdocs\postgres\windows
powershell -ExecutionPolicy Bypass -File install_zombodb.ps1
```

Enter your connection details when prompted.

---

## Quick Installation Script

Here's a PowerShell script to help with the installation process:

```powershell
# Quick PostGIS and ZomboDB Binary Installer Helper

Write-Host "PostgreSQL Extensions Binary Installation Helper" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# Check PostgreSQL version
$pgVersion = Read-Host "Enter your PostgreSQL version (14, 15, or 16)"

Write-Host ""
Write-Host "Installation Steps:" -ForegroundColor Yellow
Write-Host ""

Write-Host "1. PostGIS Installation:" -ForegroundColor Cyan
Write-Host "   Download from: https://postgis.net/windows_downloads/" -ForegroundColor White
Write-Host "   File: postgis-bundle-pg$pgVersion-3.4.x-x64.exe" -ForegroundColor Gray
Write-Host ""

Write-Host "2. ZomboDB Installation:" -ForegroundColor Cyan
Write-Host "   a. Install Elasticsearch:" -ForegroundColor White
Write-Host "      https://www.elastic.co/downloads/elasticsearch" -ForegroundColor Gray
Write-Host "   b. Download ZomboDB:" -ForegroundColor White
Write-Host "      https://github.com/zombodb/zombodb/releases" -ForegroundColor Gray
Write-Host "      File: zombodb-pg$pgVersion-X.X.X.zip" -ForegroundColor Gray
Write-Host ""

$openPostGIS = Read-Host "Open PostGIS download page? (y/n)"
if ($openPostGIS -eq "y") {
    Start-Process "https://postgis.net/windows_downloads/"
}

$openZomboDB = Read-Host "Open ZomboDB releases page? (y/n)"
if ($openZomboDB -eq "y") {
    Start-Process "https://github.com/zombodb/zombodb/releases"
}

$openElastic = Read-Host "Open Elasticsearch download page? (y/n)"
if ($openElastic -eq "y") {
    Start-Process "https://www.elastic.co/downloads/elasticsearch"
}

Write-Host ""
Write-Host "After installing binaries, run the extension installation scripts from:" -ForegroundColor Yellow
Write-Host "c:\xampp\htdocs\postgres\windows\" -ForegroundColor White
```

Save this as `download_helper.ps1` and run it to open the download pages.

---

## Troubleshooting

### PostGIS Installation Issues

**Problem:** PostGIS installer doesn't detect PostgreSQL  
**Solution:** 
- Manually specify the PostgreSQL installation path
- Ensure PostgreSQL is installed in a standard location
- Try running installer as Administrator

**Problem:** Extension still not available after installation  
**Solution:**
- Restart PostgreSQL service
- Check that files were copied to correct directories
- Verify PostgreSQL version matches PostGIS version

### ZomboDB Installation Issues

**Problem:** Elasticsearch won't start  
**Solution:**
- Check Java is installed (Elasticsearch requires Java)
- Check port 9200 is not in use
- Review Elasticsearch logs in `logs` directory

**Problem:** ZomboDB extension fails to load  
**Solution:**
- Ensure all files were copied correctly
- Verify DLL is in `lib` directory
- Verify .control and .sql files are in `share\extension`
- Restart PostgreSQL service
- Check PostgreSQL logs for detailed error messages

**Problem:** "could not load library" error  
**Solution:**
- Ensure ZomboDB version matches PostgreSQL version exactly
- Check for missing dependencies (Visual C++ Redistributable)
- Verify file permissions

---

## Verification Commands

After installation, verify everything is working:

### PostGIS Verification
```sql
-- Check extension is available
SELECT * FROM pg_available_extensions WHERE name = 'postgis';

-- Install extension
CREATE EXTENSION postgis;

-- Verify installation
SELECT PostGIS_Version();

-- Test functionality
SELECT ST_AsText(ST_MakePoint(-74.006, 40.7128));
```

### ZomboDB Verification
```sql
-- Check extension is available
SELECT * FROM pg_available_extensions WHERE name = 'zombodb';

-- Install extension
CREATE EXTENSION zombodb;

-- Verify Elasticsearch connection
SELECT zdb.version();

-- Create test table with ZomboDB index
CREATE TABLE test_docs (
    id SERIAL PRIMARY KEY,
    title TEXT,
    content TEXT
);

CREATE INDEX idx_zdb_test ON test_docs
USING zombodb ((test_docs.*))
WITH (url='http://localhost:9200/');
```

---

## Summary

1. **PostGIS:** Download installer → Run installer → Run script
2. **ZomboDB:** Install Elasticsearch → Download ZIP → Copy files → Restart PostgreSQL → Run script

Both extensions are now ready to use with your PostgreSQL database!
