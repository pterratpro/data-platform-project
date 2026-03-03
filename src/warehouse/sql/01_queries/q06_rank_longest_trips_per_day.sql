SELECT *
FROM (
  SELECT
    DATE(pickup_datetime) AS day,
    id,
    trip_duration,
    ROW_NUMBER() OVER (
      PARTITION BY DATE(pickup_datetime)
      ORDER BY trip_duration DESC
    ) AS rn
  FROM raw_trips
) x
WHERE rn <= 5
ORDER BY day, rn;