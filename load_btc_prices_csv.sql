-- ============================================================================
-- Script to load BTC prices from CSV file using pgAdmin 4 (Client-Side)
-- ============================================================================
-- This script uses client-side CSV import, which means the CSV file is read
-- from YOUR computer (where pgAdmin is running), not from the database server.
-- This is the recommended approach when using pgAdmin 4.
-- ============================================================================

-- ============================================================================
-- METHOD 1: Using pgAdmin 4 GUI (RECOMMENDED - Easiest Method)
-- ============================================================================
-- 1. In pgAdmin 4, navigate to your database
-- 2. Expand: Databases → [Your Database] → Schemas → public → Tables
-- 3. Right-click on "btc_prices" table
-- 4. Select "Import/Export Data..."
-- 5. In the dialog:
--    - Toggle "Import/Export": Select "Import"
--    - Filename: Browse and select your CSV file
--    - Format: CSV
--    - Header: Toggle OFF (your CSV has no header row)
--    - Delimiter: , (comma)
--    - Quote: " (double quote)
--    - Escape: " (double quote)
--    - Columns: Select all columns in order:
--      time, opening_price, highest_price, lowest_price, closing_price,
--      volume_btc, volume_currency, currency_code
-- 6. Click "OK" to import
-- ============================================================================

-- ============================================================================
-- METHOD 2: Using \copy command in pgAdmin Query Tool
-- ============================================================================
-- The \copy command runs on the CLIENT side (your computer), not the server.
-- This is perfect for pgAdmin 4!
--
-- INSTRUCTIONS:
-- 1. Open pgAdmin 4 Query Tool (Tools → Query Tool)
-- 2. Update the file path below to point to your CSV file
-- 3. Execute the command
-- ============================================================================

-- First, verify the table exists and is empty (or check current count)
SELECT COUNT(*) as current_record_count FROM public.btc_prices;

-- Use \copy to import from your local CSV file
-- IMPORTANT: Update the file path to match your CSV file location
\copy public.btc_prices (time, opening_price, highest_price, lowest_price, closing_price, volume_btc, volume_currency, currency_code) FROM 'C:/Users/YourUsername/Downloads/btc_prices.csv' WITH (FORMAT csv, HEADER false, DELIMITER ',', NULL '');

-- Verify the import
SELECT COUNT(*) as total_records_after_import FROM public.btc_prices;
SELECT * FROM public.btc_prices ORDER BY time DESC LIMIT 10;

-- ============================================================================
-- METHOD 3: Using a temporary staging table (for data validation)
-- ============================================================================
-- This method is useful if you want to validate/transform data before inserting
-- into the final table.
-- ============================================================================

-- Step 1: Create a temporary staging table
DROP TABLE IF EXISTS btc_prices_staging;

CREATE TEMP TABLE btc_prices_staging
(
    time_str text,                    -- Read as text for validation
    opening_price text,               -- Read as text to catch errors
    highest_price text,
    lowest_price text,
    closing_price text,
    volume_btc text,
    volume_currency text,
    currency_code character varying(10)
);

-- Step 2: Load CSV into staging table using \copy
-- IMPORTANT: Update the file path to match your CSV file location
\copy btc_prices_staging FROM 'C:/Users/YourUsername/Downloads/btc_prices.csv' WITH (FORMAT csv, HEADER false, DELIMITER ',', NULL '');

-- Step 3: Validate the data in staging table
SELECT COUNT(*) as staging_record_count FROM btc_prices_staging;
SELECT * FROM btc_prices_staging LIMIT 5;

-- Check for any invalid timestamps
SELECT time_str, COUNT(*) 
FROM btc_prices_staging 
WHERE time_str !~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$'
GROUP BY time_str;

-- Check for any invalid numeric values
SELECT * FROM btc_prices_staging 
WHERE opening_price !~ '^[0-9.]+$' 
   OR highest_price !~ '^[0-9.]+$'
   OR lowest_price !~ '^[0-9.]+$'
   OR closing_price !~ '^[0-9.]+$'
LIMIT 10;

-- Step 4: Insert validated data into final table
BEGIN;

INSERT INTO public.btc_prices 
(
    time,
    opening_price,
    highest_price,
    lowest_price,
    closing_price,
    volume_btc,
    volume_currency,
    currency_code
)
SELECT 
    time_str::timestamp with time zone,
    opening_price::double precision,
    highest_price::double precision,
    lowest_price::double precision,
    closing_price::double precision,
    volume_btc::double precision,
    volume_currency::double precision,
    currency_code
FROM btc_prices_staging
WHERE time_str IS NOT NULL;  -- Skip rows with NULL timestamps

-- Verify the insert
SELECT COUNT(*) as final_record_count FROM public.btc_prices;
SELECT * FROM public.btc_prices ORDER BY time DESC LIMIT 10;

-- If everything looks good, commit
COMMIT;
-- If there are issues, run: ROLLBACK;

-- Step 5: Clean up staging table
DROP TABLE IF EXISTS btc_prices_staging;

-- ============================================================================
-- Sample Data Verification Queries
-- ============================================================================

-- Check date range
SELECT 
    MIN(time) as earliest_date,
    MAX(time) as latest_date,
    COUNT(*) as total_records
FROM public.btc_prices;

-- Check for duplicates
SELECT time, currency_code, COUNT(*) as duplicate_count
FROM public.btc_prices
GROUP BY time, currency_code
HAVING COUNT(*) > 1;

-- Check currency distribution
SELECT currency_code, COUNT(*) as record_count
FROM public.btc_prices
GROUP BY currency_code
ORDER BY record_count DESC;

-- Check for NULL values
SELECT 
    COUNT(*) FILTER (WHERE opening_price IS NULL) as null_opening,
    COUNT(*) FILTER (WHERE highest_price IS NULL) as null_highest,
    COUNT(*) FILTER (WHERE lowest_price IS NULL) as null_lowest,
    COUNT(*) FILTER (WHERE closing_price IS NULL) as null_closing,
    COUNT(*) FILTER (WHERE volume_btc IS NULL) as null_volume_btc,
    COUNT(*) FILTER (WHERE volume_currency IS NULL) as null_volume_currency
FROM public.btc_prices;

-- ============================================================================
-- Troubleshooting Tips for pgAdmin 4
-- ============================================================================
-- 1. File path format:
--    - Windows: Use forward slashes: C:/Users/YourName/file.csv
--    - Or use double backslashes: C:\\Users\\YourName\\file.csv
--    - Avoid single backslashes (they're escape characters)
--
-- 2. Permission errors:
--    - The CSV file must be readable by YOU (not the database server)
--    - Make sure the file isn't open in Excel or another program
--
-- 3. \copy vs COPY:
--    - \copy = client-side (reads from YOUR computer) ← Use this in pgAdmin!
--    - COPY = server-side (reads from database server)
--    - pgAdmin 4 supports \copy in the Query Tool
--
-- 4. Character encoding issues:
--    - If you see weird characters, your CSV might be UTF-8 with BOM
--    - Save CSV as UTF-8 without BOM in your text editor
--    - Or add ENCODING 'UTF8' to the \copy command
--
-- 5. Date/Time format issues:
--    - Your CSV format: 2013-03-11 00:00:00
--    - This should work automatically with timestamp conversion
--    - If issues occur, use the staging table method (Method 3)
--
-- 6. Testing with small dataset:
--    - Create a test CSV with just 2-3 rows first
--    - Verify it imports correctly before loading the full dataset
--
-- 7. pgAdmin Query Tool tips:
--    - Press F5 to execute the query
--    - Use "Execute/Refresh" button in toolbar
--    - Check the "Messages" tab for detailed error messages
-- ============================================================================
