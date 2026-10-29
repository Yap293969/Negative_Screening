# Negative Screening System

Automated weekly **negative / adverse media screening** for a target company, its approved aliases and approved personnel. Each week it gathers publicly discoverable content from free, legitimate sources, screens it for adverse indicators, and produces an Excel report (emailed and saved locally) with the source URL of every finding for human verification.

> **Configuration:** the screening targets, the company website feed and the email accounts are set in `config/entities.json`, `config/settings.json` and `config/email.json`. The values shipped in this repository are placeholders used by the self-tests; replace them with your own before a real run.

> **Coverage:** best-effort. The system reports what its configured sources surfaced during the reporting period. It does not and cannot find every Internet mention.

**Status:** build steps S01–S20 are DONE (`python negative_screening.py --status`); progress is recorded in `STEP_STATUS` in `negative_screening.py` and in the Git history. Live Google Alerts and email need the account passwords to be saved once in the app (Setup → Email accounts and passwords).

**Developer:** Yap Xiang Yang, independent student developer (not an employee or representative of the client). This is a prototype for client evaluation; ownership of accounts, credentials and operation transfers to the client if adopted.

---

## How it works

- **When:** Windows Task Scheduler runs it every Monday; staff can also run it manually on any day.
- **What period:** always the previous **complete Monday–Sunday week** (Malaysia time). Running on Friday 25 Sep 2026 scans 14–20 Sep 2026.
- **Targets:** the company (incl. its "Sdn Bhd" form and approved aliases) and its approved personnel, as listed in `config/entities.json`.
- **Sources:**
  - Public Facebook, Instagram and LinkedIn content found in **Google's index** via Google Alerts — the platforms are never crawled. Each result's platform is identified from its URL; anything else is listed as **Public website** (this is also how news articles arrive).
  - The company's own website (its RSS feed, set in `config/settings.json`)
  - Securities Commission Malaysia public pages (Investor Alert List, announcements)
- **Screening (rule-based, no NLP):** approved name + adverse keyword from the owner's list → priority rules → URL verification (VERIFIED / PARTIAL / REJECTED) → deduplication → SQLite → Excel → email.

Official Meta / Instagram / LinkedIn APIs are optional future connectors, added only with client authorisation.

## Staff application (Windows)

Double-click **`NegativeScreening.exe`** in the project folder. No Command Prompt and no Python installation are needed on the staff machine.

| Button / menu | What it does |
|---|---|
| **Run Weekly Screening** | Scans the previous complete Monday–Sunday week — on any day of the week — saves the Excel report in `C:\Negative_Screening_Reports\` and emails it. Manual scans email at most once every 10 minutes (`email_defaults.manual_email_cooldown_minutes`); a scan inside that cooldown still saves the report. The Monday task emails each week once. Progress is shown while it runs; the exact report path is shown at the end. |
| **Open Latest Report** | Opens the newest report in Excel. |
| **Open Reports Folder** | Opens `C:\Negative_Screening_Reports\` in Windows Explorer. |
| **Print Report** | Opens a print-ready page of the last run (screened targets, period, result, source health, every reportable finding with its link) in the browser, A4 landscape; print it or choose *Save as PDF*. A copy is kept in `C:\Negative_Screening_Reports\print\`. |
| **Last run** panel | Screened targets (each approved company / person and the names searched), findings count, run time, who started it (weekly schedule or staff), reporting period, result, source health (a FAILED source is "not checked", never "nothing found"), email status and report file. |
| Setup → Email accounts and passwords | Saves the Google Alerts mailbox and sending-account **app passwords** in Windows Credential Manager (never in files), with *Test mailbox*, *Test sign-in* and *Send test email*. |
| Setup → Google Alerts | The alert queries to create (with *Copy all queries* and *Open Google Alerts*), the alert and Gmail-filter settings, and *Check mailbox for alert emails*. Google Alerts emails are how links from Google's index arrive. |
| Setup → Weekly schedule | Installs / removes the Windows Task Scheduler task (below). |
| More → Run without email · Run again and re-send this week's email | Admin / testing options. |

Project folder layout (everything stays here except the reports; nothing is written to system or temporary folders):

```text
Negative_screening_project\
  NegativeScreening.exe        staff application (built by build_exe.bat; not in Git)
  config\                      settings, approved names, keywords, email accounts (no passwords)
  data\                        screening.sqlite (production), run.lock while a run is active
  logs\                        negative_screening.log + one run_<id>.log per run
```

Reports are saved in `C:\Negative_Screening_Reports\` (`paths.reports_dir` in `config\settings.json`; a relative
path such as `reports` puts them back inside the project folder). The folder is created on the first run:

```text
C:\Negative_Screening_Reports\
  Negative_Screening_<week start>.xlsx   e.g. Negative_Screening_2026-09-21.xlsx
  archive\                     earlier copies of a re-run week
  dry_run\                     previews (--dry-run)
  validation\                  validation runs (--validate), with an email preview .eml
  print\                       print-ready pages (Print Report)
```

## Weekly automatic run (Windows Task Scheduler)

Double-click **`install_scheduled_task.bat`** (or use Setup → Weekly schedule in the app). It creates the task **`Negative Screening - Weekly`**:

- weekly, every **Monday at 09:00** (another time: `install_scheduled_task.bat 08:30`);
- **Start When Available** — if the computer was off or asleep on Monday morning, it runs as soon as possible afterwards;
- never two runs at once (the task's "do not start a new instance" rule plus the program's own lock);
- starts `NegativeScreening.exe --scheduled` in the project folder, with no window; logs go to `logs\`;
- runs under the signed-in Windows user, who owns the saved passwords. No run-at-boot trigger.

`uninstall_scheduled_task.bat` removes it (reports, logs, database and saved passwords are kept). `NegativeScreening.exe --task-status` shows the next and last run.

## Developer / admin command line

The Python program is still the whole application (`negative_screening.py`, steps S01–S20); the exe accepts the same options.

```bat
python negative_screening.py --status               :: build status per step
python negative_screening.py --self-test all        :: acceptance tests (expect 0 failed, 0 pending)
python negative_screening.py --show-period          :: the week a scan would cover today
python negative_screening.py --gui                  :: the staff window, from Python
python negative_screening.py                        :: manual run (emails by default)
python negative_screening.py --no-email             :: manual run without email
python negative_screening.py --scheduled            :: what the weekly task runs
python negative_screening.py --dry-run              :: preview: separate database, C:\Negative_Screening_Reports\dry_run\, no email
python negative_screening.py --validate --date 2026-09-22   :: safe validation of a past week (below)
python negative_screening.py --install-task / --uninstall-task / --task-status
```

**Validation without touching production data:** `--validate` runs the complete pipeline against the staging database `data\screening_validation.sqlite`, writes the report to `C:\Negative_Screening_Reports\validation\` (its Summary says *VALIDATION DATA*), never sends email and saves the exact email a normal run would send as `…_email_preview.eml`. Combine with `--date` (a past week) or `--scheduled` (the Monday path).

**Building the exe:** `build_exe.bat` installs `requirements.txt` + `requirements-build.txt` (PyInstaller), runs the self-tests, builds `dist\NegativeScreening.exe` and copies it into the project folder. Use a clean `.venv` for a smaller exe. No configuration or password is packaged.

Full instructions: `docs/OPERATIONS_GUIDE.md`.

## Documentation

| Document | Contents |
|---|---|
| [docs/PROJECT_STATE.md](docs/PROJECT_STATE.md) | Decisions log and open items (build progress: `STEP_STATUS` and the Git history) |
| [docs/SOURCE_ACCESS_BLUEPRINT.md](docs/SOURCE_ACCESS_BLUEPRINT.md) | How each source is accessed; Google Alerts query plan; what is never done |
| [docs/DATA_COLLECTION_ANALYSIS.md](docs/DATA_COLLECTION_ANALYSIS.md) | Fields, date handling, targets, keywords, rule-based flagging, URL verification, deduplication |
| [docs/METHOD_SELECTION_SIMULATION.md](docs/METHOD_SELECTION_SIMULATION.md) | All methods considered and why; worked example run |
| [docs/DECISION_MATRIX.md](docs/DECISION_MATRIX.md) | Weighted scoring of the methods |
| [docs/FINAL_ARCHITECTURE.md](docs/FINAL_ARCHITECTURE.md) | Pipeline, calendar logic, CLI, modules, database schema, report, email, logging, failure handling |
| [docs/FEASIBILITY_GATE.md](docs/FEASIBILITY_GATE.md) | Go/no-go, limitations, risks, acceptance criteria |
| [docs/OPERATIONS_GUIDE.md](docs/OPERATIONS_GUIDE.md) | Setup, Google Alerts, running, testing, Task Scheduler, handover |
