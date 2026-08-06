# Architecture

## System overview

The platform is a **medallion-architecture data warehouse** on Microsoft SQL Server. Source CSV
exports are loaded into a raw bronze layer, conformed into a typed silver layer, and modeled into
a star-schema gold layer that serves a semantic layer of business views.

```text
┌────────────────────────────────────────────────────────────────────────┐
│ SOURCE  (Logistics Operations Database — 14 CSVs, 2022–2024)          │
│  customers · drivers · trucks · trailers · facilities · routes        │
│  loads · trips · delivery_events · fuel_purchases · maintenance       │
│  safety_incidents · driver_monthly_metrics · truck_utilization_metrics│
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │ BULK INSERT (raw, NVARCHAR)
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│ BRONZE  bronze.* — raw immutable staging (14 tables)                  │
│  • No transformation, no type coercion, no filtering                  │
│  • Every load recorded in gold.pipeline_audit (row counts)            │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │ Typed conforming layer
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│ SILVER  silver.* — clean, typed, validated (7 dims + 8 facts)         │
│  • Native types (DATE, DECIMAL, BIT, DATETIME2)                       │
│  • ''/whitespace → NULL · 'True'/'False' → BIT                        │
│  • FK validation against source dims                                  │
│  • Orphans preserved via '-1' Unknown surrogate (never dropped)       │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │ Surrogate keys + star modeling
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│ GOLD  gold.* — star schema (7 dims + 8 facts + 11 views)              │
│  • dim_date (conformed calendar, 1,461 days)                          │
│  • Surrogate-key dims with '-1' Unknown row                           │
│  • FK constraints enforce referential integrity                       │
│  • Business views = semantic layer management queries                 │
└────────────────────────────────────────────────────────────────────────┘
```

## Design decisions

### 1. Bronze is immutable
Every source column is staged as `NVARCHAR` — nothing is cast, trimmed, or filtered at load time.
This preserves the raw record so any transformation in silver can be traced back to the original
value, and re-runs never depend on a previous transformation's output.

### 2. Silver is where data quality lives
All casting (`TRY_CONVERT`), cleaning (`LTRIM/RTRIM`, `NULLIF`), and boolean conversion
(`CASE WHEN flag = 'True' THEN 1`) happen in silver — a single, auditable pass. FK validity is
checked against the source dims with a LEFT JOIN; missing parents are mapped to `'-1'` so no fact
row is silently dropped. This is what makes the warehouse trustworthy: **row counts never shrink
between source and gold.**

### 3. Gold is a conformed star schema
- `dim_date` is shared by every fact (single source of truth for time).
- Dimensions use integer surrogate keys (`driver_sk`, `truck_sk`, …); natural keys (`TRK00055`,
  `CUST00077`) stay as unique business keys.
- Every dimension contains an `-1` Unknown row; facts that reference it are valid rows, queryable
  and reportable as "unassigned".
- Facts are modeled at their natural grain: one row per load, trip, delivery event, fuel purchase,
  maintenance record, incident, driver-month, truck-month.

### 4. Business views are the semantic layer
Management queries `gold.v_*` views — never base tables. Each view answers one operating question
with readable column names (on-time %, revenue per mile, utilization %, cost per mile). This is the
"BI without a BI tool" layer: any reporting tool can point at the views.

### 5. Pipeline audit trail
`gold.pipeline_audit` records `layer / object / rows_loaded / status` for every object in every
layer. The full pipeline is verifiable end to end with one query:

```sql
SELECT layer, COUNT(*) AS objects, SUM(rows_loaded) AS total_rows
FROM gold.pipeline_audit
GROUP BY layer ORDER BY layer;
```

Result (verified run): bronze 14 objects / 549,706 rows · silver 15 objects / 551,167 rows ·
gold 30 objects / 1,102,346 rows.

## Technology stack

| Component | Choice |
|---|---|
| Database engine | Microsoft SQL Server 2025 Express (17.0) |
| Language | T-SQL |
| Load mechanism | `BULK INSERT` (tablock, LF row terminator) |
| Schema design | Medallion (bronze / silver / gold) |
| Modeling | Star schema, conformed dimensions, surrogate keys |
| Semantic layer | 11 indexed views (gold.v_*) |
| Execution | `sqlcmd` scripted pipeline (`06_run_pipeline.sql`) |
| Validation | Independent Python recomputation of every KPI |

## Scaling notes

- The same pattern scales to **any SQL Server edition and any volume**: bronze → silver → gold
  with an audit trail is edition-agnostic.
- For >10M rows, partition the large facts (`fact_fuel`, `fact_delivery`) by `date_sk` and switch
  `BULK INSERT` to `bcp`/`OPENROWSET` with staging + `MERGE`.
- For production refreshes, wrap each layer in an explicit transaction and extend
  `pipeline_audit` with `started_at / finished_at / duration` (already present in the schema).
