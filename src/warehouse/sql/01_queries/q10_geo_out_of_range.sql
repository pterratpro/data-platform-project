SELECT COUNT(*) AS suspicious_geo_rows
FROM raw_trips
WHERE
  pickup_latitude  NOT BETWEEN -90 AND 90
  OR dropoff_latitude NOT BETWEEN -90 AND 90
  OR pickup_longitude NOT BETWEEN -180 AND 180
  OR dropoff_longitude NOT BETWEEN -180 AND 180;