WITH daily AS (
  SELECT DATE(pickup_datetime) AS day, vendor_id, COUNT(*) AS trips
  FROM raw_trips
  GROUP BY 1, 2
),
tot AS (
  SELECT day, SUM(trips) AS total_trips
  FROM daily
  GROUP BY 1
)
SELECT
  d.day,
  d.vendor_id,
  d.trips,
  t.total_trips,
  (d.trips::numeric / t.total_trips) AS share
FROM daily d
JOIN tot t USING(day)
ORDER BY d.day, d.vendor_id;