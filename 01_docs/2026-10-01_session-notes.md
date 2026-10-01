# Session notes, 1 Oct 2026: P1.1 and medallion design

## Decisions made

| # | Decision | Reason |
|---|---|---|
| 1 | **Medallion layout**: schemas `bronze` / `silver` / `gold` / `ctl` | Portfolio-grade data engineering; raw data stays replayable |
| 2 | **Bronze first**: only one table `bronze.gmail_message` (raw Gmail JSON as jsonb + ids, labels, received_at, folder_path, attachment_count, n8n_execution_id) | Bronze = raw, append-only; everything else can be derived later |
| 3 | **One folder per email** (`bronze/gmail/<threadId>_<id>/`), all attachments dumped there, files prefixed with their index | Simple; no pic / non-pic decision in ingest |
| 4 | **Pic vs non-pic decision moves to silver** (`silver.attachment`, `kind = image / other`); a photo starts the extraction process | Ingest stays free of business logic |
| 5 | **Own Postgres container** `bot-postgres` on port 5433 (n8n connects via `host.docker.internal:5433`) | `elw-postgres` (port 5432) belongs to another project |
| 6 | `route`, `route_alias`, `command`, `budget` and the route seed are **postponed to P1.3 / P1.6** (`ctl` / `silver`) | Not needed for today's done-when |
| 7 | Ingest saves the email in every case; duplicate polls are stopped by `ON CONFLICT (gmail_id) DO NOTHING` | Idempotency |

## Changes to scope and timeline

- P1.1 done-when changed: "n8n can read route" → **an email lands in `bronze.gmail_message` via n8n, attachments in its folder**.
- The Gmail OAuth credential in n8n moves from P1.2 into P1.1 (Oct 1). Risk: the 2 h estimate may stretch; use the Phase 1 buffer if needed.
- `002_seed_routes.sql` is no longer part of P1.1.

## Open items and next steps

- [ ] n8n credentials: Postgres (`host.docker.internal`, 5433, db `bot`), Gmail OAuth (automation account).
- [ ] Build workflow `ingestGmail` (Simplify off, Download Attachments on) and test with a real email incl. 2 photos + 1 PDF.
- [ ] Decide how the router is triggered from bronze (poll vs. Execute Workflow).
- [ ] Optional `bronze.llm_extraction`; optional `raw_email` style extras are not needed (the jsonb already holds everything).
- [ ] Commit `docker-compose.yml`, `.env.example` (not `.env`) and `03_code/sql/001_init.sql`.
- [ ] Update README.md and PROJECT_CHECKLIST.md (still Telegram + Sheets).

## Files created or changed

- Created `03_code/sql/001_init.sql` (local project folder: `C:\Users\thkoc\Documents\Projects\photo-to-sheets`), `docker-compose.yml`, `.env` (not committed)
- Updated `01_docs/requirements.md` (v2: scope + section 5 medallion data model + open items)
- Updated `01_docs/2026-09-27_build-calendar.html` (P1.1, P1.2, P1.3 rows)
- Created `01_docs/2026-10-01_session-notes.md` (this file)
