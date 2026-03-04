CREATE TABLE IF NOT EXISTS silver_trips (
  id                 text PRIMARY KEY,
  vendor_id          int NOT NULL,
  pickup_ts          timestamp NOT NULL,
  dropoff_ts         timestamp NOT NULL,
  pickup_date        date NOT NULL,
  trip_duration_sec  int NOT NULL,
  passenger_count    int,
  pickup_longitude   double precision,
  pickup_latitude    double precision,
  dropoff_longitude  double precision,
  dropoff_latitude   double precision,
  store_and_fwd_flag text,

  -- derived fields
  trip_duration_min  numeric(10,2) NOT NULL,
  is_geo_valid       boolean NOT NULL,
  is_duration_valid  boolean NOT NULL,
  is_time_valid      boolean NOT NULL,

  loaded_at          timestamp NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_silver_trips_pickup_date ON silver_trips (pickup_date);
CREATE INDEX IF NOT EXISTS ix_silver_trips_vendor_date ON silver_trips (vendor_id, pickup_date);