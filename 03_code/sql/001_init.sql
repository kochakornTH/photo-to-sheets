-- 001_init.sql
-- Medallion layout: bronze (raw), silver (clean), gold (reports), ctl (config).
-- Safe to re-run: every statement uses IF NOT EXISTS.

CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;
CREATE SCHEMA IF NOT EXISTS ctl;

-- Bronze: one row per Gmail message, stored raw. Append-only, no transformation.
-- Attachments are not stored here: they are dumped into folder_path (Drive).
CREATE TABLE IF NOT EXISTS bronze.gmail_message (
  gmail_id         text PRIMARY KEY,           -- Gmail API "id"
  thread_id        text,                       -- Gmail API "threadId"
  rfc_message_id   text,                       -- header Message-ID
  label_ids        text[],                     -- Gmail API "labelIds"
  received_at      timestamptz,                -- from "internalDate" (ms)
  message          jsonb NOT NULL,             -- full raw Gmail JSON (Simplify off)
  folder_path      text,                       -- bronze/gmail/<threadId>_<id>/
  attachment_count int,                        -- counted at ingest
  n8n_execution_id text,                       -- link back to the n8n run
  ingested_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_gmail_message_thread   ON bronze.gmail_message (thread_id);
CREATE INDEX IF NOT EXISTS idx_gmail_message_received ON bronze.gmail_message (received_at);
