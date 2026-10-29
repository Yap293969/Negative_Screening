# Feasibility Gate

Go / no-go assessment for starting development, the limitations the client is accepting, and the criteria each phase must meet.

---

## 1. Gate outcome

| Gate | Result | Date |
|---|---|---|
| Original scope — complete scanning of Facebook, Instagram, LinkedIn plus websites and securities commissions | **NO-GO** | Sep 2026 |
| Revised scope — best-effort discovery through free, legitimate methods (client compromise) | **GO, with conditions** | 29 Sep 2026 |

**Why the original scope failed:** platform-wide search of Facebook, Instagram and LinkedIn is only available to logged-in users and is blocked as bot access when automated; the only ways around that (personal-account scraping, evasion techniques) breach platform terms and risk account bans; official APIs only cover pages the requester administers, and the developer has no admin rights on the company's pages.

**Why the revised scope passes:** every requirement in the revised brief can be met with free, legitimate methods (§2), as long as coverage is described honestly as best-effort.

**Conditions of the GO:**

1. The client accepts the limitations in §4 (PROJECT_STATE O-9).
2. No paid service, anti-bot technique or direct social scraping is introduced (FINAL_ARCHITECTURE; SOURCE_ACCESS_BLUEPRINT §1).
3. The non-API pipeline is completed end-to-end before any optional API connector.

---

## 2. Requirement feasibility

| Requirement | Feasible? | How | Residual limitation |
|---|---|---|---|
| Weekly automatic run on Monday | Yes | Windows Task Scheduler | Machine must be on, or catch up after a missed start |
| Manual run on any day, same period rule | Yes | `python negative_screening.py`; one period function | — |
| Previous complete Mon–Sun week, MYT | Yes | `calculate_previous_completed_week()` | — |
| Facebook / Instagram / LinkedIn discovery | **Partially** | Google-indexed content via Google Alerts | Only indexed public content; not a complete record |
| Exact post/comment URLs for social items | **Partially** | URL pattern + snippet evidence; VERIFIED/PARTIAL/REJECTED | Many social hits will be PARTIAL; URLs never guessed |
| Content dates for social items | **Partially** | Snippet/URL-derived dates where possible | Many will be UNKNOWN → manual review |
| Company website monitoring | Yes | RSS / public endpoint / HTML | Depends on site structure |
| SC Malaysia monitoring | Yes | Public pages | Layout changes can break parsing (reported as FAILED) |
| External news | Partially | Google-indexed whole-web alerts, listed as Public website | Only what Google alerts on; no dedicated news feed (owner's decision) |
| Adverse keyword dictionary (configurable) | Yes | JSON config | English-only unless extended (O-4) |
| Entity filter | Yes | JSON config, context rules | Only approved names |
| Contextual NLP screening | **Excluded** | Owner's decision (PROJECT_STATE D-12) | Adverse content without an approved keyword is not detected |
| URL/platform verification | Yes | `url_validator` | See social limitations above |
| Deduplication and re-run safety | Yes | SQLite keys | Syndicated copies on different outlets stay separate |
| Excel report with summary and source health | Yes | openpyxl from SQLite | — |
| Email with attachment | Yes | SMTP + app password | Needs mailbox app password; client account later |
| Failure isolation | Yes | Per-source isolation | — |
| Complete Internet coverage | **No** | — | Explicitly out of scope; never claimed |

---

## 3. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Google Alerts returns few or no social results | High | Medium | Tier 1 + Tier 2 queries; whole-web alerts; staff check of own pages (M11); optional APIs later; report states coverage honestly |
| Google Alerts ignores `site:`/`OR` operators | Medium | Low | Test in Phase 2; simplify queries; Python filtering compensates |
| Google changes or retires Alerts | Low | High | Collector interface allows swapping to RSS mode or another discovery source |
| False positives (e.g. "fees charged") | High | Medium | Name + keyword requirement, ambiguity flags, keyword-to-name proximity, NEEDS REVIEW status, staff review |
| False negatives (content without an approved keyword) | High | Medium | Accepted by the owner (no NLP); extend the keyword list, incl. Malay/Chinese (O-4); staff check of own pages (M11) |
| SC / website layout changes | Medium | Medium | Selectors in config; FAILED status visible; manual fallback |
| Laptop off on Monday | Medium | Low | Task Scheduler catch-up; manual run any day |
| Credential leakage | Low | High | Environment variables only; log redaction; `.env.example` without values |
| Duplicate emails from re-runs | Medium | Low | `email_log` guard; manual default no-send |
| Handover friction (developer-owned accounts) | Medium | Medium | All accounts/recipients in config; handover checklist (OPERATIONS_GUIDE §8) |

---

## 4. Known limitations (for client acceptance)

1. **Not complete coverage.** The system reports what its sources surfaced. It cannot see private or login-only content, closed groups, stories, direct messages, or anything Google has not indexed.
2. **Social media is discovered indirectly** through Google's index. Instagram and Facebook are indexed far less than news sites; results may be few.
3. **Delays.** Content can take days or weeks to be indexed, so some items appear in a later week's report (by their content date) or in the Date Unknown sheet.
4. **Many social items will be PARTIAL or date UNKNOWN,** because social pages are not fetched. Staff must open the link to confirm.
5. **Keyword results are screening aids, not findings of fact.** A flagged item may be false or irrelevant; an unflagged item may still matter. Every item needs human verification before any action.
6. **English keyword dictionary** unless Malay/Chinese terms are approved.
7. **Only approved entities** are monitored.
8. **Source failures are shown, not hidden.** A FAILED source means that source was not checked that week.
9. **Prototype ownership.** Until handover, alerts, mailbox and email run on the developer's account; the client should move them to client-controlled accounts before relying on the system.
10. **Keyword-only screening (no NLP).** Content is reported only when it names an approved target and uses an approved keyword. Negative content phrased differently (e.g. "scam", or in Malay/Chinese) is not reported unless those words are added to the keyword file.

---

## 5. Phase acceptance criteria

| Phase | Done when |
|---|---|
| 1 Core framework | Config files load and validate; the period function passes all example tests (incl. year boundary); SQLite schema created; logging writes run files with secrets redacted; URL normalisation and dedup unit tests pass |
| 2 Discovery | Each collector returns `SourceResult` with correct status; Google Alerts collector extracts decoded target URLs, titles, snippets, received times and query ids from real alert emails; website and SC collectors return in-window items; public-web result pages are fetched politely and social pages never; a forced failure in one source leaves others working |
| 3 Screening | Name and keyword matching pass tests including ambiguity and proximity cases; rules R1–R7 tested; no NLP code or dependency present |
| 4 Verification | Platform, content type, URL type and VERIFIED/PARTIAL/REJECTED assigned per the pattern tables; no URL is constructed or guessed (tested) |
| 5 Reporting | Excel generated from SQLite with Summary (metadata, coverage statement, source health, counts), Findings, Date Unknown and Unverified URL sheets; re-run regenerates without duplicates and archives the previous file |
| 6 Email | Report emailed with attachment; send decision follows FINAL_ARCHITECTURE §9; no duplicate email on re-run; failure logged without losing the report |
| 7 Scheduling | Task created per OPERATIONS_GUIDE §6; a scheduled run completes with Execution Mode = Automatic; missed-start catch-up verified |
| End-to-end | One full real week processed from all non-API sources to emailed report, reviewed with the client |
