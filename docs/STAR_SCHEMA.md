# Star Schema

The gold layer is a classic star schema: **conformed dimensions** shared by **fact tables**
modeled at their natural grain. Facts reference dimensions through integer surrogate keys with
enforced FK constraints; every dimension contains an `-1` Unknown row so facts never orphan.

---

## Diagram

```text
                        ┌───────────────────────┐
                        │     dim_date (1,461)  │
                        │  date_id · year · mth │
                        └───────────┬───────────┘
        ┌───────────┬───────────────┼────────────────┬──────────────┐
        ▼           ▼               ▼                ▼              ▼
┌────────────┐ ┌──────────┐ ┌──────────────┐ ┌────────────┐ ┌─────────────┐
│ fact_load  │ │ fact_trip│ │ fact_delivery│ │ fact_fuel  │ │fact_incident│
│ 85,410     │ │ 85,410   │ │ 170,820      │ │ 196,442    │ │ 170         │
└─┬───────┬──┘ └─┬───┬───┬─┘ └─┬─────────┬──┘ └─┬───────┬──┘ └─┬───┬───┬───┘
  │       │      │   │   │     │         │      │       │      │   │   │
  ▼       ▼      ▼   ▼   ▼     ▼         ▼      ▼       ▼      ▼   ▼   ▼
 cust  route   drv trk trl   fac   (trip/load    trk   drv   trk  drv (trip
  │       │      │   │   │     │    degenerate)   │     │     │    │   degen)
  ▼       ▼      ▼   ▼   ▼     ▼                  ▼     ▼     ▼    ▼
┌────────┐┌───────┐┌────────────────────────────────────────────────────┐
│dim_    ││dim_   ││  dim_driver (151) · dim_truck (121) · dim_trailer  │
│customer││route  ││  (181) — all FK-constrained from facts             │
│ (201)  ││ (59)  ││  dim_facility (51)                                  │
└────────┘└───────┘└────────────────────────────────────────────────────┘
```

Plus monthly-grain facts sharing the same dims:
`fact_driver_monthly (4,464)` and `fact_truck_monthly (3,312)` → `dim_driver` / `dim_truck` / `dim_date`.

---

## Facts & grain

| Fact | Grain (1 row = …) | Rows | Degenerate keys | Measures |
|---|---|---|---|---|
| fact_load | one load | 85,410 | — | weight_lbs, pieces, revenue, fuel_surcharge, accessorial_charges, gross_revenue |
| fact_trip | one trip | 85,410 | load_id | actual_distance_miles, actual_duration_hours, fuel_gallons_used, average_mpg, idle_time_hours |
| fact_delivery | one event | 170,820 | load_id, trip_id | scheduled_datetime, actual_datetime, detention_minutes, on_time_flag |
| fact_fuel | one purchase | 196,442 | trip_id | gallons, price_per_gallon, total_cost |
| fact_maintenance | one record | 2,920 | — | odometer_reading, labor_hours, labor_cost, parts_cost, total_cost, downtime_hours |
| fact_incident | one incident | 170 | trip_id | at_fault_flag, injury_flag, preventable_flag, vehicle_damage_cost, cargo_damage_cost, claim_amount |
| fact_driver_monthly | one driver-month | 4,464 | — | trips_completed, total_miles, total_revenue, average_mpg, total_fuel_gallons, on_time_delivery_rate, average_idle_hours |
| fact_truck_monthly | one truck-month | 3,312 | — | trips_completed, total_miles, total_revenue, average_mpg, maintenance_events, maintenance_cost, downtime_hours, utilization_rate |

## Dimensions

| Dimension | SK | Natural key | Rows | Attributes |
|---|---|---|---|---|
| dim_date | date_id (DATE) | calendar | 1,461 | year, quarter, month (nbr+name), day, weekday (nbr+name), is_weekend, season |
| dim_customer | customer_sk | customer_id | 201 | name, type, credit terms, freight type, account status, revenue potential, is_active |
| dim_driver | driver_sk | driver_id | 151 | full_name, terminal, status, CDL class, years_experience, is_active |
| dim_truck | truck_sk | truck_id | 121 | unit_number, make, model_year, fuel_type, status, terminal, is_active |
| dim_trailer | trailer_sk | trailer_id | 181 | number, type, length, status, location, is_active |
| dim_facility | facility_sk | facility_id | 51 | name, type, city/state, dock_doors, hours |
| dim_route | route_sk | route_id | 59 | corridor, distance, base_rate_per_mile, fuel_surcharge_rate, transit_days |

## Design notes

- **Conformed dim_date** — the same calendar drives load, trip, delivery, fuel, maintenance,
  incident, and monthly facts. One definition of "month", "season", "weekend" everywhere.
- **Grain discipline** — each fact is at its most granular level; monthly facts are sourced from
  the pre-aggregated source tables (driver_monthly_metrics / truck_utilization_metrics) rather
  than re-aggregated, preserving the source's own definitions.
- **Degenerate keys** — `load_id` / `trip_id` stay on facts as degenerate dimensions: they are
  needed for drill-through (e.g. delivery events → the trip's truck) but have no attributes.
- **Unknown (-1)** — a trip without a truck in the source still appears in fact_trip with
  `truck_sk = -1`; joins to dim_truck yield the "Unknown Truck" row. Analytics can include or
  exclude it explicitly (`WHERE truck_sk > 0`).
- **Why star, not normalized** — queries against the gold layer join at most 2–3 small dims to a
  big fact; the optimizer gets simple equi-joins on clustered/PK keys, and the semantic views
  stay readable for non-engineers.
- **FK integrity verified** — the gold build runs 8 referential-integrity checks; all return 0
  orphans on the verified run.

## Common query patterns

```sql
-- On-time delivery by route corridor (delivery events joined to load's route)
SELECT r.corridor,
       COUNT(e.event_id)                                   AS events,
       SUM(CASE WHEN e.on_time_flag = 1 THEN 1 ELSE 0 END) AS on_time,
       CAST(100.0 * SUM(CASE WHEN e.on_time_flag = 1 THEN 1 ELSE 0 END) / COUNT(e.event_id) AS DECIMAL(5,1)) AS on_time_pct
FROM gold.fact_delivery e
JOIN gold.fact_load f ON f.load_id = e.load_sk
JOIN gold.dim_route r ON r.route_sk = f.route_sk
WHERE e.event_type = 'Delivery'
GROUP BY r.corridor
ORDER BY on_time_pct;
```
