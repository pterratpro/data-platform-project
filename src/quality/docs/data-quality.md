# Data Quality Checks

This project includes lightweight, production-oriented data quality checks for the Silver layer.

## Why this exists
In production pipelines, data quality checks act as a *gate*:
- detect broken upstream inputs
- prevent bad data from reaching consumption layers
- quantify data health over time

## What is checked (silver_trips)
- Primary key uniqueness (no duplicates)
- Nulls in critical columns (must be zero)
- Logical validity checks:
  - pickup <= dropoff
  - duration within acceptable range
  - coordinates within valid ranges

## How it runs
Checks are implemented as SQL queries returning "bad row counts".  
A Python runner executes these queries against Postgres and produces:
- PASS/FAIL status
- ratios (bad/total)
- a JSON artifact stored under `metrics/quality/`

## Thresholds
Some checks are hard-fail (duplicates, critical nulls).  
Others use thresholds (invalid ratios) configurable via environment variables.

### Data Freshness Check

The pipeline verifies that the latest available data is recent enough.

Freshness is measured using the maximum pickup date from the validated dataset.

If the data is older than the configured threshold, the pipeline fails.

This type of check is common in production data platforms to detect ingestion failures or upstream system outages.