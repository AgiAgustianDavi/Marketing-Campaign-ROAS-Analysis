/* ============================================================
   FILE      : join_campaign_data.sql
   PURPOSE   : Join daily campaign performance data with campaign
               master (dimension) data for marketing analysis.
   DIALECT   : Microsoft SQL Server (T-SQL)
   AUTHOR    : Data Analyst - Marketing
   SOURCE    : marketing_campaign_performance_2025.csv (fact table)
               campaign_master_2025.csv               (dimension table)
   ============================================================ */

USE MarketingAnalytics;   -- ganti sesuai nama database yang digunakan
GO

/* ------------------------------------------------------------
   STEP 1 - CREATE STAGING TABLES
   ------------------------------------------------------------ */

IF OBJECT_ID('dbo.campaign_performance', 'U') IS NOT NULL
    DROP TABLE dbo.campaign_performance;
GO

CREATE TABLE dbo.campaign_performance (
    [date]              DATE            NOT NULL,
    campaign_id         VARCHAR(20)     NOT NULL,
    campaign_name       VARCHAR(150)    NULL,
    channel             VARCHAR(50)     NULL,
    campaign_type       VARCHAR(30)     NULL,
    product_category    VARCHAR(50)     NULL,
    target_age_group    VARCHAR(20)     NULL,
    target_location     VARCHAR(50)     NULL,
    impressions         FLOAT           NULL,
    clicks              FLOAT           NULL,
    spend               FLOAT           NULL,
    conversions         FLOAT           NULL,
    revenue             FLOAT           NULL
);
GO

IF OBJECT_ID('dbo.campaign_master', 'U') IS NOT NULL
    DROP TABLE dbo.campaign_master;
GO

CREATE TABLE dbo.campaign_master (
    campaign_id         VARCHAR(20)     NOT NULL PRIMARY KEY,
    campaign_name       VARCHAR(150)    NULL,
    channel             VARCHAR(50)     NULL,
    campaign_type       VARCHAR(30)     NULL,
    product_category    VARCHAR(50)     NULL,
    target_age_group    VARCHAR(20)     NULL,
    target_location     VARCHAR(50)     NULL,
    start_date          DATE            NULL,
    end_date            DATE            NULL,
    budget_mult         FLOAT           NULL
);
GO

/* ------------------------------------------------------------
   STEP 2 - LOAD DATA FROM CSV
   Sesuaikan path file dengan lokasi CSV di server/mesin Anda.
   Format CSV: header row = 1, comma-delimited, UTF-8.
   ------------------------------------------------------------ */

BULK INSERT dbo.campaign_performance
FROM 'C:\Data\marketing_campaign_performance_2025.csv'
WITH (
    FORMAT              = 'CSV',
    FIRSTROW            = 2,
    FIELDTERMINATOR     = ',',
    ROWTERMINATOR       = '0x0a',
    CODEPAGE            = '65001',   -- UTF-8
    TABLOCK
);
GO

BULK INSERT dbo.campaign_master
FROM 'C:\Data\campaign_master_2025.csv'
WITH (
    FORMAT              = 'CSV',
    FIRSTROW            = 2,
    FIELDTERMINATOR     = ',',
    ROWTERMINATOR       = '0x0a',
    CODEPAGE            = '65001',
    TABLOCK
);
GO

/* ------------------------------------------------------------
   STEP 3 - JOIN FACT (campaign_performance) WITH DIMENSION
   (campaign_master).
   Kolom deskriptif (channel, campaign_type, dst.) sudah ada di
   kedua tabel; kita ambil dari sisi fact table (cp) sebagai
   sumber utama, dan hanya menambahkan atribut yang HANYA ada
   di master: start_date, end_date, budget_mult, serta durasi
   campaign yang dihitung dari kedua tanggal tersebut.
   ------------------------------------------------------------ */

IF OBJECT_ID('dbo.campaign_performance_joined', 'U') IS NOT NULL
    DROP TABLE dbo.campaign_performance_joined;
GO

SELECT
    cp.[date],
    cp.campaign_id,
    cp.campaign_name,
    cp.channel,
    cp.campaign_type,
    cp.product_category,
    cp.target_age_group,
    cp.target_location,
    cm.start_date,
    cm.end_date,
    DATEDIFF(DAY, cm.start_date, cm.end_date) + 1   AS campaign_duration_days,
    DATEDIFF(DAY, cm.start_date, cp.[date]) + 1     AS campaign_day_number,
    cm.budget_mult                                  AS budget_tier_multiplier,
    cp.impressions,
    cp.clicks,
    cp.spend,
    cp.conversions,
    cp.revenue
INTO dbo.campaign_performance_joined
FROM dbo.campaign_performance AS cp
LEFT JOIN dbo.campaign_master  AS cm
       ON cp.campaign_id = cm.campaign_id;
GO

/* ------------------------------------------------------------
   STEP 4 - VALIDATION CHECKS
   ------------------------------------------------------------ */

-- 4a. Pastikan jumlah baris hasil join = jumlah baris fact table
SELECT COUNT(*) AS row_count_fact       FROM dbo.campaign_performance;
SELECT COUNT(*) AS row_count_joined     FROM dbo.campaign_performance_joined;

-- 4b. Cek campaign_id di fact table yang tidak ditemukan di master (orphan rows)
SELECT DISTINCT cp.campaign_id
FROM dbo.campaign_performance AS cp
LEFT JOIN dbo.campaign_master  AS cm ON cp.campaign_id = cm.campaign_id
WHERE cm.campaign_id IS NULL;

-- 4c. Preview hasil join
SELECT TOP 100 *
FROM dbo.campaign_performance_joined
ORDER BY [date], channel, campaign_id;
GO

/* ------------------------------------------------------------
   STEP 5 - (OPSIONAL) EXPORT HASIL JOIN KE CSV
   Gunakan salah satu cara berikut sesuai environment:

   a) Dari SQL Server Management Studio (SSMS):
      Klik kanan hasil query -> "Save Results As..." -> pilih CSV

   b) Menggunakan sqlcmd dari command line:
      sqlcmd -S <server_name> -d MarketingAnalytics -E ^
        -Q "SET NOCOUNT ON; SELECT * FROM dbo.campaign_performance_joined ORDER BY [date], channel, campaign_id" ^
        -o "C:\Data\campaign_performance_joined_2025.csv" -s"," -W -w 4000

   c) Menggunakan bcp utility:
      bcp "SELECT * FROM MarketingAnalytics.dbo.campaign_performance_joined ORDER BY [date], channel, campaign_id" ^
        queryout "C:\Data\campaign_performance_joined_2025.csv" -c -t, -S <server_name> -T
   ------------------------------------------------------------ */
