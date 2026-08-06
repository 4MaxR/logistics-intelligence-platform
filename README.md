# Logistics Intelligence Platform

A production-grade **SQL Server data warehouse** built from a real logistics operations database
(2022–2024, 14 source tables, ~550K raw rows). The project demonstrates the complete analytics
engineering stack: **data engineering, SQL development, data warehousing, business intelligence,
and logistics analytics** — built and executed end to end on Microsoft SQL Server 2025.

> **Status: COMPLETED · Verified** — every number in this repository's documentation was produced
> by executing the pipeline on SQL Server, then cross-validated against the source CSVs.

---

## What this project is

| Layer | What it does |
|---|---|
| **Bronze** | Raw, immutable staging — every source CSV loaded verbatim (`NVARCHAR`), zero transformation |
| **Silver** | Clean, conformed, typed layer — native types, NULL handling, string-boolean casting, FK validation, orphan-safe surrogate resolution |
| **Gold** | Star schema — surrogate-key dimensions, conformed `dim_date`, 8 fact tables with FK constraints, business + KPI views |

## What the data says (verified output)

| KPI | Value | Source |
|---|---|---|
| Gross revenue (3 years) | **$298.6M** | `gold.v_kpi_overview` |
| Trips / delivery events | **85,410 / 170,820** | `gold.fact_trip` / `gold.fact_delivery` |
| Total miles driven | **122.2M** | `gold.fact_trip` |
| On-time delivery rate | **44.6%** | `gold.fact_delivery` |
| Average fleet utilization | **83.0%** | `gold.fact_truck_monthly` |
| Fleet average MPG | **6.50** | `gold.fact_trip` |
| Fuel spend (3 years) | **$95.6M** @ $3.90/gal avg | `gold.fact_fuel` |
| Maintenance spend (3 years) | **$5.73M** (2,920 events) | `gold.fact_maintenance` |
| Safety claims (3 years) | **$2.65M** (170 incidents) | `gold.fact_incident` |

---

## Repository structure

```text
Logistics-Operations-Database/
├── data/                          # Source export (14 CSVs + DATABASE_SCHEMA.txt)
├── sql/
│   ├── 00_database.sql            # Creates DB + medallion schemas + pipeline_audit
│   ├── 01_bronze_layer.sql        # Raw staging: 14 tables, BULK INSERT, load audit
│   ├── 02_silver_layer.sql        # Clean layer: dims + facts, typed, FK-validated
│   ├── 03_gold_layer.sql          # Star schema: surrogate dims, 8 facts, constraints
│   ├── 04_business_views.sql      # 11 business views (semantic layer)
│   ├── 05_kpi_queries.sql         # The exact KPI queries quoted in the case study
│   └── 06_run_pipeline.sql        # One-command entry point (:r includes)
└── docs/
    ├── ARCHITECTURE.md            # System design, layers, data flow
    ├── DATA_DICTIONARY.md         # Every table/column in the warehouse
    ├── BUSINESS_REQUIREMENTS.md   # The questions the warehouse answers
    ├── STAR_SCHEMA.md             # Facts, dimensions, grain, relationships
    ├── ETL.md                     # Pipeline steps, load strategy, idempotency
    ├── DATA_QUALITY.md            # Real issues found + how they were handled
    └── KPI.md                     # KPI definitions + verified values
```

---

## Quick start

Prerequisites: SQL Server 2016+ (developed on 2025 Express), `sqlcmd`.

```bash
# From the repo root
sqlcmd -S localhost -E -C -i sql/06_run_pipeline.sql
```

The pipeline is idempotent — every script drops and recreates its targets, and every load is
recorded in `gold.pipeline_audit` for end-to-end verification.

### Inspect the result

```sql
USE LogisticsIntelligenceDW;

-- Headline scorecard (one row)
SELECT * FROM gold.v_kpi_overview;

-- On-time delivery by year
SELECT year_nbr, delivery_events, on_time, on_time_pct
FROM gold.v_kpi_overview;  -- see KPI.md for the full query set

-- Top 5 routes by revenue
SELECT TOP 5 corridor, loads, gross_revenue, revenue_per_mile
FROM gold.v_route_performance
ORDER BY gross_revenue DESC;
```

---

## Verified numbers (cross-validation)

| Check | Python (source CSVs) | SQL Server (warehouse) | Match |
|---|---|---|---|
| `delivery_events` rows | 170,820 | 170,820 | ✅ |
| `fuel_purchases` rows | 196,442 | 196,442 | ✅ |
| `loads` / `trips` rows | 85,410 / 85,410 | 85,410 / 85,410 | ✅ |
| Gross revenue | $298,621,429 | $298,621,429 | ✅ |
| On-time delivery | 44.6% | 44.6% | ✅ |
| Trips missing driver_id | 1,714 | 1,714 (→ Unknown) | ✅ |
| Fuel purchases missing truck_id | 3,880 | 3,880 (→ Unknown) | ✅ |

---

## Skills demonstrated

- **Data engineering**: BULK INSERT staging, typed conforming layer, surrogate keys, idempotent pipelines, pipeline audit trail
- **SQL development**: T-SQL, CTEs, window functions, TRY_CONVERT/TRY_PARSE, dynamic file paths, constraints
- **Data warehousing**: medallion architecture, star schema design, conformed dimensions, fact grain discipline, FK integrity
- **Business intelligence**: semantic-layer views, KPI definitions, management-ready reporting queries
- **Logistics analytics**: on-time delivery, utilization, fuel efficiency, detention, safety, route and customer profitability

---

## License

MIT — free to use, learn from, and adapt. Data is a synthetic operations export for portfolio use.
