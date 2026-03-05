TRUNCATE fact_trips;

INSERT INTO fact_trips (
  id, date_key, vendor_id,
  trip_duration_sec, passenger_count,
  is_geo_valid, is_duration_valid, is_time_valid
)
SELECT
  id,
  pickup_date AS date_key,
  vendor_id,
  trip_duration_sec,
  passenger_count,
  is_geo_valid,
  is_duration_valid,
  is_time_valid
FROM silver_trips_valid;