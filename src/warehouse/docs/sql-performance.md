# SQL Performance Analysis - `raw_trips` Table

## 1. Objective

The goal of this document is to:

- Analyze the performance characteristics of analytical queries
- Measure execution plans using `EXPLAIN (ANALYZE, BUFFERS)`
- Identify bottlenecks
- Apply targeted indexing strategies
- Quantify improvements
- Document trade-offs

This mirrors real-world production data platform performance tuning practices.

## 2. Environment

- Database: PostgreSQL 16 (Docker container)
- Dataset: NYC Taxi Trip Duration (snapshot load)
- Table: `raw_trips`
- Load strategy: Snapshot full reload (`TRUNCATE + COPY`)
- Stats refreshed via `ANALYZE`

## 3. Baseline Query Under Study

We selected a representative analytical query using window functions:

```sql
SELECT *
FROM (
  SELECT
    DATE(pickup_datetime) AS day,
    id,
    trip_duration,
    ROW_NUMBER() OVER (
      PARTITION BY DATE(pickup_datetime)
      ORDER BY trip_duration DESC
    ) AS rn
  FROM raw_trips
) x
WHERE rn <= 5;
```

Why this query?

It represents:

- Analytical workload
- Partitioning
- Sorting
- Window functions
- Heavy CPU and memory operations

This type of query is common in real analytics environments.

## 4. Baseline Performance Measurement

### Command Used

Run this:

```bash
docker exec -it dp_postgres psql -U dp -d warehouse -c "
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM (
  SELECT
    DATE(pickup_datetime) AS day,
    id,
    trip_duration,
    ROW_NUMBER() OVER (
      PARTITION BY DATE(pickup_datetime)
      ORDER BY trip_duration DESC
    ) AS rn
  FROM raw_trips
) x
WHERE rn <= 5;"
```

### Baseline Execution Plan Output

Paste full output here:

```text
<< PASTE BASELINE EXPLAIN ANALYZE OUTPUT >>
```

### Baseline Observations

- Scan type:
- Execution time:
- Buffers used:
- Sort operations:
- Planner strategy:

Document what you observe.

Example:

- Sequential scan detected
- WindowAgg over full dataset
- No index usage
- CPU-heavy operation

## 5. Identified Bottleneck

The expression:

```sql
DATE(pickup_datetime)
```

prevents the query planner from leveraging a standard index on `pickup_datetime`.

Because the column is wrapped in a function, PostgreSQL cannot use a regular B-tree index directly for this expression.

## 6. Optimization Strategy

### Solution: Expression Index

Create an index on the computed expression:

```bash
docker exec -it dp_postgres psql -U dp -d warehouse -c "
CREATE INDEX IF NOT EXISTS ix_raw_trips_pickup_day
ON raw_trips ((DATE(pickup_datetime)));"
```

Refresh statistics:

```bash
docker exec -it dp_postgres psql -U dp -d warehouse -c "
ANALYZE raw_trips;"
```

## 7. Post-Optimization Measurement

Re-run the same `EXPLAIN` command:

```bash
docker exec -it dp_postgres psql -U dp -d warehouse -c "
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM (
  SELECT
    DATE(pickup_datetime) AS day,
    id,
    trip_duration,
    ROW_NUMBER() OVER (
      PARTITION BY DATE(pickup_datetime)
      ORDER BY trip_duration DESC
    ) AS rn
  FROM raw_trips
) x
WHERE rn <= 5;"
```

### Post-Optimization Output

Paste full output here:

```text
<< PASTE POST-OPTIMIZATION EXPLAIN ANALYZE OUTPUT >>
```

## 8. Performance Comparison

| Metric | Before | After |
| --- | --- | --- |
| Execution Time |  |  |
| Scan Type |  |  |
| Buffers Used |  |  |
| Sort Cost |  |  |

Fill values using measured output.

## 9. Interpretation

Explain:

- Did scan change from `Seq Scan` to `Index Scan`?
- Did buffer usage decrease?
- Was execution time reduced?
- How significant was improvement?
- Is improvement meaningful at scale?

Example reasoning:

- Index reduces full table scanning
- Planner can prune partitions more efficiently
- Window function still requires sorting
- Performance gain scales with dataset size

## 10. Trade-offs

Expression index implications:

- Increased storage
- Slightly slower writes
- Additional maintenance cost

Given snapshot load strategy, impact is minimal.

## 11. Alternative Approaches

- Precompute `pickup_date` column during ingestion
- Partition table by date
- Materialized views for heavy queries
- Gold layer aggregated tables

## 12. Scaling Considerations

If dataset grows to billions of rows:

- Table partitioning by day/month
- BRIN index for time-series workloads
- Increase `work_mem` for large sorts
- Pre-aggregation layer
- Columnar storage (Delta / Parquet)

## 13. Conclusion

This exercise demonstrates:

- Methodical performance evaluation
- Use of `EXPLAIN ANALYZE`
- Expression indexing
- Measured optimization
- Production-oriented reasoning

This reflects real-world data engineering performance tuning practices.
