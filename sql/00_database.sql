/* ================================================================
   LOGISTICS INTELLIGENCE PLATFORM — DATA WAREHOUSE
   ================================================================
   File   : 00_database.sql
   Purpose: Create the warehouse database and the medallion
            schemas (bronze / silver / gold) + audit table.
   Engine : Microsoft SQL Server 2025 (Express)
   Author : Mustafa Al-Rouby
   ================================================================ */

IF DB_ID('LogisticsIntelligenceDW') IS NULL
BEGIN
    CREATE DATABASE LogisticsIntelligenceDW;
    PRINT 'Database created: LogisticsIntelligenceDW';
END
GO

USE LogisticsIntelligenceDW;
GO

/* ----------------------------------------------------------------
   Medallion schemas
   ---------------------------------------------------------------- */
IF SCHEMA_ID('bronze') IS NULL EXEC('CREATE SCHEMA bronze AUTHORIZATION dbo');
IF SCHEMA_ID('silver') IS NULL EXEC('CREATE SCHEMA silver AUTHORIZATION dbo');
IF SCHEMA_ID('gold')   IS NULL EXEC('CREATE SCHEMA gold   AUTHORIZATION dbo');
GO

/* ----------------------------------------------------------------
   Shared audit table — every load records row counts so the
   pipeline is verifiable end to end.
   ---------------------------------------------------------------- */
IF OBJECT_ID('gold.pipeline_audit') IS NULL
BEGIN
    CREATE TABLE gold.pipeline_audit (
        audit_id        INT IDENTITY(1,1) PRIMARY KEY,
        layer           NVARCHAR(20)  NOT NULL,      -- bronze | silver | gold
        object_name     NVARCHAR(128) NOT NULL,
        rows_loaded     BIGINT        NOT NULL,
        rows_rejected   BIGINT        NULL,
        started_at      DATETIME2(0)  NOT NULL DEFAULT SYSUTCDATETIME(),
        finished_at     DATETIME2(0)  NULL,
        status          NVARCHAR(20)  NOT NULL DEFAULT 'RUNNING',
        notes           NVARCHAR(500) NULL
    );
    PRINT 'Created gold.pipeline_audit';
END
GO

/* ----------------------------------------------------------------
   Quick sanity: confirm instance + database
   ---------------------------------------------------------------- */
SELECT
    SERVERPROPERTY('MachineName')                   AS server_name,
    DB_NAME()                                       AS database_name,
    SERVERPROPERTY('ProductVersion')                AS sql_version;
GO
