# Email bot (photo-to-sheets): design notes, 27 Sep 2026

Summary of the design session on 27 Sep 2026. Input for the final requirements doc.

## 1. Purpose (decided)

The project is for **real daily use**, not only for the portfolio.

| Use | Who | When |
|---|---|---|
| Expense logging and control | Me | Now (v1) |
| Daily mood tracking | Me | Later (not in 2026) |
| Invoice photos → tables for accounting | Sister's local business, Thailand | Next year |

Photo-to-sheets becomes the first sub-workflow behind **one general email router**.

## 2. Current scope (v1)

1. **Router workflow:** email trigger, classify the command, dispatch to the right flow
2. **expenseAdd workflow:** extract receipt info and prepare the data
3. **expenseReport workflow:** reporting (on request and monthly)

Plus two small supporting workflows:

4. **Error workflow:** catches failures in any workflow
5. **sendReply sub-workflow:** the only place that sends email

## 3. Shared contracts

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

Rules:
- Sub-workflows never send email. Only the router (via `sendReply`) replies.
- `case_id` is a hash of `message_id`, so a retried trigger never creates a second case.

## 4. Router workflow

1. Gmail Trigger (poll 1 min): `-label:processed -from:<bot address>` (the `-from` stops reply loops)
2. Code: compute `case_id`, read the plus-address from To (`bot+expense@` → expenseAdd), take the first subject word lowercased, clean the body (text/plain, strip signature and quoted reply)
3. Insert into `command` with `ON CONFLICT (message_id) DO NOTHING`. No new row means the email was already handled, so stop.
4. Check the sender allow-list → owner
5. Resolve the route: plus-address → subject keyword → alias lookup in the DB (LLM classifier later)
6. Update the command: `status = 'routed'`, `resolved_by`
7. Execute Workflow with the `workflow_id` from the DB (an expression, no Switch node)
8. Call `sendReply` with the result, add the `processed` label, update `status`, `finished_at` and `summary`

Unknown command → reply with the help list (`SELECT route, description FROM route WHERE enabled`).

### Command storage in the database (decided)

```sql
CREATE TABLE route (
  route        text PRIMARY KEY,          -- 'expenseAdd'
  workflow_id  text NOT NULL,             -- n8n sub-workflow id
  enabled      boolean DEFAULT true,
  needs_attachment boolean DEFAULT false,
  description  text                        -- used by the help reply
);

CREATE TABLE route_alias (
  alias  text PRIMARY KEY,                -- 'expense','exp','receipt','beleg','ใบเสร็จ'
  route  text REFERENCES route
);

CREATE TABLE command (
  case_id     text PRIMARY KEY,           -- sha256(message_id)
  message_id  text UNIQUE,
  thread_id   text,
  owner_id    text DEFAULT 'me',
  received_at timestamptz DEFAULT now(),
  raw_subject text,
  args        text,
  route       text REFERENCES route,
  resolved_by text,                       -- plus_address / keyword / alias / llm
  status      text,                       -- received → routed → running → done / needs_input / failed
  finished_at timestamptz,
  summary     text
);
```

- Adding a new command = insert into `route` + `route_alias`. The router workflow does not change.
- The `command` table also serves the watchdog (stuck cases) and process mining later (case id, activity, timestamp).
- Trade-off: with dynamic dispatch, the n8n canvas shows no arrows from the router to sub-workflows. Document the mapping in `route.description` and the README.

## 5. expenseAdd workflow

1. Execute Workflow Trigger (receives the envelope)
2. Split attachments into one item each; keep images and PDFs only
3. Dedupe check: `message_id + attachment_idx`
4. Vision LLM with an output schema: receipt header + every line item
5. Normalize (merchant, date, amounts, units) and validate (lines add up to the total, VAT 7%/19% reconciles, date is plausible); set `needs_review` on failure
6. Write `receipt` + `receipt_line` to **Postgres**, save the photo to Drive
7. Merge the items into one result (status + summary)

Keep normalize/validate in plain Python modules from the start.

### Categories (decided)
- A **fixed category list** (10–15). NLP maps raw text to it and never invents new categories.
- Layers, cheapest first: clean + tokenize (lowercase, strip units such as `500G`, `1KG`, `ST`, expand abbreviations) → keyword dictionary → fuzzy match on confirmed items → LLM fallback limited to the list
- A category in the email note overrides the LLM's
- Store `category_source` (note / dictionary / fuzzy / llm / manual)

## 6. expenseReport workflow

Two ways in, same steps:
- On request via the router: `bot+report@`, args `2026-09` / `last30` / empty = this month
- Schedule Trigger: 1st of the month at 08:00, for the previous month

Steps: work out the period → query Postgres → aggregate (total, by category, by store, vs last month, top items, count needing review, **spent vs budget**) → HTML table in the body + CSV attachment → return the result (on request) or call `sendReply` (on schedule).

Budget table (decided): `budget(category, monthly_limit)`.

## 7. Supporting workflows

**Error workflow**, set as the error workflow on every workflow including itself:
Error Trigger → insert into `error_log` → set command `status = failed` → Gmail label `failed` → alert me (email or push, e.g. ntfy) with workflow, node and case id.

**sendReply** input:
```json
{ "to": "...", "thread_id": "... or null", "subject": "...",
  "summary": "text", "html": "optional", "files": [], "case_id": "..." }
```
Replies in the thread if there is one, otherwise sends a new email; adds the case id and attachments. A later channel (LINE) changes only this workflow.

**Watchdog** (scheduled, every 30 min): alert if any command has been stuck in `received / routed / running` for more than 30 min.

## 8. Decisions summary

| # | Topic | Decision |
|---|---|---|
| 1 | Purpose | Daily real use first |
| 2 | Architecture | Central router + one sub-workflow per route (replaces "no central router yet") |
| 3 | Routing | Plus-addresses saved as phone contacts; subject keyword as fallback; commands and aliases stored in the DB |
| 4 | Storage | **Postgres from v1** (moved up from v2); Sheets only as a read-only view |
| 5 | Categories | Fixed list + tokenize/NLP layers + LLM fallback |
| 6 | Budgets | `budget` table so the report shows spent vs limit |
| 7 | Replies | Only via `sendReply` |
| 8 | Idempotency | `case_id = sha256(message_id)`, insert-on-conflict |
| 9 | Every row | Has `owner_id`, `case_id`, `currency` from day one |

## 9. Open items

- **Revolut CSV import:** needed for full spending control (receipts miss rent, subscriptions, online purchases). Still deciding; it doesn't block v1. Until then, label reports "receipts only".
- **Out of v1 (to save time):** product matching across stores (line items are still extracted), the LLM-written report text, the LLM classifier, image quality checks and deskewing. Can move any of these into v1 if wanted.
- **Corporate build** (35–45 h, Nov–Dec): does it still happen now that the focus is daily use?
- Update the spec: the route names (`expense` / `expreport` → `expenseAdd` / `expenseReport`) and "Sheets v1 → Postgres v2".

## 10. Running it for real

- Publish the Google OAuth app to production, or tokens expire every 7 days.
- PC-hosted is fine for me: emails wait in Gmail while the PC sleeps. Move to a small VPS before my sister depends on it.
- Nightly `pg_dump` + n8n workflow export.
- Forwarded emails are untrusted input: the LLM only returns routes/fields and never triggers actions.

## 11. Future-proofing (design now, build later)

**Mood tracking**
- Scheduled evening prompt email; I reply in the thread (needs pending-case state)
- Separate private DB; no external LLM by default; delete the email after saving

**Sister's invoices (Thailand)**
- `owner_id` everywhere; routes and storage per owner
- Invoices in both Thai and English; 7% VAT; 13-digit tax ID; Buddhist-era dates (2569 = 2026); THB
- PDPA; EU-region LLM with a data processing agreement
- Reliable hosting; maybe a LINE adapter instead of email
- Rely on the vision LLM, not Tesseract (weak on Thai)

## 12. Definition of done (v1)

- **Router:** email to `bot+expense@` from the phone gets a reply within 2 minutes; unknown commands get the help list.
- **expenseAdd:** 10 real receipts saved, totals correct on at least 9.
- **expenseReport:** `bot+report@` returns this month's totals by category vs budget; the scheduled run arrives on the 1st.

## 13. Build order and timing

1. Router + `help` (echo what it parsed): proves trigger, routing, replies
2. Error workflow + `sendReply`
3. expenseAdd
4. expenseReport, after ~2 weeks of real receipts

The v1 estimate was 8–12 h (Sep 28 – Oct 5). The router + Postgres add ~4–6 h, so expect Oct 8–10, or move expenseReport into the v2 window.
