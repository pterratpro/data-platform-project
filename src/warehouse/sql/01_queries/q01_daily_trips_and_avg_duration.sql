SELECT
  DATE(pickup_datetime) AS day,
  COUNT(*) AS trips,
  AVG(trip_duration) AS avg_trip_duration_sec
FROM raw_trips
GROUP BY 1
ORDER BY 1;