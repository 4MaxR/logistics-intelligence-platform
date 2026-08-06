# KPI Definitions

**Scope:** every KPI the warehouse reports — its definition, formula, business interpretation,
an example use, and the decision it supports. This is the **single source of truth** for KPI
definitions; other documents reference it instead of duplicating it. Business context:
[BUSINESS_REQUIREMENTS.md](BUSINESS_REQUIREMENTS.md).

> ✅ **Verification:** all values below were produced by executing `sql/05_kpi_queries.sql` on
> SQL Server 2025 and recomputed independently from the source CSVs. The two agree exactly.

**One-line scorecard:** `SELECT * FROM gold.v_kpi_overview;`

---

## KPI-01 — Gross Revenue

| | |
|---|---|
| **Definition** | Total commercial value of all loads, including surcharges |
| **Formula** | `SUM(revenue + fuel_surcharge + accessorial_charges)` over `gold.fact_load` |
| **Verified value** | **$298,621,429** (2022–2024) — 2022: $99.9M · 2023: $98.9M · 2024: $99.8M |
| **Business purpose** | The headline commercial number; the anchor for every ratio below |
| **Interpretation** | Revenue is remarkably stable — ~$99M/yr for three years. Growth is not the story; efficiency and service are |
| **Example use** | "Our top 5 lanes are each ≈$10.5–11.2M — where is the next 5% coming from?" |
| **Decision supported** | Whether commercial strategy should chase volume or margin |

---

## KPI-02 — Total Trips / Miles

| | |
|---|---|
| **Definition** | Operational volume and distance |
| **Formula** | `COUNT(trip_id)`, `SUM(actual_distance_miles)` over `gold.fact_trip` |
| **Verified value** | 85,410 trips · 122,159,201 miles (avg 1,430 mi/trip) |
| **Business purpose** | Volume baseline; denominator for all per-mile and per-trip ratios |
| **Interpretation** | Consistent volume with stable revenue implies flat yield per mile |
| **Example use** | Budgeting fuel and maintenance against expected miles |
| **Decision supported** | Capacity planning, rate negotiations, cost-per-mile targets |

---

## KPI-03 — On-Time Delivery Rate

| | |
|---|---|
| **Definition** | Share of **delivery events** (not pickups) that met the scheduled time |
| **Formula** | `100 × SUM(on_time_flag) / COUNT(*)` over `gold.fact_delivery WHERE event_type = 'Delivery'` |
| **Verified value** | **44.6%** (38,102 of 85,410) — 2022: 44.7% · 2023: 44.6% · 2024: 44.6% |
| **Business purpose** | The service KPI customers and contracts care about |
| **Interpretation** | **Flat for three years.** This is the single most important finding in the data — service is a systemic problem, not a seasonal or tactical one |
| **Example use** | "Our best customer has an on-time SLA — which facilities are failing it?" |
| **Decision supported** | Whether to invest in structural change (dispatch, detention, routes) vs tweaks |

---

## KPI-04 — Fleet Utilization

| | |
|---|---|
| **Definition** | Average asset utilization from the source's monthly truck metrics |
| **Formula** | `AVG(utilization_rate) × 100` over `gold.fact_truck_monthly` |
| **Verified value** | **83.0%** — top assets: TRK00055 89.1% · TRK00044 88.5% · TRK00039 88.2% |
| **Business purpose** | How hard the fleet works; the spread between assets is the actionable signal |
| **Interpretation** | 83% average with an 89% ceiling means the tail, not the fleet, is the opportunity |
| **Example use** | "Which trucks sit below 75% utilization while others hit 89%?" |
| **Decision supported** | Asset redeployment, disposal vs repair, new-capacity justification |

---

## KPI-05 — Fleet Fuel Efficiency

| | |
|---|---|
| **Definition** | Average miles per gallon across all trips |
| **Formula** | `AVG(average_mpg)` over `gold.fact_trip` |
| **Verified value** | **6.50 MPG** |
| **Business purpose** | The operational lever under company control (fuel price is not) |
| **Interpretation** | Flat at 6.5 while fuel price fell — savings came from the market, not the fleet |
| **Example use** | "Set an MPG floor per truck; review the bottom quintile monthly" |
| **Decision supported** | Driver training, idle-time policy, truck replacement timing |

---

## KPI-06 — Fuel Cost & Price

| | |
|---|---|
| **Definition** | Total fuel spend and effective price per gallon |
| **Formula** | `SUM(total_cost)`, `SUM(total_cost) / SUM(gallons)` over `gold.fact_fuel` |
| **Verified value** | **$95,592,992** · 24,519,038 gallons · avg **$3.90/gal** — 2022: $4.20 · 2023: $3.85 · 2024: $3.65 |
| **Business purpose** | The largest controllable cost line |
| **Interpretation** | The $0.55/gal decline saved ~$13M over the period — all market, zero operational |
| **Example use** | "Fuel is 32% of gross revenue — what would 0.5 MPG of improvement be worth?" |
| **Decision supported** | Fuel procurement, efficiency investment, surcharge pass-through |

---

## KPI-07 — Maintenance Cost

| | |
|---|---|
| **Definition** | Total maintenance spend and its cost per mile |
| **Formula** | `SUM(total_cost)` over `gold.fact_maintenance`; `cost / miles` in `gold.v_maintenance_analysis` |
| **Verified value** | **$5,730,573** across 2,920 events (avg $1,963/event) · 72,231 downtime hours · **$0.047/mi** |
| **Business purpose** | Asset health cost and its drag on availability |
| **Interpretation** | Spread across trucks is uneven — the analysis view exposes cost per mile per asset |
| **Example use** | "Preventive vs repair spend: which trucks cross $0.10/mi?" |
| **Decision supported** | Preventive-maintenance schedule, repair vs replace, fleet rotation |

---

## KPI-08 — Safety Claims

| | |
|---|---|
| **Definition** | Total claims exposure and incident characteristics |
| **Formula** | `SUM(claim_amount)` over `gold.fact_incident`; rate = `incidents / miles × 1,000,000` |
| **Verified value** | **$2,653,172** · 170 incidents (54 at-fault, 64 preventable, 35 with injury) · **1.39 per 1M miles** |
| **Business purpose** | Risk exposure and the share of it that is preventable |
| **Interpretation** | 37.6% of incidents are preventable — a training and policy lever, not just bad luck |
| **Example use** | "Which drivers/trucks account for the preventable incidents?" |
| **Decision supported** | Safety program investment, driver review, insurance renewal posture |

---

## KPI-09 — Detention Time

| | |
|---|---|
| **Definition** | Time spent waiting at facilities beyond schedule |
| **Formula** | `AVG(detention_minutes)` over `gold.fact_delivery` |
| **Verified value** | **91.5 min/event** · 15,636,429 total minutes · hotspots: Indianapolis & Phoenix 93 min |
| **Business purpose** | Where the network loses time — the physical cause behind service misses |
| **Interpretation** | Hotspots carry the same ~93 min average with ~54% on-time; fixing them lifts the fleet average |
| **Example use** | "Negotiate dock appointment windows at the two worst facilities" |
| **Decision supported** | Facility-level action, customer SLA terms, driver hour-of-service risk |

---

## KPI-10 — Route / Customer Concentration

| | |
|---|---|
| **Definition** | Revenue grouped by corridor or customer |
| **Formula** | `SUM(gross_revenue)` grouped by `dim_route.corridor` / `dim_customer.customer_name` |
| **Verified value** | Top routes: Charlotte → Portland $11.2M · Seattle → Charlotte $10.9M · Columbus → Portland $10.9M. Top customers: XYZ Wholesale $6.0M · First Manufacturing $4.5M · Metro Corp $4.4M |
| **Business purpose** | Where commercial risk and opportunity concentrate |
| **Interpretation** | Top customer is ~2% of revenue — the base is well diversified; the top lanes are nearly tied |
| **Example use** | "Columbus → Portland earns the best revenue per mile ($4,678) — should we push volume there?" |
| **Decision supported** | Lane strategy, customer tiering, contract negotiation priorities |

---

## KPI Source of Truth

| KPI | Primary object | Query |
|---|---|---|
| Gross revenue | gold.fact_load | `05_kpi_queries.sql` §3 |
| Trips / miles | gold.fact_trip | §1 |
| On-time delivery | gold.fact_delivery | §2 |
| Utilization | gold.fact_truck_monthly | §6 |
| MPG | gold.fact_trip | §1 |
| Fuel | gold.fact_fuel | §7 |
| Maintenance | gold.fact_maintenance | §1 |
| Safety | gold.fact_incident | §1 |
| Detention | gold.fact_delivery | §8 |
| Routes / customers | gold.fact_load + dims | §4–5 |

---

<p align="center">
  <b>Previous:</b> <a href="DATA_QUALITY.md">🛡️ DATA_QUALITY</a> ·
  <b>Next:</b> <a href="DATA_DICTIONARY.md">📚 DATA_DICTIONARY</a> ·
  <b>Back to:</b> <a href="../README.md#documentation-hub">Documentation Hub</a>
</p>
<p align="center">
  <b>Related:</b> <a href="BUSINESS_REQUIREMENTS.md">📋 Business requirements</a> · <a href="DATA_DICTIONARY.md">📚 Data dictionary</a>
</p>
