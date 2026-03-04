SELECT
  COUNT(*) AS bad_rows
FROM raw_trips
WHERE trip_duration <= 0;