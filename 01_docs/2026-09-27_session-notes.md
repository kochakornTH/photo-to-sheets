# Session notes, 27 Sep 2026 (evening): build plan

Follows `2026-09-27_email-bot-requirements-notes.md`. Calendar: `2026-09-27_build-calendar.html`.

## Decisions made

| # | Decision | Reason |
|---|---|---|
| 1 | Build starts **Oct 1** (not Sep 28) | Actual start date |
| 2 | Versions renamed to **Phase 1 / 2 / 3** (Core loop / Make it robust / Evaluate + improve) | Clearer than v1/v2/v3 |
| 3 | Dev capacity: **2 h a day, Mon–Sat (12 h/week), Sunday off** | Rest of the day goes to German speaking practice |
| 4 | Plan uses the **high estimate** per task + **2 buffer days per phase** | Buffer is for surprises, not for new tasks |
| 5 | **Observability in Phase 1** (P1.10): `case_event` + `llm_call` tables | Log every case and LLM call from day one; also the process-mining log and cost tracking |
| 6 | **Mini eval in Phase 1** (P1.11): the 10 test receipts become `ground_truth.csv` + `evaluate.py` v0 | Eval set first, as senior AI projects do; first accuracy number before shipping |
| 7 | **OAuth to production moved to Phase 1** (P1.12, Oct 7) | In Testing mode tokens expire after 7 days, so the bot would stop around Oct 9 |
| 8 | Schema written as **SQL migration files** (`03_code/sql/001_init.sql`…) | Needed for DB tests in CI and for deploy.sh |
| 9 | Call the LLM with an **HTTP Request node** | The raw API response includes token usage |
| 10 | **Tests + CI extended** (P2.1, 3 → 5 h): unit (pytest, `node --test`), contract (JSON Schema), DB (migrations on empty Postgres); GitHub Actions: ruff, pytest, Postgres, eval regression, drift check, gitleaks | Closes the Testing + CI gap |
| 11 | **Health view + `status` route + daily cost alert** (P2.10) | Observability you can query by email |
| 12 | **Dev/prod separation** (P2.11–P2.12): `n8n-dev` on port 5679 via compose profile, `bot_dev` DB, second automation Gmail, credentials with shared IDs, `config` table per DB, pinned n8n image; `export.sh` / `deploy.sh` (pg_dump → migrations → import) | Never edit prod directly: dev → git → CI → scripted deploy, with rollback |
| 13 | Daily German practice after each dev block (~20 min): (1) report to manager: done / blocker / solution; (2) discuss the problem with a colleague (roleplay with "Max") | Project gives daily speaking content; trains verb-final and Konjunktiv II |

## Changes to scope and timeline

| Phase | Dates | Work + buffer | Milestones |
|---|---|---|---|
| 1 Core loop | Oct 1–16 | 24 h + 4 h | Reply < 2 min (Oct 6), first receipt (Oct 10), report (Oct 13), first accuracy number (Oct 14), **SHIP Oct 16** |
| 2 Make it robust | Oct 17 – Nov 2 | 24 h + 4 h | Dev → prod works (Oct 19), CI green (Oct 22), all failure cases handled (Oct 30) |
| 3 Evaluate + improve | Nov 3–18 | 23 h + 4 h | Accuracy on 30 receipts (Nov 6), prompt v1 vs v2 + cost/receipt (Nov 7), **done Nov 18** |

- Total: 42 working days, 71 h work + 12 h buffer ≈ 84 h. Previously: v1 Sep 28 – Oct 5 (8–12 h), whole thing ~Nov 2.
- First scheduled monthly report: Sun Nov 1, 08:00.
- Plan page "auto1 ships end of Sep" is out of date → Oct 16.
- If behind: cut Phase 3 first (P3.5 image handling, P3.4 matching 4–6). Protect P3.1–P3.3.
- Not included: corporate build (35–45 h), portfolio README (8–10 h), forecast model, moodLog, sister's invoices, Revolut import.

## Open items and next steps

- [ ] **Corporate build** (plan page: Nov 3 – Dec 7) now starts on the first day of Phase 3: move or drop it.
- [ ] Decide: **baseline model comparison** (~2 h, Phase 3), a cheaper model on the same 30 receipts.
- [ ] Decide: **phase retros** (30 min on the last buffer day of each phase) + **incident postmortems** (`01_docs/postmortems/_template.md`, 5 lines per alert) + runbook in Phase 2.
- [ ] Before Oct 20: repo on GitHub, out of Google Drive (`C:\dev\photo-to-sheets`); confirm first push. CI depends on it.
- [ ] Update README.md and PROJECT_CHECKLIST.md: Telegram → Gmail, Sheets → Postgres, new route names, phases (P1.9).
- [ ] Update the plan page: versions/timeline table, auto1 ship date, route names.
- [ ] Check once in P2.11: `n8n import:workflow` keeps workflow IDs; imported workflows pick up credentials by shared ID.
- [ ] Next step: **Oct 1, P1.1 Postgres setup + migrations.**

## Task list (IDs used in the calendar)

Phase 1: P1.1 Postgres + migrations (2) · P1.2 Gmail prep (1) · P1.3 Router + help (4) · P1.4 sendReply (1) · P1.5 Error workflow (1) · P1.6 Categories + budget (1) · P1.7 expenseAdd (6) · P1.8 expenseReport (3) · P1.9 Docs + commit (1) · P1.10 Observability (1.5) · P1.11 Mini eval (2) · P1.12 OAuth to production (0.5)

Phase 2: P2.11 Dev environment (1.5) · P2.12 Deploy scripts (1) · P2.1 Tests + CI (5) · P2.2 Product matching 1–3 (5) · P2.3 EXIF rotation (2) · P2.4 Pin model (0.5) · P2.5 Pending-case state (3) · P2.6 Watchdog (1) · P2.7 Backups (1) · P2.9 Branch tests (2) · P2.10 Health + cost (1.5)

Phase 3: P3.1 Grow eval set to 30 (3) · P3.2 evaluate.py + CI gate (3) · P3.3 Prompt v2 (3) · P3.4 Matching 4–6 (5) · P3.5 Image handling (4) · P3.6 Dedupe levels 2–3 (2) · P3.7 Drift (1) · P3.8 Storage + retention (2)

## Files created or changed

- Created `01_docs/2026-09-27_session-notes.md` (this file)
- Created `01_docs/2026-09-27_build-calendar.html` (Oct–Nov calendar with tasks per day + task reference)
