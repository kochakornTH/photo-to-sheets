# Session notes, 6 Oct 2026: sendReply built, router replies to help cases

Session 13:16–15:10. Follows `2026-10-05_session-notes.md`. Where they disagree, this file wins.

## Decisions made

| # | Decision | Reason |
|---|---|---|
| 1 | **`gmail_id` is added to the sendReply input** (`case_id`, `gmail_id`, `thread_id`, `to`, `subject`, `summary`, `html`, `files`). `thread_id` stays in the contract but is not used for sending | The Gmail node's Reply operation needs the message id, not the thread id; the reply then lands in that message's thread |
| 2 | **sendReply layout**: trigger with 8 defined fields → If `Has message to reply to` (`gmail_id` not empty) → `Reply to a message` / `Send a message` → `Result` (`case_id`, `gmail_id`, `reply_id`) | Reply in the thread when there is an original email, new email otherwise (S2); the caller gets one clean item back |
| 3 | **Replies are always HTML**: `html` if given, otherwise `summary` with line breaks turned into `<br>`, plus a small line `Case <first 12 characters of case_id>` | One Message expression covers text and HTML replies; the short case id is enough to find the case |
| 4 | **Both Gmail nodes**: Append n8n Attribution off, Reply to Sender Only on | No advert line; the bot does not mail its own plus-address |
| 5 | **Router chain for help cases**: `Build help text` (now also returns `gmail_id`) → `Call sendReply` (Execute Sub-workflow, once per item, waits) → `Mark done` → `Label processed` | Follows R9 |
| 6 | **Order is reply → mark done → label** | If the reply fails, the case stays `routed` and is not picked up again, so no reply is sent twice |
| 7 | **Help cases get `summary = 'help list sent'`** in `silver.command` | R9 asks for a summary; the help text itself is not worth storing per case |
| 8 | **Publish before testing a router change with a real email** | The published version runs every minute and takes the new email before a manual run can |
| 9 | **Test data is pinned on the sendReply trigger** (mock data, `gmail_id` `1a101ee7323bc4ef`, no address) | Lets sendReply run alone; pinned data is ignored when the router calls it |

## Changes to scope and timeline

- **P1.4 sendReply is built and published, but not finished**: see the first open item (Message ID is fixed to one old email). P1.3 stays open until that is fixed and re-tested.
- **Attachments in sendReply were not built today.** `files` is in the input but unused. Proposal, not yet confirmed: build the attachment branch with expenseReport (Oct 13), the first workflow that produces a file. The calendar still lists attachments under Oct 6.
- **P1.5 Error workflow has not started**; it is still planned for today.
- First live help reply: sent at 15:05 with the real case id `a7902e216e74`. The time from phone to reply was not measured, so the milestone "reply in under 2 minutes" is not confirmed.

## Open items and next steps

- [ ] **Bug: `Reply to a message` in sendReply has Message ID fixed to `1a101ee7323bc4ef`** (typed in while fixing the "Bad request" error). Every reply goes into the Oct 3 thread "Dm" instead of the thread of the new email; that is where the 15:05 help reply landed. Fix: set Message ID to the expression `{{ $json.gmail_id }}`, execute with the pinned data, publish, send a new `+help` email, check the reply is in the new thread, then download and commit `sendReply.json`.
- [ ] **Not confirmed after the live test**: the case row is `done` with `finished_at` and `summary = 'help list sent'`, and the email has the label `processed`. Check with `SELECT case_id, route, status, summary, created_at, finished_at FROM silver.command ORDER BY created_at DESC LIMIT 3;`
- [ ] Remove the leading spaces before the expression in three places: Message in both Gmail nodes of sendReply, and Query Parameters in `Mark done` (`=   {{ … }}`). Cosmetic in the emails; in `Mark done` it should be removed so the parameters are passed as a clean array.
- [ ] The case line uses `$json.case_id.slice(0, 12)`, which fails when `case_id` is empty (for example the scheduled monthly report). Use `($json.case_id ? '<br><br><small>Case ' + $json.case_id.slice(0, 12) + '</small>' : '')` before the first case-less email.
- [ ] **P1.5 Error workflow**: decide the columns of `silver.error_log` (migration `005_error_log.sql`) and the alert channel (email through the bot account, or ntfy); build `errorHandler` (Error Trigger → `error_log` → `status = failed` → label `failed` → alert); set it on `ingestGmail`, `router`, `sendReply` and itself; test with a broken node.
- [ ] Measure the reply time once from the phone (target: under 2 minutes).
- [ ] The `rejected` and `Fallback` outputs of `dispatch` are still empty: unknown senders get no reply (decision of Oct 5); `expenseAdd` / `expenseReport` cases stay `routed` without a reply until Oct 8.
- [ ] Commit `01_docs/2026-10-05_session-notes.md` (untracked) and this file.
- [ ] `requirements.md` v3: add `gmail_id` to the sendReply input and the router chain of decision 5 (joins the v3 list of Oct 5).
- [ ] Build calendar: tick the Oct 6 steps once the bug is fixed; decide where the attachment step goes.
- [ ] Docker Desktop was not running at the start of the session, so n8n and Postgres were down and no email was polled. Decide whether Docker Desktop should start with Windows.
- [ ] `/pts` could not read git state today: the shell on the PC did not mount the Drive folder. Files were read and written through file staging instead.
- [ ] All Oct 5 open items not listed here are unchanged (next: Oct 7 OAuth app to production and observability tables; Oct 8 Execute Workflow from `ctl.route`).

## Files created or changed

- Created `02_workflows/sendReply.json` (n8n export, includes the pinned test data; no address in it)
- Changed `02_workflows/router.json` (`Build help text` renamed and extended, new nodes `Call sendReply`, `Mark done`, `Label processed`)
- n8n: new workflow `sendReply` (published); `router` republished; `ingestGmail` unchanged
- Git: `609c8af` "feat: add sendReply and reply to help cases", pushed to `origin/main`
- Created `01_docs/2026-10-06_session-notes.md` (this file)
