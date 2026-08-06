# Data Dictionary

All objects in the `LogisticsIntelligenceDW` database, grouped by layer. Types are as built in
the SQL Server scripts. Source of truth for relationships: `data/DATABASE_SCHEMA.txt`.

---

## BRONZE — raw staging (bronze.*)

One table per source CSV. All columns `NVARCHAR` (raw, untransformed). Row counts are the
verified load results.

| Table | Rows | Source file |
|---|---|---|
| bronze.drivers | 150 | drivers.csv |
| bronze.trucks | 120 | trucks.csv |
| bronze.trailers | 180 | trailers.csv |
| bronze.customers | 200 | customers.csv |
| bronze.facilities | 50 | facilities.csv |
| bronze.routes | 58 | routes.csv |
| bronze.loads | 85,410 | loads.csv |
| bronze.trips | 85,410 | trips.csv |
| bronze.fuel_purchases | 196,442 | fuel_purchases.csv |
| bronze.maintenance_records | 2,920 | maintenance_records.csv |
| bronze.delivery_events | 170,820 | delivery_events.csv |
| bronze.safety_incidents | 170 | safety_incidents.csv |
| bronze.driver_monthly_metrics | 4,464 | driver_monthly_metrics.csv |
| bronze.truck_utilization_metrics | 3,312 | truck_utilization_metrics.csv |

**Total bronze rows: 549,706**

---

## SILVER — clean conformed layer (silver.*)

### Dimensions

| Table | Key | Rows | Notes |
|---|---|---|---|
| silver.dim_driver | driver_id (PK) | 150 | + full_name, hire/termination dates, license, terminal, status, CDL, experience; computed `is_active` |
| silver.dim_truck | truck_id (PK) | 120 | + unit_number, make, model_year, VIN, acquisition, fuel_type, tank capacity, status, terminal |
| silver.dim_trailer | trailer_id (PK) | 180 | + trailer_number, type, length, model_year, VIN, status, location |
| silver.dim_customer | customer_id (PK) | 200 | + name, type, credit terms, freight type, account status, contract start, revenue potential |
| silver.dim_facility | facility_id (PK) | 50 | + name, type, city/state, lat/long, dock doors, hours |
| silver.dim_route | route_id (PK) | 58 | + origin/destination, typical distance, rate per mile, fuel surcharge rate, transit days; computed corridor |
| silver.dim_date | date_id (PK) | 1,461 | 2022-01-01 → 2025-12-31; year/month/day/quarter/weekday, month/weekday name, is_weekend, season |

### Facts

| Table | Grain | Rows | Measures |
|---|---|---|---|
| silver.fact_load | 1 row per load | 85,410 | weight_lbs, pieces, revenue, fuel_surcharge, accessorial_charges; computed `gross_revenue` |
| silver.fact_trip | 1 row per trip | 85,410 | actual_distance_miles, actual_duration_hours, fuel_gallons_used, average_mpg, idle_time_hours |
| silver.fact_delivery | 1 row per event | 170,820 | scheduled/actual datetime, detention_minutes, on_time_flag (BIT) |
| silver.fact_fuel | 1 row per purchase | 196,442 | gallons, price_per_gallon, total_cost |
| silver.fact_maintenance | 1 row per record | 2,920 | odometer_reading, labor_hours, labor_cost, parts_cost, total_cost, downtime_hours |
| silver.fact_incident | 1 row per incident | 170 | at_fault/injury/preventable (BIT), vehicle/cargo damage, claim_amount |
| silver.fact_driver_monthly | 1 row per driver-month | 4,464 | trips_completed, total_miles, total_revenue, avg_mpg, fuel gallons, on-time rate, idle hours |
| silver.fact_truck_monthly | 1 row per truck-month | 3,312 | trips, miles, revenue, mpg, maintenance events/cost, downtime, utilization_rate (0–1) |

Orphan convention: facts reference `'-1'` when the parent key is missing from the source dim
(e.g. trips without a driver). No fact row is ever dropped.

---

## GOLD — star schema (gold.*)

### Dimensions (surrogate keys, `-1` = Unknown)

| Table | PK | Unique business key | Rows |
|---|---|---|---|
| gold.dim_date | date_id (DATE) | — (calendar) | 1,461 |
| gold.dim_driver | driver_sk (IDENTITY) | driver_id | 151 (150 + Unknown) |
| gold.dim_truck | truck_sk (IDENTITY) | truck_id | 121 (120 + Unknown) |
| gold.dim_trailer | trailer_sk (IDENTITY) | trailer_id | 181 (180 + Unknown) |
| gold.dim_customer | customer_sk (IDENTITY) | customer_id | 201 (200 + Unknown) |
| gold.dim_facility | facility_sk (IDENTITY) | facility_id | 51 (50 + Unknown) |
| gold.dim_route | route_sk (IDENTITY) | route_id | 59 (58 + Unknown) |

### Facts (FK-constrained to dims)

| Table | Grain | Rows | FK columns |
|---|---|---|---|
| gold.fact_load | load | 85,410 | customer_sk, route_sk, date_sk |
| gold.fact_trip | trip | 85,410 | driver_sk, truck_sk, trailer_sk, date_sk (+ load_id degenerate) |
| gold.fact_delivery | event | 170,820 | facility_sk, date_sk (+ load_id, trip_id degenerate) |
| gold.fact_fuel | purchase | 196,442 | truck_sk, driver_sk, date_sk (+ trip_id degenerate) |
| gold.fact_maintenance | record | 2,920 | truck_sk, date_sk |
| gold.fact_incident | incident | 170 | truck_sk, driver_sk, date_sk (+ trip_id degenerate) |
| gold.fact_driver_monthly | driver-month | 4,464 | driver_sk, date_sk |
| gold.fact_truck_monthly | truck-month | 3,312 | truck_sk, date_sk |

### Business views (semantic layer)

| View | Answers |
|---|---|
| gold.v_kpi_overview | One-row headline scorecard (revenue, miles, MPG, on-time %, utilization, claims) |
| gold.v_load_profitability | Per-load revenue, surcharge, accessorial, revenue per 1k lbs |
| gold.v_route_performance | Per-route loads, revenue, revenue per mile |
| gold.v_customer_service | Per-customer loads, revenue, on-time % |
| gold.v_driver_performance | Per-driver trips, miles, MPG, idle, speed, on-time % |
| gold.v_fleet_utilization | Per-truck trips, miles, utilization %, downtime, maintenance cost |
| gold.v_fuel_efficiency | Monthly gallons, fuel cost, avg price per gallon |
| gold.v_maintenance_analysis | Per-truck events, cost, downtime, cost per mile |
| gold.v_safety_dashboard | Annual incidents, at-fault, injuries, preventable, damage, claims |
| gold.v_monthly_trend | Monthly loads, revenue, weight by year/month/season |
| gold.v_detention_analysis | Per-facility events, detention minutes, on-time % |

### Other

| Object | Purpose |
|---|---|
| gold.pipeline_audit | 59 rows: every object loaded in every layer with row counts and status |
