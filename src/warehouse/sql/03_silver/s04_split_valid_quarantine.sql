TRUNCATE silver_trips_quarantine;

INSERT INTO silver_trips_quarantine
SELECT *
FROM silver_trips
WHERE NOT (is_time_valid AND is_duration_valid AND is_geo_valid);

-- Create a stable "valid" view for downstream consumers
CREATE OR REPLACE VIEW silver_trips_valid AS
SELECT *
FROM silver_trips
WHERE (is_time_valid AND is_duration_valid AND is_geo_valid);