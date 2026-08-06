# Business Requirements Document

**Project:** Logistics Intelligence Platform
**Status:** Approved · Implemented · Verified
**Version:** 2.0 (documentation revision)

This document is the business contract for the warehouse: the goals it serves, the stakeholders it
supports, and the questions it must answer. Every requirement below is implemented in the gold
layer and its answer is verified against the executed warehouse. KPI definitions and formulas live
in [KPI.md](KPI.md); this document states *what* must be answered and *why*.

---

## 1. Business Goals

| # | Goal | Why it matters |
|---|---|---|
| G1 | Create one source of truth for revenue, service, cost, and risk | The operation ran on 14 disconnected tables; cross-functional questions were unanswerable |
| G2 | Make service performance visible and comparable over time | On-time delivery was assumed to be improving; the data shows a 3-year plateau at 44.6% |
| G3 | Attribute cost accurately — fuel, maintenance, claims — to assets and lanes | Management could not answer *"which truck costs us the most per mile?"* |
| G4 | Deliver answers management can query without a data engineer | The semantic view layer turns questions into `SELECT * FROM gold.v_*` |
| G5 | Preserve every source row through the pipeline | 2% of trips lack asset assignments; dropping them would erase real revenue |

---

## 2. Stakeholders

| Stakeholder | Interest | What they consume |
|---|---|---|
| **VP Operations** | Service reliability, detention, capacity planning | `gold.v_kpi_overview`, `gold.v_detention_analysis` |
| **Finance** | Revenue, fuel spend, maintenance cost, claims exposure | `gold.v_load_profitability`, `gold.v_fuel_efficiency`, `gold.v_safety_dashboard` |
| **Fleet Manager** | Utilization, downtime, maintenance cost per asset | `gold.v_fleet_utilization`, `gold.v_maintenance_analysis` |
| **Sales / Account Managers** | Customer revenue and service level | `gold.v_customer_service` |
| **Analytics team** | A trustworthy, documented base to build on | Full gold layer + this documentation set |

---

## 3. KPIs at a Glance

| KPI | Value (verified) | Definition lives in |
|---|---|---|
| Gross revenue | $298.6M | [KPI.md → KPI-01](KPI.md#kpi-01--gross-revenue) |
| On-time delivery rate | 44.6% | [KPI.md → KPI-03](KPI.md#kpi-03--on-time-delivery-rate) |
| Fleet utilization | 83.0% | [KPI.md → KPI-04](KPI.md#kpi-04--fleet-utilization) |
| Fleet MPG | 6.50 | [KPI.md → KPI-05](KPI.md#kpi-05--fleet-fuel-efficiency) |
| Fuel spend / avg price | $95.6M / $3.90 | [KPI.md → KPI-06](KPI.md#kpi-06--fuel-cost--price) |
| Maintenance spend | $5.73M | [KPI.md → KPI-07](KPI.md#kpi-07--maintenance-cost) |
| Safety claims | $2.65M | [KPI.md → KPI-08](KPI.md#kpi-08--safety-claims) |
| Detention (avg/event) | 91.5 min | [KPI.md → KPI-09](KPI.md#kpi-09--detention-time) |

---

## 4. Business Questions (BR-01 … BR-11)

Each requirement: the question, the verified answer from the executed warehouse, and the object
that provides it. Formulas and interpretation: [KPI.md](KPI.md).

### BR-01 — Executive health check
**Question:** How is the operation doing overall — volume, revenue, efficiency, service?

**Answer (verified):** 85,410 trips · 170,820 delivery events · $298.6M gross revenue ·
122.2M miles · 44.6% on-time · 83.0% utilization · 6.50 MPG.

**Provides:** `gold.v_kpi_overview` · `gold.fact_trip` · `gold.fact_delivery` · `gold.fact_load`

### BR-02 — On-time delivery trend
**Question:** Is service reliability improving?

**Answer (verified):** **No.** 44.7% → 44.6% → 44.6% across 2022–2024. The plateau is the finding —
service is a systemic problem, not a seasonal or tactical one.

**Provides:** `gold.fact_delivery` + `gold.dim_date` (KPI query 2)

### BR-03 — Route profitability
**Question:** Which lanes make the most money, and which earn best per mile?

**Answer (verified):** Top corridors by revenue: Charlotte → Portland ($11.2M), Seattle →
Charlotte ($10.9M), Columbus → Portland ($10.9M). Columbus → Portland earns the best revenue per
mile ($4,678).

**Provides:** `gold.v_route_performance` · `gold.fact_load` + `gold.dim_route`

### BR-04 — Customer value & service
**Question:** Who are the top customers, and are they served well?

**Answer (verified):** XYZ Wholesale ($6.0M, Contract), First Manufacturing ($4.5M, Spot),
Metro Corp ($4.4M, Contract). Top customer is ~2% of revenue — the base is well diversified.

**Provides:** `gold.v_customer_service` · `gold.fact_load` + `gold.dim_customer`

### BR-05 — Fleet utilization
**Question:** Are trucks working hard enough?

**Answer (verified):** Fleet average 83.0%; top assets exceed 89% (TRK00055, TRK00044).
Utilization + downtime side by side exposes the tail to target.

**Provides:** `gold.v_fleet_utilization` · `gold.fact_truck_monthly`

### BR-06 — Fuel efficiency & cost
**Question:** Where does fuel spend go, and is efficiency improving?

**Answer (verified):** $95.6M / 24.5M gallons over 3 years. Price fell $4.20 → $3.65/gal while MPG
stayed ~6.5 — **savings came from the market, not operations.**

**Provides:** `gold.v_fuel_efficiency` · `gold.fact_fuel`

### BR-07 — Maintenance cost & downtime
**Question:** Where is maintenance spend concentrated?

**Answer (verified):** $5.73M across 2,920 events (avg ~$1,963/event), 72,231 downtime hours.
Cost per mile per truck exposed in the view.

**Provides:** `gold.v_maintenance_analysis` · `gold.fact_maintenance`

### BR-08 — Safety & claims exposure
**Question:** What is our incident and claims exposure?

**Answer (verified):** 170 incidents, $2.65M claims; 54 at-fault (31.8%), 64 preventable (37.6%),
35 with injuries. Rate: 1.39 incidents per million miles.

**Provides:** `gold.v_safety_dashboard` · `gold.fact_incident`

### BR-09 — Detention & facility bottlenecks
**Question:** Which facilities burn the most detention time?

**Answer (verified):** Indianapolis Warehouse and Phoenix Distribution Center average
93 min/event with ~54% on-time — the worst of the network. Fleet-wide: 91.5 min/event,
15.6M total minutes.

**Provides:** `gold.v_detention_analysis` · `gold.fact_delivery` + `gold.dim_facility`

### BR-10 — Seasonality & capacity
**Question:** When is demand highest?

**Answer (verified):** ~7,300 loads/month in peak months (Oct/Jan/Aug); revenue steady at ~$99M/yr
across all three years. Capacity planning windows: summer (Jun–Aug) and winter peak (Dec–Jan).

**Provides:** `gold.v_monthly_trend` · `gold.fact_load` + `gold.dim_date`

### BR-11 — Data integrity
**Question:** Can management trust the numbers?

**Answer (verified):** Yes. Every load is in `gold.pipeline_audit`; gold-layer FK checks return
**0 orphaned references**; every KPI was recomputed independently from the source CSVs and matches
exactly. Details: [DATA_QUALITY.md](DATA_QUALITY.md).

---

## 5. Success Criteria

| Criterion | Status |
|---|---|
| All 14 source tables loaded with row counts matching the CSVs exactly | ✅ 549,706 rows |
| Zero rows dropped between source and gold | ✅ verified |
| Zero orphaned foreign keys in the gold layer | ✅ 8-point check = 0 |
| Every KPI reproducible from the warehouse *and* from the raw CSVs | ✅ 100% match |
| Management questions answerable via views (no joins required by the consumer) | ✅ 11 views |
| Pipeline re-runnable (idempotent) with a single command | ✅ `sqlcmd -i 06_run_pipeline.sql` |

---

## 6. Assumptions

1. The source CSVs are the authoritative export of the operations database
   (`DATABASE_SCHEMA.txt` defines relationships).
2. Row counts must be preserved end to end; missing attributes are handled, missing facts are not.
3. The on-time KPI counts **delivery events only** — pickups are tracked but not scored.
4. The monthly metrics tables (`driver_monthly_metrics`, `truck_utilization_metrics`) are trusted
   pre-aggregations from the source and are loaded as facts at their own grain.
5. `utilization_rate` in the source is a ratio (0–1) and is scaled to % in the views.

---

## 7. Constraints

| Constraint | Impact |
|---|---|
| SQL-only mandate | No Python in the pipeline; the warehouse must stand alone. (Python was used only to cross-validate results.) |
| Single database instance | All layers in one database (`LogisticsIntelligenceDW`) with schema-level separation |
| Source data is dirty by design | 2% missing FK values must be handled, not papered over |
| Full-reload pipeline | Bronze/silver/gold rebuild on each run; incremental loading is a future enhancement (see [ETL.md](ETL.md#9-future-incremental-loads)) |

---

<p align="center">
  <b>Previous:</b> <a href="../README.md">📘 README</a> ·
  <b>Next:</b> <a href="ARCHITECTURE.md">🏗️ ARCHITECTURE</a> ·
  <b>Back to:</b> <a href="../README.md#documentation-hub">Documentation Hub</a>
</p>
<p align="center">
  <b>Related:</b> <a href="KPI.md">📏 KPI definitions</a> · <a href="DATA_QUALITY.md">🛡️ Data quality</a>
</p>
