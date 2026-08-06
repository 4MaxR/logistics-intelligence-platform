# Data Dictionary

**Scope:** every object in the `LogisticsIntelligenceDW` database — with business meaning, allowed
values, relationships, and example values. This is the **reference document**: read it when you
need to know what a column means, not for the design story (that's
[ARCHITECTURE.md](ARCHITECTURE.md) and [STAR_SCHEMA.md](STAR_SCHEMA.md)). Source of truth for
relationships: `data/DATABASE_SCHEMA.txt`.

---

## 1. Layer Overview

| Layer | Schema | Objects | Rows (verified) | Purpose |
|---|---|---|---|---|
| Bronze | `bronze` | 14 staging tables | 549,706 | Raw, immutable source copy |
| Silver | `silver` | 7 dims + 8 facts | 551,167 | Clean, typed, validated |
| Gold | `gold` | 7 dims + 8 facts + 11 views + audit | 1,102,346 | Star schema + semantic layer |

---

## 2. Bronze — Raw Staging

One table per source CSV, all columns `NVARCHAR`, **no transformation**. Row counts match the
source export exactly.

| Table | Rows | Source file | Business content |
|---|---|---|---|
| bronze.drivers | 150 | drivers.csv | Driver demographics, licenses, employment |
| bronze.trucks | 120 | trucks.csv | Fleet equipment, acquisition, status |
| bronze.trailers | 180 | trailers.csv | Trailer inventory, types, status |
| bronze.customers | 200 | customers.csv | Customer accounts, contracts, revenue potential |
| bronze.facilities | 50 | facilities.csv | Terminals and warehouses, capacity |
| bronze.routes | 58 | routes.csv | Origin-destination pairs, rates |
| bronze.loads | 85,410 | loads.csv | Shipment details, revenue, booking type |
| bronze.trips | 85,410 | trips.csv | Trip execution: distance, fuel, duration |
| bronze.fuel_purchases | 196,442 | fuel_purchases.csv | Fuel transactions, prices, locations |
| bronze.maintenance_records | 2,920 | maintenance_records.csv | Service history, costs, downtime |
| bronze.delivery_events | 170,820 | delivery_events.csv | Pickup/delivery timestamps, on-time status |
| bronze.safety_incidents | 170 | safety_incidents.csv | Accidents, violations, damage costs |
| bronze.driver_monthly_metrics | 4,464 | driver_monthly_metrics.csv | Monthly driver performance (pre-aggregated) |
| bronze.truck_utilization_metrics | 3,312 | truck_utilization_metrics.csv | Monthly equipment utilization (pre-aggregated) |

---

## 3. Silver — Clean Conformed Layer

### 3.1 Dimensions

#### silver.dim_driver — 150 rows

| Column | Type | Business meaning | Allowed values / example |
|---|---|---|---|
| driver_id | NVARCHAR(20) PK | Unique driver key | `DRV00001` |
| full_name | NVARCHAR(101) | Driver name (computed) | `Jennifer Hernandez` |
| hire_date / termination_date | DATE | Employment window | `2014-10-31` / NULL = still employed |
| license_number / license_state | NVARCHAR | CDL credentials | `DL673510887` / `WA` |
| date_of_birth | DATE | Age context | `1973-11-07` |
| home_terminal | NVARCHAR(50) | Base facility city | `Denver` |
| employment_status | NVARCHAR(20) | Employment state | `Active` (124) · `Terminated` (26) |
| cdl_class | NVARCHAR(5) | License class | `A` |
| years_experience | INT | Tenure in years | `3` |
| is_active | BIT (computed) | Status flag | 1 = Active |

**Usage note:** filter `WHERE is_active = 1` for current-driver analysis; the fact layer keeps
historical trips even after termination.

#### silver.dim_truck — 120 rows

| Column | Type | Business meaning | Allowed values / example |
|---|---|---|---|
| truck_id | NVARCHAR(20) PK | Unique asset key | `TRK00055` |
| unit_number | NVARCHAR(20) | Yard number | `3463` |
| make | NVARCHAR(50) | Manufacturer | `Peterbilt` · `Kenworth` · `Volvo` · `Freightliner` · `International` |
| model_year | INT | Year built | `2016` |
| vin | NVARCHAR(30) | Vehicle identification | `1VV205190335317039` |
| acquisition_date / acquisition_mileage | DATE / INT | Purchase context | `2017-04-27` / `18814` |
| fuel_type | NVARCHAR(20) | Powerplant | `Diesel` |
| tank_capacity_gallons | INT | Fuel capacity | `200` |
| status | NVARCHAR(20) | Fleet state | `Active` (92) · `Maintenance` (15) · `Inactive` (13) |
| home_terminal | NVARCHAR(50) | Base city | `Omaha` |

**Usage note:** `status` changes over time — currently SCD Type 1 (see
[STAR_SCHEMA.md](STAR_SCHEMA.md#6-slowly-changing-dimensions-scd)).

#### silver.dim_trailer — 180 rows

| Column | Type | Business meaning | Allowed values / example |
|---|---|---|---|
| trailer_id | NVARCHAR(20) PK | Unique trailer key | `TRL00167` |
| trailer_number | NVARCHAR(20) | Yard number | — |
| trailer_type | NVARCHAR(50) | Equipment class | `Dry Van` · `Reefer` · `Flatbed` |
| length_feet | INT | Size | `53` |
| model_year / vin | INT / NVARCHAR | Equipment age / identity | `2019` / VIN |
| acquisition_date | DATE | Purchase date | `2020-03-15` |
| status | NVARCHAR(20) | Fleet state | `Active` · `Maintenance` · `Inactive` |
| current_location | NVARCHAR(50) | Last known city | `Chicago` |

#### silver.dim_customer — 200 rows

| Column | Type | Business meaning | Allowed values / example |
|---|---|---|---|
| customer_id | NVARCHAR(20) PK | Unique customer key | `CUST00001` |
| customer_name | NVARCHAR(100) | Account name | `Metro Wholesale` |
| customer_type | NVARCHAR(30) | Booking relationship | `Dedicated` · `Contract` · `Spot` |
| credit_terms_days | INT | Payment terms | `60` · `30` · `15` |
| primary_freight_type | NVARCHAR(30) | Commodity class | `General` · `Retail` · `Food/Beverage` · `Consumer Goods` |
| account_status | NVARCHAR(20) | Account state | `Active` (168) · `Inactive` (32) |
| contract_start_date | DATE | Relationship start | `2020-02-20` |
| annual_revenue_potential | DECIMAL(12,0) | Estimated annual value | `985117` |

**Usage note:** `customer_type` maps to `loads.booking_type` — a load's booking type should agree
with the customer's relationship type.

#### silver.dim_facility — 50 rows

| Column | Type | Business meaning | Allowed values / example |
|---|---|---|---|
| facility_id | NVARCHAR(20) PK | Unique facility key | `FAC00034` |
| facility_name | NVARCHAR(100) | Terminal/warehouse name | `Houston Distribution Center` |
| facility_type | NVARCHAR(30) | Role | `Cross-Dock` · `Warehouse` · `Terminal` |
| city / state | NVARCHAR | Location | `Houston` / `TX` |
| latitude / longitude | DECIMAL(9,6) | Geoposition | `29.7604` / `-95.3698` |
| dock_doors | INT | Loading capacity | `125` |
| operating_hours | NVARCHAR(20) | Schedule | `24/7` |

#### silver.dim_route — 58 rows

| Column | Type | Business meaning | Allowed values / example |
|---|---|---|---|
| route_id | NVARCHAR(20) PK | Unique lane key | `RTE00001` |
| origin_city / origin_state | NVARCHAR | Lane start | `Atlanta` / `GA` |
| destination_city / destination_state | NVARCHAR | Lane end | `Chicago` / `IL` |
| origin_full / destination_full | NVARCHAR (computed) | Display strings | `Atlanta, GA` |
| corridor | NVARCHAR (computed) | Lane label | `Atlanta -> Chicago` |
| typical_distance_miles | INT | Booked distance | `677` |
| base_rate_per_mile | DECIMAL(6,2) | Contract rate | `1.70` |
| fuel_surcharge_rate | DECIMAL(6,3) | FSC multiplier | `0.19` |
| typical_transit_days | INT | Expected duration | `1` |

#### silver.dim_date — 1,461 rows (2022-01-01 → 2025-12-31)

| Column | Type | Business meaning | Example |
|---|---|---|---|
| date_id | DATE PK | Calendar day | `2024-06-15` |
| year_nbr / quarter_nbr / month_nbr / day_nbr | INT | Date parts | `2024` / `2` / `6` / `15` |
| weekday_nbr | INT | 1 = Sunday … 7 = Saturday | `7` |
| month_name / weekday_name | NVARCHAR | Display names | `June` / `Saturday` |
| is_weekend | BIT | 1 = Sat/Sun | `1` |
| season | NVARCHAR(10) | Weather band | `Summer` (Dec–Feb = Winter, Mar–May = Spring, Jun–Aug = Summer, else Fall) |

**Usage note:** the single conformed calendar — every fact joins this. Do not create another
date table.

### 3.2 Facts

| Table | Grain | Rows | Key columns (business meaning) |
|---|---|---|---|
| silver.fact_load | one load | 85,410 | `revenue` (linehaul), `fuel_surcharge`, `accessorial_charges` (extras), `gross_revenue` (computed total), `weight_lbs`, `pieces`, `load_type` (Dry Van/Refrigerated), `booking_type` (Spot/Dedicated/Contract), `load_status` |
| silver.fact_trip | one trip | 85,410 | `actual_distance_miles`, `actual_duration_hours`, `fuel_gallons_used`, `average_mpg`, `idle_time_hours`, `trip_status` (all `Completed` in this export) |
| silver.fact_delivery | one event | 170,820 | `event_type` (Pickup/Delivery — 85,410 each), `scheduled_datetime`/`actual_datetime`, `detention_minutes`, `on_time_flag` (BIT), `location_city/state` |
| silver.fact_fuel | one purchase | 196,442 | `gallons`, `price_per_gallon`, `total_cost`, `location_city/state`, `fuel_card_number` |
| silver.fact_maintenance | one record | 2,920 | `maintenance_type` (Inspection/Tire/Preventive/Repair/Transmission/Brake/Engine), `labor_hours`, `labor_cost`, `parts_cost`, `total_cost`, `downtime_hours`, `odometer_reading` |
| silver.fact_incident | one incident | 170 | `incident_type` (Accident/DOT Violation/Equipment Damage/Moving Violation/Customer Complaint), `at_fault_flag`, `injury_flag`, `preventable_flag` (BIT), `vehicle_damage_cost`, `cargo_damage_cost`, `claim_amount` |
| silver.fact_driver_monthly | one driver-month | 4,464 | `trips_completed`, `total_miles`, `total_revenue`, `average_mpg`, `total_fuel_gallons`, `on_time_delivery_rate`, `average_idle_hours` |
| silver.fact_truck_monthly | one truck-month | 3,312 | `trips_completed`, `total_miles`, `total_revenue`, `average_mpg`, `maintenance_events`, `maintenance_cost`, `downtime_hours`, `utilization_rate` (0–1 ratio, may exceed 1.0) |

**Orphan convention (silver):** facts reference `'-1'` when the parent key is missing from the
source dim — e.g. trips without a truck. No fact row is ever dropped. Counts:
[DATA_QUALITY.md](DATA_QUALITY.md#3-referential-integrity).

---

## 4. Gold — Star Schema

### 4.1 Dimensions (surrogate keys, `-1` = Unknown)

| Table | PK | Business key | Rows | Adds vs silver |
|---|---|---|---|---|
| gold.dim_date | date_id (DATE) | — | 1,461 | copy of silver calendar |
| gold.dim_driver | driver_sk (IDENTITY) | driver_id (UNIQUE) | 151 | + Unknown row |
| gold.dim_truck | truck_sk (IDENTITY) | truck_id (UNIQUE) | 121 | + Unknown row |
| gold.dim_trailer | trailer_sk (IDENTITY) | trailer_id (UNIQUE) | 181 | + Unknown row |
| gold.dim_customer | customer_sk (IDENTITY) | customer_id (UNIQUE) | 201 | + Unknown row |
| gold.dim_facility | facility_sk (IDENTITY) | facility_id (UNIQUE) | 51 | + Unknown row |
| gold.dim_route | route_sk (IDENTITY) | route_id (UNIQUE) | 59 | + Unknown row |

**Example:** `driver_sk = -1` → "Unknown Driver"; `driver_sk = 1` → the first real driver.

### 4.2 Facts (FK-constrained)

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

### 4.3 Business Views (semantic layer)

| View | Answers | Key columns |
|---|---|---|
| gold.v_kpi_overview | "How is the operation doing?" (one row) | total_trips, gross_revenue, total_miles, avg_mpg, fuel_cost, maintenance_cost, claims_total, on_time_delivery_pct, avg_utilization_pct, active_drivers, active_trucks |
| gold.v_load_profitability | Per-load commercial detail | revenue, fuel_surcharge, accessorial_charges, gross_revenue, revenue_per_1k_lbs |
| gold.v_route_performance | Lane economics | corridor, loads, gross_revenue, revenue_per_mile |
| gold.v_customer_service | Customer value + service | loads, gross_revenue, trips, on_time_pct |
| gold.v_driver_performance | Driver economics | trips, total_miles, avg_mpg, idle_hours, avg_speed_mph, on_time_pct |
| gold.v_fleet_utilization | Asset economics | trips, total_miles, total_hours, avg_utilization_pct, downtime_hours, maintenance_cost |
| gold.v_fuel_efficiency | Fuel trend | purchases, gallons, fuel_cost, avg_gallons_per_purchase, avg_price_per_gallon |
| gold.v_maintenance_analysis | Asset health cost | maintenance_events, maintenance_cost, downtime_hours, cost_per_mile |
| gold.v_safety_dashboard | Risk trend | incidents, at_fault, with_injury, preventable, vehicle_damage, cargo_damage, claims |
| gold.v_monthly_trend | Seasonality | loads, gross_revenue, total_weight_lbs by year/month/season |
| gold.v_detention_analysis | Facility bottlenecks | events, detention_minutes, avg_detention_min, on_time_pct |

### 4.4 Other

| Object | Purpose |
|---|---|
| gold.pipeline_audit | 59 rows: every object loaded in every layer, with row counts and status |

---

## 5. Cross-References

| Need | Document |
|---|---|
| Business meaning of a KPI | [KPI.md](KPI.md) |
| Why a column is modeled this way | [STAR_SCHEMA.md](STAR_SCHEMA.md) |
| Where the data came from | [ETL.md](ETL.md#2-extraction) |
| Why some values are `-1` | [DATA_QUALITY.md](DATA_QUALITY.md#3-referential-integrity) |
| The source relationships | `data/DATABASE_SCHEMA.txt` |

---

<p align="center">
  <b>Previous:</b> <a href="KPI.md">📏 KPI</a> ·
  <b>Next:</b> <a href="../README.md">📘 back to README</a> ·
  <b>Back to:</b> <a href="../README.md#documentation-hub">Documentation Hub</a>
</p>
<p align="center">
  <b>Related:</b> <a href="STAR_SCHEMA.md">⭐ Star schema</a> · <a href="DATA_QUALITY.md">🛡️ Data quality</a>
</p>
