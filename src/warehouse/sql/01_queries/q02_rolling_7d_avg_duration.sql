WITH daily AS (
  SELECT DATE(pickup_datetime) AS day,
         AVG(trip_duration) AS avg_duration
  FROM raw_trips
  GROUP BY 1
)
SELECT
  day,
  avg_duration,
  AVG(avg_duration) OVER (
    ORDER BY day
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ) AS rolling_7d_avg_duration
FROM daily
ORDER BY day;