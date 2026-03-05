CREATE TABLE IF NOT EXISTS silver_trips_quarantine AS
SELECT *
FROM silver_trips
WHERE 1=0;

-- Useful index for investigation
CREATE INDEX IF NOT EXISTS ix_quarantine_pickup_date
ON silver_trips_quarantine (pickup_date);