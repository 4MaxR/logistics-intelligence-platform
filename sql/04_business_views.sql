/* ================================================================
   LOGISTICS INTELLIGENCE PLATFORM — DATA WAREHOUSE
   ================================================================
   File   : 04_business_views.sql
   Purpose: Business views — the "semantic layer" management
            queries directly. Each view answers one operating
            question and is written for readability, not cleverness.
   ================================================================ */

USE LogisticsIntelligenceDW;
GO

SET NOCOUNT ON;
GO

/* ================================================================
   4.1  KPI view — single row, headline numbers
   ================================================================ */
IF OBJECT_ID('gold.v_kpi_overview', 'V') IS NOT NULL DROP VIEW gold.v_kpi_overview;
GO
CREATE VIEW gold.v_kpi_overview AS
SELECT
    (SELECT COUNT(*) FROM gold.fact_trip)                                   AS total_trips,
    (SELECT COUNT(*) FROM gold.fact_delivery WHERE event_type = 'Delivery') AS delivery_events,
    (SELECT SUM(gross_revenue) FROM gold.fact_load)                         AS gross_revenue,
    (SELECT SUM(actual_distance_miles) FROM gold.fact_trip)                 AS total_miles,
    (SELECT AVG(average_mpg) FROM gold.fact_trip)                           AS avg_mpg,
    (SELECT SUM(total_cost) FROM gold.fact_fuel)                            AS fuel_cost,
    (SELECT SUM(total_cost) FROM gold.fact_maintenance)                     AS maintenance_cost,
    (SELECT SUM(claim_amount) FROM gold.fact_incident)                      AS claims_total,
    (SELECT CAST(100.0 * SUM(CASE WHEN on_time_flag = 1 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,1))
       FROM gold.fact_delivery WHERE event_type = 'Delivery')               AS on_time_delivery_pct,
    (SELECT CAST(AVG(utilization_rate) * 100 AS DECIMAL(5,1))
       FROM gold.fact_truck_monthly)                                        AS avg_utilization_pct,
    (SELECT COUNT(DISTINCT driver_sk) FROM gold.fact_trip WHERE driver_sk > 0) AS active_drivers,
    (SELECT COUNT(DISTINCT truck_sk)  FROM gold.fact_trip WHERE truck_sk  > 0) AS active_trucks;
GO

/* ================================================================
   4.2  Load profitability
   ================================================================ */
IF OBJECT_ID('gold.v_load_profitability', 'V') IS NOT NULL DROP VIEW gold.v_load_profitability;
GO
CREATE VIEW gold.v_load_profitability AS
SELECT
    f.load_id,
    c.customer_name,
    r.corridor,
    d.year_nbr,
    f.load_type,
    f.booking_type,
    f.weight_lbs,
    f.revenue,
    f.fuel_surcharge,
    f.accessorial_charges,
    f.gross_revenue,
    f.gross_revenue / NULLIF(f.weight_lbs, 0) * 1000 AS revenue_per_1k_lbs
FROM gold.fact_load f
JOIN gold.dim_customer c ON c.customer_sk = f.customer_sk
JOIN gold.dim_route    r ON r.route_sk    = f.route_sk
JOIN gold.dim_date     d ON d.date_id     = f.date_sk;
GO

/* ================================================================
   4.3  Route performance
   ================================================================ */
IF OBJECT_ID('gold.v_route_performance', 'V') IS NOT NULL DROP VIEW gold.v_route_performance;
GO
CREATE VIEW gold.v_route_performance AS
SELECT
    r.route_id,
    r.corridor,
    r.typical_distance_miles,
    COUNT(DISTINCT f.load_id)                  AS loads,
    SUM(f.gross_revenue)                       AS gross_revenue,
    SUM(f.gross_revenue) / NULLIF(r.typical_distance_miles, 0) AS revenue_per_mile
FROM gold.fact_load f
JOIN gold.dim_route r ON r.route_sk = f.route_sk
GROUP BY r.route_id, r.corridor, r.typical_distance_miles;
GO

/* ================================================================
   4.4  Customer service levels
   ================================================================ */
IF OBJECT_ID('gold.v_customer_service', 'V') IS NOT NULL DROP VIEW gold.v_customer_service;
GO
CREATE VIEW gold.v_customer_service AS
SELECT
    c.customer_id,
    c.customer_name,
    c.customer_type,
    COUNT(DISTINCT f.load_id)                          AS loads,
    SUM(f.gross_revenue)                               AS gross_revenue,
    COUNT(DISTINCT e.trip_sk)                          AS trips,
    CAST(100.0 * SUM(CASE WHEN e.on_time_flag = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(e.event_id), 0) AS DECIMAL(5,1)) AS on_time_pct
FROM gold.fact_load f
JOIN gold.dim_customer c ON c.customer_sk = f.customer_sk
LEFT JOIN gold.fact_delivery e ON e.load_sk = f.load_id
GROUP BY c.customer_id, c.customer_name, c.customer_type;
GO

/* ================================================================
   4.5  Driver performance
   ================================================================ */
IF OBJECT_ID('gold.v_driver_performance', 'V') IS NOT NULL DROP VIEW gold.v_driver_performance;
GO
CREATE VIEW gold.v_driver_performance AS
SELECT
    d.driver_id,
    d.full_name,
    d.home_terminal,
    d.years_experience,
    COUNT(f.trip_id)                        AS trips,
    SUM(f.actual_distance_miles)            AS total_miles,
    AVG(f.average_mpg)                      AS avg_mpg,
    SUM(f.idle_time_hours)                  AS idle_hours,
    SUM(f.actual_distance_miles) / NULLIF(SUM(f.actual_duration_hours), 0) AS avg_speed_mph,
    CAST(100.0 * SUM(CASE WHEN e.on_time_flag = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(e.event_id), 0) AS DECIMAL(5,1)) AS on_time_pct
FROM gold.fact_trip f
JOIN gold.dim_driver d ON d.driver_sk = f.driver_sk
LEFT JOIN gold.fact_delivery e ON e.trip_sk = f.trip_id
WHERE f.driver_sk > 0
GROUP BY d.driver_id, d.full_name, d.home_terminal, d.years_experience;
GO

/* ================================================================
   4.6  Fleet utilization
   ================================================================ */
IF OBJECT_ID('gold.v_fleet_utilization', 'V') IS NOT NULL DROP VIEW gold.v_fleet_utilization;
GO
CREATE VIEW gold.v_fleet_utilization AS
SELECT
    t.truck_id,
    t.unit_number,
    t.make,
    t.model_year,
    t.status,
    COUNT(f.trip_id)                        AS trips,
    SUM(f.actual_distance_miles)            AS total_miles,
    SUM(f.actual_duration_hours)            AS total_hours,
    AVG(m.utilization_rate) * 100           AS avg_utilization_pct,
    SUM(m.downtime_hours)                   AS downtime_hours,
    SUM(m.maintenance_cost)                 AS maintenance_cost
FROM gold.fact_truck_monthly m
JOIN gold.dim_truck t ON t.truck_sk = m.truck_sk
LEFT JOIN gold.fact_trip f ON f.truck_sk = t.truck_sk
WHERE t.truck_sk > 0
GROUP BY t.truck_id, t.unit_number, t.make, t.model_year, t.status;
GO

/* ================================================================
   4.7  Fuel efficiency (monthly trend)
   ================================================================ */
IF OBJECT_ID('gold.v_fuel_efficiency', 'V') IS NOT NULL DROP VIEW gold.v_fuel_efficiency;
GO
CREATE VIEW gold.v_fuel_efficiency AS
SELECT
    d.year_nbr,
    d.month_nbr,
    d.month_name,
    COUNT(f.fuel_purchase_id)          AS purchases,
    SUM(f.gallons)                     AS gallons,
    SUM(f.total_cost)                  AS fuel_cost,
    SUM(f.gallons) / NULLIF(COUNT(f.fuel_purchase_id), 0) AS avg_gallons_per_purchase,
    SUM(f.total_cost) / NULLIF(SUM(f.gallons), 0)         AS avg_price_per_gallon
FROM gold.fact_fuel f
JOIN gold.dim_date d ON d.date_id = f.date_sk
GROUP BY d.year_nbr, d.month_nbr, d.month_name;
GO

/* ================================================================
   4.8  Maintenance analysis
   ================================================================ */
IF OBJECT_ID('gold.v_maintenance_analysis', 'V') IS NOT NULL DROP VIEW gold.v_maintenance_analysis;
GO
CREATE VIEW gold.v_maintenance_analysis AS
SELECT
    t.truck_id,
    t.make,
    t.model_year,
    COUNT(f.maintenance_id)                 AS maintenance_events,
    SUM(f.total_cost)                       AS maintenance_cost,
    SUM(f.downtime_hours)                   AS downtime_hours,
    SUM(f.total_cost) / NULLIF(SUM(trip_miles.miles), 0) AS cost_per_mile
FROM gold.fact_maintenance f
JOIN gold.dim_truck t ON t.truck_sk = f.truck_sk
LEFT JOIN (
    SELECT truck_sk, SUM(actual_distance_miles) AS miles
    FROM gold.fact_trip
    GROUP BY truck_sk
) trip_miles ON trip_miles.truck_sk = t.truck_sk
WHERE t.truck_sk > 0
GROUP BY t.truck_id, t.make, t.model_year;
GO

/* ================================================================
   4.9  Safety dashboard
   ================================================================ */
IF OBJECT_ID('gold.v_safety_dashboard', 'V') IS NOT NULL DROP VIEW gold.v_safety_dashboard;
GO
CREATE VIEW gold.v_safety_dashboard AS
SELECT
    d.year_nbr,
    COUNT(f.incident_id)                              AS incidents,
    SUM(CASE WHEN f.at_fault_flag = 1 THEN 1 ELSE 0 END)    AS at_fault,
    SUM(CASE WHEN f.injury_flag = 1 THEN 1 ELSE 0 END)      AS with_injury,
    SUM(CASE WHEN f.preventable_flag = 1 THEN 1 ELSE 0 END) AS preventable,
    SUM(f.vehicle_damage_cost)                        AS vehicle_damage,
    SUM(f.cargo_damage_cost)                          AS cargo_damage,
    SUM(f.claim_amount)                               AS claims
FROM gold.fact_incident f
JOIN gold.dim_date d ON d.date_id = f.date_sk
GROUP BY d.year_nbr;
GO

/* ================================================================
   4.10  Seasonal / monthly revenue trend
   ================================================================ */
IF OBJECT_ID('gold.v_monthly_trend', 'V') IS NOT NULL DROP VIEW gold.v_monthly_trend;
GO
CREATE VIEW gold.v_monthly_trend AS
SELECT
    d.year_nbr,
    d.month_nbr,
    d.month_name,
    d.season,
    COUNT(f.load_id)      AS loads,
    SUM(f.gross_revenue)  AS gross_revenue,
    SUM(f.weight_lbs)     AS total_weight_lbs
FROM gold.fact_load f
JOIN gold.dim_date d ON d.date_id = f.date_sk
GROUP BY d.year_nbr, d.month_nbr, d.month_name, d.season;
GO

/* ================================================================
   4.11  Detention / service-level view
   ================================================================ */
IF OBJECT_ID('gold.v_detention_analysis', 'V') IS NOT NULL DROP VIEW gold.v_detention_analysis;
GO
CREATE VIEW gold.v_detention_analysis AS
SELECT
    g.facility_id,
    g.facility_name,
    g.city,
    g.state,
    COUNT(e.event_id)                    AS events,
    SUM(e.detention_minutes)             AS detention_minutes,
    AVG(e.detention_minutes)             AS avg_detention_min,
    CAST(100.0 * SUM(CASE WHEN e.on_time_flag = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(e.event_id), 0) AS DECIMAL(5,1)) AS on_time_pct
FROM gold.fact_delivery e
JOIN gold.dim_facility g ON g.facility_sk = e.facility_sk
GROUP BY g.facility_id, g.facility_name, g.city, g.state;
GO

PRINT 'Business views created: v_kpi_overview, v_load_profitability, v_route_performance, v_customer_service, v_driver_performance, v_fleet_utilization, v_fuel_efficiency, v_maintenance_analysis, v_safety_dashboard, v_monthly_trend, v_detention_analysis';
GO
