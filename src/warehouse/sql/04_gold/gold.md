# Gold Layer (`gold_trips_daily`, `gold_vendor_daily`)

The Gold layer turns Silver-level trip records into business-ready daily aggregates for reporting and KPIs.

## 1) Create Gold aggregate tables

```sql
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
```

## 2) Refresh Gold aggregates from Silver

```sql
TRUNCATE gold_trips_daily;
TRUNCATE gold_vendor_daily;

INSERT INTO gold_trips_daily
SELECT
  pickup_date,
  COUNT(*) AS trips,
  AVG(trip_duration_sec) AS avg_duration_sec,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY trip_duration_sec) AS p95_duration_sec,
  SUM(CASE WHEN NOT is_geo_valid THEN 1 ELSE 0 END) AS invalid_geo_trips,
  SUM(CASE WHEN NOT is_duration_valid THEN 1 ELSE 0 END) AS invalid_duration_trips
FROM silver_trips
GROUP BY pickup_date
ORDER BY pickup_date;

INSERT INTO gold_vendor_daily
SELECT
  pickup_date,
  vendor_id,
  COUNT(*) AS trips,
  AVG(trip_duration_sec) AS avg_duration_sec,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY trip_duration_sec) AS p95_duration_sec
FROM silver_trips
GROUP BY pickup_date, vendor_id
ORDER BY pickup_date, vendor_id;
```

## What was cleaned and structured in Gold?

In Gold, the goal is less raw-data cleaning and more metric structuring for analytics consumption.

1. **Aggregation and grain definition**
- `gold_trips_daily` is structured at **day level** (`pickup_date`).
- `gold_vendor_daily` is structured at **day + vendor level** (`pickup_date`, `vendor_id`).
- This defines stable business grains for dashboards and downstream BI queries.

2. **KPI standardization**
- Both tables expose consistent core metrics: total trips, average duration, and p95 duration.
- `PERCENTILE_CONT(0.95)` adds a robust tail metric to monitor long trips, not only averages.

3. **Data quality visibility from Silver flags**
- Gold keeps quality monitoring by aggregating invalid counts (`invalid_geo_trips`, `invalid_duration_trips`).
- This makes data issues observable at reporting level without scanning row-level tables.

4. **Performance-oriented shape**
- Pre-aggregated tables reduce query cost and latency for common daily analyses.
- Primary keys enforce uniqueness at the intended reporting grain.

5. **Deterministic full refresh pattern**
- `TRUNCATE` + `INSERT` rebuilds aggregates from the current Silver state.
- This ensures deterministic outputs and avoids drift from partial updates.

The result is a compact, business-facing data model that is ready for dashboards, trend tracking, and SLA/KPI monitoring.
