/* ================================================================
   LOGISTICS INTELLIGENCE PLATFORM — DATA WAREHOUSE
   ================================================================
   File   : 02_silver_layer.sql
   Purpose: SILVER layer — clean, conformed, typed.
            * Casts every column to its native type
            * Converts '' and whitespace to NULL
            * Converts 'True'/'False' to BIT
            * Validates foreign keys against the source tables
            * Resolves orphan references to an Unknown surrogate
              (-1) so fact rows are never dropped silently
   ================================================================ */

USE LogisticsIntelligenceDW;
GO

SET NOCOUNT ON;
GO

/* ----------------------------------------------------------------
   2.1  Drop targets (idempotent re-runs)
   ---------------------------------------------------------------- */
IF OBJECT_ID('silver.dim_driver')   IS NOT NULL DROP TABLE silver.dim_driver;
IF OBJECT_ID('silver.dim_truck')    IS NOT NULL DROP TABLE silver.dim_truck;
IF OBJECT_ID('silver.dim_trailer')  IS NOT NULL DROP TABLE silver.dim_trailer;
IF OBJECT_ID('silver.dim_customer') IS NOT NULL DROP TABLE silver.dim_customer;
IF OBJECT_ID('silver.dim_facility') IS NOT NULL DROP TABLE silver.dim_facility;
IF OBJECT_ID('silver.dim_route')    IS NOT NULL DROP TABLE silver.dim_route;
IF OBJECT_ID('silver.dim_date')     IS NOT NULL DROP TABLE silver.dim_date;

IF OBJECT_ID('silver.fact_load')         IS NOT NULL DROP TABLE silver.fact_load;
IF OBJECT_ID('silver.fact_trip')         IS NOT NULL DROP TABLE silver.fact_trip;
IF OBJECT_ID('silver.fact_delivery')     IS NOT NULL DROP TABLE silver.fact_delivery;
IF OBJECT_ID('silver.fact_fuel')         IS NOT NULL DROP TABLE silver.fact_fuel;
IF OBJECT_ID('silver.fact_maintenance')  IS NOT NULL DROP TABLE silver.fact_maintenance;
IF OBJECT_ID('silver.fact_incident')     IS NOT NULL DROP TABLE silver.fact_incident;
IF OBJECT_ID('silver.fact_driver_monthly')  IS NOT NULL DROP TABLE silver.fact_driver_monthly;
IF OBJECT_ID('silver.fact_truck_monthly')   IS NOT NULL DROP TABLE silver.fact_truck_monthly;
GO

/* ================================================================
   2.2  Dimension tables (typed, deduplicated, keyed)
   ================================================================ */

/* --- dim_driver ------------------------------------------------- */
CREATE TABLE silver.dim_driver (
    driver_id         NVARCHAR(20)  PRIMARY KEY,
    first_name        NVARCHAR(50)  NOT NULL,
    last_name         NVARCHAR(50)  NOT NULL,
    full_name         NVARCHAR(101) NOT NULL,
    hire_date         DATE          NULL,
    termination_date  DATE          NULL,
    license_number    NVARCHAR(30)  NULL,
    license_state     NVARCHAR(5)   NULL,
    date_of_birth     DATE          NULL,
    home_terminal     NVARCHAR(50)  NULL,
    employment_status NVARCHAR(20)  NOT NULL DEFAULT 'Unknown',
    cdl_class         NVARCHAR(5)   NULL,
    years_experience  INT           NULL,
    is_active         AS CASE WHEN employment_status = 'Active' THEN 1 ELSE 0 END
);

INSERT INTO silver.dim_driver (
    driver_id, first_name, last_name, full_name, hire_date, termination_date,
    license_number, license_state, date_of_birth, home_terminal,
    employment_status, cdl_class, years_experience
)
SELECT
    driver_id,
    NULLIF(LTRIM(RTRIM(first_name)), ''),
    NULLIF(LTRIM(RTRIM(last_name)), ''),
    LTRIM(RTRIM(first_name)) + ' ' + LTRIM(RTRIM(last_name)),
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(hire_date)), '')),
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(termination_date)), '')),
    NULLIF(LTRIM(RTRIM(license_number)), ''),
    NULLIF(LTRIM(RTRIM(license_state)), ''),
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(date_of_birth)), '')),
    NULLIF(LTRIM(RTRIM(home_terminal)), ''),
    NULLIF(LTRIM(RTRIM(employment_status)), ''),
    NULLIF(LTRIM(RTRIM(cdl_class)), ''),
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(years_experience)), ''))
FROM bronze.drivers;
PRINT 'silver.dim_driver loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(12));

/* --- dim_truck -------------------------------------------------- */
CREATE TABLE silver.dim_truck (
    truck_id              NVARCHAR(20) PRIMARY KEY,
    unit_number           NVARCHAR(20) NULL,
    make                  NVARCHAR(50) NULL,
    model_year            INT          NULL,
    vin                   NVARCHAR(30) NULL,
    acquisition_date      DATE         NULL,
    acquisition_mileage   INT          NULL,
    fuel_type             NVARCHAR(20) NULL,
    tank_capacity_gallons INT          NULL,
    status                NVARCHAR(20) NOT NULL DEFAULT 'Unknown',
    home_terminal         NVARCHAR(50) NULL,
    is_active             AS CASE WHEN status = 'Active' THEN 1 ELSE 0 END
);

INSERT INTO silver.dim_truck (
    truck_id, unit_number, make, model_year, vin, acquisition_date,
    acquisition_mileage, fuel_type, tank_capacity_gallons, status, home_terminal
)
SELECT
    truck_id,
    NULLIF(LTRIM(RTRIM(unit_number)), ''),
    NULLIF(LTRIM(RTRIM(make)), ''),
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(model_year)), '')),
    NULLIF(LTRIM(RTRIM(vin)), ''),
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(acquisition_date)), '')),
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(acquisition_mileage)), '')),
    NULLIF(LTRIM(RTRIM(fuel_type)), ''),
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(tank_capacity_gallons)), '')),
    NULLIF(LTRIM(RTRIM(status)), ''),
    NULLIF(LTRIM(RTRIM(home_terminal)), '')
FROM bronze.trucks;
PRINT 'silver.dim_truck loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(12));

/* --- dim_trailer ------------------------------------------------ */
CREATE TABLE silver.dim_trailer (
    trailer_id       NVARCHAR(20) PRIMARY KEY,
    trailer_number   NVARCHAR(20) NULL,
    trailer_type     NVARCHAR(50) NULL,
    length_feet      INT          NULL,
    model_year       INT          NULL,
    vin              NVARCHAR(30) NULL,
    acquisition_date DATE         NULL,
    status           NVARCHAR(20) NOT NULL DEFAULT 'Unknown',
    current_location NVARCHAR(50) NULL,
    is_active        AS CASE WHEN status = 'Active' THEN 1 ELSE 0 END
);

INSERT INTO silver.dim_trailer (
    trailer_id, trailer_number, trailer_type, length_feet, model_year,
    vin, acquisition_date, status, current_location
)
SELECT
    trailer_id,
    NULLIF(LTRIM(RTRIM(trailer_number)), ''),
    NULLIF(LTRIM(RTRIM(trailer_type)), ''),
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(length_feet)), '')),
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(model_year)), '')),
    NULLIF(LTRIM(RTRIM(vin)), ''),
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(acquisition_date)), '')),
    NULLIF(LTRIM(RTRIM(status)), ''),
    NULLIF(LTRIM(RTRIM(current_location)), '')
FROM bronze.trailers;
PRINT 'silver.dim_trailer loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(12));

/* --- dim_customer ----------------------------------------------- */
CREATE TABLE silver.dim_customer (
    customer_id              NVARCHAR(20) PRIMARY KEY,
    customer_name            NVARCHAR(100) NOT NULL,
    customer_type            NVARCHAR(30)  NULL,
    credit_terms_days        INT           NULL,
    primary_freight_type     NVARCHAR(30)  NULL,
    account_status           NVARCHAR(20)  NOT NULL DEFAULT 'Unknown',
    contract_start_date      DATE          NULL,
    annual_revenue_potential DECIMAL(12,0) NULL,
    is_active                AS CASE WHEN account_status = 'Active' THEN 1 ELSE 0 END
);

INSERT INTO silver.dim_customer (
    customer_id, customer_name, customer_type, credit_terms_days,
    primary_freight_type, account_status, contract_start_date, annual_revenue_potential
)
SELECT
    customer_id,
    NULLIF(LTRIM(RTRIM(customer_name)), ''),
    NULLIF(LTRIM(RTRIM(customer_type)), ''),
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(credit_terms_days)), '')),
    NULLIF(LTRIM(RTRIM(primary_freight_type)), ''),
    NULLIF(LTRIM(RTRIM(account_status)), ''),
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(contract_start_date)), '')),
    TRY_CONVERT(DECIMAL(12,0), NULLIF(LTRIM(RTRIM(annual_revenue_potential)), ''))
FROM bronze.customers;
PRINT 'silver.dim_customer loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(12));

/* --- dim_facility ----------------------------------------------- */
CREATE TABLE silver.dim_facility (
    facility_id     NVARCHAR(20) PRIMARY KEY,
    facility_name   NVARCHAR(100) NOT NULL,
    facility_type   NVARCHAR(30)  NULL,
    city            NVARCHAR(50)  NULL,
    state           NVARCHAR(5)   NULL,
    latitude        DECIMAL(9,6)  NULL,
    longitude       DECIMAL(9,6)  NULL,
    dock_doors      INT           NULL,
    operating_hours NVARCHAR(20)  NULL
);

INSERT INTO silver.dim_facility (
    facility_id, facility_name, facility_type, city, state,
    latitude, longitude, dock_doors, operating_hours
)
SELECT
    facility_id,
    NULLIF(LTRIM(RTRIM(facility_name)), ''),
    NULLIF(LTRIM(RTRIM(facility_type)), ''),
    NULLIF(LTRIM(RTRIM(city)), ''),
    NULLIF(LTRIM(RTRIM(state)), ''),
    TRY_CONVERT(DECIMAL(9,6), NULLIF(LTRIM(RTRIM(latitude)), '')),
    TRY_CONVERT(DECIMAL(9,6), NULLIF(LTRIM(RTRIM(longitude)), '')),
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(dock_doors)), '')),
    NULLIF(LTRIM(RTRIM(operating_hours)), '')
FROM bronze.facilities;
PRINT 'silver.dim_facility loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(12));

/* --- dim_route -------------------------------------------------- */
CREATE TABLE silver.dim_route (
    route_id               NVARCHAR(20) PRIMARY KEY,
    origin_city            NVARCHAR(50) NULL,
    origin_state           NVARCHAR(5)  NULL,
    destination_city       NVARCHAR(50) NULL,
    destination_state      NVARCHAR(5)  NULL,
    origin_full            AS origin_city + ', ' + origin_state,
    destination_full       AS destination_city + ', ' + destination_state,
    corridor               AS origin_city + ' -> ' + destination_city,
    typical_distance_miles INT          NULL,
    base_rate_per_mile     DECIMAL(6,2) NULL,
    fuel_surcharge_rate    DECIMAL(6,3) NULL,
    typical_transit_days   INT          NULL
);

INSERT INTO silver.dim_route (
    route_id, origin_city, origin_state, destination_city, destination_state,
    typical_distance_miles, base_rate_per_mile, fuel_surcharge_rate, typical_transit_days
)
SELECT
    route_id,
    NULLIF(LTRIM(RTRIM(origin_city)), ''),
    NULLIF(LTRIM(RTRIM(origin_state)), ''),
    NULLIF(LTRIM(RTRIM(destination_city)), ''),
    NULLIF(LTRIM(RTRIM(destination_state)), ''),
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(typical_distance_miles)), '')),
    TRY_CONVERT(DECIMAL(6,2), NULLIF(LTRIM(RTRIM(base_rate_per_mile)), '')),
    TRY_CONVERT(DECIMAL(6,3), NULLIF(LTRIM(RTRIM(fuel_surcharge_rate)), '')),
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(typical_transit_days)), ''))
FROM bronze.routes;
PRINT 'silver.dim_route loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(12));

/* --- dim_date (2022-01-01 .. 2025-12-31, calendar) -------------- */
;WITH numbers AS (
    SELECT TOP (4 * 366) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
SELECT
    CAST(DATEADD(DAY, n, '2022-01-01') AS DATE) AS date_id,
    YEAR(DATEADD(DAY, n, '2022-01-01'))    AS year_nbr,
    MONTH(DATEADD(DAY, n, '2022-01-01'))   AS month_nbr,
    DAY(DATEADD(DAY, n, '2022-01-01'))     AS day_nbr,
    DATEPART(QUARTER, DATEADD(DAY, n, '2022-01-01')) AS quarter_nbr,
    DATEPART(WEEKDAY, DATEADD(DAY, n, '2022-01-01')) AS weekday_nbr,  -- 1=Sunday
    DATENAME(MONTH, DATEADD(DAY, n, '2022-01-01')) AS month_name,
    DATENAME(WEEKDAY, DATEADD(DAY, n, '2022-01-01')) AS weekday_name,
    CASE WHEN DATEPART(WEEKDAY, DATEADD(DAY, n, '2022-01-01')) IN (1,7) THEN 1 ELSE 0 END AS is_weekend,
    CASE
        WHEN MONTH(DATEADD(DAY, n, '2022-01-01')) IN (12,1,2)  THEN 'Winter'
        WHEN MONTH(DATEADD(DAY, n, '2022-01-01')) IN (3,4,5)   THEN 'Spring'
        WHEN MONTH(DATEADD(DAY, n, '2022-01-01')) IN (6,7,8)   THEN 'Summer'
        ELSE 'Fall'
    END AS season
INTO silver.dim_date
FROM numbers
WHERE DATEADD(DAY, n, '2022-01-01') <= '2025-12-31';

ALTER TABLE silver.dim_date ALTER COLUMN date_id DATE NOT NULL;
ALTER TABLE silver.dim_date ADD PRIMARY KEY (date_id);
CREATE INDEX ix_dim_date_year  ON silver.dim_date (year_nbr);
CREATE INDEX ix_dim_date_month ON silver.dim_date (month_nbr);
DECLARE @date_cnt INT = (SELECT COUNT(*) FROM silver.dim_date);
PRINT 'silver.dim_date loaded: ' + CAST(@date_cnt AS VARCHAR(12));
GO

/* ================================================================
   2.3  Fact tables (typed, FK-validated, orphan-safe)
   ================================================================ */

/* --- fact_load -------------------------------------------------- */
CREATE TABLE silver.fact_load (
    load_id            NVARCHAR(20) PRIMARY KEY,
    customer_id        NVARCHAR(20) NOT NULL,
    route_id           NVARCHAR(20) NOT NULL,
    load_date          DATE         NOT NULL,
    load_type          NVARCHAR(30) NULL,
    weight_lbs         DECIMAL(10,0) NULL,
    pieces             INT          NULL,
    revenue            DECIMAL(12,2) NULL,
    fuel_surcharge     DECIMAL(12,2) NULL,
    accessorial_charges DECIMAL(12,2) NULL,
    load_status        NVARCHAR(20) NULL,
    booking_type       NVARCHAR(20) NULL,
    gross_revenue      AS revenue + fuel_surcharge + accessorial_charges
);

INSERT INTO silver.fact_load (
    load_id, customer_id, route_id, load_date, load_type, weight_lbs, pieces,
    revenue, fuel_surcharge, accessorial_charges, load_status, booking_type
)
SELECT
    load_id,
    -- FK validated: if the customer/route is missing from the source dim,
    -- keep the row and flag it instead of silently dropping the fact.
    CASE WHEN c.customer_id IS NULL THEN '-1' ELSE l.customer_id END,
    CASE WHEN r.route_id    IS NULL THEN '-1' ELSE l.route_id    END,
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(load_date)), '')),
    NULLIF(LTRIM(RTRIM(load_type)), ''),
    TRY_CONVERT(DECIMAL(10,0), NULLIF(LTRIM(RTRIM(weight_lbs)), '')),
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(pieces)), '')),
    TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM(revenue)), '')),
    TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM(fuel_surcharge)), '')),
    TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM(accessorial_charges)), '')),
    NULLIF(LTRIM(RTRIM(load_status)), ''),
    NULLIF(LTRIM(RTRIM(booking_type)), '')
FROM bronze.loads l
LEFT JOIN silver.dim_customer c ON c.customer_id = l.customer_id
LEFT JOIN silver.dim_route    r ON r.route_id    = l.route_id;
PRINT 'silver.fact_load loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(12));

/* --- fact_trip -------------------------------------------------- */
CREATE TABLE silver.fact_trip (
    trip_id               NVARCHAR(20) PRIMARY KEY,
    load_id               NVARCHAR(20) NOT NULL,
    driver_id             NVARCHAR(20) NOT NULL,
    truck_id              NVARCHAR(20) NOT NULL,
    trailer_id            NVARCHAR(20) NOT NULL,
    dispatch_date         DATE         NOT NULL,
    actual_distance_miles DECIMAL(10,1) NULL,
    actual_duration_hours DECIMAL(7,2)  NULL,
    fuel_gallons_used     DECIMAL(10,2) NULL,
    average_mpg           DECIMAL(6,2)  NULL,
    idle_time_hours       DECIMAL(7,2)  NULL,
    trip_status           NVARCHAR(20)  NULL
);

INSERT INTO silver.fact_trip (
    trip_id, load_id, driver_id, truck_id, trailer_id, dispatch_date,
    actual_distance_miles, actual_duration_hours, fuel_gallons_used,
    average_mpg, idle_time_hours, trip_status
)
SELECT
    t.trip_id,
    CASE WHEN l.load_id    IS NULL THEN '-1' ELSE t.load_id    END,
    CASE WHEN d.driver_id  IS NULL THEN '-1' ELSE t.driver_id  END,
    CASE WHEN k.truck_id   IS NULL THEN '-1' ELSE t.truck_id   END,
    CASE WHEN tr.trailer_id IS NULL THEN '-1' ELSE t.trailer_id END,
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(t.dispatch_date)), '')),
    TRY_CONVERT(DECIMAL(10,1), NULLIF(LTRIM(RTRIM(t.actual_distance_miles)), '')),
    TRY_CONVERT(DECIMAL(7,2),  NULLIF(LTRIM(RTRIM(t.actual_duration_hours)), '')),
    TRY_CONVERT(DECIMAL(10,2), NULLIF(LTRIM(RTRIM(t.fuel_gallons_used)), '')),
    TRY_CONVERT(DECIMAL(6,2),  NULLIF(LTRIM(RTRIM(t.average_mpg)), '')),
    TRY_CONVERT(DECIMAL(7,2),  NULLIF(LTRIM(RTRIM(t.idle_time_hours)), '')),
    NULLIF(LTRIM(RTRIM(t.trip_status)), '')
FROM bronze.trips t
LEFT JOIN silver.fact_load   l  ON l.load_id    = t.load_id
LEFT JOIN silver.dim_driver  d  ON d.driver_id  = t.driver_id
LEFT JOIN silver.dim_truck   k  ON k.truck_id   = t.truck_id
LEFT JOIN silver.dim_trailer tr ON tr.trailer_id = t.trailer_id;
PRINT 'silver.fact_trip loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(12));

/* --- fact_delivery ---------------------------------------------- */
CREATE TABLE silver.fact_delivery (
    event_id          NVARCHAR(20) PRIMARY KEY,
    load_id           NVARCHAR(20) NOT NULL,
    trip_id           NVARCHAR(20) NOT NULL,
    facility_id       NVARCHAR(20) NOT NULL,
    event_type        NVARCHAR(20) NOT NULL,
    scheduled_datetime DATETIME2(0) NULL,
    actual_datetime   DATETIME2(0)  NULL,
    detention_minutes INT           NULL,
    on_time_flag      BIT           NULL,
    location_city     NVARCHAR(50)  NULL,
    location_state    NVARCHAR(5)   NULL
);

INSERT INTO silver.fact_delivery (
    event_id, load_id, trip_id, facility_id, event_type,
    scheduled_datetime, actual_datetime, detention_minutes, on_time_flag,
    location_city, location_state
)
SELECT
    e.event_id,
    CASE WHEN l.load_id  IS NULL THEN '-1' ELSE e.load_id  END,
    CASE WHEN t.trip_id  IS NULL THEN '-1' ELSE e.trip_id  END,
    CASE WHEN f.facility_id IS NULL THEN '-1' ELSE e.facility_id END,
    NULLIF(LTRIM(RTRIM(e.event_type)), ''),
    TRY_CONVERT(DATETIME2(0), NULLIF(LTRIM(RTRIM(e.scheduled_datetime)), '')),
    TRY_CONVERT(DATETIME2(0), NULLIF(LTRIM(RTRIM(e.actual_datetime)), '')),
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(e.detention_minutes)), '')),
    CASE WHEN e.on_time_flag = 'True' THEN 1 WHEN e.on_time_flag = 'False' THEN 0 ELSE NULL END,
    NULLIF(LTRIM(RTRIM(e.location_city)), ''),
    NULLIF(LTRIM(RTRIM(e.location_state)), '')
FROM bronze.delivery_events e
LEFT JOIN silver.fact_load     l ON l.load_id    = e.load_id
LEFT JOIN silver.fact_trip     t ON t.trip_id    = e.trip_id
LEFT JOIN silver.dim_facility  f ON f.facility_id = e.facility_id;
PRINT 'silver.fact_delivery loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(12));

/* --- fact_fuel --------------------------------------------------- */
CREATE TABLE silver.fact_fuel (
    fuel_purchase_id  NVARCHAR(20) PRIMARY KEY,
    trip_id           NVARCHAR(20) NOT NULL,
    truck_id          NVARCHAR(20) NOT NULL,
    driver_id         NVARCHAR(20) NOT NULL,
    purchase_date     DATE         NOT NULL,
    location_city     NVARCHAR(50) NULL,
    location_state    NVARCHAR(5)  NULL,
    gallons           DECIMAL(10,2) NULL,
    price_per_gallon  DECIMAL(6,3)  NULL,
    total_cost        DECIMAL(12,2) NULL,
    fuel_card_number  NVARCHAR(20)  NULL
);

INSERT INTO silver.fact_fuel (
    fuel_purchase_id, trip_id, truck_id, driver_id, purchase_date,
    location_city, location_state, gallons, price_per_gallon, total_cost, fuel_card_number
)
SELECT
    f.fuel_purchase_id,
    CASE WHEN t.trip_id  IS NULL THEN '-1' ELSE f.trip_id  END,
    CASE WHEN k.truck_id IS NULL THEN '-1' ELSE f.truck_id END,
    CASE WHEN d.driver_id IS NULL THEN '-1' ELSE f.driver_id END,
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(LEFT(f.purchase_date, 10))), '')),
    NULLIF(LTRIM(RTRIM(f.location_city)), ''),
    NULLIF(LTRIM(RTRIM(f.location_state)), ''),
    TRY_CONVERT(DECIMAL(10,2), NULLIF(LTRIM(RTRIM(f.gallons)), '')),
    TRY_CONVERT(DECIMAL(6,3),  NULLIF(LTRIM(RTRIM(f.price_per_gallon)), '')),
    TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM(f.total_cost)), '')),
    NULLIF(LTRIM(RTRIM(f.fuel_card_number)), '')
FROM bronze.fuel_purchases f
LEFT JOIN silver.fact_trip  t ON t.trip_id   = f.trip_id
LEFT JOIN silver.dim_truck  k ON k.truck_id  = f.truck_id
LEFT JOIN silver.dim_driver d ON d.driver_id = f.driver_id;
PRINT 'silver.fact_fuel loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(12));

/* --- fact_maintenance -------------------------------------------- */
CREATE TABLE silver.fact_maintenance (
    maintenance_id    NVARCHAR(20) PRIMARY KEY,
    truck_id          NVARCHAR(20) NOT NULL,
    maintenance_date  DATE         NULL,
    maintenance_type  NVARCHAR(30) NULL,
    odometer_reading  DECIMAL(12,0) NULL,
    labor_hours       DECIMAL(7,2)  NULL,
    labor_cost        DECIMAL(12,2) NULL,
    parts_cost        DECIMAL(12,2) NULL,
    total_cost        DECIMAL(12,2) NULL,
    facility_location NVARCHAR(50)  NULL,
    downtime_hours    DECIMAL(7,2)  NULL,
    service_description NVARCHAR(200) NULL
);

INSERT INTO silver.fact_maintenance (
    maintenance_id, truck_id, maintenance_date, maintenance_type, odometer_reading,
    labor_hours, labor_cost, parts_cost, total_cost, facility_location,
    downtime_hours, service_description
)
SELECT
    m.maintenance_id,
    CASE WHEN k.truck_id IS NULL THEN '-1' ELSE m.truck_id END,
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(m.maintenance_date)), '')),
    NULLIF(LTRIM(RTRIM(m.maintenance_type)), ''),
    TRY_CONVERT(DECIMAL(12,0), NULLIF(LTRIM(RTRIM(m.odometer_reading)), '')),
    TRY_CONVERT(DECIMAL(7,2),  NULLIF(LTRIM(RTRIM(m.labor_hours)), '')),
    TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM(m.labor_cost)), '')),
    TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM(m.parts_cost)), '')),
    TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM(m.total_cost)), '')),
    NULLIF(LTRIM(RTRIM(m.facility_location)), ''),
    TRY_CONVERT(DECIMAL(7,2),  NULLIF(LTRIM(RTRIM(m.downtime_hours)), '')),
    NULLIF(LTRIM(RTRIM(m.service_description)), '')
FROM bronze.maintenance_records m
LEFT JOIN silver.dim_truck k ON k.truck_id = m.truck_id;
PRINT 'silver.fact_maintenance loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(12));

/* --- fact_incident ----------------------------------------------- */
CREATE TABLE silver.fact_incident (
    incident_id         NVARCHAR(20) PRIMARY KEY,
    trip_id             NVARCHAR(20) NOT NULL,
    truck_id            NVARCHAR(20) NOT NULL,
    driver_id           NVARCHAR(20) NOT NULL,
    incident_date       DATE         NULL,
    incident_type       NVARCHAR(30) NULL,
    location_city       NVARCHAR(50) NULL,
    location_state      NVARCHAR(5)  NULL,
    at_fault_flag       BIT          NULL,
    injury_flag         BIT          NULL,
    vehicle_damage_cost DECIMAL(12,2) NULL,
    cargo_damage_cost   DECIMAL(12,2) NULL,
    claim_amount        DECIMAL(12,2) NULL,
    preventable_flag    BIT          NULL,
    description         NVARCHAR(500) NULL
);

INSERT INTO silver.fact_incident (
    incident_id, trip_id, truck_id, driver_id, incident_date, incident_type,
    location_city, location_state, at_fault_flag, injury_flag,
    vehicle_damage_cost, cargo_damage_cost, claim_amount, preventable_flag, description
)
SELECT
    i.incident_id,
    CASE WHEN t.trip_id  IS NULL THEN '-1' ELSE i.trip_id  END,
    CASE WHEN k.truck_id IS NULL THEN '-1' ELSE i.truck_id END,
    CASE WHEN d.driver_id IS NULL THEN '-1' ELSE i.driver_id END,
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(i.incident_date)), '')),
    NULLIF(LTRIM(RTRIM(i.incident_type)), ''),
    NULLIF(LTRIM(RTRIM(i.location_city)), ''),
    NULLIF(LTRIM(RTRIM(i.location_state)), ''),
    CASE WHEN i.at_fault_flag = 'True' THEN 1 WHEN i.at_fault_flag = 'False' THEN 0 ELSE NULL END,
    CASE WHEN i.injury_flag   = 'True' THEN 1 WHEN i.injury_flag   = 'False' THEN 0 ELSE NULL END,
    TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM(i.vehicle_damage_cost)), '')),
    TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM(i.cargo_damage_cost)), '')),
    TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM(i.claim_amount)), '')),
    CASE WHEN i.preventable_flag = 'True' THEN 1 WHEN i.preventable_flag = 'False' THEN 0 ELSE NULL END,
    NULLIF(LTRIM(RTRIM(i.description)), '')
FROM bronze.safety_incidents i
LEFT JOIN silver.fact_trip   t ON t.trip_id   = i.trip_id
LEFT JOIN silver.dim_truck   k ON k.truck_id  = i.truck_id
LEFT JOIN silver.dim_driver  d ON d.driver_id = i.driver_id;
PRINT 'silver.fact_incident loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(12));

/* --- fact_driver_monthly (pre-aggregated source) ------------------ */
CREATE TABLE silver.fact_driver_monthly (
    driver_id            NVARCHAR(20) NOT NULL,
    month                DATE         NOT NULL,
    trips_completed      INT          NULL,
    total_miles          DECIMAL(12,1) NULL,
    total_revenue        DECIMAL(12,2) NULL,
    average_mpg          DECIMAL(6,2)  NULL,
    total_fuel_gallons   DECIMAL(12,2) NULL,
    on_time_delivery_rate DECIMAL(6,2) NULL,
    average_idle_hours   DECIMAL(7,2)  NULL,
    CONSTRAINT pk_fact_driver_monthly PRIMARY KEY (driver_id, month)
);

INSERT INTO silver.fact_driver_monthly (
    driver_id, month, trips_completed, total_miles, total_revenue,
    average_mpg, total_fuel_gallons, on_time_delivery_rate, average_idle_hours
)
SELECT
    CASE WHEN d.driver_id IS NULL THEN '-1' ELSE m.driver_id END,
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(m.month)), '')),
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(m.trips_completed)), '')),
    TRY_CONVERT(DECIMAL(12,1), NULLIF(LTRIM(RTRIM(m.total_miles)), '')),
    TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM(m.total_revenue)), '')),
    TRY_CONVERT(DECIMAL(6,2),  NULLIF(LTRIM(RTRIM(m.average_mpg)), '')),
    TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM(m.total_fuel_gallons)), '')),
    TRY_CONVERT(DECIMAL(6,2),  NULLIF(LTRIM(RTRIM(m.on_time_delivery_rate)), '')),
    TRY_CONVERT(DECIMAL(7,2),  NULLIF(LTRIM(RTRIM(m.average_idle_hours)), ''))
FROM bronze.driver_monthly_metrics m
LEFT JOIN silver.dim_driver d ON d.driver_id = m.driver_id;
PRINT 'silver.fact_driver_monthly loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(12));

/* --- fact_truck_monthly (pre-aggregated source) ------------------- */
CREATE TABLE silver.fact_truck_monthly (
    truck_id           NVARCHAR(20) NOT NULL,
    month              DATE         NOT NULL,
    trips_completed    INT          NULL,
    total_miles        DECIMAL(12,1) NULL,
    total_revenue      DECIMAL(12,2) NULL,
    average_mpg        DECIMAL(6,2)  NULL,
    maintenance_events INT          NULL,
    maintenance_cost   DECIMAL(12,2) NULL,
    downtime_hours     DECIMAL(7,2)  NULL,
    utilization_rate   DECIMAL(6,3)  NULL,
    CONSTRAINT pk_fact_truck_monthly PRIMARY KEY (truck_id, month)
);

INSERT INTO silver.fact_truck_monthly (
    truck_id, month, trips_completed, total_miles, total_revenue,
    average_mpg, maintenance_events, maintenance_cost, downtime_hours, utilization_rate
)
SELECT
    CASE WHEN k.truck_id IS NULL THEN '-1' ELSE m.truck_id END,
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(m.month)), '')),
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(m.trips_completed)), '')),
    TRY_CONVERT(DECIMAL(12,1), NULLIF(LTRIM(RTRIM(m.total_miles)), '')),
    TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM(m.total_revenue)), '')),
    TRY_CONVERT(DECIMAL(6,2),  NULLIF(LTRIM(RTRIM(m.average_mpg)), '')),
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(m.maintenance_events)), '')),
    TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM(m.maintenance_cost)), '')),
    TRY_CONVERT(DECIMAL(7,2),  NULLIF(LTRIM(RTRIM(m.downtime_hours)), '')),
    TRY_CONVERT(DECIMAL(6,3),  NULLIF(LTRIM(RTRIM(m.utilization_rate)), ''))
FROM bronze.truck_utilization_metrics m
LEFT JOIN silver.dim_truck k ON k.truck_id = m.truck_id;
PRINT 'silver.fact_truck_monthly loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(12));
GO

/* ================================================================
   2.4  Data-quality report: orphans sent to Unknown (-1)
   ================================================================ */
SELECT 'fact_load'       AS fact, 'customer' AS fk, SUM(CASE WHEN customer_id = '-1' THEN 1 ELSE 0 END) AS orphans FROM silver.fact_load
UNION ALL SELECT 'fact_load', 'route', SUM(CASE WHEN route_id = '-1' THEN 1 ELSE 0 END) FROM silver.fact_load
UNION ALL SELECT 'fact_trip', 'load', SUM(CASE WHEN load_id = '-1' THEN 1 ELSE 0 END) FROM silver.fact_trip
UNION ALL SELECT 'fact_trip', 'driver', SUM(CASE WHEN driver_id = '-1' THEN 1 ELSE 0 END) FROM silver.fact_trip
UNION ALL SELECT 'fact_trip', 'truck', SUM(CASE WHEN truck_id = '-1' THEN 1 ELSE 0 END) FROM silver.fact_trip
UNION ALL SELECT 'fact_trip', 'trailer', SUM(CASE WHEN trailer_id = '-1' THEN 1 ELSE 0 END) FROM silver.fact_trip
UNION ALL SELECT 'fact_delivery', 'load', SUM(CASE WHEN load_id = '-1' THEN 1 ELSE 0 END) FROM silver.fact_delivery
UNION ALL SELECT 'fact_delivery', 'trip', SUM(CASE WHEN trip_id = '-1' THEN 1 ELSE 0 END) FROM silver.fact_delivery
UNION ALL SELECT 'fact_delivery', 'facility', SUM(CASE WHEN facility_id = '-1' THEN 1 ELSE 0 END) FROM silver.fact_delivery
UNION ALL SELECT 'fact_fuel', 'trip', SUM(CASE WHEN trip_id = '-1' THEN 1 ELSE 0 END) FROM silver.fact_fuel
UNION ALL SELECT 'fact_fuel', 'truck', SUM(CASE WHEN truck_id = '-1' THEN 1 ELSE 0 END) FROM silver.fact_fuel
UNION ALL SELECT 'fact_fuel', 'driver', SUM(CASE WHEN driver_id = '-1' THEN 1 ELSE 0 END) FROM silver.fact_fuel
UNION ALL SELECT 'fact_maintenance', 'truck', SUM(CASE WHEN truck_id = '-1' THEN 1 ELSE 0 END) FROM silver.fact_maintenance
UNION ALL SELECT 'fact_incident', 'trip', SUM(CASE WHEN trip_id = '-1' THEN 1 ELSE 0 END) FROM silver.fact_incident
UNION ALL SELECT 'fact_incident', 'truck', SUM(CASE WHEN truck_id = '-1' THEN 1 ELSE 0 END) FROM silver.fact_incident
UNION ALL SELECT 'fact_incident', 'driver', SUM(CASE WHEN driver_id = '-1' THEN 1 ELSE 0 END) FROM silver.fact_incident;

INSERT INTO gold.pipeline_audit (layer, object_name, rows_loaded, status, notes)
SELECT 'silver', 'dim_driver',    COUNT(*), 'DONE', NULL FROM silver.dim_driver
UNION ALL SELECT 'silver', 'dim_truck',     COUNT(*), 'DONE', NULL FROM silver.dim_truck
UNION ALL SELECT 'silver', 'dim_trailer',   COUNT(*), 'DONE', NULL FROM silver.dim_trailer
UNION ALL SELECT 'silver', 'dim_customer',  COUNT(*), 'DONE', NULL FROM silver.dim_customer
UNION ALL SELECT 'silver', 'dim_facility',  COUNT(*), 'DONE', NULL FROM silver.dim_facility
UNION ALL SELECT 'silver', 'dim_route',     COUNT(*), 'DONE', NULL FROM silver.dim_route
UNION ALL SELECT 'silver', 'dim_date',      COUNT(*), 'DONE', NULL FROM silver.dim_date
UNION ALL SELECT 'silver', 'fact_load',         COUNT(*), 'DONE', NULL FROM silver.fact_load
UNION ALL SELECT 'silver', 'fact_trip',         COUNT(*), 'DONE', NULL FROM silver.fact_trip
UNION ALL SELECT 'silver', 'fact_delivery',     COUNT(*), 'DONE', NULL FROM silver.fact_delivery
UNION ALL SELECT 'silver', 'fact_fuel',         COUNT(*), 'DONE', NULL FROM silver.fact_fuel
UNION ALL SELECT 'silver', 'fact_maintenance',  COUNT(*), 'DONE', NULL FROM silver.fact_maintenance
UNION ALL SELECT 'silver', 'fact_incident',     COUNT(*), 'DONE', NULL FROM silver.fact_incident
UNION ALL SELECT 'silver', 'fact_driver_monthly', COUNT(*), 'DONE', NULL FROM silver.fact_driver_monthly
UNION ALL SELECT 'silver', 'fact_truck_monthly',  COUNT(*), 'DONE', NULL FROM silver.fact_truck_monthly;
GO
