# Data Quality

This warehouse was built from a real export, and the source had **genuine data-quality issues**.
This document records every issue found, how it was detected, and how the pipeline handles it.
All counts are verified against the loaded data.

---

## Issues found (verified counts)

### 1. Missing foreign keys — trips without an asset assignment

| Issue | Count | % of table |
|---|---|---|
| `trips.driver_id` empty | 1,714 | 2.0% |
| `trips.truck_id` empty | 1,672 | 2.0% |
| `trips.trailer_id` empty | 1,680 | 2.0% |

**Detection:** `WHERE driver_id = '' OR driver_id IS NULL` against bronze.

**Handling:** These trips are **real, completed trips** (trip_status = 'Completed') — they must
not be dropped. Silver maps them to the `'-1'` Unknown surrogate; gold joins resolve to the
"Unknown Driver/Truck/Trailer" dimension rows. Analytics that need asset attribution filter
`WHERE driver_sk > 0` explicitly.

### 2. Missing foreign keys — fuel purchases

| Issue | Count |
|---|---|
| `fuel_purchases.truck_id` empty | 3,880 |
| `fuel_purchases.driver_id` empty | 3,988 |

**Detection:** empty-string scan on bronze.fuel_purchases.

**Handling:** Same orphan-safe pattern — Unknown surrogates. Note these fuel rows still carry a
valid `trip_id`, so they remain joinable to trip context.

### 3. String booleans

`on_time_flag`, `at_fault_flag`, `injury_flag`, `preventable_flag` arrive as `'True'/'False'`
strings. **Handling:** converted to BIT in silver via explicit CASE — no implicit parsing.

### 4. Empty strings vs NULL

Many optional columns (termination_date, license_state, service_description, etc.) contain
`''` rather than NULL. **Handling:** `NULLIF(LTRIM(RTRIM(col)), '')` normalizes every string
column in silver.

### 5. Whitespace

Source text fields can carry leading/trailing spaces. **Handling:** `LTRIM`/`RTRIM` applied in
silver on all text columns.

### 6. Invalid dates / numbers

Some values fail conversion (e.g. blank dates). **Handling:** all casts use `TRY_CONVERT` →
NULL. Loads never fail; bad values are visible in quality reports.

### 7. Duplicate keys

**Detection:** PK-duplicate scan on loads, trips, events, fuel, drivers, trucks.

**Result:** **0 duplicates** in every table — the source keys are clean, verified before the
warehouse was built.

### 8. Cross-field consistency — on_time_flag vs delay reasons

Delivery events carry both an `on_time_flag` and, via trips, a `trip_status`. All trips are
'Completed' in this export, so the on-time measure is the event flag alone — consistent and
unambiguous.

---

## Quality checks embedded in the pipeline

| Check | Where | What it proves |
|---|---|---|
| Row-count audit per table | end of each layer script | bronze = source CSV counts exactly |
| Orphan report (facts → dims) | end of 02_silver_layer.sql | lists every '-1' count per FK |
| 8-point FK orphan check | end of 03_gold_layer.sql | 0 orphaned references in gold |
| pipeline_audit table | all layers | 59 rows: every object, layer, count, status |

## Quality metrics (verified run)

| Metric | Value |
|---|---|
| Bronze rows loaded | 549,706 (14 tables) |
| Silver objects | 15 (7 dims + 8 facts) |
| Gold objects | 30 (7 dims + 8 facts + 11 views + audit) |
| Orphaned gold references | **0** |
| Rows dropped by the pipeline | **0** |
| Duplicate source keys | **0** |
| Cross-validation vs source CSVs | **100% match on all KPIs** |

## The honest framing

The dataset is realistic: 2% of trips have no asset assignment and 2% of fuel purchases lack
truck/driver. A naive pipeline would either drop those rows (losing revenue facts) or silently
join them to garbage. This warehouse **keeps every row** and makes the unassigned population
explicit and filterable — which is exactly how production logistics data behaves.
