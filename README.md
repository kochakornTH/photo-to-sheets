# Photo-to-Sheets: Project Structure

An n8n workflow that receives photos (e.g. receipts) via Telegram, extracts structured data with a vision LLM, validates it with Python, and writes it to Google Sheets.

This document describes how the project repository is organized and the conventions used to manage it.

---

## Folder structure

```
photo-to-sheets/
├── README.md                      # Portfolio page: problem, architecture, results, lessons
├── .gitignore                     # Excludes data/raw, .env, secrets
├── .env.example                   # Variable names only, no real keys
├── docker-compose.yml             # Self-hosted n8n setup (if not using n8n cloud)
│
├── docs/
│   ├── 01-before/
│   │   ├── requirements.md        # Photo type, fields, success metrics
│   │   ├── model-comparison.md    # LLMs tested, accuracy, cost
│   │   └── gdpr-notes.md          # Personal data, provider location, retention
│   ├── 02-during/
│   │   ├── schema-spec.md         # Sheet tabs + JSON contracts between nodes
│   │   └── decisions.md           # Decision log: what you chose and why
│   ├── 03-after/
│   │   ├── runbook.md             # What to do when the error workflow fires
│   │   └── lessons-learned.md
│   └── diagrams/
│       ├── context.mmd            # Mermaid source (diagrams as code)
│       ├── data-flow.mmd
│       ├── workflow.mmd
│       ├── deployment.mmd
│       └── exports/               # PNG/SVG versions for README
│
├── workflows/                     # n8n JSON exports, versioned in Git
│   ├── main-photo-to-sheets.json
│   └── error-handler.json
│
├── code/                          # Python used in n8n Code nodes
│   ├── normalize.py
│   ├── validate.py
│   └── tests/                     # Test the logic locally before pasting into n8n
│       ├── test_normalize.py
│       └── test_validate.py
│
├── prompts/
│   ├── extraction_v1.md           # Keep every version, never overwrite
│   ├── extraction_v2.md
│   └── output_schema.json         # JSON schema the LLM must return
│
├── data/
│   ├── raw/                       # Sample photos (gitignored: may contain personal data)
│   ├── ground_truth.csv           # Correct answers per photo
│   └── README.md                  # How the test set was collected
│
└── evaluation/
    ├── evaluate.py                # Compares LLM output with ground truth
    ├── results/
    │   ├── 2026-10-01_prompt-v1.csv
    │   └── 2026-10-08_prompt-v2.csv
    └── summary.md                 # Accuracy per version, error types
```

---

## Folder guide

| Folder | Purpose | Main role | Phase |
|---|---|---|---|
| `docs/01-before/` | Requirements, model choice, GDPR review | DS, AI, DE | Before |
| `docs/02-during/` | Schema spec and decision log | DE | During |
| `docs/03-after/` | Runbook and lessons learned | DE | After |
| `docs/diagrams/` | Architecture and flow diagrams as Mermaid code | DE | All |
| `workflows/` | Exported n8n workflows (JSON) | DE | During |
| `code/` | Python logic for n8n Code nodes, with tests | DE | During |
| `prompts/` | Versioned LLM prompts and output schema | AI | During |
| `data/` | Test photos and ground truth answers | DS | Before |
| `evaluation/` | Accuracy measurement per prompt version | DS | During / After |

---

## Conventions

### 1. Secrets never go into Git
- API keys and tokens live in the n8n credential store and in `.env`.
- `.env` is gitignored. Only `.env.example` (variable names, no values) is committed.

### 2. Personal data never goes into Git
- Real receipt photos can contain card digits, names, or loyalty IDs.
- `data/raw/` is gitignored and kept locally or in a private Drive folder.
- `ground_truth.csv` contains anonymized values only.

### 3. Python is written in files first
- Develop `normalize.py` and `validate.py` locally with tests.
- Paste the tested code into the n8n Code nodes afterwards.
- The repo stays the source of truth; the n8n UI is the runtime.

### 4. Prompts are versioned, never overwritten
- Each change creates a new file: `extraction_v1.md`, `extraction_v2.md`, ...
- Every evaluation result references the prompt version it tested.

### 5. Evaluation results are named by date and version
- Format: `YYYY-MM-DD_prompt-vN.csv`
- `summary.md` tracks progress, e.g. "prompt v2 improved total accuracy from 84% to 93%."

### 6. Workflows are exported at each milestone
- Export from n8n after each working change and commit.
- Commit message style: `feat: add dedupe branch`, `fix: handle missing total`, `docs: update data flow diagram`.

### 7. Decisions are logged as they happen
Format for `docs/02-during/decisions.md`:

```
## 2026-10-01 — Telegram as first input channel
Decision: Use Telegram instead of WhatsApp for the MVP.
Reason: Free bot API, native n8n trigger, no business account needed.
```

---

## Suggested .gitignore

```
# Secrets
.env

# Personal data
data/raw/

# Local n8n data (if self-hosted)
.n8n/

# Python
__pycache__/
*.pyc
.venv/
.pytest_cache/

# OS
.DS_Store
Thumbs.db
```

---

## Suggested .env.example

```
TELEGRAM_BOT_TOKEN=
LLM_API_KEY=
GOOGLE_SHEET_ID=
GOOGLE_DRIVE_FOLDER_ID=
ADMIN_TELEGRAM_CHAT_ID=
```

---

## Build order

Start small and add folders as each phase needs them.

| Step | What to create | Phase |
|---|---|---|
| 1 | `README.md`, `.gitignore`, `docs/01-before/requirements.md` | Before |
| 2 | `data/raw/`, `data/ground_truth.csv` (20–50 sample photos) | Before |
| 3 | `docs/01-before/model-comparison.md`, `gdpr-notes.md` | Before |
| 4 | `docs/diagrams/context.mmd`, `data-flow.mmd` | Before |
| 5 | `prompts/extraction_v1.md`, `output_schema.json` | During |
| 6 | MVP workflow → `workflows/main-photo-to-sheets.json` | During |
| 7 | `code/normalize.py`, `code/validate.py` with tests | During |
| 8 | `evaluation/evaluate.py`, first results file | During |
| 9 | Error workflow, `docs/03-after/runbook.md` | During / After |
| 10 | Final `README.md` with diagram, accuracy result, lessons | After |
