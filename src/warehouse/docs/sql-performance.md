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
(q06_rank_longest_trips_per_day.sql)

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

```text
 WindowAgg  (cost=246903.46..279722.95 rows=1458644 width=26) (actual time=657.285..782.331 rows=910 loops=1)
   Run Condition: (row_number() OVER (?) <= 5)
   Buffers: shared hit=2406 read=17104, temp read=9999 written=10025
   ->  Sort  (cost=246903.46..250550.07 rows=1458644 width=18) (actual time=657.249..735.218 rows=1458644 loops=1)
         Sort Key: (date(raw_trips.pickup_datetime)), raw_trips.trip_duration DESC
         Sort Method: external merge  Disk: 40024kB
         Buffers: shared hit=2406 read=17104, temp read=9999 written=10025
         ->  Seq Scan on raw_trips  (cost=0.00..37737.05 rows=1458644 width=18) (actual time=4.222..171.272 rows=1458644 loops=1)
               Buffers: shared hit=2400 read=17104
 Planning:
   Buffers: shared hit=139
 Planning Time: 0.389 ms
 JIT:
   Functions: 7
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 0.471 ms, Inlining 0.000 ms, Optimization 0.234 ms, Emission 3.958 ms, Total 4.664 ms
 Execution Time: 809.330 ms
```

### Baseline Observations

- Scan type: Sequential Scan 
Sequential scan over entire raw_trips table (1.46M rows).
- Execution time: 809.330 ms
~809 ms for 1.4M rows. Acceptable at this scale but non-scalable linearly.
- Buffers used: shared hit=2406 read=17104
Indicates significant disk I/O.
- Sort operations: external merge Disk: 40024kB temp read=9999 written=10025
External merge sort, 40MB temp disk usage and work_mem insufficient
- Planner strategy: Seq Scan → Sort → WindowAgg
No index usage. Full dataset processing required.

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

```text
 WindowAgg  (cost=1116.42..250520.25 rows=1458644 width=26) (actual time=99.997..1648.611 rows=910 loops=1)
   Run Condition: (row_number() OVER (?) <= 5)
   Buffers: shared hit=942412 read=254760 written=20
   ->  Incremental Sort  (cost=1116.42..221347.37 rows=1458644 width=18) (actual time=99.983..1602.425 rows=1458644 loops=1)
         Sort Key: (date(raw_trips.pickup_datetime)), raw_trips.trip_duration DESC
         Presorted Key: (date(raw_trips.pickup_datetime))
         Full-sort Groups: 182  Sort Method: quicksort  Average Memory: 28kB  Peak Memory: 28kB
         Pre-sorted Groups: 182  Sort Method: quicksort  Average Memory: 818kB  Peak Memory: 844kB
         Buffers: shared hit=942412 read=254760 written=20
         ->  Index Scan using ix_raw_trips_pickup_day on raw_trips  (cost=0.43..108529.27 rows=1458644 width=18) (actual time=26.234..1323.161 rows=1458644 loops=1)
               Buffers: shared hit=942406 read=254760 written=20
 Planning:
   Buffers: shared hit=161
 Planning Time: 0.542 ms
 JIT:
   Functions: 7
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 0.811 ms, Inlining 0.000 ms, Optimization 2.743 ms, Emission 22.828 ms, Total 26.382 ms
 Execution Time: 1784.695 ms
```

## 8. Performance Comparison

| Metric | Baseline (Seq Scan) | With Expression Index |
| --- | --- | --- |
| Execution Time | ~809 ms | ~1785 ms |
| Scan Type | Sequential Scan | Index Scan |
| Buffers Used | hit=2406 / read=17104 | hit=942412 / read=254760 |
| Sort Method | External Merge (40MB disk spill) | Incremental Sort (in-memory) |

### Key Observations

- The index was successfully used (`Index Scan`).
- Sorting improved (no large disk spill).
- However, overall execution time more than doubled.
- Buffer usage increased dramatically.

---

## 9. Interpretation

### Did scan change from `Seq Scan` to `Index Scan`?

Yes. PostgreSQL switched from a full sequential scan to an index scan on the expression index.

---

### Did buffer usage decrease?

No. It increased significantly.

Baseline:
- ~19K buffers touched

With index:
- ~1.2M buffers touched

This indicates heavy random I/O and poor cache locality.

---

### Was execution time reduced?

No. Execution time increased from ~809 ms to ~1785 ms.

This is a critical finding.

---

### Why did performance degrade?

Although the expression index allowed PostgreSQL to:

- Avoid a full external merge sort
- Perform an incremental sort

The cost of the index scan outweighed the benefit.

Index scans are efficient when:
- Only a small portion of the table is accessed

In this case:
- Nearly the entire dataset (~1.46M rows) is processed
- Index scan caused random access to table pages
- Sequential scan was more efficient for full-table workloads

---

### Is improvement meaningful at scale?

No.

For analytical workloads scanning large portions of the table:

- Sequential scans are often optimal
- Index scans can become significantly more expensive
- Over-indexing analytical tables can degrade performance

This demonstrates that:

> Indexes are not universally beneficial.
> They must match workload patterns.

---

## 10. Trade-offs

Expression index implications:

- Increased storage footprint
- Slower ingestion (index maintenance during load)
- Additional planning complexity
- Higher memory pressure

Given a snapshot full reload strategy:

- Index maintenance cost may be acceptable
- But only if it improves real query patterns

In this workload, the index introduces more cost than benefit.

---

## 11. Alternative Approaches

More appropriate optimization strategies for this workload:

- Increase `work_mem` to prevent external disk sort
- Precompute `pickup_date` during ingestion
- Partition table by day or month
- Use materialized views for frequent analytical queries
- Build aggregated Gold-layer tables

For full analytical scans:

- Sequential access is often optimal
- Memory tuning is more impactful than indexing

---

## 12. Scaling Considerations

If dataset grows to hundreds of millions or billions of rows:

- Partition by time (range partitioning)
- Use BRIN index for time-series patterns
- Increase `work_mem` to avoid sort spill
- Move analytical workloads to columnar storage (Delta / Parquet)
- Pre-aggregate heavy window computations

For very large datasets:

- OLTP indexing strategies do not scale for analytical scans
- Storage layout and memory configuration become dominant factors

---

## 13. Conclusion

This exercise demonstrates:

- Methodical performance evaluation using `EXPLAIN (ANALYZE, BUFFERS)`
- Evidence-based tuning decisions
- Understanding of sequential vs index scan trade-offs
- Recognition that indexing can degrade performance
- Awareness of memory and sort behavior

Most importantly:

> Performance tuning requires measurement, not assumptions.

The analysis reflects production-grade data engineering practices and realistic performance trade-offs in analytical workloads.
