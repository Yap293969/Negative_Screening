# Final Architecture

Production-oriented prototype architecture for the Negative Screening System. Source access: `SOURCE_ACCESS_BLUEPRINT.md`. Processing rules: `DATA_COLLECTION_ANALYSIS.md`. Running and scheduling: `OPERATIONS_GUIDE.md`.

---

## 1. Overview

```text
                     USER / SCHEDULER
                           │
            ┌──────────────┴──────────────┐
            ▼                             ▼
   Automatic (Monday)              Manual (any day)
   Windows Task Scheduler          python negative_screening.py
   python negative_screening.py --scheduled
            │                             │
            └──────────────┬──────────────┘
                           ▼
        calculate_previous_completed_week(reference_date)
        → period_start (Mon 00:00) … period_end (Sun 23:59:59), Asia/Kuala_Lumpur
                           │
                           ▼
   ┌──────────────── Data collection (each source isolated) ───────────────┐
   │ Google Alerts — Google-indexed results for the targets + keywords     │
   │   → platform from URL: Facebook / Instagram / LinkedIn /              │
   │     anything else = Public website (page fetched once for text+date)  │
   │ +  Company website  +  SC Malaysia                                   │
   │ [+ optional authorised API connectors later]                          │
   └───────────────────────────────────────────────────────────────────────┘
                           │
                           ▼
   Normalise (text, URL, dates)  →  in-run URL de-duplication
                           ▼
   Platform detection  →  URL classification
                           ▼
   Date filter (content date vs period; UNKNOWN → manual review bucket)
                           ▼
   Target-name matching  →  Adverse keyword screening (+ keyword-to-name proximity)
                           ▼
   Rule-based flagging & priority (R1–R7) — no NLP
                           ▼
   URL verification (VERIFIED / PARTIAL / REJECTED)
                           ▼
   Deduplication (URL key, content hash, title/date) → upsert
                           ▼
                     SQLite database
                           ▼
                  Excel report (from SQLite)
                           │
                     ┌─────┴─────┐
                     ▼           ▼
                Local save     Email (if allowed for this mode
               (reports/)       and not already sent for the period)
```

Official social-media APIs are optional future connectors. The non-API pipeline must work end-to-end first.

---

## 2. One pipeline for both modes

Automatic and manual execution differ only in **how the program is started** and **two settings that follow from that** (the "Execution Mode" label and the default email behaviour). After the reporting period is calculated, both modes call the same `run_pipeline(period, run_context)` function. There is no separate manual implementation.

| | Automatic | Manual |
|---|---|---|
| Started by | Windows Task Scheduler, every Monday at a configurable time | A person, any day |
| Command | `python negative_screening.py --scheduled` | `python negative_screening.py` |
| Reference date | Today (Malaysia time) | Today (Malaysia time), or `--date` for testing |
| Reporting period | Previous complete Mon–Sun week | Previous complete Mon–Sun week |
| Email default | `email.send_on_automatic` (default `true`) | `email.send_on_manual` (default `false`) |
| Pipeline | `run_pipeline()` | `run_pipeline()` |

---

## 3. Reporting-period logic

One function in `core/calendar.py`, used by every mode. No other module calculates periods; `processing/date_filter.py` only compares content dates against the `ReportingPeriod` it is given.

```python
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

MYT = ZoneInfo("Asia/Kuala_Lumpur")   # on Windows, requires the 'tzdata' package

@dataclass(frozen=True)
class ReportingPeriod:
    reference_date: date
    period_start: date          # Monday
    period_end: date            # Sunday (inclusive, for display)
    start_dt: datetime          # Monday 00:00:00 MYT
    end_dt_exclusive: datetime  # following Monday 00:00:00 MYT (for filtering)

def calculate_previous_completed_week(reference_date: date) -> ReportingPeriod:
    """Return the immediately preceding COMPLETE Monday–Sunday week.

    Works for any weekday. Never returns the current, incomplete week.
    """
    this_monday = reference_date - timedelta(days=reference_date.weekday())
    period_start = this_monday - timedelta(days=7)
    period_end = this_monday - timedelta(days=1)
    return ReportingPeriod(
        reference_date=reference_date,
        period_start=period_start,
        period_end=period_end,
        start_dt=datetime.combine(period_start, time.min, tzinfo=MYT),
        end_dt_exclusive=datetime.combine(this_monday, time.min, tzinfo=MYT),
    )

def today_in_malaysia() -> date:
    return datetime.now(MYT).date()
```

Checked examples (these become unit tests):

| Reference date | Weekday | Period |
|---|---|---|
| 2026-09-21 | Mon | 2026-09-14 → 2026-09-20 |
| 2026-09-22 | Tue | 2026-09-14 → 2026-09-20 |
| 2026-09-25 | Fri | 2026-09-14 → 2026-09-20 |
| 2026-09-27 | Sun | 2026-09-14 → 2026-09-20 |
| 2026-09-28 | Mon | 2026-09-21 → 2026-09-27 |
| 2026-09-29 | Tue | 2026-09-21 → 2026-09-27 |
| 2027-01-01 | Fri | 2026-12-21 → 2026-12-27 |
| 2027-01-04 | Mon | 2026-12-28 → 2027-01-03 |

**Not implemented, on purpose:** `if today.weekday() != 0: exit()`. The scheduler controls how often automatic runs happen; Python only controls which period is scanned. The earlier `--force` override is therefore unnecessary.

A custom date-range scan is a possible future feature and is not part of the current scope.

---

## 4. Command-line interface

| Command | Behaviour |
|---|---|
| `python negative_screening.py` | Manual run for the previous complete week (any weekday). Report saved locally and emailed (`email_defaults.send_on_manual`, default true). The staff app's **Run Weekly Screening** is the same run. |
| `python negative_screening.py --scheduled` | Automatic run (used only by Task Scheduler). Execution Mode = Automatic. Email per `email.send_on_automatic`. |
| `python negative_screening.py --date YYYY-MM-DD` | Testing only: behaves as if run on that date. Execution Mode shows "Manual (test reference date)". Email is suppressed. Cannot be combined with `--scheduled`. |
| `python negative_screening.py --dry-run` | Calculates the period, runs collection and processing, shows what would be reported, writes the report to `reports/dry_run/` using a separate database (`data/screening_dryrun.sqlite`). Never sends email; never changes the real database. |
| `python negative_screening.py --no-email` | Run normally but do not send email. |
| `python negative_screening.py --send-email` | Force the email when a mode's default is off (kept for compatibility/testing); an already-emailed week still needs `--resend-email`. |
| `python negative_screening.py --resend-email` | Email the report even if this period was already emailed. |
| `python negative_screening.py --sources google_alerts,sc_malaysia` | Testing: run only the listed sources (`google_alerts`, `website`, `sc_malaysia`); others show SKIPPED in the report. |
| `python negative_screening.py --print-alert-queries` | Print the Google Alerts query list generated from the entity and keyword files, then exit. |
| `python negative_screening.py --verbose` | Debug-level console logging. |
| `python negative_screening.py --write-scheduler-files` | Write `run_weekly.bat` (CRLF): changes to the project folder, then runs `NegativeScreening.exe --scheduled` if present, else `--scheduled` with the project's `.venv` Python (or the Python that ran this command). Never contains `--date`. |
| `python negative_screening.py --validate` | Safe validation run: full pipeline on the staging database `data/screening_validation.sqlite`, report in `reports/validation/` marked VALIDATION DATA, email never sent (the exact message is saved as `…_email_preview.eml`). Combine with `--date` or `--scheduled`; not with `--dry-run`. |
| `python negative_screening.py --gui` | The staff window (also what `NegativeScreening.exe` opens without options). |
| `python negative_screening.py --install-task [--task-time HH:MM]` / `--uninstall-task` / `--task-status` | Create / remove / show the Windows Task Scheduler task `Negative Screening - Weekly` (§14). |
| `python negative_screening.py --status` / `--self-test all` / `--show-period` | Build status per step, acceptance tests, and the period a scan would cover (respects `--date`). |

A real or dry run starts only when every step it depends on (S03–S20, including the S20 run lock taken around the pipeline) is DONE; otherwise it stops with exit code 2 and lists the missing steps.

Flags combine where sensible, e.g. `python negative_screening.py --date 2026-09-28 --dry-run`.

Exit codes (visible in Task Scheduler's "Last Run Result"): `0` completed, all sources succeeded · `1` completed, at least one source failed · `2` fatal error, no report produced (e.g. invalid config, database not writable) · `3` another run is already in progress (lock file present).

---

## 5. Directory structure

```text
Negative_screening_project/
├── README.md
├── negative_screening.py       # current single-file build: CLI, pipeline and every step (S01–S20)
├── requirements.txt
├── run_weekly.bat              # Task Scheduler wrapper (cd + project python + --scheduled); written by --write-scheduler-files, not committed
├── .env.example                # names of required environment variables, no values
│
├── config/
│   ├── settings.json           # paths, source toggles, endpoints, feeds, thresholds, timeouts
│   ├── entities.json           # approved entities, variants, ambiguous terms
│   ├── adverse_keywords.json   # categories, priorities, keywords, ambiguity flags
│   └── email.json              # sender, recipients, SMTP/IMAP host+port, subject template (no secrets)
│
├── core/
│   ├── models.py               # RawItem, Candidate, SourceResult, ReportingPeriod, RunContext
│   ├── calendar.py             # calculate_previous_completed_week(), today_in_malaysia()
│   ├── config.py               # load + validate JSON config and environment variables
│   ├── logging_setup.py        # file + console logging, secret redaction
│   └── pipeline.py             # run_pipeline(): orchestrates every stage
│
├── collectors/
│   ├── base.py                 # Collector interface
│   ├── google_alerts.py        # IMAP (default) or RSS (fallback) ingestion
│   ├── website.py              # the company's own website (RSS feed)
│   ├── securities_commission.py
│   └── api/                    # optional, disabled until authorised
│       ├── facebook.py
│       ├── instagram.py
│       └── linkedin.py
│
├── processing/
│   ├── normalizer.py           # text, URL canonicalisation, Google redirect decoding
│   ├── date_filter.py          # date resolution + period filtering (uses core/calendar.py)
│   ├── entity_matcher.py
│   ├── keyword_scanner.py
│   ├── flagging.py             # rule-based priorities R1–R7 (no NLP)
│   ├── url_validator.py        # platform detection, URL type, VERIFIED/PARTIAL/REJECTED
│   └── deduplicator.py
│
├── reporting/
│   ├── excel_report.py
│   └── email_report.py
│
├── database/
│   ├── database.py             # connection, migrations, upserts, queries for the report
│   └── schema.sql
│
├── tests/                      # unit tests (calendar, URL rules, keyword/entity matching, dedup)
├── docs/
├── logs/
├── reports/                    # Negative_Screening_YYYY-MM-DD.xlsx, archive/, dry_run/
└── data/                       # screening.sqlite, model cache
```

**Current build:** everything lives in `negative_screening.py`, organised in sections S01–S20 whose banners name the module each will become, so it can be split into this layout later without redesign. The target layout follows the development instruction, with two additions: `core/` (shared models, calendar, config, logging, pipeline orchestration) and `processing/flagging.py` (priority rules kept separate from NLP). Modules stay small and single-purpose. Collectors are interchangeable behind one interface, so a source can be replaced (e.g. Google Alerts → an authorised API) without touching processing or reporting.

---

## 6. Module interfaces

```python
class Collector(Protocol):
    name: str                       # "google_alerts", "website", "sc_malaysia"
    def collect(self, period: ReportingPeriod, ctx: RunContext) -> SourceResult: ...

@dataclass
class SourceResult:
    source: str
    status: Literal["SUCCESS", "FAILED", "SKIPPED"]   # report rows may also show "NOT CHECKED" (D-25)
    items: list[RawItem]
    error: str | None               # short, secret-free message
    stats: dict[str, int]           # retrieved, emails_read, pages_fetched, ...
```

`RawItem` fields are listed in DATA_COLLECTION_ANALYSIS §1. Each processing step takes and returns a list of `Candidate` objects and adds its own fields; no step mutates another step's fields.

`RunContext` carries: run id, execution mode, reference date, dry-run flag, email decision, loaded config, logger, HTTP session (shared User-Agent, timeouts, retry policy).

---

## 7. Database (SQLite, `data/screening.sqlite`)

SQLite is the primary store and the only input to the Excel generator. Excel is never the database.

```sql
-- One row per execution
CREATE TABLE runs (
    run_id            TEXT PRIMARY KEY,           -- e.g. 20260922T103012+0800
    started_at        TEXT NOT NULL,              -- ISO 8601, MYT
    finished_at       TEXT,
    execution_mode    TEXT NOT NULL,              -- AUTOMATIC | MANUAL | MANUAL_TEST_DATE
    reference_date    TEXT NOT NULL,
    period_start      TEXT NOT NULL,
    period_end        TEXT NOT NULL,
    dry_run           INTEGER NOT NULL DEFAULT 0,
    exit_code         INTEGER,
    report_path       TEXT,
    app_version       TEXT,
    config_versions   TEXT                        -- JSON: entities/keywords/settings versions
);

-- Source health per run
CREATE TABLE source_status (
    run_id            TEXT NOT NULL REFERENCES runs(run_id),
    source            TEXT NOT NULL,              -- Google Alerts, Facebook, Instagram, LinkedIn, Public website, Company website, SC Malaysia
    status            TEXT NOT NULL,              -- SUCCESS | FAILED | SKIPPED | NOT CHECKED
    retrieved         INTEGER DEFAULT 0,
    filtered_out      INTEGER DEFAULT 0,
    flagged           INTEGER DEFAULT 0,
    duplicates        INTEGER DEFAULT 0,
    rejected          INTEGER DEFAULT 0,
    error             TEXT,
    PRIMARY KEY (run_id, source)
);

-- One row per unique piece of content, ever
CREATE TABLE findings (
    finding_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    url_key             TEXT NOT NULL UNIQUE,     -- sha256 of canonical URL / platform key
    canonical_url       TEXT NOT NULL,
    discovered_url      TEXT NOT NULL,
    final_url           TEXT,
    platform            TEXT NOT NULL,
    content_class       TEXT NOT NULL,            -- social | public_web | regulatory | company
    content_type        TEXT,
    url_type            TEXT,                     -- SPECIFIC_CONTENT | CONTAINER | NON_EVIDENCE | UNKNOWN
    url_verification    TEXT NOT NULL,            -- VERIFIED | PARTIAL | REJECTED
    verification_basis  TEXT,
    title               TEXT,
    snippet             TEXT,
    publisher           TEXT,
    content_hash        TEXT,                     -- when content legitimately available
    language            TEXT,
    source_published_at TEXT,
    alert_received_at   TEXT,
    content_date        TEXT,                     -- event / content date, never the discovery date
    date_status         TEXT NOT NULL,            -- VERIFIED | DERIVED | APPROXIMATE | FIRST_SEEN | UNKNOWN
    date_basis          TEXT,
    first_discovered_at TEXT NOT NULL,            -- when this system first found the item (Discovery Date)
    last_seen_at        TEXT NOT NULL,
    date_precision      TEXT                      -- DAY | MONTH | YEAR; NULL when content_date is NULL
);
CREATE INDEX idx_findings_content_hash ON findings(content_hash);

-- Entity/keyword matches for a finding
CREATE TABLE finding_matches (
    finding_id        INTEGER NOT NULL REFERENCES findings(finding_id),
    entity_id         TEXT NOT NULL,
    matched_text      TEXT NOT NULL,
    keyword           TEXT,                       -- NULL for entity-only matches
    keyword_category  TEXT,
    keyword_priority  TEXT,
    ambiguous         INTEGER DEFAULT 0,
    proximity_words   INTEGER,
    UNIQUE (finding_id, entity_id, matched_text, keyword)
);

-- Which reporting week a finding belongs to, and its review state for that week
CREATE TABLE finding_periods (
    finding_id        INTEGER NOT NULL REFERENCES findings(finding_id),
    period_start      TEXT NOT NULL,
    period_end        TEXT NOT NULL,
    report_section    TEXT NOT NULL,              -- MAIN | DATE_UNKNOWN | UNVERIFIED_URL | OUT_OF_PERIOD | NOT_REPORTED
    priority          TEXT,
    rules_applied     TEXT,                       -- e.g. "R2,R5"
    review_status     TEXT NOT NULL DEFAULT 'PENDING',   -- PENDING | MANUAL REVIEW | NEEDS REVIEW | CONFIRMED ADVERSE | FALSE POSITIVE
    reviewer_note     TEXT,
    first_run_id      TEXT NOT NULL,
    last_run_id       TEXT NOT NULL,
    PRIMARY KEY (finding_id, period_start)
);

-- Every time a finding was surfaced (audit of discovery queries)
CREATE TABLE discovery_hits (
    hit_id            INTEGER PRIMARY KEY AUTOINCREMENT,
    finding_id        INTEGER NOT NULL REFERENCES findings(finding_id),
    run_id            TEXT NOT NULL REFERENCES runs(run_id),
    source            TEXT NOT NULL,
    discovery_method  TEXT NOT NULL,
    discovery_query   TEXT,
    source_message_id TEXT,                       -- alert email Message-ID / feed entry id
    seen_at           TEXT NOT NULL,
    UNIQUE (finding_id, run_id, source, discovery_query)
);

-- Email sends, used to prevent duplicate emails for a period
CREATE TABLE email_log (
    email_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id            TEXT NOT NULL REFERENCES runs(run_id),
    period_start      TEXT NOT NULL,
    sent_at           TEXT NOT NULL,
    recipient_count   INTEGER NOT NULL,
    status            TEXT NOT NULL,              -- SENT | FAILED | SKIPPED
    reason            TEXT                        -- e.g. "already sent for period", "manual mode default"
);
```

**Re-run safety:** re-running a week upserts on `findings.url_key` and `finding_periods (finding_id, period_start)`, updates `last_seen_at` / `last_run_id`, and appends to `discovery_hits`. It never creates a second finding, and it never resets a `review_status` that staff have already changed.

---

## 8. Excel report

File: `reports/Negative_Screening_YYYY-MM-DD.xlsx`, where the date is the **period start (Monday of the reported week)**, so every run for the same week produces the same file name. On a re-run, the previous file is moved to `reports/archive/` with its generation timestamp appended, then the new file is written. Dry runs write to `reports/dry_run/`.

The report is generated entirely from SQLite for the given period.

### Sheet 1 — Summary

- Report Generated: actual execution date/time (MYT)
- Reporting Period: Monday – Sunday
- Execution Mode: Automatic / Manual / Manual (test reference date)
- Reference Date: date used to calculate the period
- Coverage statement: "This report covers content surfaced by the sources listed below during the reporting period. It is not a complete record of all Internet mentions."
- Screened targets: each approved entity (e.g. <company> — Company; <founder> — Person (Founder)) with every name and variant searched; the email body carries the same list on one line
- Source health table: each source, status (SUCCESS / FAILED / SKIPPED / NOT CHECKED), retrieved, flagged, error message; FAILED and NOT CHECKED rows carry the "absence of findings does not mean no adverse content" note. NOT CHECKED = Google Alerts ran but no alert emails arrived, so Facebook / Instagram / LinkedIn / Public website were not screened (D-25)
- Sources attempted / successful / failed (counted per collector — Google Alerts, Company website, SC Malaysia — so one mailbox failure is one failed source, although the Facebook / Instagram / LinkedIn / Public website rows also show FAILED)
- Dates in this report: reported items by Historical Status (CURRENT / HISTORICAL / DATE UNKNOWN); a highlighted "Historical findings" line saying how many reported items are older records found this week (not new incidents), with the oldest event / content date; and a one-line explanation of each date column (Report Week, Event / Content Date, Date Status, Historical Status, Record Age, Discovery Date)
- Total discovered candidates · total relevant (entity-matched) candidates · total potentially adverse items · critical items · manual-review items · items with unknown date · unverified URLs · reported items dated before the period (HISTORICAL) · items surfaced this week but dated before the period (not in the Findings sheet)
- Configuration versions (entities, keywords)

**Printing (all sheets):** A4 landscape, fitted to one page wide, header row repeated on every page (findings sheets), page header "Negative Screening Report · <period> · <sheet>", footer "Printed <date/time>" and "Page x of y". The staff app's *Print Report* produces an HTML print view of the same SQLite data with fewer columns (priority, event / content date, Historical Status, platform, entity, keyword, title/snippet, URL, verification, review status) so it stays readable on A4; all web text is HTML-escaped.

**Google Alerts with an empty mailbox:** if the label holds no alert email for the period, the Google Alerts row is SUCCESS with the warning "no Google Alerts emails arrived …", and the Facebook / Instagram / LinkedIn / Public website rows say "No Google Alerts emails arrived in the period — not checked through Google's index", so it is never read as "no findings".

### Sheet 2 — Findings (main)

In-period items with VERIFIED or PARTIAL URLs, sorted by priority then content date.

| Column | Notes |
|---|---|
| Report Week | e.g. 2026-09-14 – 2026-09-20 |
| Event / Content Date | when the incident or source record is dated, only as precisely as the source states it (`2022` for a year-only SC entry); `UNKNOWN` if none. Never the discovery date |
| Date Status | reliability of the event / content date: VERIFIED / VERIFIED (year only) / VERIFIED (month only) / DERIVED / APPROXIMATE / FIRST_SEEN (no event date; listed in the week first found) |
| Historical Status | CURRENT / HISTORICAL / DATE UNKNOWN — the event / content date against the reporting week (DATA_COLLECTION_ANALYSIS §2.3); HISTORICAL cells highlighted |
| Record Age | HISTORICAL items only, e.g. "approx. 4 years" |
| Discovery Date | when this system first found the item (`findings.first_discovered_at`) |
| Platform | |
| Content Type | |
| Finding Type | Company finding / Founder finding (the person's role) / Relationship-linked finding / Several entities — no approved relationship |
| Matched Entity | display names of the approved entities named in the item |
| Matched Name / Alias | the exact name, variant or alias that matched (e.g. a Chinese alias), prefixed by the entity when several matched |
| Associated Entity | only for a relationship-linked finding: the other end of an approved relationship that is also named in the item |
| Relationship | only when both ends of an approved relationship are named, e.g. "<founder> → Founder of → <company> (approved relationship)…"; it says that who the keyword concerns needs human review |
| Keyword | all matched, comma-separated; not attributed to one entity |
| Keyword Category | |
| Priority | CRITICAL / HIGH / MEDIUM / REVIEW / LOW |
| Title / Comment / Snippet | |
| URL | clickable hyperlink. The page's final URL (after redirects) when the page was read and matched — VERIFIED by `page text match` — unless the redirect went to the home page or a parent section of the discovered URL; otherwise the discovered URL. Never built or guessed; social URLs are never fetched, so they are always the discovered URL |
| URL Type | |
| URL Verification | VERIFIED / PARTIAL |
| Discovered URL | the link exactly as the source delivered it (Google Alerts result after redirect decoding, RSS item link, SC page) |
| Fetched URL | the page the program actually downloaded (after HTTP redirects) — public web result pages, SC Malaysia pages; otherwise "Not fetched — social media pages are never opened by the program" or "Not fetched — link, title and snippet as delivered by the source". Never guessed |
| Discovery Method | incl. number of queries that found it |
| Manual Review Status | |
| Notes | rules applied, URL verification basis, date basis, discovery queries, reviewer note |

### Sheet 3 — Date Unknown — Manual Review

Entity-matched items discovered during the period whose content date could not be confirmed. Same columns; Date Status = UNKNOWN, Manual Review Status = MANUAL REVIEW.

### Sheet 4 — Unverified URLs — Manual Lookup

Entity-matched items whose URL was REJECTED as evidence (search pages, hashtag pages, image URLs, etc.), with the snippet and alert query so staff can locate the content themselves.

### Optional Sheet 5 — Out of Period (audit)

Enabled with `report.include_out_of_period_sheet`. Items surfaced this week but dated before the period.

Formatting: frozen header row, autofilter, CRITICAL rows highlighted, HISTORICAL cells highlighted, column widths set, URLs as hyperlinks, all dates shown in MYT.

---

## 9. Email

- Built by `reporting/email_report.py`; sent over SMTP with STARTTLS.
- Prototype: sender and recipient `operator@example.com`, until the client provides a client-controlled account and recipients. All of this is in `config/email.json`; changing it needs no code change.
- Secrets (SMTP app password, IMAP app password) come from the environment variables `NS_SMTP_PASSWORD` / `NS_IMAP_PASSWORD` if set (developer/admin override), otherwise from **Windows Credential Manager**, where the staff app's Setup saves them for the signed-in Windows user. They are never in JSON, code, logs, the report, the exe or Git; log redaction covers both places.
- A failed send records its reason in `email_log.reason` (e.g. "email sending is not configured …", "the mail server rejected … app password") so the staff window can explain it.
- Subject: `[Negative Screening] 14–20 Sep 2026 — 2 critical, 5 for review` (plus `— 1 source failed` when relevant, counted per collector as in the Summary sheet).
- Body: reporting period, execution mode, source health, key counts, coverage statement. Attachment: the Excel report.

**Send decision** (evaluated once, before sending):

```text
if dry_run or --validate or --date used or --no-email  → do not send
elif --resend-email                                    → send
elif MANUAL and email_defaults.manual_email_cooldown_minutes is set
     and the newest SENT email (any week) is younger  → do not send ("cooldown: an email was sent N min ago …")
elif (AUTOMATIC, or no cooldown set) and the period
     already has a SENT row in email_log              → do not send (log "already sent for period")
elif --send-email                                      → send
elif mode == AUTOMATIC                                 → send if email_defaults.send_on_automatic (default true)
else (MANUAL)                                          → send if email_defaults.send_on_manual (default true)
```

So every normal run — the Monday task or a staff click on any day — emails the week's report once; staff can re-scan a week as often as they like without duplicate emails unless they explicitly re-send (`--resend-email`, *More → Run again and re-send* in the app). An email failure is logged and recorded in `email_log`; the local report is still saved and the run exits with code 1.

---

## 10. Failure handling

- Each collector runs inside its own `try/except`. A failed source → `SourceResult(status="FAILED", error=...)`; the remaining sources continue.
- Network calls: timeout (default 30 s), up to 3 retries with exponential back-off for timeouts, connection errors and HTTP 429/5xx. No retries on 401/403 (these indicate access problems, reported as FAILED).
- A single bad item (unparseable email, malformed page) is logged and skipped; it does not fail the source.
- The report is always produced if the pipeline reaches reporting, even when every source failed (the report then says so).
- Fatal errors (invalid configuration, database not writable) stop the run with exit code 2 and a clear log entry.
- A lock file (`data/run.lock`) prevents two runs overlapping (e.g. staff manual run while the scheduled one is running); a stale lock older than the configured maximum run time (`run.max_run_minutes`) is cleared with a warning. The lock is created exclusively (one process wins) and holds the process id, computer name, start time and a random token; a run releases it only if the token is still its own, so it never deletes a lock another run has taken. Dry runs use the same lock. A refused run exits with code 3.

---

## 11. Logging

Files: `logs/negative_screening.log` (rotating) plus one file per run `logs/run_<run_id>.log`. Console output mirrors key events.

Logged every run:

```text
run started (run id, mode, reference date, app version)
reporting period
source started / source completed (status, duration)
number retrieved, filtered, flagged, duplicated, rejected (per source and total)
errors (message and source; stack trace at DEBUG level)
report generated (path)
email status (sent / skipped + reason / failed)
run completed (exit code, duration)
```

Never logged: passwords, app passwords, API secrets, access tokens, full email bodies. A logging filter redacts values of known secret environment variables and anything that looks like a token or `password=` pair.

---

## 12. Configuration and secrets

| File / variable | Contains |
|---|---|
| `config/settings.json` | timezone, paths, enabled sources, website/SC endpoints, Google Alerts mode and public-web page fetching, HTTP timeouts/retries/delays, screening window (`keyword_name_window_words`), report options, email defaults per mode. An `nlp` section is rejected (NLP excluded by the owner). |
| `config/entities.json` | DATA_COLLECTION_ANALYSIS §3 |
| `config/adverse_keywords.json` | DATA_COLLECTION_ANALYSIS §4 |
| `config/email.json` | sender, recipients, SMTP host/port, IMAP host/port, alert mailbox label, subject template |
| `NS_SMTP_PASSWORD`, `NS_IMAP_PASSWORD` | secrets: saved in Windows Credential Manager by the staff app's Setup, or set as Windows user environment variables (these take precedence) |
| `.env.example` | lists the variable names only |

Config is validated at start-up; an invalid file stops the run with a message naming the file and field.

---

## 13. Dependencies (all free)

| Package | Use |
|---|---|
| `requests` | HTTP for the Company website, SC Malaysia and Public website result pages |
| `openpyxl` | Excel report |
| `tzdata` | Time-zone data for `zoneinfo` on Windows |
| Python standard library | `imaplib` / `email` / `smtplib` (alert ingestion and sending), `html.parser` (HTML), `xml.etree` (RSS/Atom), `urllib.robotparser` (robots.txt), `sqlite3`, `logging` |

**Kept to the standard library where possible (owner's instruction, 29 Sep 2026):** `beautifulsoup4` + `lxml`, `feedparser` and `python-dateutil` were planned but are not used — `html.parser`, `xml.etree` and `datetime` cover the need. Tests run through `python negative_screening.py --self-test` (no `pytest` needed). `requirements.txt` lists only what the program imports.

Python 3.10+ on Windows. SQLite is built into Python.

---

## 14. Staff application, scheduling and packaging

- **Staff window** (Tkinter, standard library; `StaffApp` in `negative_screening.py`): *Run Weekly Screening* (a MANUAL run of the previous complete week, emailed by default), *Open Latest Report*, *Open Reports Folder*, *Print Report* (HTML print view), Setup → *Google Alerts* (queries, settings, mailbox check), and a *Last run* panel with the screened targets and the period's findings count read from `data/screening.sqlite` (run time, mode, period, result, source health with plain-language notes, email status, report path). The run happens in a background thread through `execute_run()` — the same path as the CLI and the scheduled task — so the same lock, logs and database are used. Missing passwords are shown as "not configured" notices, never as tracebacks. Developer options (`--date`, `--dry-run`, `--validate`, `--sources`) are not in the window.
- **Windows Task Scheduler task** `Negative Screening - Weekly` (created from XML by `schtasks /Create /XML`): calendar trigger weekly on Monday (default 09:00), `StartWhenAvailable` true (missed runs catch up), `MultipleInstancesPolicy` IgnoreNew, execution limit = `run.max_run_minutes`, runs as the signed-in user (interactive token, least privilege), action `NegativeScreening.exe --scheduled` with the project folder as the start folder (developer fallback: `run_weekly.bat`). No boot or logon trigger. `install_scheduled_task.bat` / `uninstall_scheduled_task.bat` wrap `--install-task` / `--uninstall-task`.
- **Packaging**: `build_exe.bat` → PyInstaller one-file, windowed (`--collect-data tzdata`) → `dist/NegativeScreening.exe`, copied to the project folder. The exe finds its project folder from its own location (or the folder above `dist\`). Without options it opens the staff window; with options it behaves like the Python CLI (output goes to the calling Command Prompt). Configuration and passwords are never packaged.
- **Run ids** are `YYYYMMDDTHHMMSS+0800`; a second run in the same second gets `-2`, `-3` … so it cannot collide in `runs`.
