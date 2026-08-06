# ETL Documentation

The pipeline is a **three-layer ETL (Extract → Load → Transform)** implemented entirely in
T-SQL. Extract and Load happen together in the bronze layer (BULK INSERT); Transform happens in
silver and gold.

---

## Pipeline execution order

```text
sql/00_database.sql        → creates DB, schemas (bronze/silver/gold), pipeline_audit
sql/01_bronze_layer.sql    → EXTRACT + LOAD (raw staging, 14 tables)
sql/02_silver_layer.sql    → TRANSFORM (clean, type, validate, conform)
sql/03_gold_layer.sql      → TRANSFORM (star schema, surrogate keys, constraints)
sql/04_business_views.sql  → SEMANTIC LAYER (11 business views)
sql/05_kpi_queries.sql     → REPORT (the verified KPI numbers)
```

One command runs everything:

```bash
sqlcmd -S localhost -E -C -i sql/06_run_pipeline.sql
```

Each script is **idempotent**: it drops and recreates its own targets, so re-running the pipeline
produces an identical database. All loads are recorded in `gold.pipeline_audit`.

---

## Step 1 — Extract & Load (bronze)

**Mechanism:** `BULK INSERT` from CSV with `FIRSTROW = 2` (skip header),
`FIELDTERMINATOR = ','`, `ROWTERMINATOR = '0x0a'` (LF — verified in the source files),
`TABLOCK` (minimal logging on the default recovery model).

**Design choices**
- All staging columns are `NVARCHAR` — **zero coercion at load time**. A bad date or number in
  the source can never fail the load; it fails later in silver where it can be seen and reported.
- File paths are parameterized through a `@data_dir` variable and concatenated dynamically, so
  moving the repo only requires changing one path.
- Every table's load is recorded in `pipeline_audit` (layer='bronze', rows_loaded=COUNT(*)).

**Verified result:** 14 tables, 549,706 rows — identical to the source CSVs.

## Step 2 — Transform (silver)

Silver is a single auditable pass per object:

1. **Type casting** — every column is converted with `TRY_CONVERT` to its native type
   (DATE, DECIMAL, INT, BIT, DATETIME2(0)). Rows that fail casting get NULL, never a load error.
2. **NULL normalization** — `NULLIF(LTRIM(RTRIM(col)), '')` converts empty strings and
   whitespace-only values to NULL.
3. **Boolean conversion** — `'True'/'False'` → `1/0` via `CASE` (on_time_flag, at_fault_flag,
   injury_flag, preventable_flag).
4. **Date truncation** — fuel `purchase_date` is truncated to the date part
   (`LEFT(col, 10)` → DATE) since the gold layer models daily grain.
5. **FK validation** — every fact joins its parent dim with `LEFT JOIN`; missing parents are
   mapped to `'-1'` (Unknown) so **no fact row is dropped**. A data-quality report at the end of
   the script lists every orphan count per fact/FK.

**Verified result:** 15 objects, 551,167 rows (7 dims + 8 facts; the +1,461 delta vs bronze is
the generated calendar dimension).

## Step 3 — Transform (gold / star schema)

1. **Surrogate keys** — dimensions are rebuilt with `INT IDENTITY(1,1)` SKs; the `-1` Unknown
   row is inserted first so it always gets the lowest SK. Natural keys stay as UNIQUE columns.
2. **Conformed calendar** — `silver.dim_date` (1,461 days, 2022-01-01 → 2025-12-31) is copied to
   gold and becomes the single date dimension for every fact.
3. **Fact load** — facts join their dims on natural key and store the SK; degenerate keys
   (load_id, trip_id) are carried on the fact.
4. **Integrity** — FK constraints are declared on the tables, then an 8-point orphan check runs;
   all checks return 0 on the verified run.

**Verified result:** 30 objects, 1,102,346 rows (dims + facts; more rows than silver because the
same dims are counted once per layer, and monthly facts carry their own rows).

## Step 4 — Semantic layer (views)

Eleven `gold.v_*` views wrap the star schema with business-readable column names and precomputed
ratios (on_time_pct, revenue_per_mile, utilization_pct, cost_per_mile). Management and BI tools
query views, never base tables. See `04_business_views.sql` and KPI.md.

---

## Data-flow guarantees

| Guarantee | Mechanism | Verified |
|---|---|---|
| No silent row loss | FK LEFT JOIN + '-1' surrogate | bronze 549,706 → silver facts 549,706 equivalent |
| No orphaned facts | FK constraints + 8-point check | all 0 |
| Reproducible loads | Idempotent DROP+CREATE per script | re-runnable |
| Auditable pipeline | gold.pipeline_audit (59 rows) | layer/object/rows/status |
| Casting never kills a load | TRY_CONVERT → NULL | 0 load failures |
| Numbers are real | Independent Python recomputation | every KPI matches |

## Production evolution

- Replace CSV `BULK INSERT` with `bcp`/`OPENROWSET` staging + `MERGE` for incremental loads.
- Wrap each layer in a transaction; extend `pipeline_audit` with duration and row-count deltas.
- Add partitioning on `date_sk` for fact tables above ~10M rows.
- Add SSIS/Airflow orchestration with failure alerting per step.
