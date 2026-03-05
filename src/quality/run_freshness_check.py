import json
import os
import subprocess
from datetime import datetime, timedelta, timezone

POSTGRES_CONTAINER = os.getenv("DP_POSTGRES_CONTAINER", "dp_postgres")
DB_USER = os.getenv("DP_DB_USER", "dp")
DB_NAME = os.getenv("DP_DB_NAME", "warehouse")

# how many days of delay we tolerate
MAX_DATA_DELAY_DAYS = int(os.getenv("DP_MAX_DATA_DELAY_DAYS", "7"))

def get_max_pickup_date():
    cmd = [
        "docker", "exec", "-i", POSTGRES_CONTAINER,
        "psql", "-U", DB_USER, "-d", DB_NAME,
        "-t", "-A",
        "-c", "SELECT MAX(pickup_date) FROM silver_trips_valid;"
    ]

    out = subprocess.check_output(cmd, text=True).strip()
    return out

def main():
    now = datetime.now(timezone.utc)
    max_date_str = get_max_pickup_date()

    if not max_date_str:
        raise RuntimeError("No data found in silver_trips_valid")

    max_date = datetime.fromisoformat(max_date_str).replace(tzinfo=timezone.utc)

    delay = (now - max_date).days

    status = "PASS"
    if delay > MAX_DATA_DELAY_DAYS:
        status = "FAIL"

    report = {
        "timestamp_utc": now.isoformat(),
        "table": "silver_trips_valid",
        "max_pickup_date": max_date_str,
        "allowed_delay_days": MAX_DATA_DELAY_DAYS,
        "actual_delay_days": delay,
        "status": status
    }

    print(json.dumps(report, indent=2))

    if status == "FAIL":
        raise SystemExit(2)

if __name__ == "__main__":
    main()