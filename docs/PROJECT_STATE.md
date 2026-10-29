# Project State — Negative Screening System

| | |
|---|---|
| **Last updated** | 30 September 2026 |
| **Stage** | Phases 1–7 done — build steps S01–S20 DONE, self-tests 103 passed / 0 failed / 0 pending · next: live credentials, first real run for a past week reviewed with the owner (§7) |
| **Developer** | Yap Xiang Yang (independent student developer) — operator@example.com |
| **Target environment** | Windows, Python, run on one local machine |

This file is the single source of truth for *where the project stands*. Design detail lives in the other documents (see [Document map](#document-map)); this file only records status, decisions and open items.

---

## 1. Objective

Build an automated weekly **Negative / Adverse Media Screening System** that helps staff find publicly discoverable online content that may be negative or adverse about:

- the client company
- approved company aliases
- approved relevant company personnel (currently: the founder)
- relevant regulatory mentions

Each finding is delivered with its original source URL so a person can verify it.

**Practical objective:** find as many relevant, publicly discoverable negative/adverse links as reasonably possible using free, legitimate and maintainable discovery methods.

**Coverage statement (must appear in the report and never be contradicted):** the system does not and cannot find every Internet mention. It reports what its configured discovery sources surfaced during the reporting period.

This is a real small-business application intended for future staff use, not an academic-only exercise.

---

## 2. Roles and ownership

- The developer is an **independent student/developer**. He is **not** an employee, intern, staff member, legal representative or owner of the client company.
- The application is a **prototype** built for client evaluation and possible future deployment.
- Documentation must not describe the developer as owning or operating the client's business infrastructure.
- If the client adopts the system, application ownership, API credentials, mailbox/account authorisation and operational responsibility transfer to the client. The design keeps all accounts, credentials and recipients in configuration so this handover needs no code changes (see `OPERATIONS_GUIDE.md` → Handover checklist).

---

## 3. History (why the scope changed)

| When | What happened |
|---|---|
| Aug–Sep 2026 | Original brief: screen Facebook, Instagram, LinkedIn, public websites (including the company's own) and securities commissions for negative content about the company and its founder; run weekly; email a table report (originally to a company staff mailbox) and keep a local backup. |
| Sep 2026 | Feasibility work showed the original scope could not be delivered as written: platform-wide automated search of Facebook, Instagram and LinkedIn is blocked as bot access; scraping with a personal account risks account bans and breaches platform terms; the developer has no admin rights on the company's social pages, so official APIs could not be authorised. The earlier documentation set was discarded. |
| Sep 2026 | The client agreed to a **compromise**: no complete scanning and no direct crawling of social platforms. Social content is discovered only where it is publicly indexed (initially via Google Alerts); public websites, SC Malaysia and news are retrieved directly from free, public sources. |
| 29 Sep 2026 | Final pre-development decisions and the manual-scan requirement recorded in this documentation set. Development approved to start. |

---

## 4. Final decisions log

| ID | Decision | Detail in |
|---|---|---|
| D-01 | Monitored social platforms are **Facebook, Instagram, LinkedIn**. "LINE" in earlier notes was a typo and is not a source. | SOURCE_ACCESS_BLUEPRINT §3 |
| D-02 | **Direct Google Search HTML scraping and anti-bot-evasion methods are NOT selected** as the production architecture. No CAPTCHA solving, proxy rotation, fingerprint spoofing, evasive browser automation, personal login-cookie scraping or bypassing access controls. | SOURCE_ACCESS_BLUEPRINT §1 |
| D-03 | **Google-indexed public-content discovery is implemented initially through Google Alerts email ingestion.** Python reads alert emails from a designated mailbox; it never scrapes Google result pages. Google's index is used to find public Facebook, Instagram and LinkedIn content (plus whole-web results); each result URL's platform is identified from its hostname, and anything not identifiable is listed as **Public website**. | SOURCE_ACCESS_BLUEPRINT §2 |
| D-04 | Official Meta (Facebook/Instagram) and LinkedIn Community Management APIs are **optional future connectors**, added only if the client provides authorised access. They are not built first. | METHOD_SELECTION_SIMULATION §1 (M6–M8) |
| D-05 | The company's public website: direct public retrieval (RSS/Atom → official endpoint → requests + BeautifulSoup → browser automation only if necessary and permitted). | SOURCE_ACCESS_BLUEPRINT §4 |
| D-06 | SC Malaysia is monitored separately and classified as **Regulatory / Potentially Adverse**. | SOURCE_ACCESS_BLUEPRINT §5 |
| D-07 | No separate news collector. News articles are found through Google-indexed whole-web alerts and reported as **Public website**. The GDELT/RSS news collector is removed from the build (kept only as a documented alternative). | SOURCE_ACCESS_BLUEPRINT §6 |
| D-08 | The default reporting period is always the **immediately preceding complete Monday–Sunday week** in Asia/Kuala_Lumpur (UTC+8), computed by one central function. | FINAL_ARCHITECTURE §3 |
| D-09 | **Automatic mode:** Windows Task Scheduler starts the app every Monday. **Manual mode:** staff can run it on any day and get the same previous-complete-week period. Python never refuses to run on non-Mondays and never loops waiting for Monday. | FINAL_ARCHITECTURE §2–4 |
| D-10 | Both modes use exactly the same pipeline after the period is calculated. There is no separate manual implementation. | FINAL_ARCHITECTURE §2 |
| D-11 | Keyword dictionary and entity list are configurable JSON files, not hard-coded. | DATA_COLLECTION_ANALYSIS §3–4 |
| D-12 | **No NLP.** Sentiment analysis, mBERT and any other machine-learning classification are completely excluded from this project by the project owner's decision (29 Sep 2026). Only the owner can reinstate them. Screening is rule-based: approved name + adverse keyword. | DATA_COLLECTION_ANALYSIS §5–7 |
| D-13 | A result is reported only when it names an approved target **and** contains an approved adverse keyword (SC Malaysia pages excepted). Unambiguous Sanctions & Regulatory Enforcement keywords are CRITICAL / MANUAL REVIEW ("immediate action"); ambiguous keywords go to NEEDS REVIEW. | DATA_COLLECTION_ANALYSIS §7 |
| D-14 | Every result carries URL verification status **VERIFIED / PARTIAL / REJECTED**. URLs are never guessed or fabricated. | DATA_COLLECTION_ANALYSIS §8 |
| D-15 | Content date comes from the source whenever verifiable. Alert email time is never silently used as the content date; unknown dates are marked UNKNOWN / MANUAL REVIEW. | DATA_COLLECTION_ANALYSIS §2 |
| D-16 | SQLite is the primary store; Excel is generated from it. Re-running the same week never duplicates records. | FINAL_ARCHITECTURE §7 |
| D-17 | A failed source is reported as **FAILED**, never as "no negative content". The run continues and the report is still produced. | FINAL_ARCHITECTURE §10 |
| D-18 | Prototype email uses operator@example.com until a client-controlled account is provided. Email settings and secrets live in config / environment variables. Manual re-runs do not re-send a week's email unless explicitly requested. | FINAL_ARCHITECTURE §9 |
| D-19 | Search targets: **the company** (including the "Sdn Bhd" form) and **the founder**. Keywords: the owner's list in 9 categories. | DATA_COLLECTION_ANALYSIS §3–4 |
| D-20 | The report does not list syndicated copies ("also published by …") in Notes. Copies on different outlets remain separate findings. No database change is made for this (owner, 30 Sep 2026). | DATA_COLLECTION_ANALYSIS §9.2 |
| D-21 | The report's URL column shows the page's final URL (after redirects) when that page was read and matched (VERIFIED, `page text match`) and the redirect did not go to the home page or a parent section; otherwise the discovered URL, which then stays in Notes as "Discovered as: …". No URL is ever built (30 Sep 2026). | DATA_COLLECTION_ANALYSIS §8.3 |
| D-22 | A real or dry run needs S03–S20 DONE (S20's run lock wraps the pipeline). `run_weekly.bat` is generated per machine by `--write-scheduler-files` and not committed (30 Sep 2026). | FINAL_ARCHITECTURE §4 |
| D-23 | The report separates the **reporting week**, the **event / content date** (as precisely as the source states it — a year stays a year), the **discovery date** (when the system first found the item) and the **Historical Status** (CURRENT / HISTORICAL / DATE UNKNOWN, with an approximate age for HISTORICAL items). An old record is still reported for manual review; age never changes priority or routing. `FIRST_SEEN` now only means "no event date; listed in the week first found" and is never stored as the content date (4 Oct 2026). | DATA_COLLECTION_ANALYSIS §2.3 |
| D-24 | **Nothing counted "for review" is hidden, and nothing is repeated.** An out-of-period item that an earlier week's report already listed (e.g. an SC Investor Alert List entry, listed in the week first found) is not repeated and not counted for review again; the Summary names the week that listed it. An item found this week but dated before the period and never reported before is always listed: the Out of Period sheet is added automatically for it, even when `report.include_out_of_period_sheet` is false (that setting now only adds the audit copies of already-reported items). Prompted by the 28 Sep – 4 Oct 2026 report, whose email said "1 for review" with no row or link (5 Oct 2026). | FINAL_ARCHITECTURE §8 |
| D-25 | When the Google Alerts mailbox delivered **no alert emails**, Google Alerts and Facebook / Instagram / LinkedIn / Public website show **NOT CHECKED**, never SUCCESS: a 0 there is not an all-clear. The rows are highlighted with the "absence of findings" note, the Summary counts "Sources not checked", and the email subject adds "social media & news NOT CHECKED" (5 Oct 2026). | FINAL_ARCHITECTURE §10 |
| D-26 | **Look-alike web addresses** (closes O-12, owner, 5 Oct 2026; dormant since D-27 removed the only ambiguous term): an ambiguous term (a single word of the company name) confirmed only through a web address — the term inside a look-alike domain or an email address, or a context word ("fund") that appears only in one — is a *look-alike* mention. It stays visible for staff, once, in the week first found, but rule **R9** caps its priority at REVIEW / NEEDS REVIEW (never CRITICAL) and the Matched Name column says "only in a web address — possible look-alike". The company's own domain, full names, variants and aliases are unaffected. | DATA_COLLECTION_ANALYSIS §3, §5 |
| D-27 | **Screening uses the full company name only** (owner, 5 Oct 2026): the full company name and its approved forms (Sdn Bhd / Sdn. Bhd. variants, Chinese name) — never a single word of the name. The single-word ambiguous term is removed from `entities.json` and the built-in defaults; other companies are out of scope. The SC Investor Alert List is therefore pre-filtered on the full names only (the look-alike domain entry is no longer a candidate). The founder is unchanged. Since D-29 the only ambiguous terms are the founder's Chinese name (Simplified / Traditional). | DATA_COLLECTION_ANALYSIS §3 |
| D-28 | **Chinese screening** (owner, 5 Oct 2026; closes the Chinese half of O-4): every English adverse keyword that has a Chinese equivalent lists it as a `variant`, in Simplified and Traditional characters (e.g. fraud → 诈骗 / 欺诈 / 詐騙 / 欺詐), keeping the English keyword's category, priority and ambiguity. The company's Chinese name also matches in Traditional characters. The Chinese company names get Google Alerts (Tier 1, 8 alerts); Tier 2 keeps English names with English keywords. The Keyword column shows the form found, e.g. "fraud (欺诈)". | DATA_COLLECTION_ANALYSIS §3–4, SOURCE_ACCESS_BLUEPRINT §2.3 |
| D-29 | **The founder's Chinese name needs the company or the founder's English name in the same item** (owner, 5 Oct 2026): it is a common Chinese name, so on its own it may be someone else. It counts only when the same item also names the company (English or Chinese) or the founder's English name, and it is never an alert. This replaces the 1 Oct relationship case "<Chinese name> accused of fraud" → founder finding: that sentence alone is now not reported. | DATA_COLLECTION_ANALYSIS §3.2 |
| D-30 | **Every keyword must be near the name for full priority** (owner, 5 Oct 2026): an unambiguous keyword more than `keyword_name_window_words` (30 words; characters in Chinese) from the nearest name is reported at REVIEW / NEEDS REVIEW (R5) instead of HIGH or CRITICAL — e.g. market commentary quoting the founder that mentions "fraud" about someone else. | DATA_COLLECTION_ANALYSIS §7 |

### Superseded decisions (kept for traceability)

| Old position | Replaced by | Reason |
|---|---|---|
| Complete scanning of Facebook, Instagram, LinkedIn | D-02, D-03, D-04 | Not technically or legitimately achievable; client accepted best-effort discovery. |
| "LINE" as a platform | D-01 | Typo for LinkedIn. |
| Python exits unless today is Monday; `--force` override for testing | D-09 | Manual scans must work on any day. The scheduler controls *when* automatic runs happen; Python only controls *which period* is scanned. `--force` is therefore unnecessary and is not implemented. |
| Report emailed to a company staff mailbox | D-18 | Prototype sends to the developer's address. The production recipient is set by the client at handover. |
| mBERT contextual NLP screening (old D-12) | D-12 (No NLP) | Owner's decision, 29 Sep 2026. Only the owner can reinstate it. |
| GDELT DOC API + RSS news collector (old D-07) | D-07 | Owner kept Google-indexed discovery, the Company website and SC Malaysia only; news arrives through Google Alerts. |
| `docs/FYP_SPECIFICATION.md` | Not recreated | This is a business application, not an FYP deliverable; its useful content is covered by this file and FINAL_ARCHITECTURE. |

---

## 5. Development phase tracker

The non-API discovery pipeline must work end-to-end before any optional social API is added. Build steps S01–S20 in `negative_screening.py` follow these phases; `python negative_screening.py --status` shows progress.

| Phase | Scope | Status |
|---|---|---|
| 1 — Core framework | config loading, entities, keywords, reporting-period function, SQLite, logging, URL normalisation, deduplication | **Done** — S01 models, S02 calendar, S03 config, S04 logging, S05 database, S06 URL normalisation, S07 deduplication |
| 2 — Discovery | Google Alerts email ingestion (Facebook / Instagram / LinkedIn / public web), Company website collector, SC Malaysia collector | **Done** — S08 collector framework, S09 alert queries, S10 Google Alerts collector, S11 Company website collector, S12 SC Malaysia collector |
| 3 — Screening | approved-name matching, adverse keyword scanning, keyword-to-name proximity, rule-based priorities (no NLP) | **Done** — S14 dates and period filter, S15 entity matcher, S16 keyword scanner, S17 rules R1–R7 and report sections |
| 4 — Verification | platform detection, URL classification, URL verification, evidence status | **Done** — S13 platform detection, URL classification, verification |
| 5 — Reporting | Excel report, summary, source-health section | **Done** — S18 Excel report from SQLite (Summary with coverage statement, source health and counts; Findings, Date Unknown, Unverified URLs and optional Out of Period sheets; previous file for the same week archived) |
| 6 — Email | weekly email with attachment, duplicate-email guard | **Done** — S19 send decision (dry run / --date / --no-email never send; already-sent weeks are not re-sent unless --resend-email), SMTP STARTTLS with the report attached, password only from `NS_SMTP_PASSWORD`; a failure is logged and the report is kept |
| 7 — Scheduling | Windows Task Scheduler setup and scheduled-run test | **Done (code)** — S20 run lock (exclusive create, stale after `run.max_run_minutes`, released only by its owner), `--write-scheduler-files` → `run_weekly.bat` (CRLF, `--scheduled`, never `--date`), run gate now requires S03–S20; full dry run 30 Sep 2026. Creating the Windows task on the production machine is open (O-8) |
| Optional | Meta / Instagram / LinkedIn API connectors | Deferred — needs client authorisation |

### Phase 1 deliverables (from the development instruction)

1. Updated Markdown documentation — **done (this set)**
2. Final architecture — **documented** (FINAL_ARCHITECTURE)
3. Source-access decisions — **documented** (SOURCE_ACCESS_BLUEPRINT)
4. Working project structure — **single-file scaffold** `negative_screening.py` (steps S01–S20, acceptance tests written for each step)
5. Configuration files — **done (S03)**: `--init-config` writes them; `load_config()` validates every file and names the file + field on error
6. Database schema — **done (S05)**: created by `db_connect()`, identical to FINAL_ARCHITECTURE §7; re-runs never duplicate findings, matches or discovery hits, and staff review decisions are never overwritten
7. Date/calendar logic — **done (S02)**, all example dates tested
8. Discovery collector implementation — **done (S08–S12)**: Google Alerts (IMAP + RSS fallback), Company website (RSS feed), SC Malaysia (Investor Alert List + media releases)
9. Keyword scanner — **done (S16)**: whole-word/phrase matching of the owner's list, optional variants, ambiguity flag and distance to the nearest name mention
10. URL/platform detector — **done (S13)**: platform from the hostname only; content type and URL type from the SOURCE_ACCESS_BLUEPRINT §3 pattern tables; VERIFIED / PARTIAL / REJECTED with a recorded basis
11. Initial report generator — **done (S18)**: `reports/Negative_Screening_<period start>.xlsx` built from SQLite only; frozen header, autofilter, hyperlinks, CRITICAL rows highlighted; web text is always stored as text (never as a formula); an earlier file for the same week moves to `reports/archive/`; dry runs go to `reports/dry_run/`
12. Development/test instructions — **documented** (OPERATIONS_GUIDE)
13. Known limitations and client-side dependencies — **documented** (FEASIBILITY_GATE)

---

## 6. Open items and client-side dependencies

| # | Item | Owner | Needed by |
|---|---|---|---|
| O-1 | Confirm approved personnel names beyond the founder, and any approved aliases/spelling variants. Nothing is added without approval. | Client | Phase 1 |
| O-2 | Confirm the Google account that owns the Google Alerts and the mailbox that receives them (prototype: developer's Gmail). | Client / developer | Phase 2 |
| O-3 | Confirm priority levels for keyword categories other than Sanctions/Regulatory (proposed defaults in DATA_COLLECTION_ANALYSIS §4). | Client | Phase 3 |
| O-4 | Decide whether **Malay** keyword equivalents should be added (the Chinese equivalents were added on 5 Oct 2026, D-28; Malay content still will not match). | Owner / client | Phase 3 |
| O-5 | Review the keyword-to-name window (default 30 words) and the ambiguous-keyword list after the first weeks of real results. | Developer / owner | After first runs |
| O-6 | Production email recipient(s) and sending account. | Client | Handover |
| O-7 | If the client wants owned-channel comment monitoring, provide admin authorisation for Meta / LinkedIn API apps. | Client | Optional |
| O-8 | Confirm the machine that will run the weekly task (must be on, or able to catch up, on Mondays). | Client | Phase 7 |
| O-9 | Client written acceptance of the coverage limitations in FEASIBILITY_GATE §4. | Client | Before deployment |
| O-10 | Set `NS_IMAP_PASSWORD` and `NS_SMTP_PASSWORD` (Gmail app passwords) on the run machine, create the alerts from `--print-alert-queries` and the NS-Alerts label, then run a live Google Alerts dry run and one `--send-email` test. Neither is set on the development machine yet. | Developer / owner | Before first scheduled run |
| O-11 | One real (non-dry) run for a past week, reviewed with the owner, as S20 requires. | Developer / owner | Before first scheduled run |
| O-12 | ~~Whether look-alike/impersonation entries (e.g. an SC Investor Alert List entry for an unrelated scheme whose website is a look-alike of the company name) are wanted findings.~~ **Closed 5 Oct 2026 — D-26:** kept for review at REVIEW priority, not CRITICAL. | Owner | Done |

---

## 7. End-to-end readiness (30 Sep 2026)

"Code verified" = acceptance tests pass with test doubles. "Live" = exercised against the real service on the development machine.

| Area | Code | Live |
|---|---|---|
| Calendar, manual run on any day | verified (S02; `--show-period` for 21, 22, 25, 27, 28 Sep) | verified — Wednesday 30 Sep scans 21–27 Sep |
| Configuration, database, logging | verified (S03–S05) | verified by the dry run |
| Collector framework, FAILED ≠ "no findings" | verified (S08) | verified — Google Alerts reported FAILED with the reason |
| Google Alerts (IMAP / RSS) | verified (S09–S10) | **not configured** (O-10) |
| Company website | verified (S11) | working |
| SC Malaysia | verified (S12) | working |
| Platform detection, URL verification, dates, entities, keywords, R1–R7 | verified (S13–S17) | verified by the dry run |
| Excel report | verified (S18) | verified — `reports/dry_run/Negative_Screening_2026-09-14.xlsx` |
| Email decision and SMTP sending | verified (S19, fake SMTP server) | **not configured** — no `NS_SMTP_PASSWORD`; nothing has been sent |
| Run lock | verified (S20) | verified — a held lock refused a second run with exit code 3 |
| Scheduler wrapper | verified (S20) | `run_weekly.bat` written; Windows task not yet created (O-8) |

Dry run: `python negative_screening.py --date 2026-09-21 --dry-run` → period 14–20 Sep 2026, exit code 1 (one source failed), 4 candidates, 1 CRITICAL finding, email skipped (dry run).

---

## Document map

| Document | Answers |
|---|---|
| `README.md` | What the project is and where to start |
| `docs/PROJECT_STATE.md` | Status, decisions, open items (this file) |
| `docs/SOURCE_ACCESS_BLUEPRINT.md` | How each source is accessed, and what is never done |
| `docs/DATA_COLLECTION_ANALYSIS.md` | Fields, dates, targets, keywords, rule-based flagging, URL verification, deduplication |
| `docs/METHOD_SELECTION_SIMULATION.md` | Every method considered, with feasibility, cost, limits and decision; a worked example run |
| `docs/DECISION_MATRIX.md` | Weighted scoring behind the method choices |
| `docs/FINAL_ARCHITECTURE.md` | Pipeline, calendar logic, CLI, modules, database, report, email, logging, failure handling |
| `docs/FEASIBILITY_GATE.md` | Go/no-go outcome, limitations, risks, acceptance criteria |
| `docs/OPERATIONS_GUIDE.md` | Setup, Google Alerts, running and testing, Windows Task Scheduler, handover |
