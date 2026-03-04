# Silver Layer (`silver_trips`)

The Silver layer transforms raw trip events into a cleaned and analytics-ready table.

## 1) Create the Silver table

```sql
CREATE TABLE IF NOT EXISTS silver_trips (
  id                 text PRIMARY KEY,
  vendor_id          int NOT NULL,
  pickup_ts          timestamp NOT NULL,
  dropoff_ts         timestamp NOT NULL,
  pickup_date        date NOT NULL,
  trip_duration_sec  int NOT NULL,
  passenger_count    int,
  pickup_longitude   double precision,
  pickup_latitude    double precision,
  dropoff_longitude  double precision,
  dropoff_latitude   double precision,
  store_and_fwd_flag text,

  -- derived fields
  trip_duration_min  numeric(10,2) NOT NULL,
  is_geo_valid       boolean NOT NULL,
  is_duration_valid  boolean NOT NULL,
  is_time_valid      boolean NOT NULL,

  loaded_at          timestamp NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_silver_trips_pickup_date ON silver_trips (pickup_date);
CREATE INDEX IF NOT EXISTS ix_silver_trips_vendor_date ON silver_trips (vendor_id, pickup_date);
```

## 2) Load and standardize Silver data

```sql
TRUNCATE silver_trips;

INSERT INTO silver_trips (
  id, vendor_id, pickup_ts, dropoff_ts, pickup_date,
  trip_duration_sec, passenger_count,
  pickup_longitude, pickup_latitude, dropoff_longitude, dropoff_latitude,
  store_and_fwd_flag,
  trip_duration_min,
  is_geo_valid, is_duration_valid, is_time_valid
)
SELECT
  id,
  vendor_id,
  pickup_datetime AS pickup_ts,
  dropoff_datetime AS dropoff_ts,
  DATE(pickup_datetime) AS pickup_date,
  trip_duration AS trip_duration_sec,
  passenger_count,
  pickup_longitude, pickup_latitude, dropoff_longitude, dropoff_latitude,
  store_and_fwd_flag,
  ROUND(trip_duration / 60.0, 2) AS trip_duration_min,
  (
    pickup_latitude BETWEEN -90 AND 90 AND dropoff_latitude BETWEEN -90 AND 90 AND
    pickup_longitude BETWEEN -180 AND 180 AND dropoff_longitude BETWEEN -180 AND 180
  ) AS is_geo_valid,
  (trip_duration > 0 AND trip_duration < 6*3600) AS is_duration_valid,
  (pickup_datetime <= dropoff_datetime) AS is_time_valid
FROM raw_trips;
```

## What was cleaned and structured?

Cleaning and structuring in this layer happens in four main ways:

1. **Column standardization and typing**
- Raw column names are normalized to business-friendly names (`pickup_datetime` -> `pickup_ts`, `trip_duration` -> `trip_duration_sec`).
- Data is stored with explicit SQL types (`timestamp`, `date`, `double precision`, `boolean`) to make downstream logic consistent.

2. **Derived analytical fields**
- `pickup_date` is extracted from timestamp for daily aggregations.
- `trip_duration_min` is computed from seconds, rounded to 2 decimals.

3. **Data quality flags (without dropping records)**
- `is_geo_valid` checks latitude/longitude bounds.
- `is_duration_valid` enforces realistic trip duration (`> 0` and `< 6 hours`).
- `is_time_valid` verifies pickup time is not after dropoff time.
- Instead of deleting suspicious rows, the pipeline keeps them and labels quality status for transparent reporting.

4. **Performance and model structure**
- Primary key on `id` ensures trip-level uniqueness.
- Indexes on `pickup_date` and `(vendor_id, pickup_date)` optimize common Gold-layer aggregations.
- `loaded_at` tracks ingestion time for operational observability.

This gives a reliable Silver table that is ready for Gold KPIs while preserving full traceability of data quality.
