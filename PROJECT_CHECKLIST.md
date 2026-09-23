# Photo-to-Sheets: Project Checklist (0 → 100%)

Track progress by ticking boxes: change `- [ ]` to `- [x]`.
Percentages show roughly where the project stands when each stage is done.

---

## 0–10% · Setup

- [ ] Decide where the project lives: local folder + GitHub (recommended), or Google Drive only
- [ ] Run `setup-project.ps1` to create the folder structure
- [ ] Create a GitHub repo and make the first commit (structure + `.gitignore`)
- [ ] Choose n8n hosting: n8n Cloud trial or self-hosted with Docker
- [ ] Create a Telegram bot with BotFather and save the token
- [ ] Get an LLM API key (OpenAI, Anthropic, or Gemini) and set a spending limit
- [ ] Create the Google Sheet with 4 tabs: `data`, `review`, `run_log`, `error_log`
- [ ] Create the Google Drive folder for uploaded photos
- [ ] Connect Telegram, Google, and LLM credentials in n8n

## 10–25% · Before development (requirements and planning)

- [ ] Decide the photo type (e.g. receipts)
- [ ] Define the fields to extract and write `docs/01-before/requirements.md`
- [ ] Define success metrics (e.g. ≥90% field accuracy, ≤20% review rate)
- [ ] Collect 20–50 sample photos, including difficult ones
- [ ] Fill in `data/ground_truth.csv` with the correct values
- [ ] Test 2–3 LLMs manually on 5–10 photos and write `docs/01-before/model-comparison.md`
- [ ] Write `docs/01-before/gdpr-notes.md`: what personal data exists, where the provider processes it, how long photos are kept
- [ ] Draw the context diagram and data flow diagram (`docs/diagrams/`)
- [ ] Write `docs/02-during/schema-spec.md`: sheet columns and JSON contracts between nodes

## 25–45% · MVP (make it work end to end)

- [ ] Write `prompts/extraction_v1.md` and `prompts/output_schema.json`
- [ ] Build: Telegram Trigger → get file → AI analyze image → Sheets append → Telegram reply
- [ ] Send one real photo and confirm a row appears in the sheet
- [ ] Export the workflow to `workflows/` and commit
- [ ] Log first decisions in `docs/02-during/decisions.md`

## 45–65% · Make it robust (data engineering layer)

- [ ] Write `code/normalize.py` with tests, then add it as a Code node
- [ ] Write `code/validate.py` with tests (required fields, types, price-sum check), then add it as a Code node
- [ ] Add IF: has photo? → reply "please send a photo"
- [ ] Add IF: valid? → route low-confidence results to the `review` tab
- [ ] Add dedupe lookup and IF: duplicate? → reply "already saved"
- [ ] Add Drive upload for raw photos
- [ ] Add run log entries for every execution
- [ ] Build the error workflow: Error Trigger → error log → Telegram alert
- [ ] Test each branch on purpose (send text, send a duplicate, send a blurry photo, break an API key)
- [ ] Export and commit after each working feature

## 65–80% · Measure and improve (data science + AI layer)

- [ ] Write `evaluation/evaluate.py` to compare LLM output with ground truth
- [ ] Run the full test set and save `evaluation/results/YYYY-MM-DD_prompt-v1.csv`
- [ ] Analyze errors: which fields fail, and on which photo types
- [ ] Improve the prompt → `prompts/extraction_v2.md`, re-run, compare
- [ ] Adjust confidence rules based on results
- [ ] Record cost per photo
- [ ] Write `evaluation/summary.md` with accuracy per version

## 80–90% · Real use (after development)

- [ ] Use it for real for 2–4 weeks
- [ ] Check the review tab weekly and note correction patterns
- [ ] Fix issues that only show up with real use
- [ ] Write `docs/03-after/runbook.md`: what to do when an alert arrives
- [ ] Update diagrams to the as-built version and export PNGs to `docs/diagrams/exports/`

## 90–100% · Portfolio finish

- [ ] Write `docs/03-after/lessons-learned.md`: what went wrong and how it was fixed
- [ ] Write the final `README.md`: problem, architecture diagram, how it works, results (accuracy, cost, review rate), lessons
- [ ] Add screenshots of the n8n workflow and a sample Telegram conversation
- [ ] Remove any personal data and secrets from the repo, and double-check the Git history
- [ ] Record a short demo video or GIF (optional but strong)
- [ ] Add the project to CV and LinkedIn with one result sentence, e.g. "Automated receipt capture with 93% field accuracy at €0.01 per photo"
- [ ] Prepare a 2-minute explanation for interviews

---

## Notes

**Realistic time:** about 3–5 weeks at a few hours per week, plus 2–4 weeks of real use (can run in parallel with writing docs).

**Three most important checkpoints** (protect these if time gets tight):
1. First photo becomes a sheet row (end of MVP)
2. First accuracy number (end of evaluation)
3. Finished README
