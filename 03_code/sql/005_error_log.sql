-- 005_error_log.sql
-- Error workflow (P1.5): silver.error_log, plus the n8n execution id on silver.command
-- so a failed execution can be matched to its cases.
-- Safe to re-run: IF NOT EXISTS everywhere.

BEGIN;

-- One row per failed n8n execution (or failed trigger).
CREATE TABLE IF NOT EXISTS silver.error_log (
  error_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  occurred_at      timestamptz NOT NULL DEFAULT now(),
  workflow_id      text,                        -- n8n workflow id
  workflow_name    text,
  n8n_execution_id text,                        -- NULL when the trigger itself failed
  execution_url    text,
  mode             text,                        -- trigger, webhook, error, ...
  node_name        text,                        -- last node executed
  error_message    text NOT NULL,
  error_stack      text
);

CREATE INDEX IF NOT EXISTS idx_error_log_occurred  ON silver.error_log (occurred_at);
CREATE INDEX IF NOT EXISTS idx_error_log_execution ON silver.error_log (n8n_execution_id);

-- Which router execution handled the case. The error workflow uses it to find
-- the cases of a failed execution.
ALTER TABLE silver.command ADD COLUMN IF NOT EXISTS n8n_execution_id text;

CREATE INDEX IF NOT EXISTS idx_command_execution ON silver.command (n8n_execution_id);

COMMIT;
