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