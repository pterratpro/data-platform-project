-- Returns the most recent pickup_date in the validated dataset
SELECT MAX(pickup_date) AS max_pickup_date
FROM silver_trips_valid;