SELECT
  width_bucket(trip_duration, 0, 3600, 12) AS bucket,
  COUNT(*) AS trips
FROM raw_trips
GROUP BY 1
ORDER BY 1;