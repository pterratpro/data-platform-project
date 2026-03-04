SELECT
  COUNT(*) AS bad_rows
FROM raw_trips
WHERE pickup_datetime > dropoff_datetime;