-- 006_observability.sql
-- Observability (P1.10): silver.case_event (what happened to a case, and when)
-- and silver.llm_call (one row per LLM request: model, tokens, cost, latency, raw output).
-- A trigger on silver.command writes one event for every new case and every status change,
-- so no workflow has to remember to log them.
-- Safe to re-run: IF NOT EXISTS, CREATE OR REPLACE, DROP TRIGGER IF EXISTS;
-- the backfill skips cases that already have events.

BEGIN;

-- One row per thing that happened to a case. Event-log shape: case_id, activity, ts.
-- activity is a status of silver.command (received, routed, running, needs_input, done, failed)
-- or an extra step logged by a workflow (replied).
-- No CHECK on activity on purpose: the trigger copies the status, so a CHECK here
-- would block silver.command as soon as a new status is added there.
CREATE TABLE IF NOT EXISTS silver.case_event (
  event_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  case_id          text NOT NULL REFERENCES silver.command(case_id) ON DELETE CASCADE,
  activity         text NOT NULL,
  ts               timestamptz NOT NULL DEFAULT clock_timestamp(),  -- wall clock, not transaction start
  detail           text,                        -- route, summary or error text (max 200 characters)
  n8n_execution_id text                         -- the n8n run that caused the event
);

CREATE INDEX IF NOT EXISTS idx_case_event_case ON silver.case_event (case_id, event_id);
CREATE INDEX IF NOT EXISTS idx_case_event_ts   ON silver.case_event (ts);

-- One row per request to an LLM, successful or not.
CREATE TABLE IF NOT EXISTS silver.llm_call (
  llm_call_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  case_id          text REFERENCES silver.command(case_id) ON DELETE SET NULL,  -- NULL for calls outside a case (eval runs)
  called_at        timestamptz NOT NULL DEFAULT clock_timestamp(),
  purpose          text NOT NULL,               -- extract, categorize, ...
  model            text NOT NULL,               -- exact model id, taken from the response
  prompt_version   text,                        -- e.g. extraction_v1
  input_tokens     int,
  output_tokens    int,
  cost_usd         numeric(12,6),               -- tokens x price at call time
  latency_ms       int,
  success          boolean NOT NULL DEFAULT true,
  error_message    text,                        -- filled when success is false
  raw_output       jsonb,                       -- full API response, unchanged
  n8n_execution_id text
);

CREATE INDEX IF NOT EXISTS idx_llm_call_case   ON silver.llm_call (case_id);
CREATE INDEX IF NOT EXISTS idx_llm_call_called ON silver.llm_call (called_at);

-- Writes the event. activity = the new status of the case.
CREATE OR REPLACE FUNCTION silver.log_case_event() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO silver.case_event (case_id, activity, detail, n8n_execution_id)
  VALUES (
    NEW.case_id,
    NEW.status,
    left(CASE WHEN NEW.status = 'routed'
              THEN NEW.route || ' (' || coalesce(NEW.resolved_by, '?') || ')'
              ELSE NEW.summary
         END, 200),
    NEW.n8n_execution_id
  );
  RETURN NULL;
END;
$$;

-- New case: event 'received'
DROP TRIGGER IF EXISTS trg_command_insert_event ON silver.command;
CREATE TRIGGER trg_command_insert_event
AFTER INSERT ON silver.command
FOR EACH ROW EXECUTE FUNCTION silver.log_case_event();

-- Status change: event with the new status (routed, done, failed, ...)
DROP TRIGGER IF EXISTS trg_command_status_event ON silver.command;
CREATE TRIGGER trg_command_status_event
AFTER UPDATE OF status ON silver.command
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION silver.log_case_event();

-- Backfill: cases created before this migration get 'received' and their current status.
DROP TABLE IF EXISTS pg_temp.tmp_backfill;

CREATE TEMP TABLE tmp_backfill AS
SELECT c.case_id, c.status, c.route, c.summary, c.created_at, c.finished_at, c.n8n_execution_id
FROM silver.command c
LEFT JOIN silver.case_event e ON e.case_id = c.case_id
WHERE e.case_id IS NULL;

INSERT INTO silver.case_event (case_id, activity, ts, detail)
SELECT case_id, 'received', created_at, 'backfill'
FROM tmp_backfill
ORDER BY created_at;

INSERT INTO silver.case_event (case_id, activity, ts, detail, n8n_execution_id)
SELECT case_id, status, coalesce(finished_at, created_at),
       left('backfill: ' || coalesce(summary, route, ''), 200), n8n_execution_id
FROM tmp_backfill
WHERE status <> 'received'
ORDER BY created_at;

DROP TABLE tmp_backfill;

COMMIT;
