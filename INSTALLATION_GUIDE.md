# Installing Additional PostgreSQL Extensions

This guide provides step-by-step instructions for installing PostgreSQL extensions that require separate binary installation.

## PostGIS Installation

### Step 1: Download PostGIS
1. Visit: https://postgis.net/windows_downloads/
2. Download the installer matching your PostgreSQL version
3. Example: `postgis-bundle-pg16-3.4.1-1-x64.exe` for PostgreSQL 16

### Step 2: Run the Installer
1. Run the downloaded `.exe` file
2. Select your PostgreSQL installation directory
3. Complete the installation wizard

### Step 3: Enable PostGIS
```sql
CREATE EXTENSION postgis;
CREATE EXTENSION postgis_topology;  -- Optional
CREATE EXTENSION postgis_raster;    -- Optional
```

### Step 4: Verify Installation
```sql
SELECT PostGIS_Version();
```

## ZomboDB Installation

### Prerequisites
- Elasticsearch must be installed and running
- Download from: https://www.elastic.co/downloads/elasticsearch

### Step 1: Download ZomboDB
1. Visit: https://github.com/zombodb/zombodb/releases
2. Download the appropriate version for your PostgreSQL version
3. Example: `zombodb-pg16-3.1.0.zip`

### Step 2: Install ZomboDB
1. Extract the ZIP file
2. Copy files to PostgreSQL directories:
   ```powershell
   # Copy DLL files
   Copy-Item "zombodb.dll" "C:\Program Files\PostgreSQL\16\lib\"
   
   # Copy control and SQL files
   Copy-Item "zombodb.control" "C:\Program Files\PostgreSQL\16\share\extension\"
   Copy-Item "zombodb--*.sql" "C:\Program Files\PostgreSQL\16\share\extension\"
   ```

### Step 3: Configure Elasticsearch Connection
```sql
CREATE EXTENSION zombodb;

-- Create an index using ZomboDB
CREATE INDEX idx_zdb_mydata 
ON mytable 
USING zombodb ((mytable.*))
WITH (url='http://localhost:9200/');
```

### Step 4: Verify Installation
```sql
SELECT * FROM zdb.version();
```

## TimescaleDB Installation

### Step 1: Download TimescaleDB
1. Visit: https://www.timescale.com/download
2. Select "Windows" and your PostgreSQL version
3. Download the installer

### Step 2: Run the Installer
1. Run the downloaded `.exe` file
2. Follow the installation wizard
3. The installer will automatically configure PostgreSQL

### Step 3: Update postgresql.conf
Add TimescaleDB to shared_preload_libraries:
```ini
shared_preload_libraries = 'timescaledb'
```

### Step 4: Restart PostgreSQL
```powershell
Restart-Service postgresql-x64-16  # Adjust service name as needed
```

### Step 5: Enable TimescaleDB
```sql
CREATE EXTENSION IF NOT EXISTS timescaledb;
```

### Step 6: Verify Installation
```sql
SELECT default_version, installed_version 
FROM pg_available_extensions 
WHERE name = 'timescaledb';
```

## pg_sphere Installation

### Note
pg_sphere typically requires compilation from source, which can be complex on Windows.

### Option 1: Pre-compiled Binaries (if available)
Check: https://github.com/akorotkov/pgsphere/releases

### Option 2: Compile from Source (Advanced)

#### Prerequisites
- Visual Studio with C++ compiler
- PostgreSQL development files
- Git

#### Steps
```powershell
# Clone the repository
git clone https://github.com/akorotkov/pgsphere.git
cd pgsphere

# Set PostgreSQL path
$env:PGROOT = "C:\Program Files\PostgreSQL\16"

# Build (requires Visual Studio)
nmake /f Makefile.win

# Install
nmake /f Makefile.win install
```

#### Enable pg_sphere
```sql
CREATE EXTENSION pg_sphere;
```

## PostPic Installation

### Note
PostPic is less commonly available as pre-built binaries for Windows.

### Recommended Approach
1. Check if available in your PostgreSQL distribution
2. May require compilation from source
3. Consider alternative image processing solutions:
   - Store images in filesystem, metadata in PostgreSQL
   - Use external image processing services
   - Process images in application layer

## Verification Script

After installing any extension, run this to verify:

```sql
-- Check if extension is available
SELECT * 
FROM pg_available_extensions 
WHERE name IN ('postgis', 'zombodb', 'timescaledb', 'pg_sphere', 'postpic')
ORDER BY name;

-- Check installed extensions
SELECT extname, extversion 
FROM pg_extension 
WHERE extname IN ('postgis', 'zombodb', 'timescaledb', 'pg_sphere', 'postpic')
ORDER BY extname;
```

## Troubleshooting

### Extension Not Found After Installation
1. Restart PostgreSQL service
2. Check file permissions in PostgreSQL directories
3. Verify files are in correct directories:
   - DLLs in: `PostgreSQL\16\lib\`
   - Control files in: `PostgreSQL\16\share\extension\`

### Version Mismatch Errors
- Ensure extension version matches PostgreSQL version
- Example: PostgreSQL 16 requires pg16 extensions

### Permission Errors
- Run installers as Administrator
- Check PostgreSQL service account has read access to extension files

### Dependency Errors
- Some extensions require other extensions first
- Example: PostGIS topology requires PostGIS core

## Quick Re-run Script

After installing binaries, re-run the installation script:
```powershell
powershell -ExecutionPolicy Bypass -File install_extensions.ps1
```

## Support Resources

- **PostGIS:** https://postgis.net/documentation/
- **ZomboDB:** https://github.com/zombodb/zombodb/wiki
- **TimescaleDB:** https://docs.timescale.com/
- **pg_sphere:** https://github.com/akorotkov/pgsphere
- **PostgreSQL Extensions:** https://www.postgresql.org/docs/current/contrib.html
