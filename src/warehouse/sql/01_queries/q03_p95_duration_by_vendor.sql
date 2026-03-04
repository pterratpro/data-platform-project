SELECT
  vendor_id,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY trip_duration) AS p95_duration
FROM raw_trips
GROUP BY vendor_id
ORDER BY vendor_id;