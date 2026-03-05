TRUNCATE gold_trips_daily;
TRUNCATE gold_vendor_daily;

INSERT INTO gold_trips_daily
SELECT
  pickup_date,
  COUNT(*) AS trips,
  AVG(trip_duration_sec) AS avg_duration_sec,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY trip_duration_sec) AS p95_duration_sec,
  SUM(CASE WHEN NOT is_geo_valid THEN 1 ELSE 0 END) AS invalid_geo_trips,
  SUM(CASE WHEN NOT is_duration_valid THEN 1 ELSE 0 END) AS invalid_duration_trips
FROM silver_trips_valid
GROUP BY pickup_date
ORDER BY pickup_date;

INSERT INTO gold_vendor_daily
SELECT
  pickup_date,
  vendor_id,
  COUNT(*) AS trips,
  AVG(trip_duration_sec) AS avg_duration_sec,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY trip_duration_sec) AS p95_duration_sec
FROM silver_trips_valid
GROUP BY pickup_date, vendor_id
ORDER BY pickup_date, vendor_id;