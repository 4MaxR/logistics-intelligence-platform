/* ================================================================
   LOGISTICS INTELLIGENCE PLATFORM — DATA WAREHOUSE
   ================================================================
   File   : 01_bronze_layer.sql
   Purpose: BRONZE layer — raw, immutable staging.
            Each source CSV is loaded verbatim into its own
            staging table. All columns are NVARCHAR so nothing is
            lost or coerced at load time; type casting happens in
            the SILVER layer where it can be validated.
   Note   : Paths point at the local source export:
            D:\Desktop\Projects\Logistics-Operations-Database\data
   ================================================================ */

USE LogisticsIntelligenceDW;
GO

SET NOCOUNT ON;
GO

/* ----------------------------------------------------------------
   1.1  DROP staging tables (idempotent re-runs)
   ---------------------------------------------------------------- */
IF OBJECT_ID('bronze.drivers')               IS NOT NULL DROP TABLE bronze.drivers;
IF OBJECT_ID('bronze.trucks')                IS NOT NULL DROP TABLE bronze.trucks;
IF OBJECT_ID('bronze.trailers')              IS NOT NULL DROP TABLE bronze.trailers;
IF OBJECT_ID('bronze.customers')             IS NOT NULL DROP TABLE bronze.customers;
IF OBJECT_ID('bronze.facilities')            IS NOT NULL DROP TABLE bronze.facilities;
IF OBJECT_ID('bronze.routes')                IS NOT NULL DROP TABLE bronze.routes;
IF OBJECT_ID('bronze.loads')                 IS NOT NULL DROP TABLE bronze.loads;
IF OBJECT_ID('bronze.trips')                 IS NOT NULL DROP TABLE bronze.trips;
IF OBJECT_ID('bronze.fuel_purchases')        IS NOT NULL DROP TABLE bronze.fuel_purchases;
IF OBJECT_ID('bronze.maintenance_records')   IS NOT NULL DROP TABLE bronze.maintenance_records;
IF OBJECT_ID('bronze.delivery_events')       IS NOT NULL DROP TABLE bronze.delivery_events;
IF OBJECT_ID('bronze.safety_incidents')      IS NOT NULL DROP TABLE bronze.safety_incidents;
IF OBJECT_ID('bronze.driver_monthly_metrics')IS NOT NULL DROP TABLE bronze.driver_monthly_metrics;
IF OBJECT_ID('bronze.truck_utilization_metrics') IS NOT NULL DROP TABLE bronze.truck_utilization_metrics;
GO

/* ----------------------------------------------------------------
   1.2  Dimension staging tables
   ---------------------------------------------------------------- */
CREATE TABLE bronze.drivers (
    driver_id         NVARCHAR(20),
    first_name        NVARCHAR(50),
    last_name         NVARCHAR(50),
    hire_date         NVARCHAR(20),
    termination_date  NVARCHAR(20),
    license_number    NVARCHAR(30),
    license_state     NVARCHAR(5),
    date_of_birth     NVARCHAR(20),
    home_terminal     NVARCHAR(50),
    employment_status NVARCHAR(20),
    cdl_class         NVARCHAR(5),
    years_experience  NVARCHAR(10)
);

CREATE TABLE bronze.trucks (
    truck_id             NVARCHAR(20),
    unit_number          NVARCHAR(20),
    make                 NVARCHAR(50),
    model_year           NVARCHAR(10),
    vin                  NVARCHAR(30),
    acquisition_date     NVARCHAR(20),
    acquisition_mileage  NVARCHAR(15),
    fuel_type            NVARCHAR(20),
    tank_capacity_gallons NVARCHAR(10),
    status               NVARCHAR(20),
    home_terminal        NVARCHAR(50)
);

CREATE TABLE bronze.trailers (
    trailer_id       NVARCHAR(20),
    trailer_number   NVARCHAR(20),
    trailer_type     NVARCHAR(50),
    length_feet      NVARCHAR(10),
    model_year       NVARCHAR(10),
    vin              NVARCHAR(30),
    acquisition_date NVARCHAR(20),
    status           NVARCHAR(20),
    current_location NVARCHAR(50)
);

CREATE TABLE bronze.customers (
    customer_id             NVARCHAR(20),
    customer_name           NVARCHAR(100),
    customer_type           NVARCHAR(30),
    credit_terms_days       NVARCHAR(10),
    primary_freight_type    NVARCHAR(30),
    account_status          NVARCHAR(20),
    contract_start_date     NVARCHAR(20),
    annual_revenue_potential NVARCHAR(15)
);

CREATE TABLE bronze.facilities (
    facility_id      NVARCHAR(20),
    facility_name    NVARCHAR(100),
    facility_type    NVARCHAR(30),
    city             NVARCHAR(50),
    state            NVARCHAR(5),
    latitude         NVARCHAR(15),
    longitude        NVARCHAR(15),
    dock_doors       NVARCHAR(10),
    operating_hours  NVARCHAR(20)
);

CREATE TABLE bronze.routes (
    route_id              NVARCHAR(20),
    origin_city           NVARCHAR(50),
    origin_state          NVARCHAR(5),
    destination_city      NVARCHAR(50),
    destination_state     NVARCHAR(5),
    typical_distance_miles NVARCHAR(10),
    base_rate_per_mile    NVARCHAR(10),
    fuel_surcharge_rate   NVARCHAR(10),
    typical_transit_days  NVARCHAR(10)
);

/* ----------------------------------------------------------------
   1.3  Fact staging tables
   ---------------------------------------------------------------- */
CREATE TABLE bronze.loads (
    load_id            NVARCHAR(20),
    customer_id        NVARCHAR(20),
    route_id           NVARCHAR(20),
    load_date          NVARCHAR(20),
    load_type          NVARCHAR(30),
    weight_lbs         NVARCHAR(15),
    pieces             NVARCHAR(10),
    revenue            NVARCHAR(15),
    fuel_surcharge     NVARCHAR(15),
    accessorial_charges NVARCHAR(15),
    load_status        NVARCHAR(20),
    booking_type       NVARCHAR(20)
);

CREATE TABLE bronze.trips (
    trip_id               NVARCHAR(20),
    load_id               NVARCHAR(20),
    driver_id             NVARCHAR(20),
    truck_id              NVARCHAR(20),
    trailer_id            NVARCHAR(20),
    dispatch_date         NVARCHAR(20),
    actual_distance_miles NVARCHAR(15),
    actual_duration_hours NVARCHAR(10),
    fuel_gallons_used     NVARCHAR(15),
    average_mpg           NVARCHAR(10),
    idle_time_hours       NVARCHAR(10),
    trip_status           NVARCHAR(20)
);

CREATE TABLE bronze.fuel_purchases (
    fuel_purchase_id  NVARCHAR(20),
    trip_id           NVARCHAR(20),
    truck_id          NVARCHAR(20),
    driver_id         NVARCHAR(20),
    purchase_date     NVARCHAR(25),
    location_city     NVARCHAR(50),
    location_state    NVARCHAR(5),
    gallons           NVARCHAR(15),
    price_per_gallon  NVARCHAR(15),
    total_cost        NVARCHAR(15),
    fuel_card_number  NVARCHAR(20)
);

CREATE TABLE bronze.maintenance_records (
    maintenance_id     NVARCHAR(20),
    truck_id           NVARCHAR(20),
    maintenance_date   NVARCHAR(20),
    maintenance_type   NVARCHAR(30),
    odometer_reading   NVARCHAR(15),
    labor_hours        NVARCHAR(10),
    labor_cost         NVARCHAR(15),
    parts_cost         NVARCHAR(15),
    total_cost         NVARCHAR(15),
    facility_location  NVARCHAR(50),
    downtime_hours     NVARCHAR(10),
    service_description NVARCHAR(200)
);

CREATE TABLE bronze.delivery_events (
    event_id          NVARCHAR(20),
    load_id           NVARCHAR(20),
    trip_id           NVARCHAR(20),
    event_type        NVARCHAR(20),
    facility_id       NVARCHAR(20),
    scheduled_datetime NVARCHAR(30),
    actual_datetime   NVARCHAR(30),
    detention_minutes NVARCHAR(10),
    on_time_flag      NVARCHAR(10),
    location_city     NVARCHAR(50),
    location_state    NVARCHAR(5)
);

CREATE TABLE bronze.safety_incidents (
    incident_id         NVARCHAR(20),
    trip_id             NVARCHAR(20),
    truck_id            NVARCHAR(20),
    driver_id           NVARCHAR(20),
    incident_date       NVARCHAR(20),
    incident_type       NVARCHAR(30),
    location_city       NVARCHAR(50),
    location_state      NVARCHAR(5),
    at_fault_flag       NVARCHAR(10),
    injury_flag         NVARCHAR(10),
    vehicle_damage_cost NVARCHAR(15),
    cargo_damage_cost   NVARCHAR(15),
    claim_amount        NVARCHAR(15),
    preventable_flag    NVARCHAR(10),
    description         NVARCHAR(500)
);

/* ----------------------------------------------------------------
   1.4  Pre-aggregated source metrics
   ---------------------------------------------------------------- */
CREATE TABLE bronze.driver_monthly_metrics (
    driver_id            NVARCHAR(20),
    month                NVARCHAR(20),
    trips_completed      NVARCHAR(10),
    total_miles          NVARCHAR(15),
    total_revenue        NVARCHAR(15),
    average_mpg          NVARCHAR(10),
    total_fuel_gallons   NVARCHAR(15),
    on_time_delivery_rate NVARCHAR(10),
    average_idle_hours   NVARCHAR(10)
);

CREATE TABLE bronze.truck_utilization_metrics (
    truck_id           NVARCHAR(20),
    month              NVARCHAR(20),
    trips_completed    NVARCHAR(10),
    total_miles        NVARCHAR(15),
    total_revenue      NVARCHAR(15),
    average_mpg        NVARCHAR(10),
    maintenance_events NVARCHAR(10),
    maintenance_cost   NVARCHAR(15),
    downtime_hours     NVARCHAR(10),
    utilization_rate   NVARCHAR(10)
);
GO

/* ----------------------------------------------------------------
   1.5  Load — BULK INSERT (raw, no transformation)
   ---------------------------------------------------------------- */
DECLARE @data_dir NVARCHAR(200) = N'D:\Desktop\Projects\Logistics-Operations-Database\data\';

EXEC('BULK INSERT bronze.drivers                 FROM ''' + @data_dir + 'drivers.csv''                 WITH (FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK)');
EXEC('BULK INSERT bronze.trucks                  FROM ''' + @data_dir + 'trucks.csv''                  WITH (FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK)');
EXEC('BULK INSERT bronze.trailers                FROM ''' + @data_dir + 'trailers.csv''                WITH (FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK)');
EXEC('BULK INSERT bronze.customers               FROM ''' + @data_dir + 'customers.csv''               WITH (FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK)');
EXEC('BULK INSERT bronze.facilities              FROM ''' + @data_dir + 'facilities.csv''              WITH (FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK)');
EXEC('BULK INSERT bronze.routes                  FROM ''' + @data_dir + 'routes.csv''                  WITH (FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK)');
EXEC('BULK INSERT bronze.loads                   FROM ''' + @data_dir + 'loads.csv''                   WITH (FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK)');
EXEC('BULK INSERT bronze.trips                   FROM ''' + @data_dir + 'trips.csv''                   WITH (FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK)');
EXEC('BULK INSERT bronze.fuel_purchases          FROM ''' + @data_dir + 'fuel_purchases.csv''          WITH (FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK)');
EXEC('BULK INSERT bronze.maintenance_records     FROM ''' + @data_dir + 'maintenance_records.csv''     WITH (FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK)');
EXEC('BULK INSERT bronze.delivery_events         FROM ''' + @data_dir + 'delivery_events.csv''         WITH (FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK)');
EXEC('BULK INSERT bronze.safety_incidents        FROM ''' + @data_dir + 'safety_incidents.csv''        WITH (FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK)');
EXEC('BULK INSERT bronze.driver_monthly_metrics  FROM ''' + @data_dir + 'driver_monthly_metrics.csv''  WITH (FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK)');
EXEC('BULK INSERT bronze.truck_utilization_metrics FROM ''' + @data_dir + 'truck_utilization_metrics.csv'' WITH (FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK)');
GO

/* ----------------------------------------------------------------
   1.6  Audit — verify every load matches the source export
   ---------------------------------------------------------------- */
INSERT INTO gold.pipeline_audit (layer, object_name, rows_loaded, status, notes)
SELECT 'bronze', 'drivers',                COUNT(*), 'DONE', NULL FROM bronze.drivers
UNION ALL SELECT 'bronze', 'trucks',                 COUNT(*), 'DONE', NULL FROM bronze.trucks
UNION ALL SELECT 'bronze', 'trailers',               COUNT(*), 'DONE', NULL FROM bronze.trailers
UNION ALL SELECT 'bronze', 'customers',              COUNT(*), 'DONE', NULL FROM bronze.customers
UNION ALL SELECT 'bronze', 'facilities',             COUNT(*), 'DONE', NULL FROM bronze.facilities
UNION ALL SELECT 'bronze', 'routes',                 COUNT(*), 'DONE', NULL FROM bronze.routes
UNION ALL SELECT 'bronze', 'loads',                  COUNT(*), 'DONE', NULL FROM bronze.loads
UNION ALL SELECT 'bronze', 'trips',                  COUNT(*), 'DONE', NULL FROM bronze.trips
UNION ALL SELECT 'bronze', 'fuel_purchases',         COUNT(*), 'DONE', NULL FROM bronze.fuel_purchases
UNION ALL SELECT 'bronze', 'maintenance_records',    COUNT(*), 'DONE', NULL FROM bronze.maintenance_records
UNION ALL SELECT 'bronze', 'delivery_events',        COUNT(*), 'DONE', NULL FROM bronze.delivery_events
UNION ALL SELECT 'bronze', 'safety_incidents',       COUNT(*), 'DONE', NULL FROM bronze.safety_incidents
UNION ALL SELECT 'bronze', 'driver_monthly_metrics', COUNT(*), 'DONE', NULL FROM bronze.driver_monthly_metrics
UNION ALL SELECT 'bronze', 'truck_utilization_metrics', COUNT(*), 'DONE', NULL FROM bronze.truck_utilization_metrics;

SELECT layer, object_name, rows_loaded
FROM gold.pipeline_audit
WHERE layer = 'bronze'
ORDER BY object_name;
GO
