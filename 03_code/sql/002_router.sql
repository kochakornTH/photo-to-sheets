-- 002_router.sql
-- Router: control tables (ctl.route, ctl.route_alias) and silver.command, plus seed rows.
-- Safe to re-run: IF NOT EXISTS and ON CONFLICT DO NOTHING.

BEGIN;

-- One row per command the bot understands. Adding a command = insert here + aliases.
CREATE TABLE IF NOT EXISTS ctl.route (
  route            text PRIMARY KEY,
  workflow_id      text,                        -- n8n workflow id; NULL until the workflow exists
  enabled          boolean NOT NULL DEFAULT true,
  needs_attachment boolean NOT NULL DEFAULT false,
  description      text NOT NULL                -- shown in the help list
);

-- Words that map to a route (plus-address part or first subject word), lowercase.
CREATE TABLE IF NOT EXISTS ctl.route_alias (
  alias text PRIMARY KEY,
  route text NOT NULL REFERENCES ctl.route(route)
);

-- Silver: one case per email. case_id makes a retried trigger harmless.
CREATE TABLE IF NOT EXISTS silver.command (
  case_id     text PRIMARY KEY,                 -- sha256(gmail_id), hex
  gmail_id    text NOT NULL UNIQUE,             -- bronze.gmail_message.gmail_id
  thread_id   text,
  owner_id    text,                             -- set by the allow-list step
  route       text REFERENCES ctl.route(route),
  resolved_by text,                             -- how the route was found
  status      text NOT NULL DEFAULT 'received'
              CHECK (status IN ('received','routed','running','done','needs_input','failed')),
  summary     text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_command_status ON silver.command (status);

-- Seed: routes
INSERT INTO ctl.route (route, needs_attachment, description) VALUES
  ('expenseAdd',    true,  'Save a receipt: send a photo or PDF'),
  ('expenseReport', false, 'Spending report: 2026-09, last30, or empty for this month'),
  ('help',          false, 'List the available commands')
ON CONFLICT (route) DO NOTHING;

-- Seed: aliases
INSERT INTO ctl.route_alias (alias, route) VALUES
  ('expense', 'expenseAdd'),
  ('exp',     'expenseAdd'),
  ('receipt', 'expenseAdd'),
  ('beleg',   'expenseAdd'),
  ('report',  'expenseReport')
ON CONFLICT (alias) DO NOTHING;

COMMIT;
