/* ================================================================
   LOGISTICS INTELLIGENCE PLATFORM — DATA WAREHOUSE
   ================================================================
   File   : 05_kpi_queries.sql
   Purpose: The exact KPI queries that power the business views —
            run directly against the gold layer. These are the
            numbers quoted in the portfolio case study.
   ================================================================ */

USE LogisticsIntelligenceDW;
GO

/* ----------------------------------------------------------------
   KPI 1 — Headline scorecard
   ---------------------------------------------------------------- */
SELECT
    total_trips,
    delivery_events,
    FORMAT(gross_revenue, 'N0')       AS gross_revenue,
    FORMAT(total_miles, 'N0')         AS total_miles,
    ROUND(avg_mpg, 2)                 AS avg_mpg,
    FORMAT(fuel_cost, 'N0')           AS fuel_cost,
    FORMAT(maintenance_cost, 'N0')    AS maintenance_cost,
    FORMAT(claims_total, 'N0')        AS claims_total,
    on_time_delivery_pct,
    avg_utilization_pct,
    active_drivers,
    active_trucks
FROM gold.v_kpi_overview;
GO

/* ----------------------------------------------------------------
   KPI 2 — On-time delivery by year (service level)
   ---------------------------------------------------------------- */
SELECT
    d.year_nbr,
    COUNT(e.event_id)                                                       AS delivery_events,
    SUM(CASE WHEN e.on_time_flag = 1 THEN 1 ELSE 0 END)                     AS on_time,
    CAST(100.0 * SUM(CASE WHEN e.on_time_flag = 1 THEN 1 ELSE 0 END)
        / COUNT(e.event_id) AS DECIMAL(5,1))                                AS on_time_pct
FROM gold.fact_delivery e
JOIN gold.dim_date d ON d.date_id = e.date_sk
WHERE e.event_type = 'Delivery'
GROUP BY d.year_nbr
ORDER BY d.year_nbr;
GO

/* ----------------------------------------------------------------
   KPI 3 — Revenue by year (growth)
   ---------------------------------------------------------------- */
SELECT
    d.year_nbr,
    COUNT(f.load_id)             AS loads,
    FORMAT(SUM(f.gross_revenue), 'N0') AS gross_revenue,
    FORMAT(SUM(f.revenue), 'N0') AS base_revenue
FROM gold.fact_load f
JOIN gold.dim_date d ON d.date_id = f.date_sk
GROUP BY d.year_nbr
ORDER BY d.year_nbr;
GO

/* ----------------------------------------------------------------
   KPI 4 — Top 5 routes by revenue
   ---------------------------------------------------------------- */
SELECT TOP 5
    r.corridor,
    COUNT(f.load_id)         AS loads,
    FORMAT(SUM(f.gross_revenue), 'N0') AS gross_revenue,
    ROUND(SUM(f.gross_revenue) / NULLIF(r.typical_distance_miles, 0), 2) AS revenue_per_mile
FROM gold.fact_load f
JOIN gold.dim_route r ON r.route_sk = f.route_sk
GROUP BY r.corridor, r.typical_distance_miles
ORDER BY SUM(f.gross_revenue) DESC;
GO

/* ----------------------------------------------------------------
   KPI 5 — Top 5 customers by revenue
   ---------------------------------------------------------------- */
SELECT TOP 5
    c.customer_name,
    c.customer_type,
    COUNT(f.load_id)          AS loads,
    FORMAT(SUM(f.gross_revenue), 'N0') AS gross_revenue
FROM gold.fact_load f
JOIN gold.dim_customer c ON c.customer_sk = f.customer_sk
GROUP BY c.customer_name, c.customer_type
ORDER BY SUM(f.gross_revenue) DESC;
GO

/* ----------------------------------------------------------------
   KPI 6 — Fleet utilization: top 5 trucks by utilization
   ---------------------------------------------------------------- */
SELECT TOP 5
    t.truck_id,
    t.make,
    t.model_year,
    ROUND(AVG(m.utilization_rate) * 100, 1) AS avg_utilization_pct,
    SUM(m.downtime_hours)                   AS downtime_hours,
    SUM(m.maintenance_cost)                 AS maintenance_cost
FROM gold.fact_truck_monthly m
JOIN gold.dim_truck t ON t.truck_sk = m.truck_sk
WHERE t.truck_sk > 0
GROUP BY t.truck_id, t.make, t.model_year
ORDER BY AVG(m.utilization_rate) DESC;
GO

/* ----------------------------------------------------------------
   KPI 7 — Fuel efficiency trend by year
   ---------------------------------------------------------------- */
SELECT
    d.year_nbr,
    FORMAT(SUM(f.gallons), 'N0')                  AS gallons,
    FORMAT(SUM(f.total_cost), 'N0')               AS fuel_cost,
    ROUND(SUM(f.total_cost) / NULLIF(SUM(f.gallons), 0), 3) AS avg_price_per_gallon
FROM gold.fact_fuel f
JOIN gold.dim_date d ON d.date_id = f.date_sk
GROUP BY d.year_nbr
ORDER BY d.year_nbr;
GO

/* ----------------------------------------------------------------
   KPI 8 — Detention hotspots (top 5 facilities)
   ---------------------------------------------------------------- */
SELECT TOP 5
    g.facility_name,
    g.city,
    COUNT(e.event_id)          AS events,
    ROUND(AVG(e.detention_minutes), 1) AS avg_detention_min,
    CAST(100.0 * SUM(CASE WHEN e.on_time_flag = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(e.event_id), 0) AS DECIMAL(5,1)) AS on_time_pct
FROM gold.fact_delivery e
JOIN gold.dim_facility g ON g.facility_sk = e.facility_sk
GROUP BY g.facility_name, g.city
ORDER BY AVG(e.detention_minutes) DESC;
GO
