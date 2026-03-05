-- Each query must return a single row with a single integer column named "value".
-- We keep this super simple: checks are counts of "bad rows".

-- 1) Total rows (not a check, but needed for ratios)
SELECT COUNT(*)::bigint AS value FROM silver_trips;

-- 2) PK uniqueness check (should be 0 duplicates)
SELECT (COUNT(*) - COUNT(DISTINCT id))::bigint AS value FROM silver_trips;

-- 3) Null critical fields (should be 0)
SELECT COUNT(*)::bigint AS value
FROM silver_trips
WHERE id IS NULL OR vendor_id IS NULL OR pickup_ts IS NULL OR dropoff_ts IS NULL OR pickup_date IS NULL;

-- 4) Invalid time ordering (should be 0 ideally)
SELECT COUNT(*)::bigint AS value
FROM silver_trips
WHERE NOT is_time_valid;

-- 5) Invalid duration (should be low, thresholded)
SELECT COUNT(*)::bigint AS value
FROM silver_trips
WHERE NOT is_duration_valid;

-- 6) Invalid geo (should be low, thresholded)
SELECT COUNT(*)::bigint AS value
FROM silver_trips
WHERE NOT is_geo_valid;