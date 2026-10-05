# Session notes, 3 Oct 2026: P1.1 finished, n8n moved into compose

## Decisions made

| # | Decision | Reason |
|---|---|---|
| 1 | **n8n runs from the project's `docker-compose.yml`** (service `n8n`, existing volume `n8n_data` as external, port 5678, timezone Europe/Berlin) | It had been started by hand with `docker run`, so there was no file to add a mount to; now the setup is written down and reproducible |
| 2 | **Attachments are saved to a local folder**: `./05_data/bronze` mounted at `/home/node/.n8n-files/bronze` | Simplest path that works today. This differs from the Oct 1 plan (upload to Google Drive); see open items |
| 3 | **One Code node `Save attachments`** (JavaScript, Run Once for All Items) on a second branch from the Gmail Trigger creates the folder and writes the files; needs `NODE_FUNCTION_ALLOW_BUILTIN=fs` | `Prepare` returns `json` only, so the files must be read from the trigger; the write-to-disk node cannot create a missing folder |
| 4 | **JavaScript for n8n glue nodes, Python for the logic modules** (`normalize.py`, `validate.py`, `evaluate.py`) | The Python Code node needs a separate runner and has no helper for attachment data |
| 5 | `05_data/bronze/` is in `.gitignore` | Real receipts must never reach the repo |
| 6 | **Replan after the sick day (Oct 2)**: Oct 3 = P1.1 rest + Gmail labels; Sun Oct 4 = wrap-up, plus-addresses, Router 1/2, P1.6 | Clear the week by Sunday without spending buffer days |

## Changes to scope and timeline

- P1.1 done-when is met: emails land in `bronze.gmail_message` and their attachments in `05_data/bronze/gmail/<threadId>_<id>/`. Tested with 2 photos in one email, 1 PDF, a reply in a thread, an email without attachments, and a re-run (no duplicate row).
- Sunday Oct 4 is a one-off working day (about 3.5 h). Oct 5 onward and both buffer days are unchanged. If Sunday runs long, P1.6 can wait; it is not needed before Oct 10.
- P1.2 is half done: labels `processed` and `failed` exist; plus-addresses are open.

## Open items and next steps

- [ ] Publish (activate) the `ingestGmail` workflow.
- [ ] Delete the stray file `03_code/sql/001_init.sqlssdfasdl`; commit `docker-compose.yml`, `.env.example`, `.gitignore`, `03_code/sql/001_init.sql`; `git push` (main is 2 commits ahead of origin).
- [ ] Remove the old container: `docker rm n8n-old`.
- [ ] Plus-address contacts (`+expense`, `+report`, `+help`) and one test email to each; check `message->'headers'->>'to'` holds the plus-address.
- [ ] **Decide: local folder or Google Drive for bronze attachments**, before Oct 8 (P1.7 reads them). The Oct 8 and Oct 10 calendar steps still say Drive.
- [ ] P2.9: add the case "email with a Drive link but no file". Gmail turns attachments over 25 MB into Drive links, so the email arrives with `attachment_count` 0.
- [ ] The 13:22 test email (`1a101ee7323bc4ef`, 1 attachment) has a row but no folder; it was ingested before `Save attachments` existed. Test data only.
- [ ] `POSTGRES_PASSWORD` is still `change_me`; set a real one before anything else can reach the database.
- [ ] The old `docker run` flags of n8n are unknown; anything beyond timezone and port was not carried over.
- [ ] `01_docs` exists twice (Google Drive and the local repo) and the two had drifted apart. Pick one as the source; the `/pts` skill currently reads the Drive copy.

## Files created or changed

- Changed `docker-compose.yml` (service `n8n`, external volume `n8n_data`) and `.gitignore` in the local repo `C:\Users\thkoc\Documents\Projects\photo-to-sheets`
- n8n workflow `ingestGmail`: new node `Save attachments`
- Updated `01_docs/2026-09-27_build-calendar.html` (Oct 2–4 rows and steps, per-day hours, two notes under the rules); the same version now also sits in the Drive copy
- Created `01_docs/2026-10-03_session-notes.md` (this file), in both copies
