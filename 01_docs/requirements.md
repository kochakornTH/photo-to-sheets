# Email bot (photo-to-sheets): requirements

Status: draft v2, 1 Oct 2026 (medallion data model: see section 5)
Sources: `2026-09-27_email-bot-requirements-notes.md` (design) + `2026-09-27_session-notes.md` (build plan). Where they disagree, the session notes (newer) win.

---

## 1. Purpose

A personal email bot for **real daily use**, built with n8n. It is also a portfolio project.

| Use | Who | When |
|---|---|---|
| Expense logging and control (receipt photos → database → reports) | Me | Now (Phase 1) |
| Daily mood tracking | Me | Later (not in 2026) |
| Invoice photos → tables for accounting | Sister's business, Thailand | Next year |

Photo-to-sheets is the first sub-workflow behind **one general email router**.

## 2. Scope

### In scope (Phase 1)

0. **ingestGmail** (bronze): Gmail trigger → save the raw email as one row in `bronze.gmail_message` → dump all attachments into one folder per email. No decisions, no transformation.
1. **router**: reads new bronze rows, classify the command, dispatch to a sub-workflow, reply
2. **expenseAdd**: extract receipt data (header + line items), validate, store
3. **expenseReport**: totals on request and monthly, including spent vs budget
4. **error workflow**: catches failures in every workflow
5. **sendReply**: the only workflow that sends email
6. **Observability**: `case_event` + `llm_call` tables (every case and every LLM call is logged)
7. **Mini eval**: 10 test receipts → `ground_truth.csv` + `evaluate.py` v0
8. **OAuth app published to production** (otherwise tokens expire after 7 days)

### Out of scope for Phase 1

Product matching across stores (line items are still extracted), LLM-written report text, LLM route classifier, image quality checks and deskewing, Revolut CSV import, mood tracking, sister's invoices, corporate build, portfolio README, forecast model.

## 3. Functional requirements

### 3.1 Router

| ID | Requirement |
|---|---|
| R1 | Poll Gmail every 1 min (done by ingestGmail; the router reads the new bronze rows) with `-label:processed -from:<bot address>` (the `-from` prevents reply loops). |
| R2 | Compute `case_id = sha256(message_id)`. |
| R3 | Insert into `silver.command` with `ON CONFLICT (message_id) DO NOTHING`. If no row is inserted, stop (the email was already handled). |
| R4 | Accept only senders on the allow-list; map the sender to `owner_id`. |
| R5 | Resolve the route in this order: plus-address (`bot+expense@` → expenseAdd) → first subject word (lowercased) → alias lookup in `route_alias`. Store `resolved_by`. |
| R6 | Clean the body: text/plain, strip signature and quoted reply. |
| R7 | Dispatch with Execute Workflow using `workflow_id` from the `route` table (an expression, not a Switch node). |
| R8 | Unknown command → reply with the help list (`SELECT route, description FROM route WHERE enabled`). |
| R9 | After the sub-workflow: call `sendReply`, add the `processed` label, update `status`, `finished_at`, `summary`. |
| R10 | Adding a new command = insert rows into `route` + `route_alias`. No change to the router workflow. |

Command status flow: `received → routed → running → done / needs_input / failed`.

### 3.2 expenseAdd

| ID | Requirement |
|---|---|
| A1 | Receive the task envelope via Execute Workflow Trigger. |
| A2 | Split attachments into one item each; keep images and PDFs only. |
| A3 | Skip duplicates by `message_id + attachment_idx`. |
| A4 | Extract the receipt header and **every line item** with a vision LLM and an output schema. Call the LLM with an **HTTP Request node** (the raw response includes token usage). |
| A5 | Normalize merchant, date, amounts and units. |
| A6 | Validate: line items add up to the total; VAT (7% / 19%) reconciles; date is plausible. On failure set `needs_review`. |
| A7 | Assign a category from the fixed list (see 3.5). |
| A8 | Write `receipt` + `receipt_line` to Postgres; save the photo to Drive. |
| A9 | Return one merged result (status + summary). |

Normalize and validate live in plain Python modules from the start.

### 3.3 expenseReport

| ID | Requirement |
|---|---|
| E1 | On request via the router (`bot+report@`). Args: `2026-09`, `last30`, or empty (= this month). |
| E2 | Scheduled: 1st of the month at 08:00, for the previous month. First scheduled run: Sun 1 Nov 2026. |
| E3 | Contents: total, by category, by store, vs last month, top items, count needing review, **spent vs budget**. |
| E4 | Output: HTML table in the email body + CSV attachment. |
| E5 | Label reports "receipts only" until a bank import exists. |

### 3.4 Supporting workflows

| ID | Requirement |
|---|---|
| S1 | **Error workflow** is set on every workflow, including itself: insert into `error_log` → set command `status = failed` → Gmail label `failed` → alert me (email or push, e.g. ntfy) with workflow, node and case id. |
| S2 | **sendReply** replies in the thread if `thread_id` exists, otherwise sends a new email; includes the case id and attachments. A later channel (e.g. LINE) changes only this workflow. |
| S3 | **Watchdog** (Phase 2): every 30 min, alert if a command has been in `received / routed / running` for more than 30 min. |

### 3.5 Categories

- Fixed list of 10–15 categories. Nothing may invent new ones.
- Layers, cheapest first: clean + tokenize (lowercase, strip units like `500G`, `1KG`, `ST`, expand abbreviations) → keyword dictionary → fuzzy match on confirmed items → LLM fallback limited to the list.
- A category in the email note overrides everything else.
- Store `category_source`: `note / dictionary / fuzzy / llm / manual`.

## 4. Interfaces (contracts)

Router → sub-workflow (task envelope):
```json
{ "case_id": "sha256(message_id)", "owner_id": "me", "route": "expenseAdd",
  "args": "#food @card", "note": "body_clean", "attachments": [],
  "thread_id": "...", "message_id": "..." }
```

Sub-workflow → router (result):
```json
{ "status": "done | needs_input | failed", "summary": "Saved: REWE · 2026-09-23 · €12.40",
  "files": [], "error": null }
```

sendReply input:
```json
{ "to": "...", "thread_id": "... or null", "subject": "...",
  "summary": "text", "html": "optional", "files": [], "case_id": "..." }
```

Rules: sub-workflows never send email; only the router replies, through `sendReply`.

## 5. Data model (Postgres, medallion)

Schema is written as migration files: `03_code/sql/001_init.sql`, ... Database `bot` in its own container (`bot-postgres`, port 5433).

| Layer | Schema | Content | Rule |
|---|---|---|---|
| Bronze | `bronze` | `gmail_message` (Phase 1); later `llm_extraction` | Raw, append-only, no transformation |
| Silver | `silver` | `command`, `attachment`, `receipt`, `receipt_line`, `error_log` | Parsed, validated, normalized; rebuildable from bronze |
| Gold | `gold` | `monthly_spend`, `category_vs_budget`, `store_summary` | Report-ready, used by expenseReport |
| Control | `ctl` | `route`, `route_alias`, `budget`, `config` | Configuration, not data |

### 5.1 Bronze: one table, one folder per email (built in P1.1)

```sql
CREATE TABLE bronze.gmail_message (
  gmail_id         text PRIMARY KEY,   -- Gmail API id
  thread_id        text,
  rfc_message_id   text,               -- header Message-ID
  label_ids        text[],
  received_at      timestamptz,        -- from internalDate (ms)
  message          jsonb NOT NULL,     -- full raw Gmail JSON (Simplify off)
  folder_path      text,               -- bronze/gmail/<threadId>_<id>/
  attachment_count int,
  n8n_execution_id text,
  ingested_at      timestamptz NOT NULL DEFAULT now()
);
```

- Insert with `ON CONFLICT (gmail_id) DO NOTHING`; if nothing was inserted, stop (duplicate poll).
- Attachments are not in the database: all of them are saved into `folder_path`, files prefixed with their index (`0_receipt1.jpg`) so equal names cannot overwrite each other.
- Ingest makes no pic / non-pic decision. Silver reads `message` and the folder and builds `silver.attachment` (one row per file, `mime_type`, `kind = image / other`). A photo starts the extraction process; other files are only stored.

### 5.2 Silver and control (created with the task that uses them)

| Table | Task | Notes |
|---|---|---|
| `ctl.route`, `ctl.route_alias`, `silver.command` | P1.3 | Columns as in the earlier draft: `route(route, workflow_id, enabled, needs_attachment, description)`, `route_alias(alias, route)`, `command(case_id = sha256(message_id), gmail_id, thread_id, owner_id, route, resolved_by, status, summary, ...)` with status check `received / routed / running / done / needs_input / failed` |
| `ctl.budget` | P1.6 | `(owner_id, category, monthly_limit, currency)` |
| `silver.error_log` | P1.5 | Columns to be specified |
| `silver.receipt`, `silver.receipt_line` | P1.7 | Columns to be specified |
| `silver.case_event`, `silver.llm_call` | P1.10 | Columns to be specified |
| `ctl.config` | P2.11 | One per database (dev/prod) |

Rules for every data row: `owner_id`, `case_id` and `currency` from day one. Google Sheets is only a read-only view.

## 6. Non-functional requirements

| Area | Requirement |
|---|---|
| Idempotency | A retried trigger never creates a second case (`case_id` + insert-on-conflict). |
| Security | Forwarded emails are untrusted input: the LLM only returns routes/fields and never triggers actions. Sender allow-list. No secrets in the repo (gitleaks in CI). |
| Observability | Every case and LLM call logged (`case_event`, `llm_call`), incl. tokens and cost. Phase 2: health view, `status` route, daily cost alert. |
| Reliability | PC-hosted is fine for me (emails wait in Gmail while the PC sleeps). Move to a small VPS before my sister depends on it. |
| Backups | Nightly `pg_dump` + n8n workflow export (Phase 2). |
| Environments | Phase 2: `n8n-dev` on port 5679, `bot_dev` DB, second automation Gmail, pinned n8n image; changes go dev → git → CI → `deploy.sh`, never edit prod directly. |
| Testing | Phase 2: pytest, `node --test`, JSON Schema contract tests, migrations on empty Postgres; GitHub Actions with ruff, pytest, eval regression, drift check, gitleaks. |
| Privacy | Future mood data: separate private DB, no external LLM. Sister's data: PDPA, EU-region LLM with a DPA. |

## 7. Definition of done (Phase 1)

- **Router:** an email to `bot+expense@` from the phone gets a reply within 2 minutes; unknown commands get the help list.
- **expenseAdd:** 10 real receipts saved; totals correct on at least 9.
- **expenseReport:** `bot+report@` returns this month's totals by category vs budget; the scheduled run arrives on the 1st.
- **Eval:** first accuracy number from `evaluate.py` v0.
- **OAuth:** app in production mode.

## 8. Timeline

Capacity: 2 h/day, Mon–Sat (12 h/week). Plan uses high estimates + 2 buffer days per phase.

| Phase | Dates | Hours | Milestones |
|---|---|---|---|
| 1 Core loop | Oct 1–16 | 24 + 4 buffer | Reply < 2 min (Oct 6), OAuth prod (Oct 7), first receipt (Oct 10), report (Oct 13), first accuracy (Oct 14), **ship Oct 16** |
| 2 Make it robust | Oct 17 – Nov 2 | 24 + 4 buffer | Dev → prod (Oct 19), CI green (Oct 22), all failure cases handled (Oct 30) |
| 3 Evaluate + improve | Nov 3–18 | 23 + 4 buffer | Accuracy on 30 receipts (Nov 6), prompt v1 vs v2 + cost/receipt (Nov 7), **done Nov 18** |

If behind: cut Phase 3 first (P3.5 image handling, P3.4 matching 4–6). Protect P3.1–P3.3.

## 9. Future requirements (design now, build later)

**Mood tracking:** scheduled evening prompt email, reply in thread (needs pending-case state), separate private DB, no external LLM, delete the email after saving.

**Sister's invoices:** `owner_id` everywhere, routes and storage per owner; Thai + English invoices, 7% VAT, 13-digit tax ID, Buddhist-era dates (2569 = 2026), THB; vision LLM instead of Tesseract; reliable hosting; maybe a LINE adapter.

## 10. Open items

- [ ] Corporate build (Nov 3 – Dec 7) clashes with Phase 3: move or drop.
- [ ] Revolut CSV import: needed for full spending control; doesn't block Phase 1.
- [ ] Baseline model comparison (~2 h, Phase 3)?
- [ ] Phase retros + incident postmortems + runbook?
- [ ] Define the fixed category list (10–15) and the budget values.
- [ ] Specify columns for `silver.receipt`, `silver.receipt_line`, `silver.error_log`, `silver.case_event`, `silver.llm_call`, `ctl.config`.
- [ ] Decide how the router is triggered from bronze (poll `bronze.gmail_message` vs. Execute Workflow from ingestGmail).
- [ ] Optional: `bronze.llm_extraction` (raw model JSON + tokens).
- [ ] Repo to GitHub (`C:\dev\photo-to-sheets`) before Oct 20.
- [ ] Update README.md and PROJECT_CHECKLIST.md (Telegram → Gmail, Sheets → Postgres, route names, phases).
