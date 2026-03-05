import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path
import subprocess

POSTGRES_CONTAINER = os.getenv("DP_POSTGRES_CONTAINER", "dp_postgres")
DB_USER = os.getenv("DP_DB_USER", "dp")
DB_NAME = os.getenv("DP_DB_NAME", "warehouse")

# Thresholds (enterprise-style)
MAX_INVALID_TIME_RATIO = float(os.getenv("DP_MAX_INVALID_TIME_RATIO", "0.001"))      # 0.1%
MAX_INVALID_DURATION_RATIO = float(os.getenv("DP_MAX_INVALID_DURATION_RATIO", "0.01"))  # 1%
MAX_INVALID_GEO_RATIO = float(os.getenv("DP_MAX_INVALID_GEO_RATIO", "0.01"))         # 1%

REPO_ROOT = Path(__file__).resolve().parents[2]
CHECKS_SQL_PATH = REPO_ROOT / "src" / "quality" / "checks" / "silver_trips_checks.sql"

ARTIFACT_DIR = REPO_ROOT / "metrics" / "quality"
ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)


def psql_scalar(sql: str) -> int:
    cmd = [
        "docker", "exec", "-i", POSTGRES_CONTAINER,
        "psql", "-U", DB_USER, "-d", DB_NAME,
        "-t", "-A",
        "-c", sql
    ]
    out = subprocess.check_output(cmd, text=True).strip()
    return int(out) if out else 0


def main():
    start = time.time()
    ts = datetime.now(timezone.utc).isoformat()

    if not CHECKS_SQL_PATH.exists():
        raise FileNotFoundError(f"Checks SQL not found: {CHECKS_SQL_PATH}")

    # Remove full-line comments before splitting statements.
    sql_text = CHECKS_SQL_PATH.read_text(encoding="utf-8")
    sql_lines = [line for line in sql_text.splitlines() if not line.strip().startswith("--")]
    sql_without_comments = "\n".join(sql_lines)
    statements = [s.strip() for s in sql_without_comments.split(";") if s.strip()]

    # Map checks by order (simple)
    # 0 total_rows, 1 dup_pk, 2 null_critical, 3 invalid_time, 4 invalid_duration, 5 invalid_geo
    results = []
    for stmt in statements:
        val = psql_scalar(stmt)
        results.append(val)

    expected_results = 6
    if len(results) < expected_results:
        raise RuntimeError(
            f"Expected {expected_results} quality check queries from {CHECKS_SQL_PATH}, got {len(results)}."
        )

    total_rows = results[0]
    dup_pk = results[1]
    null_critical = results[2]
    invalid_time = results[3]
    invalid_duration = results[4]
    invalid_geo = results[5]

    def ratio(bad: int) -> float:
        return (bad / total_rows) if total_rows > 0 else 0.0

    report = {
        "timestamp_utc": ts,
        "table": "silver_trips",
        "total_rows": total_rows,
        "checks": {
            "duplicate_primary_key_rows": dup_pk,
            "null_critical_fields_rows": null_critical,
            "invalid_time_rows": invalid_time,
            "invalid_duration_rows": invalid_duration,
            "invalid_geo_rows": invalid_geo,
        },
        "ratios": {
            "invalid_time_ratio": ratio(invalid_time),
            "invalid_duration_ratio": ratio(invalid_duration),
            "invalid_geo_ratio": ratio(invalid_geo),
        },
        "thresholds": {
            "max_invalid_time_ratio": MAX_INVALID_TIME_RATIO,
            "max_invalid_duration_ratio": MAX_INVALID_DURATION_RATIO,
            "max_invalid_geo_ratio": MAX_INVALID_GEO_RATIO,
        },
        "status": "PASS",
        "duration_ms": int((time.time() - start) * 1000),
    }

    # Hard failures (must be zero)
    hard_fail = (dup_pk > 0) or (null_critical > 0)

    # Soft failures (ratio thresholds)
    soft_fail = (
        report["ratios"]["invalid_time_ratio"] > MAX_INVALID_TIME_RATIO or
        report["ratios"]["invalid_duration_ratio"] > MAX_INVALID_DURATION_RATIO or
        report["ratios"]["invalid_geo_ratio"] > MAX_INVALID_GEO_RATIO
    )

    if hard_fail or soft_fail:
        report["status"] = "FAIL"

    artifact_path = ARTIFACT_DIR / f"silver_trips_quality_{int(time.time())}.json"
    artifact_path.write_text(json.dumps(report, indent=2), encoding="utf-8")

    print(json.dumps(report, indent=2))

    # Exit non-zero if FAIL (so Airflow/CI can stop the pipeline)
    if report["status"] != "PASS":
        raise SystemExit(2)


if __name__ == "__main__":
    main()
