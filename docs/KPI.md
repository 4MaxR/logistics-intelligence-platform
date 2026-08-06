# KPI Definitions

Every KPI is defined once, computed from the gold layer, and verified against the source data.
Values marked **VERIFIED** were produced by running `05_kpi_queries.sql` on SQL Server 2025 and
recomputed independently from the source CSVs — the two agree exactly.

---

## KPI-01 — Gross Revenue

**Definition:** `SUM(revenue + fuel_surcharge + accessorial_charges)` over `gold.fact_load`.
**Grain:** 3-year total.
**VERIFIED: $298,621,429**
- 2022: $99,922,319 · 2023: $98,908,238 · 2024: $99,790,872 (flat ~$99M/yr)

## KPI-02 — Total Trips / Miles

**Definition:** `COUNT(trip_id)` and `SUM(actual_distance_miles)` over `gold.fact_trip`.
**VERIFIED:** 85,410 trips · 122,159,201 miles (avg 1,430 mi/trip)

## KPI-03 — On-Time Delivery Rate

**Definition:** `100 × SUM(on_time_flag) / COUNT(*)` over `gold.fact_delivery`
**filtered to** `event_type = 'Delivery'`. Delivery events only — pickups are tracked but not
counted in the service KPI.
**VERIFIED: 44.6%** (38,102 of 85,410 delivery events on time)
- 2022: 44.7% · 2023: 44.6% · 2024: 44.6% — flat, systemic

## KPI-04 — Fleet Utilization

**Definition:** `AVG(utilization_rate) × 100` over `gold.fact_truck_monthly`
(source provides the ratio; the view scales to %).
**VERIFIED: 83.0%**
- Top assets: TRK00055 89.1% · TRK00044 88.5% · TRK00039 88.2%

## KPI-05 — Fleet Fuel Efficiency

**Definition:** `AVG(average_mpg)` over `gold.fact_trip` (trip-level MPG).
**VERIFIED: 6.50 MPG**

## KPI-06 — Fuel Cost & Price

**Definition:** `SUM(total_cost)` / `SUM(gallons)` over `gold.fact_fuel`.
**VERIFIED:** $95,592,992 spend · 24,519,038 gallons · avg **$3.90/gal**
- 2022: $4.20 · 2023: $3.85 · 2024: $3.65 (price declined; MPG flat ⇒ savings came from market)

## KPI-07 — Maintenance Cost

**Definition:** `SUM(total_cost)` over `gold.fact_maintenance`.
**VERIFIED: $5,730,573** across 2,920 events (avg $1,963/event); 72,231 downtime hours.
Cost per mile view: `gold.v_maintenance_analysis` ($0.047/mi fleet-wide).

## KPI-08 — Safety Claims

**Definition:** `SUM(claim_amount)` over `gold.fact_incident`.
**VERIFIED: $2,653,172** across 170 incidents (54 at-fault, 64 preventable, 35 with injury).
Incident rate: 1.39 per million miles.

## KPI-09 — Detention Time

**Definition:** `AVG(detention_minutes)` over `gold.fact_delivery`.
**VERIFIED:** 15,636,429 total minutes · **91.5 min/event** fleet-wide
- Hotspots: Indianapolis Warehouse 93 min (54.2% on-time) · Phoenix DC 93 min (54.6%)

## KPI-10 — Top Route / Customer Concentration

**Definition:** `SUM(gross_revenue)` grouped by `dim_route.corridor` / `dim_customer.customer_name`.
**VERIFIED top routes:** Charlotte → Portland $11.2M · Seattle → Charlotte $10.9M ·
Columbus → Portland $10.9M
**VERIFIED top customers:** XYZ Wholesale $6.0M · First Manufacturing $4.5M · Metro Corp $4.4M

---

## KPI source of truth

| KPI | Primary object | KPI query |
|---|---|---|
| Gross revenue | gold.fact_load | 05_kpi_queries.sql §3 |
| Trips / miles | gold.fact_trip | 05_kpi_queries.sql §1 |
| On-time delivery | gold.fact_delivery | 05_kpi_queries.sql §2 |
| Utilization | gold.fact_truck_monthly | 05_kpi_queries.sql §6 |
| MPG | gold.fact_trip | 05_kpi_queries.sql §1 |
| Fuel | gold.fact_fuel | 05_kpi_queries.sql §7 |
| Maintenance | gold.fact_maintenance | 05_kpi_queries.sql §1 |
| Safety | gold.fact_incident | 05_kpi_queries.sql §1 |
| Detention | gold.fact_delivery | 05_kpi_queries.sql §8 |
| Routes / customers | gold.fact_load + dims | 05_kpi_queries.sql §4–5 |

**Single-line scorecard:** `SELECT * FROM gold.v_kpi_overview;`
