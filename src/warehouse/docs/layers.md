# Data Layers Architecture

This project follows a common modern data engineering pattern based on layered data processing:

Raw (Bronze) → Silver → Gold

The goal of this architecture is to separate responsibilities between ingestion, cleaning, and business-level analytics.

---

# Raw Layer (Bronze)

The Raw layer stores data exactly as it is received from the source.

In this project, the dataset is loaded from a CSV file containing NYC taxi trip data.

Characteristics of the Raw layer:

- Schema matches the source structure
- No transformations applied
- Minimal validation
- Serves as the immutable source of truth

Why this matters:

If a transformation error occurs later in the pipeline, we can always return to the raw dataset and rebuild downstream layers.

Raw ingestion uses a **snapshot loading strategy**:

- TRUNCATE table
- COPY data from CSV

This makes the ingestion step idempotent and reproducible.

---

# Silver Layer

The Silver layer contains cleaned and structured data derived from the Raw layer.

Transformations performed in this layer include:

- Column renaming for consistency
- Type normalization
- Derived columns creation
- Data quality validation flags

Examples of transformations:

- `pickup_datetime` → `pickup_ts`
- `DATE(pickup_ts)` → `pickup_date`
- `trip_duration` → `trip_duration_sec`
- Derived metric: `trip_duration_min`

Data quality flags are also added:

- `is_geo_valid`
- `is_duration_valid`
- `is_time_valid`

Instead of silently fixing incorrect data, the pipeline **flags invalid records**.  
This allows downstream monitoring and data quality reporting.

Indexes are also introduced at this stage to support common query patterns.

---

# Gold Layer

The Gold layer contains aggregated and business-ready datasets.

These tables are designed for analytics and reporting.

Examples include:

- daily trip counts
- average trip duration
- p95 trip duration
- vendor-level performance metrics

Gold tables are typically queried by:

- BI dashboards
- analytics workloads
- APIs serving aggregated data

This layer reduces query complexity and improves performance by precomputing common aggregations.

---

# Why Layered Architecture Matters

Separating Raw, Silver, and Gold provides several advantages:

Reliability  
Each step can be recomputed independently.

Traceability  
Raw data remains preserved as the source of truth.

Data Quality  
Issues can be detected and measured in the Silver layer.

Performance  
Gold tables avoid heavy recomputation for analytical queries.

Maintainability  
Transformations are modular and easier to evolve.

---

Downstream analytical layers only consume `silver_trips_valid`.

The base `silver_trips` table is preserved for debugging, quality monitoring, and pipeline evolution.