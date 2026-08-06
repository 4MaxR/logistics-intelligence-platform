# Business Requirements

This document captures the operating questions the warehouse was built to answer. Each requirement
maps to a gold-layer fact/view and a verified KPI. The list was derived from the analytical use
cases in `data/DATABASE_SCHEMA.txt` and framed as management questions.

---

## BR-01 — Executive performance (headline)

**Question:** What is the overall health of the operation — volume, revenue, efficiency, service?

**Answer (verified):**
- 85,410 trips · 170,820 delivery events across 2022–2024
- Gross revenue **$298.6M** · total miles **122.2M**
- On-time delivery **44.6%** · fleet utilization **83.0%** · fleet MPG **6.50**

**Objects:** `gold.v_kpi_overview`, `gold.fact_trip`, `gold.fact_delivery`, `gold.fact_load`

---

## BR-02 — On-time delivery (service level)

**Question:** How reliable is delivery, and is it improving?

**Answer (verified):** 44.6% of delivery events were on time. Year over year the rate is flat
(44.7% → 44.6% → 44.6%), meaning service reliability is a systemic problem, not a seasonal blip.
2025 has only 77 delivery events in the source (partial year).

**Objects:** `gold.v_kpi_overview`, KPI query 2 (`on_time_pct` by year)

---

## BR-03 — Route profitability

**Question:** Which lanes make the most money, and where is revenue per mile strongest?

**Answer (verified):** Top 5 corridors by gross revenue: Charlotte → Portland ($11.2M),
Seattle → Charlotte ($10.9M), Columbus → Portland ($10.9M), Philadelphia → Seattle ($10.9M),
Phoenix → Philadelphia ($10.5M).

**Objects:** `gold.v_route_performance`, `gold.fact_load` + `gold.dim_route`

---

## BR-04 — Customer value & service

**Question:** Who are the top customers by revenue, and are they being served well?

**Answer (verified):** Top customers: XYZ Wholesale ($6.0M, Contract), First Manufacturing
($4.5M, Spot), Metro Corp ($4.4M, Contract). The customer view exposes on-time % per customer so
service level can be negotiated from data.

**Objects:** `gold.v_customer_service`, `gold.fact_load` + `gold.dim_customer`

---

## BR-05 — Fleet utilization

**Question:** Are our trucks working hard enough, and which assets are over/under-utilized?

**Answer (verified):** Average utilization 83.0%. Top assets: TRK00055 (Peterbilt 2017, 89.1%),
TRK00044 (Volvo 2015, 88.5%), TRK00039 (International 2015, 88.2%). Utilization above 85% should
trigger idle/downtime review; the view surfaces downtime hours alongside utilization.

**Objects:** `gold.v_fleet_utilization`, `gold.fact_truck_monthly`

---

## BR-06 — Fuel efficiency & cost

**Question:** What drives fuel spend, and is efficiency improving?

**Answer (verified):** $95.6M fuel spend over 3 years (24.5M gallons). Average price per gallon
fell from $4.20 (2022) → $3.85 (2023) → $3.65 (2024). Fleet MPG is flat at ~6.5, so fuel savings
came from market price, not operations — efficiency remains the lever.

**Objects:** `gold.v_fuel_efficiency`, `gold.fact_fuel`

---

## BR-07 — Maintenance cost & downtime

**Question:** Where is maintenance spend concentrated, and how much does downtime cost?

**Answer (verified):** $5.73M over 2,920 maintenance events (avg ~$1,963/event). Total downtime
72,231 hours. `v_maintenance_analysis` surfaces cost per mile per truck so preventive maintenance
can target the worst assets.

**Objects:** `gold.v_maintenance_analysis`, `gold.fact_maintenance`

---

## BR-08 — Safety

**Question:** What is our incident and claims exposure, and is it improving?

**Answer (verified):** 170 incidents, $2.65M total claims. 54 at-fault (31.8%), 64 preventable
(37.6%), 35 with injuries. Incident rate 1.39 per million miles.

**Objects:** `gold.v_safety_dashboard`, `gold.fact_incident`

---

## BR-09 — Detention & facility bottlenecks

**Question:** Which facilities burn the most detention time and hurt on-time performance?

**Answer (verified):** Indianapolis Warehouse (avg 93 min/event, 54.2% on-time) and Phoenix
Distribution Center (avg 93 min, 54.6%) lead detention. Fleet-wide average 91.5 min per event
across 15.6M total detention minutes.

**Objects:** `gold.v_detention_analysis`, `gold.fact_delivery` + `gold.dim_facility`

---

## BR-10 — Seasonality & capacity planning

**Question:** When is demand highest, and how should capacity be planned?

**Answer (verified):** Revenue is steady across years (~$99M/yr) with the busiest months
October/January/August (~7,300 loads/month). Summer (Jun–Aug) and winter peak (Dec–Jan) are the
capacity-planning windows.

**Objects:** `gold.v_monthly_trend`, `gold.fact_load` + `gold.dim_date`

---

## BR-11 — Data integrity (the warehouse must be trustworthy)

**Question:** Can management trust the numbers?

**Answer:** Yes — every object load is recorded in `gold.pipeline_audit`; FK integrity checks in
the gold layer return **zero** orphaned references; every KPI was cross-validated against the
source CSVs (see DATA_QUALITY.md). Row counts are preserved from source through gold
(549,706 → 551,167 → 1,102,346; silver/gold add dimension rows by design).
