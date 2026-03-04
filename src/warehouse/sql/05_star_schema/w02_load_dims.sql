TRUNCATE dim_date;
TRUNCATE dim_vendor;

INSERT INTO dim_date (date_key, year, month, day, dow)
SELECT
  d::date,
  EXTRACT(YEAR FROM d)::int,
  EXTRACT(MONTH FROM d)::int,
  EXTRACT(DAY FROM d)::int,
  EXTRACT(DOW FROM d)::int
FROM (
  SELECT generate_series(
    (SELECT MIN(pickup_date) FROM silver_trips),
    (SELECT MAX(pickup_date) FROM silver_trips),
    interval '1 day'
  ) AS d
) s;

INSERT INTO dim_vendor (vendor_id)
SELECT DISTINCT vendor_id
FROM silver_trips
ORDER BY vendor_id;