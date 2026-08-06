/* ================================================================
   LOGISTICS INTELLIGENCE PLATFORM — DATA WAREHOUSE
   ================================================================
   File   : 06_run_pipeline.sql
   Purpose: One entry point that executes the whole pipeline in
            order. Run with:
              sqlcmd -S localhost -E -C -i 06_run_pipeline.sql
   ================================================================ */

:r 00_database.sql
:r 01_bronze_layer.sql
:r 02_silver_layer.sql
:r 03_gold_layer.sql
:r 04_business_views.sql
:r 05_kpi_queries.sql
GO
