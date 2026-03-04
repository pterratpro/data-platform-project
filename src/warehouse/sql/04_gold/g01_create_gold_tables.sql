CREATE TABLE IF NOT EXISTS gold_trips_daily (
  pickup_date date PRIMARY KEY,
  trips bigint NOT NULL,
  avg_duration_sec numeric(12,2) NOT NULL,
  p95_duration_sec numeric(12,2) NOT NULL,
  invalid_geo_trips bigint NOT NULL,
  invalid_duration_trips bigint NOT NULL
);

CREATE TABLE IF NOT EXISTS gold_vendor_daily (
  pickup_date date NOT NULL,
  vendor_id int NOT NULL,
  trips bigint NOT NULL,
  avg_duration_sec numeric(12,2) NOT NULL,
  p95_duration_sec numeric(12,2) NOT NULL,
  PRIMARY KEY (pickup_date, vendor_id)
);