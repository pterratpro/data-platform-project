# Data Platform Portfolio — Walkthrough (Local, Production-Like)

## Executive Summary

I designed and implemented a local, production-like data pipeline that ingests a snapshot dataset into a PostgreSQL warehouse running in Docker.  
The pipeline is **reproducible**, **idempotent**, includes **audit logging**, and supports a layered architecture (**Raw/Bronze → Silver → Gold → Star Schema**).  
I also performed a **SQL performance analysis** using `EXPLAIN (ANALYZE, BUFFERS)` and documented a real-world lesson: indexes can degrade performance on full-table analytical scans.

## 1) Why Docker Compose (and what it gives me)

### What we did
We used `docker compose up -d` to start:
- `postgres` (the warehouse database)
- `pgadmin` (UI to explore and query the database)

### Why this matches industry practice
- Reproducible environment (no "works on my machine")
- Easy onboarding: a reviewer can start the full stack locally
- Isolation: Postgres runs in a container without polluting the host system

### Key Docker concepts (interview-ready)
- **Image**: immutable package (e.g. `postgres:16`)
- **Container**: running instance of an image
- **Network**: Docker creates a private network so services can reach each other by name (`postgres:5432`)
- **Ports**: `localhost:5432` is mapped from host → container
- **Volumes**: Postgres data is persisted outside the container so it survives restarts


## 2) Bronze / Raw Layer — Ingesting the dataset

### Goal
Store the dataset “as-is” with minimal transformations:
- Preserve source truth
- Make ingestion reliable and repeatable
- Defer business cleaning to Silver

### Raw table: `raw_trips`
We created a raw table matching the source CSV schema and loaded the file via PostgreSQL bulk loading.

#### Why DDL + COPY is realistic
- **DDL** defines a reproducible schema in the warehouse
- **COPY** is the standard bulk ingestion method in Postgres (much faster than row-by-row inserts)

### Snapshot ingestion strategy
Because the dataset is a **full snapshot**, we load it using:

- `TRUNCATE raw_trips;`
- `COPY raw_trips FROM 'file.csv' ...;`

This gives us **idempotence**: re-running the pipeline produces the same result.


## 3) Understanding `TRUNCATE` (important)

`TRUNCATE` empties a table quickly.

### Why we use it
- For snapshot loads, it’s a clean “replace the dataset” approach
- It avoids duplicates and makes reruns safe

### TRUNCATE vs DELETE
- `DELETE FROM table;` removes rows one by one (slower, logs each row)
- `TRUNCATE table;` removes all rows in bulk (typically much faster)

For snapshot full reload pipelines, `TRUNCATE + COPY` is a common production pattern.


## 4) Adding an audit trail (production habit)

### Why audit logging matters
In real pipelines you want to answer:
- Did the job run?
- How many rows were loaded?
- How long did it take?
- Did it fail? Why?

### What we implemented
A table `load_audit` storing for each run:
- `run_id`, pipeline name, table name
- file path
- start/end timestamps, duration
- `rows_loaded`
- status + error message

This turns a “script” into something closer to an operational pipeline.


## 5) Post-load statistics (why ANALYZE exists)

After loading, we run:

- `ANALYZE raw_trips;`

PostgreSQL uses table statistics to choose efficient execution plans.

This is important because:
- Snapshot loads replace the dataset
- Planner stats can become stale
- Stale stats = bad query plans

In production, refreshing stats after large loads is standard practice.


## 6) SQL Analytics Layer + Performance Engineering

### What we built
A set of analytical queries (window functions, percentiles, rolling averages, sanity checks) stored as versioned `.sql` files under:

- `warehouse/sql/01_queries/`

This is portfolio-grade because:
- Queries are reproducible
- They show advanced SQL knowledge (CTEs, windows, percentiles)
- They demonstrate real analytics use cases

### Performance measurement: EXPLAIN (ANALYZE, BUFFERS)
We measured a window query and captured:
- scan strategy (Seq Scan vs Index Scan)
- sort strategy (in-memory vs disk spill)
- buffer hits/reads (cache vs disk)
- total execution time

#### Key real-world lesson found
We added an expression index on `DATE(pickup_datetime)` expecting performance to improve.

Result:
- Postgres switched from **Seq Scan** to **Index Scan**
- Sorting improved (Incremental Sort)
- But overall runtime got **worse** due to heavy random I/O and massive buffer reads

Conclusion (interview-level):
> Indexes are not universally beneficial.  
> For analytical queries scanning most of a table, sequential scans can outperform index scans.  
> Performance tuning must be evidence-based using EXPLAIN and measured results.

This is a very realistic production behavior.


## 7) Layered modeling: Silver → Gold → Warehouse (Star Schema)

### Why layers exist
Companies separate:
- **Bronze/Raw**: immutable source capture
- **Silver**: cleaned/typed/validated and enriched data
- **Gold**: aggregated KPIs and consumption-ready tables
- **Warehouse / Star Schema**: facts + dimensions for BI and analytics

This makes pipelines:
- easier to debug (you can compare raw vs cleaned)
- easier to evolve (new rules go in Silver, not in ingestion)
- more reliable (quality checks become explicit)


## 8) Silver Layer: `silver_trips`

### What Silver means here
We keep the same grain (one row per trip) but:
- rename columns to a consistent naming convention
- add derived fields (`pickup_date`, `trip_duration_min`)
- add quality flags instead of silently “fixing” data:
  - `is_geo_valid`
  - `is_duration_valid`
  - `is_time_valid`

### Why flags are better than "fixing"
In real pipelines, silently correcting data can hide source issues.  
Flagging allows:
- reporting quality metrics
- quarantining bad rows later
- keeping raw as source-of-truth


## 9) Gold Layer: Aggregations

Gold tables represent consumption-ready metrics:
- daily trip counts, avg duration, p95 duration
- vendor/day KPIs
- quality metrics (how many invalid rows)

Gold is what dashboards typically query.


## 10) Warehouse / Star Schema

We model a classic star schema:
- **Dimensions**
  - `dim_date`
  - `dim_vendor`
- **Facts**
  - `fact_trips` (one row per trip)

Why this matters:
- It matches how BI/analytics tools are built
- It separates descriptive attributes (dims) from measures (facts)
- It supports consistent filtering and aggregation


## 11) How to run everything (PowerShell-friendly)

PowerShell cannot use bash redirection (`< file.sql`), so we run SQL files using:

```powershell
Get-Content .\path\to\file.sql -Raw | docker exec -i dp_postgres psql -U dp -d warehouse