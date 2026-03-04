CREATE TABLE IF NOT EXISTS dim_date (
  date_key date PRIMARY KEY,
  year int NOT NULL,
  month int NOT NULL,
  day int NOT NULL,
  dow int NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_vendor (
  vendor_id int PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS fact_trips (
  id text PRIMARY KEY,
  date_key date NOT NULL REFERENCES dim_date(date_key),
  vendor_id int NOT NULL REFERENCES dim_vendor(vendor_id),
  trip_duration_sec int NOT NULL,
  passenger_count int,
  is_geo_valid boolean NOT NULL,
  is_duration_valid boolean NOT NULL,
  is_time_valid boolean NOT NULL
);

CREATE INDEX IF NOT EXISTS ix_fact_trips_date ON fact_trips (date_key);
CREATE INDEX IF NOT EXISTS ix_fact_trips_vendor_date ON fact_trips (vendor_id, date_key);