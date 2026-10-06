# Session notes, 5 Oct 2026: Sunday backlog + Router 2/2, repo moved to Drive, pipeline live

Session 14:28–16:10. Follows `2026-10-03_session-notes.md`. Where they disagree, this file wins.

## Decisions made

| # | Decision | Reason |
|---|---|---|
| 1 | **Working copy moved to `G:\My Drive\Project\n8n\photo-to-sheets`**; remote stays on GitHub. The copy in `Documents\Projects` is deleted; the earlier Drive copy is kept as `photo-to-sheets_old` | One location for docs and code. Replaces the rule "repo outside Google Drive"; CI only needs the GitHub remote |
| 2 | **Bronze attachments are saved on `C:`**, outside the repo: `BRONZE_DIR` in `.env` → `C:\Users\thkoc\Documents\Projects\photo-to-sheets-data\bronze`; compose mounts `${BRONZE_DIR:-./05_data/bronze}` | Docker cannot write into the Google Drive disk (`EACCES … mkdir` in `Save attachments`). Answers the Oct 3 question for now: local folder, not Drive |
| 3 | **`case_id = sha256(gmail_id)`** as hex, not the `Message-ID` header | `gmail_id` is the bronze primary key and always present |
| 4 | **The router starts itself**: Schedule Trigger every minute, reads bronze rows that have no case. `ingestGmail` does not call it | The router's only other trigger is a manual test trigger, so n8n could not publish it or offer it as a sub-workflow. Closes the open item "poll bronze vs Execute Workflow" |
| 5 | **The router logic is one SQL script** in the node `Resolve route`, written with temp tables (no `WITH`): create cases → allow-list → resolve route → update `silver.command` | One place to read and test; temp tables are the preferred style |
| 6 | **Route resolution**: plus-address word → first subject word (after removing `Re:`, `Fwd:`, `AW:`, `WG:`), each matched against route names and aliases; no match → route `help`. `resolved_by` = `plus_address` / `subject` / `fallback` | Follows R5; an unknown command gets the help list (R8) |
| 7 | **Unknown sender** → status `failed`, summary `sender not on the allow-list`, no route, no reply | The status list has no `rejected` value |
| 8 | **Allow-list table `ctl.owner_address (address, owner_id)`**; the address row is inserted by hand | Real addresses stay out of the migration files |
| 9 | **Categories: 6 + `OTHER`** (`MEAT`, `JUNKFOOD`, `VEGGY AND FRUIT`, `SOAP AND SHAMPOO`, `MEDICAMENTER`, `LAUNDRY`, `OTHER`) in `ctl.category`; 52 starter keywords in `ctl.category_keyword`, lowercase ASCII (ä→ae, ö→oe, ü→ue, ß→ss) | Own list instead of 10–15; `OTHER` catches every line that fits nothing; ASCII survives the PowerShell pipe |
| 10 | **One overall budget**: 1000 EUR a month (`owner_id = me`, `category = ALL`) in `ctl.budget` | One limit for everything, not a limit per category |
| 11 | **Filter node after `Resolve route`** (`case_id` exists, type String) | When the script changes no rows, n8n outputs one placeholder item `success: true`; the Filter stops it |
| 12 | **The build calendar is no longer tracked in git** (`.gitignore`) | Personal planning file; older versions remain in the git history |

## Changes to scope and timeline

- **Back on schedule.** Sunday's backlog (P1.1 wrap-up, Router 1/2, P1.6) and Monday's Router 2/2 were done in this one session. Buffer days are untouched.
- **P1.2 and P1.6 are done.** P1.6 scope changed: 6 + `OTHER` categories instead of 10–15; one overall budget instead of one per category, so the report can show total vs budget but not budget per category.
- **P1.3 stays open** until a reply is actually sent: sendReply is Oct 6; Execute Workflow with `workflow_id` from `ctl.route` moved to Oct 8 (needs `expenseAdd`). The Switch's `Fallback` output is the placeholder.
- **The pipeline runs by itself**: test email with a photo to `+expense` at 15:56 → bronze row and attachment folder → case created and routed to `expenseAdd` at 15:58. Database: 9 emails, 9 cases.
- **Reply time**: Gmail poll (1 min) + router schedule (1 min) → about 1 minute on average, up to about 2 minutes. This is at the limit of the Oct 6 milestone. A direct call can be added later; then only one start path may stay active, otherwise two runs can take the same email.
- Changes to `router` go live only after **Publish**; the schedule runs the published version.

## Open items and next steps

- [ ] **Oct 6, sendReply**: attach to the output of the help query (`case_id`, `thread_id`, `summary`); after the reply set `status = done`, `finished_at`, label `processed` (R9). Then the error workflow.
- [ ] To re-test old cases: `update silver.command set status='received', route=null, owner_id=null, resolved_by=null`.
- [ ] **Oct 7**: OAuth app to production (test tokens expire around Oct 9); observability tables.
- [ ] **Oct 8**: Execute Workflow from `ctl.route`; fill `ctl.route.workflow_id` for `expenseAdd`.
- [ ] expenseAdd clean step must lowercase and fold umlauts the same way as the keyword dictionary.
- [ ] Category names are keys in the data (`MEDICAMENTER`, `VEGGY AND FRUIT`): rename before the first receipt is saved, if wanted.
- [ ] **Bronze row size**: a photo sent inline is also stored as base64 inside `message->'html'` (about 3 MB per photo). Decide whether ingest should strip it. Never `select message` on whole rows.
- [ ] The Gmail Trigger in `ingestGmail` filters on one sender address, so other senders never reach bronze. A second owner (sister) needs this filter changed as well as a row in `ctl.owner_address`.
- [ ] `02_workflows/ingestGmail.json` contains that sender address (committed on purpose). Check that the GitHub repo is private, or replace the address.
- [ ] The Postgres password was shown in a Claude chat on Oct 5; change it before sharing that conversation. The Oct 3 item "password is still `change_me`" is closed: `.env` has a real one.
- [ ] Oct 10 calendar step "move the original photo to the expense folder in Drive": Docker cannot write to `G:`; decide how (or keep it on `C:`).
- [ ] Update `requirements.md` to v3: `gmail_id` in R2/R3, router trigger (schedule), categories, budget, attachment location, `ctl.owner_address`, `ctl.category`, `ctl.category_keyword`; close the matching open items in section 10.
- [ ] README.md and PROJECT_CHECKLIST.md still describe Telegram + Sheets (P1.9).
- [ ] Clean-up: delete the archived n8n workflow "My Sub-Workflow 1"; delete the unused `05_data\bronze` inside the Drive folder; delete `photo-to-sheets_old` after a few days; set `router` to not save successful production executions; rename the router's test trigger (it is a manual trigger named "When Executed by Another Workflow"); optionally bind n8n to `127.0.0.1:5678`.
- [ ] Git inside Google Drive: watch for lock files and files that change back after a sync; push often. Add `.gitattributes` (LF) when the shell scripts arrive in Phase 2.
- [ ] `/pts` reads this Drive folder, which is now also the repo: the Oct 3 item "01_docs exists twice" is closed.

## Files created or changed

- Created `03_code/sql/002_router.sql` (`ctl.route`, `ctl.route_alias`, `silver.command` + seed), `003_categories.sql` (`ctl.category`, `ctl.category_keyword`, `ctl.budget` + seed), `004_owner_address.sql` (`ctl.owner_address`, no seed)
- Created `02_workflows/router.json` and `02_workflows/ingestGmail.json` (n8n exports)
- Changed `docker-compose.yml` (attachments mount from `BRONZE_DIR`), `.env.example` (`BRONZE_DIR`), `.env` (`BRONZE_DIR`, not committed), `.gitignore` (build calendar)
- n8n: new workflow `router` (published): Schedule Trigger → `Resolve route` → Filter → Switch `dispatch` (`rejected` / `help` / `Fallback`) → help query. `ingestGmail` republished, logic unchanged
- Updated `01_docs/2026-09-27_build-calendar.html` (Oct 4 and Oct 5 steps, P1.6 done, notes); not tracked in git any more
- Git: `02ee7f2` compose + Oct 3 notes, `4d3f763` migration 002, `5492d00` migration 003, `279ccbc` router export, `e5e76ec` ingestGmail export, plus the commits for migration 004, the compose change and the calendar; `git status` clean at 16:07
- Created `01_docs/2026-10-05_session-notes.md` (this file)
