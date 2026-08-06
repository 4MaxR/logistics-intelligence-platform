/* ================================================================
   LOGISTICS INTELLIGENCE PLATFORM — DATA WAREHOUSE
   ================================================================
   File   : 03_gold_layer.sql
   Purpose: GOLD layer — star schema.
            * Surrogate-key dimensions (dim_*_sk)
            * One conformed dim_date reused by every fact
            * Fact tables with FK constraints to dims
            * Unknown surrogate (-1) row in every dimension so
              no fact row is ever orphaned
   ================================================================ */

USE LogisticsIntelligenceDW;
GO

SET NOCOUNT ON;
GO

/* ----------------------------------------------------------------
   3.1  Drop targets (idempotent re-runs)
   ---------------------------------------------------------------- */
IF OBJECT_ID('gold.fact_trip')       IS NOT NULL DROP TABLE gold.fact_trip;
IF OBJECT_ID('gold.fact_load')       IS NOT NULL DROP TABLE gold.fact_load;
IF OBJECT_ID('gold.fact_delivery')   IS NOT NULL DROP TABLE gold.fact_delivery;
IF OBJECT_ID('gold.fact_fuel')       IS NOT NULL DROP TABLE gold.fact_fuel;
IF OBJECT_ID('gold.fact_maintenance')IS NOT NULL DROP TABLE gold.fact_maintenance;
IF OBJECT_ID('gold.fact_incident')   IS NOT NULL DROP TABLE gold.fact_incident;
IF OBJECT_ID('gold.fact_driver_monthly') IS NOT NULL DROP TABLE gold.fact_driver_monthly;
IF OBJECT_ID('gold.fact_truck_monthly')  IS NOT NULL DROP TABLE gold.fact_truck_monthly;

IF OBJECT_ID('gold.dim_driver')   IS NOT NULL DROP TABLE gold.dim_driver;
IF OBJECT_ID('gold.dim_truck')    IS NOT NULL DROP TABLE gold.dim_truck;
IF OBJECT_ID('gold.dim_trailer')  IS NOT NULL DROP TABLE gold.dim_trailer;
IF OBJECT_ID('gold.dim_customer') IS NOT NULL DROP TABLE gold.dim_customer;
IF OBJECT_ID('gold.dim_facility') IS NOT NULL DROP TABLE gold.dim_facility;
IF OBJECT_ID('gold.dim_route')    IS NOT NULL DROP TABLE gold.dim_route;
IF OBJECT_ID('gold.dim_date')     IS NOT NULL DROP TABLE gold.dim_date;
GO

/* ================================================================
   3.2  Dimensions (surrogate keys, Unknown = -1 first)
   ================================================================ */

/* --- dim_date (from silver calendar) ---------------------------- */
SELECT
    date_id, year_nbr, month_nbr, day_nbr, quarter_nbr, weekday_nbr,
    month_name, weekday_name, is_weekend, season
INTO gold.dim_date
FROM silver.dim_date;
ALTER TABLE gold.dim_date ADD PRIMARY KEY (date_id);
CREATE INDEX ix_gold_date_year  ON gold.dim_date (year_nbr);
CREATE INDEX ix_gold_date_month ON gold.dim_date (month_nbr);

/* --- dim_driver -------------------------------------------------- */
CREATE TABLE gold.dim_driver (
    driver_sk          INT IDENTITY(1,1) PRIMARY KEY,
    driver_id          NVARCHAR(20) UNIQUE NOT NULL,
    full_name          NVARCHAR(101) NOT NULL,
    home_terminal      NVARCHAR(50)  NULL,
    employment_status  NVARCHAR(20)  NULL,
    cdl_class          NVARCHAR(5)   NULL,
    years_experience   INT           NULL,
    is_active          BIT           NULL
);
INSERT INTO gold.dim_driver (driver_id, full_name, home_terminal, employment_status, cdl_class, years_experience, is_active)
SELECT '-1', 'Unknown Driver', NULL, NULL, NULL, NULL, NULL;
INSERT INTO gold.dim_driver (driver_id, full_name, home_terminal, employment_status, cdl_class, years_experience, is_active)
SELECT driver_id, full_name, home_terminal, employment_status, cdl_class, years_experience, is_active
FROM silver.dim_driver;

/* --- dim_truck --------------------------------------------------- */
CREATE TABLE gold.dim_truck (
    truck_sk           INT IDENTITY(1,1) PRIMARY KEY,
    truck_id           NVARCHAR(20) UNIQUE NOT NULL,
    unit_number        NVARCHAR(20) NULL,
    make               NVARCHAR(50) NULL,
    model_year         INT          NULL,
    fuel_type          NVARCHAR(20) NULL,
    status             NVARCHAR(20) NULL,
    home_terminal      NVARCHAR(50) NULL,
    is_active          BIT          NULL
);
INSERT INTO gold.dim_truck (truck_id, unit_number, make, model_year, fuel_type, status, home_terminal, is_active)
SELECT '-1', NULL, NULL, NULL, NULL, NULL, NULL, NULL;
INSERT INTO gold.dim_truck (truck_id, unit_number, make, model_year, fuel_type, status, home_terminal, is_active)
SELECT truck_id, unit_number, make, model_year, fuel_type, status, home_terminal, is_active
FROM silver.dim_truck;

/* --- dim_trailer ------------------------------------------------- */
CREATE TABLE gold.dim_trailer (
    trailer_sk         INT IDENTITY(1,1) PRIMARY KEY,
    trailer_id         NVARCHAR(20) UNIQUE NOT NULL,
    trailer_number     NVARCHAR(20) NULL,
    trailer_type       NVARCHAR(50) NULL,
    length_feet        INT          NULL,
    status             NVARCHAR(20) NULL,
    current_location   NVARCHAR(50) NULL,
    is_active          BIT          NULL
);
INSERT INTO gold.dim_trailer (trailer_id, trailer_number, trailer_type, length_feet, status, current_location, is_active)
SELECT '-1', NULL, NULL, NULL, NULL, NULL, NULL;
INSERT INTO gold.dim_trailer (trailer_id, trailer_number, trailer_type, length_feet, status, current_location, is_active)
SELECT trailer_id, trailer_number, trailer_type, length_feet, status, current_location, is_active
FROM silver.dim_trailer;

/* --- dim_customer ------------------------------------------------ */
CREATE TABLE gold.dim_customer (
    customer_sk         INT IDENTITY(1,1) PRIMARY KEY,
    customer_id         NVARCHAR(20) UNIQUE NOT NULL,
    customer_name       NVARCHAR(100) NOT NULL,
    customer_type       NVARCHAR(30)  NULL,
    credit_terms_days   INT           NULL,
    primary_freight_type NVARCHAR(30) NULL,
    account_status      NVARCHAR(20)  NULL,
    annual_revenue_potential DECIMAL(12,0) NULL,
    is_active           BIT           NULL
);
INSERT INTO gold.dim_customer (customer_id, customer_name, customer_type, credit_terms_days, primary_freight_type, account_status, annual_revenue_potential, is_active)
SELECT '-1', 'Unknown Customer', NULL, NULL, NULL, NULL, NULL, NULL;
INSERT INTO gold.dim_customer (customer_id, customer_name, customer_type, credit_terms_days, primary_freight_type, account_status, annual_revenue_potential, is_active)
SELECT customer_id, customer_name, customer_type, credit_terms_days, primary_freight_type, account_status, annual_revenue_potential, is_active
FROM silver.dim_customer;

/* --- dim_facility ------------------------------------------------ */
CREATE TABLE gold.dim_facility (
    facility_sk      INT IDENTITY(1,1) PRIMARY KEY,
    facility_id      NVARCHAR(20) UNIQUE NOT NULL,
    facility_name    NVARCHAR(100) NOT NULL,
    facility_type    NVARCHAR(30)  NULL,
    city             NVARCHAR(50)  NULL,
    state            NVARCHAR(5)   NULL,
    dock_doors       INT           NULL,
    operating_hours  NVARCHAR(20)  NULL
);
INSERT INTO gold.dim_facility (facility_id, facility_name, facility_type, city, state, dock_doors, operating_hours)
SELECT '-1', 'Unknown Facility', NULL, NULL, NULL, NULL, NULL;
INSERT INTO gold.dim_facility (facility_id, facility_name, facility_type, city, state, dock_doors, operating_hours)
SELECT facility_id, facility_name, facility_type, city, state, dock_doors, operating_hours
FROM silver.dim_facility;

/* --- dim_route --------------------------------------------------- */
CREATE TABLE gold.dim_route (
    route_sk             INT IDENTITY(1,1) PRIMARY KEY,
    route_id             NVARCHAR(20) UNIQUE NOT NULL,
    origin_city          NVARCHAR(50) NULL,
    origin_state         NVARCHAR(5)  NULL,
    destination_city     NVARCHAR(50) NULL,
    destination_state    NVARCHAR(5)  NULL,
    corridor             NVARCHAR(110) NULL,
    typical_distance_miles INT        NULL,
    base_rate_per_mile   DECIMAL(6,2) NULL,
    fuel_surcharge_rate  DECIMAL(6,3) NULL,
    typical_transit_days INT          NULL
);
INSERT INTO gold.dim_route (route_id, origin_city, origin_state, destination_city, destination_state, corridor, typical_distance_miles, base_rate_per_mile, fuel_surcharge_rate, typical_transit_days)
SELECT '-1', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL;
INSERT INTO gold.dim_route (route_id, origin_city, origin_state, destination_city, destination_state, corridor, typical_distance_miles, base_rate_per_mile, fuel_surcharge_rate, typical_transit_days)
SELECT route_id, origin_city, origin_state, destination_city, destination_state, corridor, typical_distance_miles, base_rate_per_mile, fuel_surcharge_rate, typical_transit_days
FROM silver.dim_route;
GO

/* ================================================================
   3.3  Facts (surrogate keys, FK constraints)
   ================================================================ */

/* --- fact_load --------------------------------------------------- */
CREATE TABLE gold.fact_load (
    load_id             NVARCHAR(20) PRIMARY KEY,
    customer_sk         INT NOT NULL REFERENCES gold.dim_customer (customer_sk),
    route_sk            INT NOT NULL REFERENCES gold.dim_route    (route_sk),
    date_sk             DATE NOT NULL REFERENCES gold.dim_date    (date_id),
    load_type           NVARCHAR(30) NULL,
    weight_lbs          DECIMAL(10,0) NULL,
    pieces              INT          NULL,
    revenue             DECIMAL(12,2) NULL,
    fuel_surcharge      DECIMAL(12,2) NULL,
    accessorial_charges DECIMAL(12,2) NULL,
    booking_type        NVARCHAR(20) NULL,
    gross_revenue       AS revenue + fuel_surcharge + accessorial_charges
);

INSERT INTO gold.fact_load (load_id, customer_sk, route_sk, date_sk, load_type, weight_lbs, pieces, revenue, fuel_surcharge, accessorial_charges, booking_type)
SELECT
    l.load_id,
    ISNULL(c.customer_sk, -1),
    ISNULL(r.route_sk, -1),
    l.load_date,
    l.load_type, l.weight_lbs, l.pieces, l.revenue, l.fuel_surcharge, l.accessorial_charges, l.booking_type
FROM silver.fact_load l
LEFT JOIN gold.dim_customer c ON c.customer_id = l.customer_id
LEFT JOIN gold.dim_route    r ON r.route_id    = l.route_id;
PRINT 'gold.fact_load: ' + CAST(@@ROWCOUNT AS VARCHAR(12));

/* --- fact_trip --------------------------------------------------- */
CREATE TABLE gold.fact_trip (
    trip_id               NVARCHAR(20) PRIMARY KEY,
    load_sk               NVARCHAR(20) NOT NULL,               -- degenerate (1:1 with load)
    driver_sk             INT NOT NULL REFERENCES gold.dim_driver  (driver_sk),
    truck_sk              INT NOT NULL REFERENCES gold.dim_truck   (truck_sk),
    trailer_sk            INT NOT NULL REFERENCES gold.dim_trailer (trailer_sk),
    date_sk               DATE NOT NULL REFERENCES gold.dim_date   (date_id),
    actual_distance_miles DECIMAL(10,1) NULL,
    actual_duration_hours DECIMAL(7,2)  NULL,
    fuel_gallons_used     DECIMAL(10,2) NULL,
    average_mpg           DECIMAL(6,2)  NULL,
    idle_time_hours       DECIMAL(7,2)  NULL,
    trip_status           NVARCHAR(20)  NULL
);

INSERT INTO gold.fact_trip (trip_id, load_sk, driver_sk, truck_sk, trailer_sk, date_sk, actual_distance_miles, actual_duration_hours, fuel_gallons_used, average_mpg, idle_time_hours, trip_status)
SELECT
    t.trip_id,
    t.load_id,
    ISNULL(d.driver_sk, -1),
    ISNULL(k.truck_sk, -1),
    ISNULL(tr.trailer_sk, -1),
    t.dispatch_date,
    t.actual_distance_miles, t.actual_duration_hours, t.fuel_gallons_used,
    t.average_mpg, t.idle_time_hours, t.trip_status
FROM silver.fact_trip t
LEFT JOIN gold.dim_driver  d  ON d.driver_id  = t.driver_id
LEFT JOIN gold.dim_truck   k  ON k.truck_id   = t.truck_id
LEFT JOIN gold.dim_trailer tr ON tr.trailer_id = t.trailer_id;
PRINT 'gold.fact_trip: ' + CAST(@@ROWCOUNT AS VARCHAR(12));

/* --- fact_delivery ------------------------------------------------ */
CREATE TABLE gold.fact_delivery (
    event_id           NVARCHAR(20) PRIMARY KEY,
    load_sk            NVARCHAR(20) NOT NULL,
    trip_sk            NVARCHAR(20) NOT NULL,
    facility_sk        INT NOT NULL REFERENCES gold.dim_facility (facility_sk),
    date_sk            DATE NOT NULL REFERENCES gold.dim_date   (date_id),
    event_type         NVARCHAR(20) NOT NULL,
    scheduled_datetime DATETIME2(0) NULL,
    actual_datetime    DATETIME2(0) NULL,
    detention_minutes  INT          NULL,
    on_time_flag       BIT          NULL,
    location_city      NVARCHAR(50) NULL,
    location_state     NVARCHAR(5)  NULL
);

INSERT INTO gold.fact_delivery (event_id, load_sk, trip_sk, facility_sk, date_sk, event_type, scheduled_datetime, actual_datetime, detention_minutes, on_time_flag, location_city, location_state)
SELECT
    e.event_id, e.load_id, e.trip_id,
    ISNULL(f.facility_sk, -1),
    CAST(e.scheduled_datetime AS DATE),
    e.event_type, e.scheduled_datetime, e.actual_datetime,
    e.detention_minutes, e.on_time_flag, e.location_city, e.location_state
FROM silver.fact_delivery e
LEFT JOIN gold.dim_facility f ON f.facility_id = e.facility_id;
PRINT 'gold.fact_delivery: ' + CAST(@@ROWCOUNT AS VARCHAR(12));

/* --- fact_fuel ---------------------------------------------------- */
CREATE TABLE gold.fact_fuel (
    fuel_purchase_id  NVARCHAR(20) PRIMARY KEY,
    trip_sk           NVARCHAR(20) NOT NULL,
    truck_sk          INT NOT NULL REFERENCES gold.dim_truck  (truck_sk),
    driver_sk         INT NOT NULL REFERENCES gold.dim_driver (driver_sk),
    date_sk           DATE NOT NULL REFERENCES gold.dim_date  (date_id),
    location_city     NVARCHAR(50) NULL,
    location_state    NVARCHAR(5)  NULL,
    gallons           DECIMAL(10,2) NULL,
    price_per_gallon  DECIMAL(6,3)  NULL,
    total_cost        DECIMAL(12,2) NULL
);

INSERT INTO gold.fact_fuel (fuel_purchase_id, trip_sk, truck_sk, driver_sk, date_sk, location_city, location_state, gallons, price_per_gallon, total_cost)
SELECT
    f.fuel_purchase_id, f.trip_id,
    ISNULL(k.truck_sk, -1),
    ISNULL(d.driver_sk, -1),
    f.purchase_date,
    f.location_city, f.location_state, f.gallons, f.price_per_gallon, f.total_cost
FROM silver.fact_fuel f
LEFT JOIN gold.dim_truck  k ON k.truck_id  = f.truck_id
LEFT JOIN gold.dim_driver d ON d.driver_id = f.driver_id;
PRINT 'gold.fact_fuel: ' + CAST(@@ROWCOUNT AS VARCHAR(12));

/* --- fact_maintenance --------------------------------------------- */
CREATE TABLE gold.fact_maintenance (
    maintenance_id    NVARCHAR(20) PRIMARY KEY,
    truck_sk          INT NOT NULL REFERENCES gold.dim_truck (truck_sk),
    date_sk           DATE NOT NULL REFERENCES gold.dim_date (date_id),
    maintenance_type  NVARCHAR(30) NULL,
    odometer_reading  DECIMAL(12,0) NULL,
    labor_hours       DECIMAL(7,2)  NULL,
    labor_cost        DECIMAL(12,2) NULL,
    parts_cost        DECIMAL(12,2) NULL,
    total_cost        DECIMAL(12,2) NULL,
    facility_location NVARCHAR(50)  NULL,
    downtime_hours    DECIMAL(7,2)  NULL
);

INSERT INTO gold.fact_maintenance (maintenance_id, truck_sk, date_sk, maintenance_type, odometer_reading, labor_hours, labor_cost, parts_cost, total_cost, facility_location, downtime_hours)
SELECT
    m.maintenance_id,
    ISNULL(k.truck_sk, -1),
    m.maintenance_date,
    m.maintenance_type, m.odometer_reading, m.labor_hours, m.labor_cost,
    m.parts_cost, m.total_cost, m.facility_location, m.downtime_hours
FROM silver.fact_maintenance m
LEFT JOIN gold.dim_truck k ON k.truck_id = m.truck_id;
PRINT 'gold.fact_maintenance: ' + CAST(@@ROWCOUNT AS VARCHAR(12));

/* --- fact_incident ------------------------------------------------ */
CREATE TABLE gold.fact_incident (
    incident_id         NVARCHAR(20) PRIMARY KEY,
    trip_sk             NVARCHAR(20) NOT NULL,
    truck_sk            INT NOT NULL REFERENCES gold.dim_truck  (truck_sk),
    driver_sk           INT NOT NULL REFERENCES gold.dim_driver (driver_sk),
    date_sk             DATE NOT NULL REFERENCES gold.dim_date  (date_id),
    incident_type       NVARCHAR(30) NULL,
    at_fault_flag       BIT          NULL,
    injury_flag         BIT          NULL,
    vehicle_damage_cost DECIMAL(12,2) NULL,
    cargo_damage_cost   DECIMAL(12,2) NULL,
    claim_amount        DECIMAL(12,2) NULL,
    preventable_flag    BIT          NULL
);

INSERT INTO gold.fact_incident (incident_id, trip_sk, truck_sk, driver_sk, date_sk, incident_type, at_fault_flag, injury_flag, vehicle_damage_cost, cargo_damage_cost, claim_amount, preventable_flag)
SELECT
    i.incident_id, i.trip_id,
    ISNULL(k.truck_sk, -1),
    ISNULL(d.driver_sk, -1),
    i.incident_date,
    i.incident_type, i.at_fault_flag, i.injury_flag,
    i.vehicle_damage_cost, i.cargo_damage_cost, i.claim_amount, i.preventable_flag
FROM silver.fact_incident i
LEFT JOIN gold.dim_truck  k ON k.truck_id  = i.truck_id
LEFT JOIN gold.dim_driver d ON d.driver_id = i.driver_id;
PRINT 'gold.fact_incident: ' + CAST(@@ROWCOUNT AS VARCHAR(12));

/* --- fact_driver_monthly ------------------------------------------ */
CREATE TABLE gold.fact_driver_monthly (
    driver_sk             INT NOT NULL REFERENCES gold.dim_driver (driver_sk),
    date_sk               DATE NOT NULL REFERENCES gold.dim_date (date_id),
    trips_completed       INT          NULL,
    total_miles           DECIMAL(12,1) NULL,
    total_revenue         DECIMAL(12,2) NULL,
    average_mpg           DECIMAL(6,2)  NULL,
    total_fuel_gallons    DECIMAL(12,2) NULL,
    on_time_delivery_rate DECIMAL(6,2)  NULL,
    average_idle_hours    DECIMAL(7,2)  NULL,
    CONSTRAINT pk_fact_driver_monthly PRIMARY KEY (driver_sk, date_sk)
);

INSERT INTO gold.fact_driver_monthly (driver_sk, date_sk, trips_completed, total_miles, total_revenue, average_mpg, total_fuel_gallons, on_time_delivery_rate, average_idle_hours)
SELECT
    ISNULL(d.driver_sk, -1), m.month,
    m.trips_completed, m.total_miles, m.total_revenue, m.average_mpg,
    m.total_fuel_gallons, m.on_time_delivery_rate, m.average_idle_hours
FROM silver.fact_driver_monthly m
LEFT JOIN gold.dim_driver d ON d.driver_id = m.driver_id;
PRINT 'gold.fact_driver_monthly: ' + CAST(@@ROWCOUNT AS VARCHAR(12));

/* --- fact_truck_monthly ------------------------------------------- */
CREATE TABLE gold.fact_truck_monthly (
    truck_sk           INT NOT NULL REFERENCES gold.dim_truck (truck_sk),
    date_sk            DATE NOT NULL REFERENCES gold.dim_date (date_id),
    trips_completed    INT          NULL,
    total_miles        DECIMAL(12,1) NULL,
    total_revenue      DECIMAL(12,2) NULL,
    average_mpg        DECIMAL(6,2)  NULL,
    maintenance_events INT          NULL,
    maintenance_cost   DECIMAL(12,2) NULL,
    downtime_hours     DECIMAL(7,2)  NULL,
    utilization_rate   DECIMAL(6,3)  NULL,
    CONSTRAINT pk_fact_truck_monthly PRIMARY KEY (truck_sk, date_sk)
);

INSERT INTO gold.fact_truck_monthly (truck_sk, date_sk, trips_completed, total_miles, total_revenue, average_mpg, maintenance_events, maintenance_cost, downtime_hours, utilization_rate)
SELECT
    ISNULL(k.truck_sk, -1), m.month,
    m.trips_completed, m.total_miles, m.total_revenue, m.average_mpg,
    m.maintenance_events, m.maintenance_cost, m.downtime_hours, m.utilization_rate
FROM silver.fact_truck_monthly m
LEFT JOIN gold.dim_truck k ON k.truck_id = m.truck_id;
PRINT 'gold.fact_truck_monthly: ' + CAST(@@ROWCOUNT AS VARCHAR(12));
GO

/* ================================================================
   3.4  Star schema sanity: row counts + join integrity
   ================================================================ */
SELECT 'fact_load' AS fact_name, COUNT(*) AS rows_cnt FROM gold.fact_load
UNION ALL SELECT 'fact_trip', COUNT(*) FROM gold.fact_trip
UNION ALL SELECT 'fact_delivery', COUNT(*) FROM gold.fact_delivery
UNION ALL SELECT 'fact_fuel', COUNT(*) FROM gold.fact_fuel
UNION ALL SELECT 'fact_maintenance', COUNT(*) FROM gold.fact_maintenance
UNION ALL SELECT 'fact_incident', COUNT(*) FROM gold.fact_incident
UNION ALL SELECT 'fact_driver_monthly', COUNT(*) FROM gold.fact_driver_monthly
UNION ALL SELECT 'fact_truck_monthly', COUNT(*) FROM gold.fact_truck_monthly;

-- Any fact row whose FK points at a missing dim key (should be zero)?
SELECT
    (SELECT COUNT(*) FROM gold.fact_load       f LEFT JOIN gold.dim_customer c ON f.customer_sk = c.customer_sk WHERE c.customer_sk IS NULL) AS bad_load_customer,
    (SELECT COUNT(*) FROM gold.fact_load       f LEFT JOIN gold.dim_route    r ON f.route_sk    = r.route_sk    WHERE r.route_sk    IS NULL) AS bad_load_route,
    (SELECT COUNT(*) FROM gold.fact_trip       f LEFT JOIN gold.dim_driver   d ON f.driver_sk   = d.driver_sk   WHERE d.driver_sk   IS NULL) AS bad_trip_driver,
    (SELECT COUNT(*) FROM gold.fact_trip       f LEFT JOIN gold.dim_truck    k ON f.truck_sk    = k.truck_sk    WHERE k.truck_sk    IS NULL) AS bad_trip_truck,
    (SELECT COUNT(*) FROM gold.fact_trip       f LEFT JOIN gold.dim_trailer  t ON f.trailer_sk  = t.trailer_sk  WHERE t.trailer_sk  IS NULL) AS bad_trip_trailer,
    (SELECT COUNT(*) FROM gold.fact_fuel       f LEFT JOIN gold.dim_truck    k ON f.truck_sk    = k.truck_sk    WHERE k.truck_sk    IS NULL) AS bad_fuel_truck,
    (SELECT COUNT(*) FROM gold.fact_fuel       f LEFT JOIN gold.dim_driver   d ON f.driver_sk   = d.driver_sk   WHERE d.driver_sk   IS NULL) AS bad_fuel_driver,
    (SELECT COUNT(*) FROM gold.fact_delivery   f LEFT JOIN gold.dim_facility g ON f.facility_sk = g.facility_sk WHERE g.facility_sk IS NULL) AS bad_delivery_facility;

INSERT INTO gold.pipeline_audit (layer, object_name, rows_loaded, status, notes)
SELECT 'gold', 'dim_driver',    COUNT(*), 'DONE', NULL FROM gold.dim_driver
UNION ALL SELECT 'gold', 'dim_truck',     COUNT(*), 'DONE', NULL FROM gold.dim_truck
UNION ALL SELECT 'gold', 'dim_trailer',   COUNT(*), 'DONE', NULL FROM gold.dim_trailer
UNION ALL SELECT 'gold', 'dim_customer',  COUNT(*), 'DONE', NULL FROM gold.dim_customer
UNION ALL SELECT 'gold', 'dim_facility',  COUNT(*), 'DONE', NULL FROM gold.dim_facility
UNION ALL SELECT 'gold', 'dim_route',     COUNT(*), 'DONE', NULL FROM gold.dim_route
UNION ALL SELECT 'gold', 'dim_date',      COUNT(*), 'DONE', NULL FROM gold.dim_date
UNION ALL SELECT 'gold', 'fact_load',         COUNT(*), 'DONE', NULL FROM gold.fact_load
UNION ALL SELECT 'gold', 'fact_trip',         COUNT(*), 'DONE', NULL FROM gold.fact_trip
UNION ALL SELECT 'gold', 'fact_delivery',     COUNT(*), 'DONE', NULL FROM gold.fact_delivery
UNION ALL SELECT 'gold', 'fact_fuel',         COUNT(*), 'DONE', NULL FROM gold.fact_fuel
UNION ALL SELECT 'gold', 'fact_maintenance',  COUNT(*), 'DONE', NULL FROM gold.fact_maintenance
UNION ALL SELECT 'gold', 'fact_incident',     COUNT(*), 'DONE', NULL FROM gold.fact_incident
UNION ALL SELECT 'gold', 'fact_driver_monthly', COUNT(*), 'DONE', NULL FROM gold.fact_driver_monthly
UNION ALL SELECT 'gold', 'fact_truck_monthly',  COUNT(*), 'DONE', NULL FROM gold.fact_truck_monthly;
GO
