# Operations Guide

Setting up, running, testing and scheduling the Negative Screening System on Windows, and handing it over to the client. Commands assume the project folder is `C:\Users\<user>\Desktop\Negative_screening_project`; adjust the path for the machine in use.

> All build steps S01–S20 in `negative_screening.py` are done (`python negative_screening.py --status`). Staff use `NegativeScreening.exe` (§1.1); the Python command line stays available for developers and admins (§1.2). Live Google Alerts ingestion and email sending need the account app passwords saved once (§1.1 step 3); until then those parts are verified by the self-tests only.

---

## 1. First-time setup

### 1.1 Staff machine (no Python, no Command Prompt)

1. Copy the project folder, including `NegativeScreening.exe` and `config\`, to the machine (e.g. `C:\Users\<user>\Desktop\Negative_screening_project`). The exe keeps everything in this folder: `data\`, `logs\`, `reports\` (created automatically).
2. Double-click `NegativeScreening.exe`. If `config\` is missing, default configuration files are created and the window says so; review them (approved names in `entities.json`, recipients in `email.json`).
3. **Setup → Email accounts and passwords.** Enter the Gmail **App Password** (Google Account → Security → 2-Step Verification → App passwords; 16 letters, not the normal password) for:
   - the **Google Alerts mailbox** (`alerts_mailbox` in `email.json`) → *Test mailbox* checks the sign-in and the `NS-Alerts` label;
   - the **report sending account** (`smtp` in `email.json`) → *Test sign-in*, then *Send test email* to the configured recipients.

   *Save passwords* stores them in **Windows Credential Manager** for this Windows user only. They are never written to files, logs, reports or Git. Until they are saved, the window shows that Google Alerts / email are not configured, Google Alerts is reported as FAILED ("not checked"), and reports are saved but not emailed.
4. **Setup → Weekly schedule → Install** (or double-click `install_scheduled_task.bat`), see §6.
5. Click **Run Weekly Screening** once and check the report and the email.

### 1.2 Developer / admin machine (Python)

1. Install Python 3.10 or newer for Windows (tick "Add python.exe to PATH").
2. Open *Command Prompt* in the project folder and create a virtual environment:

   ```bat
   cd /d "C:\Users\<user>\Desktop\Negative_screening_project"
   python -m venv .venv
   .venv\Scripts\activate
   pip install -r requirements.txt
   ```

3. Create the configuration files with `python negative_screening.py --init-config` (existing files are never overwritten) and review them in `config\` (entities, keywords, settings, email). Only approved names go in `entities.json`. Email:
   - `email.json` → `sender`, `recipients` and the SMTP/IMAP accounts. The prototype uses operator@example.com for all of them until the client supplies a production account and recipients.
   - `settings.json` → `email_defaults`: `send_on_automatic` (default `true`: the Monday task emails the report) and `send_on_manual` (default `true`: *Run Weekly Screening* / a manual run emails the report). `manual_email_cooldown_minutes` (default `10`; e.g. `5` for five minutes): a manual scan emails the report unless any report email was sent less than that many minutes ago — then the report is saved but not emailed ("Not sent: an email was sent N min ago …"). Without this setting, manual scans follow the scheduled rule (each week emailed once). The Monday task always emails a week only once. `--no-email` suppresses email; `--resend-email` (More → Run again and re-send) sends regardless of the cooldown; `--date`, `--dry-run` and `--validate` never email.
4. Passwords: use the app's Setup (`python negative_screening.py --gui`), or set user environment variables, which take precedence over saved passwords:

   ```bat
   setx NS_IMAP_PASSWORD "<app password for the alerts mailbox>"
   setx NS_SMTP_PASSWORD "<app password for the sending account>"
   ```

   Close and reopen Command Prompt after `setx`.
5. Check everything: `python negative_screening.py --self-test all`, then a dry run `python negative_screening.py --dry-run`.
6. Build the staff exe: `build_exe.bat` (installs PyInstaller from `requirements-build.txt`, runs the self-tests, builds `dist\NegativeScreening.exe` and copies it into the project folder). Build from a clean `.venv` to keep the exe small. The exe contains no configuration and no passwords.

---

## 2. Mailbox preparation (Google Alerts inbox)

1. In the mailbox that will receive alerts (prototype: operator@example.com), enable IMAP.
2. Create a filter: *From* = the Google Alerts sender (`googlealerts-noreply@google.com`) → apply label **NS-Alerts** (the label name must match `config/email.json`) and skip the inbox if preferred.
3. Do not delete alert emails — they are the audit trail and allow past weeks to be re-processed.

---

## 3. Creating the Google Alerts

Links from Google's index (public Facebook, Instagram, LinkedIn posts and news) only arrive when these alerts exist and their emails reach the `NS-Alerts` label. Without them the run still succeeds, but the report and the app say **"no Google Alerts emails arrived — nothing from Google's index was read"** (never a silent "0 results"). Check at any time with *Setup → Google Alerts → Check mailbox for alert emails*, which counts the alert emails in the label.

In the staff app: **Setup → Google Alerts** lists the queries (*Copy all queries*), opens google.com/alerts (*Open Google Alerts*) and shows the settings below. From the command line:

1. Print the query list generated from the config files:

   ```bat
   python negative_screening.py --print-alert-queries
   ```

2. Signed in to the Google account that will own the alerts, open https://www.google.com/alerts and create one alert per printed query with these options:

   | Option | Setting |
   |---|---|
   | How often | At most once a day |
   | Sources | Automatic |
   | Language | Any language |
   | Region | Any region |
   | How many | All results |
   | Deliver to | the alerts mailbox |

3. Re-run step 1 whenever `entities.json` or `adverse_keywords.json` changes, and add/remove alerts to match.
4. During Phase 2, confirm that `site:` and `OR` queries actually produce matching alerts; simplify any that do not (SOURCE_ACCESS_BLUEPRINT §2.3).

Creating and owning the alerts is a manual step done by the account owner. The application only reads the resulting emails.

---

## 4. Running a scan

| Situation | Staff app | Command (developer / admin) |
|---|---|---|
| Normal scan (any day), report emailed | **Run Weekly Screening** | `python negative_screening.py` |
| Scan without emailing | More → Run without email | `python negative_screening.py --no-email` |
| Re-send a week's report that was already emailed | More → Run again and re-send this week's email | `python negative_screening.py --resend-email` |
| Open the newest report / the reports folder | Open Latest Report / Open Reports Folder | — |
| Preview only (no email, real database untouched) | — | `python negative_screening.py --dry-run` |
| Safe validation of a past week (staging database) | — | `python negative_screening.py --validate --date 2026-09-22` |

Whatever the day, the scan covers the **previous complete Monday–Sunday week**. Running on Tuesday 22, Friday 25 or Sunday 27 Sep 2026 scans 14–20 Sep 2026; Monday 28 Sep scans 21–27 Sep. The program never refuses to run because it is not Monday. The report's Summary sheet shows the execution mode and reference date so this is clear to readers.

Re-running the same week is safe: no duplicate records are created and the report file for that week is regenerated (the previous copy is archived in `reports\archive\`). A manual re-run emails the report again once the 10-minute cooldown has passed; within it, the report is saved but not emailed. If a run is already in progress (e.g. the Monday task), a second one is refused with a message (exit code 3).

Output:

- Report: `reports\Negative_Screening_<period start>.xlsx` (the app shows the exact path after each run). Every sheet is set up to print: A4 landscape, one page wide, column headings repeated on every page, the period in the page header and *Page x of y* in the footer.
- Printable page: **Print Report** in the app writes `reports\print\Negative_Screening_<period start>.html` and opens it in the browser with the print dialog — the screened targets, result, source health and findings (with links) on a few readable A4 pages; choose a printer or *Save as PDF*.
- Logs: `logs\negative_screening.log` and `logs\run_<run id>.log`
- Database: `data\screening.sqlite`

---

## 5. Testing

### 5.1 Reporting-period checks

`--date` makes the program behave as if run on that date. It is for testing only, never for scheduled operation (it suppresses email and cannot be combined with `--scheduled`).

| Command | Expected period |
|---|---|
| `python negative_screening.py --date 2026-09-21 --dry-run` | 2026-09-14 → 2026-09-20 |
| `python negative_screening.py --date 2026-09-22 --dry-run` | 2026-09-14 → 2026-09-20 |
| `python negative_screening.py --date 2026-09-25 --dry-run` | 2026-09-14 → 2026-09-20 |
| `python negative_screening.py --date 2026-09-27 --dry-run` | 2026-09-14 → 2026-09-20 |
| `python negative_screening.py --date 2026-09-28 --dry-run` | 2026-09-21 → 2026-09-27 |
| `python negative_screening.py --date 2027-01-04 --dry-run` | 2026-12-28 → 2027-01-03 |

These are also acceptance tests (`python negative_screening.py --self-test S02`). `--show-period` prints the period without running a scan, e.g. `python negative_screening.py --date 2026-09-25 --show-period`.

### 5.2 Validation run (real sources, production data untouched)

```bat
python negative_screening.py --validate --date 2026-09-22     :: a past week, as if run on Tuesday 22 Sep
python negative_screening.py --scheduled --validate           :: the Monday scheduled path, today
```

Both run every stage against the live sources but store results in `data\screening_validation.sqlite`, write the report to `reports\validation\` (Summary: *Validation Run — VALIDATION DATA*), never send email, and save the exact email a normal run would send as `reports\validation\Negative_Screening_<week>_email_preview.eml` (open it in Outlook or Windows Mail to review the subject, body and attachment). The log states whether a normal run would have emailed and why. Delete the staging database to start a validation from scratch; production data (`data\screening.sqlite`, `reports\`) is never touched.

### 5.3 Other checks

| Check | How |
|---|---|
| One source at a time | `python negative_screening.py --dry-run --sources sc_malaysia` |
| Source failure is reported, not hidden | Temporarily set an invalid endpoint for one source; expect `FAILED` in the report, other sources `SUCCESS`, exit code 1 |
| Re-run creates no duplicates | Run the same `--date` twice (without `--dry-run`, on a test copy of the database); finding counts must not change |
| Current-week protection | Use a test item dated inside the current week; it must not appear in the report |
| No secrets in logs | Search `logs\` for the password values; expect no matches |
| Acceptance tests | `python negative_screening.py --self-test all` — expect `0 failed, 0 pending` |

---

## 6. Windows Task Scheduler (automatic Monday run)

The scheduler decides **when** automatic runs happen. Python decides **which week** is scanned. Python does not loop or wait for Monday.

### 6.1 Install, check, remove

| Action | Staff | Admin |
|---|---|---|
| Install / update (Monday 09:00) | Setup → Weekly schedule → *Install / update weekly task*, or double-click `install_scheduled_task.bat` | `NegativeScreening.exe --install-task --task-time 09:00` |
| Other time | enter it in Setup → Weekly schedule | `install_scheduled_task.bat 08:30` |
| Check next / last run | Last run panel → *Weekly schedule*; Setup → Weekly schedule | `NegativeScreening.exe --task-status` |
| Remove | Setup → Weekly schedule → *Remove weekly task*, or `uninstall_scheduled_task.bat` | `NegativeScreening.exe --uninstall-task` |

The task is named **`Negative Screening - Weekly`** and is created for the signed-in Windows user (no administrator rights needed). Its definition:

- **Trigger:** weekly, every Monday at the chosen time. No "at startup" or "at log on" trigger.
- **Run as soon as possible after a scheduled start is missed** (Start When Available): a laptop that was off or asleep on Monday morning runs the screening when it is next on and the user is signed in — it still scans the previous complete week and still counts as Automatic.
- **If the task is already running: do not start a new instance**; the program's own lock (`data\run.lock`) also refuses overlapping runs, including a staff click during the scheduled run.
- **Stop the task if it runs longer than** `run.max_run_minutes` (120 min). Runs on battery power too.
- **Action:** `NegativeScreening.exe --scheduled`, *Start in* = the project folder, no window. Logs: `logs\run_<run id>.log` and `logs\negative_screening.log`; Task Scheduler's *Last Run Result* is the exit code (`0x0` all sources OK, `0x1` completed with a failed source or email, `0x2` fatal, `0x3` another run was active).
- **Account:** runs only while that user is signed in (it uses that user's saved passwords in Credential Manager). For a machine where nobody is signed in on Mondays, an administrator can change the task in Task Scheduler to *Run whether user is logged on or not* (stores the Windows password) — the passwords must then be saved as that user.

The XML the task was created from is kept at `data\scheduled_task.xml` for reference.

### 6.2 Developer fallback: run_weekly.bat

`python negative_screening.py --write-scheduler-files` writes `run_weekly.bat` (CRLF). It changes to the project folder, then runs `NegativeScreening.exe --scheduled` if the exe is there, otherwise `negative_screening.py --scheduled` with the `.venv` Python (or the Python that wrote it). It never contains `--date`. `--install-task` uses it only when there is no exe. The file is machine-specific and not committed to Git.

### 6.3 Behaviour to expect

- A catch-up run on Tuesday (after a missed Monday) still scans the previous complete week, and still counts as Automatic.
- If staff already ran and emailed that week manually, the scheduled run does not email it again (and vice versa).
- No paid scheduling service is needed.

---

## 7. Troubleshooting

| Symptom | Likely cause | Action |
|---|---|---|
| Google Alerts / Facebook / Instagram / LinkedIn all FAILED — "Google Alerts email access has not been configured" | No mailbox app password saved | Setup → Email accounts and passwords → enter it, *Test mailbox*, *Save passwords* |
| Google Alerts / Facebook / Instagram / LinkedIn all FAILED (other reason) | Mailbox login failed (IMAP disabled, app password changed) | Check the IMAP setting; re-enter the app password in Setup and *Test mailbox*; see run log |
| Social sources SUCCESS but always 0 results | Alerts not created, wrong label, or queries return nothing | Check `--print-alert-queries` vs. alerts in Google; check the label filter |
| SC Malaysia FAILED with parse error | SC website layout changed | Update the selector/endpoint in `config/settings.json` or `collectors/securities_commission.py` |
| Email NOT SENT | App password missing/changed, or sending limits | Setup → Email accounts and passwords → *Test sign-in* / *Send test email*; the report is still in `reports\` and can be sent with More → Run again and re-send |
| Exit code 3 | Another run in progress, or stale lock | Wait; if no run is active, the lock clears automatically after the maximum run time (`settings.json` → `run.max_run_minutes`, default 120). `data\run.lock` shows the process id, computer and start time of the run holding it; delete it by hand only if that run is certainly not active |
| Task did not run | Laptop off/asleep, task disabled | Confirm "run as soon as possible after a missed start" is ticked |

---

## 8. Handover checklist (if the client adopts the system)

- [ ] Client provides the machine or server that runs the weekly task.
- [ ] Google Alerts recreated under a **client-owned** Google account; alerts mailbox is client-controlled.
- [ ] `config/email.json` updated with the client's sending account and recipients (e.g. the originally named compliance recipient).
- [ ] App passwords saved in the app (Setup → Email accounts and passwords) under the client's Windows account; developer passwords removed (*Remove saved passwords*) and any `NS_*` environment variables deleted.
- [ ] Any optional API apps (Meta, LinkedIn) registered and authorised by the client's own admin accounts.
- [ ] Scheduled task created under the client's account and test-run.
- [ ] Client has read and accepted the limitations in `FEASIBILITY_GATE.md` §4.
- [ ] Developer access removed.
