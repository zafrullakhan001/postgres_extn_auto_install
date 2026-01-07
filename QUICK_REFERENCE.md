# PostgreSQL Extensions - Quick Reference Card

## 🎯 Your Database Configuration
- **Host:** localhost
- **Port:** 5433
- **User:** postgres
- **Password:** password
- **Database:** postgres

## ✅ Currently Installed Extensions
- ✅ pg_stat_statements
- ✅ postgres_fdw
- ✅ intarray
- ✅ timescaledb

## 📥 To Install: PostGIS

### 1. Download & Install Binaries
```
URL: https://postgis.net/windows_downloads/
File: postgis-bundle-pg16-3.4.x-x64.exe
```

### 2. Run Installer
- Double-click the .exe file
- Follow the wizard
- Select PostgreSQL installation directory

### 3. Install Extension
```powershell
cd c:\xampp\htdocs\postgres\windows
powershell -ExecutionPolicy Bypass -File install_postgis.ps1
```
Enter: localhost, 5433, postgres, password, postgres

## 📥 To Install: ZomboDB

### 1. Install Elasticsearch
```
URL: https://www.elastic.co/downloads/elasticsearch
Download and install
Start Elasticsearch
Verify: http://localhost:9200
```

### 2. Download ZomboDB
```
URL: https://github.com/zombodb/zombodb/releases
File: zombodb-pg16-X.X.X.zip
Extract to: C:\Users\YourUsername\Downloads\
```

### 3. Copy Files (Run PowerShell as Admin)
```powershell
$ZOMBODB_PATH = "C:\Users\YourUsername\Downloads\zombodb-pg16-X.X.X"
Copy-Item "$ZOMBODB_PATH\zombodb.dll" "C:\Program Files\PostgreSQL\16\lib\" -Force
Copy-Item "$ZOMBODB_PATH\zombodb.control" "C:\Program Files\PostgreSQL\16\share\extension\" -Force
Copy-Item "$ZOMBODB_PATH\zombodb--*.sql" "C:\Program Files\PostgreSQL\16\share\extension\" -Force
```

### 4. Restart PostgreSQL
```powershell
Restart-Service postgresql-x64-16
```

### 5. Install Extension
```powershell
cd c:\xampp\htdocs\postgres\windows
powershell -ExecutionPolicy Bypass -File install_zombodb.ps1
```
Enter: localhost, 5433, postgres, password, postgres

## 🚀 Quick Commands

### Open Download Helper
```powershell
cd c:\xampp\htdocs\postgres
powershell -ExecutionPolicy Bypass -File download_helper.ps1
```

### Install Any Extension
```powershell
cd c:\xampp\htdocs\postgres\windows
powershell -ExecutionPolicy Bypass -File install_<extension_name>.ps1
```

### Check Installed Extensions
```sql
SELECT extname, extversion FROM pg_extension ORDER BY extname;
```

### Check Available Extensions
```sql
SELECT name, default_version FROM pg_available_extensions 
WHERE name IN ('postgis', 'zombodb') ORDER BY name;
```

## 📚 Documentation Files
- **SUMMARY.md** - Complete overview
- **README.md** - Main documentation
- **BINARY_INSTALLATION_GUIDE.md** - Detailed PostGIS & ZomboDB guide
- **INSTALLATION_GUIDE.md** - General installation guide

## 🔗 Download Links
- PostGIS: https://postgis.net/windows_downloads/
- Elasticsearch: https://www.elastic.co/downloads/elasticsearch
- ZomboDB: https://github.com/zombodb/zombodb/releases

## 💡 Usage Examples

### pg_stat_statements
```sql
SELECT query, calls, total_exec_time 
FROM pg_stat_statements 
ORDER BY total_exec_time DESC LIMIT 10;
```

### PostGIS
```sql
CREATE TABLE cities (
    id SERIAL PRIMARY KEY,
    name TEXT,
    location GEOMETRY(Point, 4326)
);

INSERT INTO cities (name, location)
VALUES ('NYC', ST_SetSRID(ST_MakePoint(-74.006, 40.7128), 4326));
```

### ZomboDB
```sql
CREATE INDEX idx_zdb ON documents
USING zombodb ((documents.*))
WITH (url='http://localhost:9200/');

SELECT * FROM documents 
WHERE documents ==> 'title:postgresql';
```

## ⚠️ Troubleshooting

**Connection Failed**
- Check PostgreSQL is running
- Verify port 5433
- Check credentials

**Extension Not Available**
- Install binaries first (PostGIS, ZomboDB)
- Restart PostgreSQL after installing binaries
- Check: `SELECT * FROM pg_available_extensions;`

**Permission Denied**
- Run PowerShell as Administrator
- Check PostgreSQL service is running

---

**Location:** c:\xampp\htdocs\postgres\
**Scripts:** windows/ (PowerShell) | linux/ (Bash)
**Status:** ✅ Ready to use
