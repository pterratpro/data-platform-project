SELECT
  EXTRACT(HOUR FROM pickup_datetime) AS pickup_hour,
  COUNT(*) AS trips
FROM raw_trips
GROUP BY 1
ORDER BY trips DESC
LIMIT 10;