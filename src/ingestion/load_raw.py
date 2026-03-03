import json
import os
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

from src.common.run_id import new_run_id

# ---- Config (simple and enterprise) ----
POSTGRES_CONTAINER = os.getenv("DP_POSTGRES_CONTAINER", "dp_postgres")
DB_USER = os.getenv("DP_DB_USER", "dp")
DB_NAME = os.getenv("DP_DB_NAME", "warehouse")

PIPELINE_NAME = os.getenv("DP_PIPELINE_NAME", "raw_snapshot_loader")
TABLE_NAME = os.getenv("DP_TABLE_NAME", "raw_trips")
MODE = os.getenv("DP_MODE", "snapshot_full_reload")

# Chemins
REPO_ROOT = Path(__file__).resolve().parents[2]
SQL_DIR = REPO_ROOT / "src" / "ingestion" / "sql"

LOCAL_CSV_PATH = Path(os.getenv("DP_CSV_PATH", str(REPO_ROOT / "data" / "raw" / "NYC.csv")))
CONTAINER_CSV_PATH = os.getenv("DP_CONTAINER_CSV_PATH", "/tmp/NYC.csv")


def log(event: str, **fields):
    payload = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "event": event,
        **fields,
    }
    print(json.dumps(payload, ensure_ascii=False))


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)


def psql(sql: str) -> str:
    """
    Execute SQL in Postgres container and return stdout.
    """
    cmd = [
        "docker", "exec", "-i", POSTGRES_CONTAINER,
        "psql", "-U", DB_USER, "-d", DB_NAME,
        "-t", "-A",  # tuples only, unaligned
        "-c", sql
    ]
    out = subprocess.check_output(cmd, text=True)
    return out.strip()


def psql_file(path: Path) -> None:
    sql_text = path.read_text(encoding="utf-8")
    _ = psql(sql_text)


def main():
    if not LOCAL_CSV_PATH.exists():
        raise FileNotFoundError(f"CSV not found: {LOCAL_CSV_PATH}")

    run_id = new_run_id()
    started = datetime.now(timezone.utc)
    t0 = time.time()

    log("run_start",
        run_id=run_id,
        pipeline=PIPELINE_NAME,
        mode=MODE,
        csv=str(LOCAL_CSV_PATH),
        table=TABLE_NAME,
        container=POSTGRES_CONTAINER)

    status = "success"
    error_message = None
    rows_loaded = 0

    try:
        # 1) Ensure tables exist
        psql_file(SQL_DIR / "001_create_raw_trips.sql")
        psql_file(SQL_DIR / "002_create_load_audit.sql")

        # 2) Snapshot strategy: truncate target
        psql_file(SQL_DIR / "003_truncate_raw.sql")

        # 3) Copy CSV into container
        run(["docker", "cp", str(LOCAL_CSV_PATH), f"{POSTGRES_CONTAINER}:{CONTAINER_CSV_PATH}"])

        # 4) Load CSV into raw table
        #    NOTE: \copy runs in psql client inside container -> reads file path inside container
        psql(f"\\copy {TABLE_NAME} FROM '{CONTAINER_CSV_PATH}' WITH (FORMAT csv, HEADER true);")

        # 5) Count rows (for audit)
        rows_loaded_str = psql(f"SELECT COUNT(*) FROM {TABLE_NAME};")
        rows_loaded = int(rows_loaded_str) if rows_loaded_str else 0

        # 6) Update planner stats for better query plans
        psql_file(SQL_DIR / "004_analyze_raw.sql")

    except subprocess.CalledProcessError as e:
        status = "failed"
        error_message = f"Command failed: {e}"
        raise
    except Exception as e:
        status = "failed"
        error_message = str(e)
        raise
    finally:
        finished = datetime.now(timezone.utc)
        duration_ms = int((time.time() - t0) * 1000)

        # 7) Write audit row (even if failed)
        # Escape single quotes in error_message to avoid breaking SQL
        safe_error = (error_message or "").replace("'", "''") if error_message else None

        audit_sql = f"""
        INSERT INTO load_audit
          (run_id, pipeline, source_file, table_name, mode, started_at, finished_at, duration_ms, rows_loaded, status, error_message)
        VALUES
          ('{run_id}', '{PIPELINE_NAME}', '{LOCAL_CSV_PATH.as_posix()}', '{TABLE_NAME}', '{MODE}',
           '{started.isoformat()}', '{finished.isoformat()}', {duration_ms}, {rows_loaded}, '{status}',
           { "NULL" if safe_error is None else f"'{safe_error}'" });
        """
        try:
            psql(audit_sql)
        except Exception:
            pass

        log("run_end",
            run_id=run_id,
            status=status,
            rows_loaded=rows_loaded,
            duration_ms=duration_ms)

if __name__ == "__main__":
    main()