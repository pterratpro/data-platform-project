CREATE TABLE IF NOT EXISTS load_audit (
  run_id        text PRIMARY KEY,
  pipeline      text NOT NULL,
  source_file   text NOT NULL,
  table_name    text NOT NULL,
  mode          text NOT NULL,
  started_at    timestamp NOT NULL,
  finished_at   timestamp NOT NULL,
  duration_ms   bigint NOT NULL,
  rows_loaded   bigint NOT NULL,
  status        text NOT NULL,
  error_message text
);

CREATE INDEX IF NOT EXISTS ix_load_audit_table_finished
ON load_audit (table_name, finished_at DESC);