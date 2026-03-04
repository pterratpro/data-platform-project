CREATE TABLE IF NOT EXISTS raw_trips (
  id                   text PRIMARY KEY,
  vendor_id            int,
  pickup_datetime      timestamp,
  dropoff_datetime     timestamp,
  passenger_count      int,
  pickup_longitude     double precision,
  pickup_latitude      double precision,
  dropoff_longitude    double precision,
  dropoff_latitude     double precision,
  store_and_fwd_flag   text,
  trip_duration        int
);