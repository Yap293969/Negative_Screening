# Method Selection & Simulation

Every discovery/access method considered for this project, with its feasibility, cost, limitations, decision and possible future use. Alternatives are **kept on record even when not selected**, so the client can revisit them (e.g. if budget or authorised access becomes available). Scores behind these decisions are in `DECISION_MATRIX.md`.

Decision labels: **SELECTED** (in the prototype) · **FALLBACK** (supported alternative behind the same interface) · **OPTIONAL FUTURE** (built only with client authorisation/approval) · **DEFERRED** (possible later, not planned) · **REJECTED** (will not be used) · **NOT AVAILABLE** (cannot be obtained for this use).

---

## 1. Social-media discovery (Facebook, Instagram, LinkedIn)

### M1 — Google Alerts, email delivery · **SELECTED**

| | |
|---|---|
| What | Alerts on Google-indexed content for entity (and entity + keyword-category) queries, delivered to a mailbox that Python reads over IMAP. |
| Feasibility | High. No platform access needed; free Google account; IMAP and email parsing are standard library. |
| Cost | Free. |
| Limitations | Only finds content Google indexes and chooses to alert on; sparse for Instagram and Facebook; indexing delays; short snippets; rarely includes a publication date; operator support (`site:`, `OR`) must be confirmed; alerts must be created by hand. |
| Why selected | The only free, legitimate way to discover public social content about the company across all three platforms without crawling them. The mailbox keeps a full history, so any past week can be re-processed and missed runs lose nothing. Easy to hand over by recreating alerts under a client account. |
| Future use | Remains the discovery layer for content the company does not own, even after APIs are added. |

### M2 — Google Alerts, RSS delivery · **FALLBACK**

| | |
|---|---|
| What | Same alerts, delivered as RSS feeds read with `feedparser`. |
| Feasibility | High. |
| Cost | Free. |
| Limitations | Each feed keeps only recent entries, so a machine that is off for a while can miss results; no mailbox audit trail; one feed URL per alert to manage. |
| Why not primary | Weaker reliability and auditability than email for a weekly job on a single laptop. |
| Future use | Switch `google_alerts.mode` to `"rss"` if mailbox access is not allowed in the client's environment. |

### M3 — Scraping Google Search result pages · **REJECTED**

| | |
|---|---|
| What | Automated `site:facebook.com "…"` searches, parsing Google's HTML results. |
| Feasibility | Technically possible short-term, unreliable long-term: Google blocks automated queries (CAPTCHAs, rate limits), and keeping it working requires the evasion techniques this project prohibits. |
| Cost | Free in money; high in maintenance. |
| Limitations | Against Google's terms; breaks without warning; IP blocking. |
| Why rejected | **Direct Google Search HTML scraping and anti-bot-evasion methods are not selected as the production architecture.** |
| Future use | None. |

### M4 — Search APIs (Google Programmable Search JSON API, commercial SERP APIs) · **DEFERRED**

| | |
|---|---|
| What | Official or third-party APIs returning search results as JSON. |
| Feasibility | Medium. Google's own API has historically had a small free daily quota and restrictions for new projects; availability and terms must be re-checked before use. Commercial SERP APIs work but are paid. |
| Cost | Free tier small or unavailable; paid beyond that. |
| Limitations | Quota limits the number of queries per week; paid services need client approval; third-party SERP services raise their own terms questions. |
| Why deferred | Google Alerts covers the same index for free at this project's volume. |
| Future use | Add as another collector if the client approves a budget, or to run on-demand searches for a specific incident. |

### M5 — Direct scraping of Facebook / Instagram / LinkedIn · **REJECTED**

| | |
|---|---|
| What | Selenium / Playwright / requests against the platforms, with or without a logged-in personal account. |
| Feasibility | Low. Platform-wide search needs login; platforms detect and block automation; sustained use requires CAPTCHA solving, proxies, fingerprint spoofing or cookie reuse. |
| Cost | Free in money; high risk. |
| Limitations | Breaches platform terms; personal accounts get restricted or banned; constant breakage; legal/reputational risk for the client. |
| Why rejected | Proven unworkable during feasibility, prohibited by the project rules, and the client has withdrawn the requirement for complete scanning and direct crawling. |
| Future use | None. |

### M6 — Meta Graph API (Facebook Page) · **OPTIONAL FUTURE**

| | |
|---|---|
| What | Official API access to the client's own Facebook Page: its posts, comments on them, and Page ratings/recommendations. |
| Feasibility | Feasible only with authorisation from a Page admin at the client; a Meta developer app; and the required permissions (some need Meta app review/business verification). |
| Cost | Free. |
| Limitations | Covers the client's **own** Page, not the whole of Facebook. Public-content search across Facebook is not available for this use case. Tokens expire and permissions change over time. |
| Why not now | The developer has no admin rights on the company's Page; the non-API pipeline comes first. |
| Future use | Best way to reliably capture complaints posted as comments on the company's own Page, with exact comment URLs and timestamps. |

### M7 — Instagram Graph API (professional account) · **OPTIONAL FUTURE**

| | |
|---|---|
| What | Official API access to the client's own Instagram professional account: its media and comments, plus mentions/tags where the API exposes them. |
| Feasibility | As M6 — needs the account linked to a Facebook Page and client authorisation. |
| Cost | Free. |
| Limitations | Own account only; no general search of Instagram; hashtag features are limited and rate-capped. |
| Why not now | No authorised access yet. |
| Future use | Comment monitoring on the company's own Instagram posts. |

### M8 — LinkedIn Community Management API · **OPTIONAL FUTURE**

| | |
|---|---|
| What | Official API access to the client's LinkedIn Company Page: posts, comments on them, and mentions of the Page. |
| Feasibility | Needs a LinkedIn developer app approved for the Community Management product and a Page admin to authorise it. Approval is not guaranteed. |
| Cost | Free. |
| Limitations | Own Page only; no general LinkedIn search; approval process and access reviews. |
| Why not now | No Page admin rights; approval uncertain; non-API pipeline first. |
| Future use | Comment/mention monitoring on the company's Page. |

### M9 — CrowdTangle / Meta Content Library · **NOT AVAILABLE**

| | |
|---|---|
| What | Meta's research tools for public content across Facebook/Instagram. |
| Feasibility | CrowdTangle was shut down by Meta in 2024. Meta Content Library access is limited to qualifying researchers/non-commercial use through an application process. |
| Cost | — |
| Why | Not obtainable for a commercial company's monitoring. |
| Future use | None expected. |

### M10 — Paid social-listening platforms (e.g. Brand24, Meltwater, Talkwalker, Mention) · **REJECTED (cost), strongest future upgrade**

| | |
|---|---|
| What | Commercial services that monitor social and news mentions through their own data agreements. |
| Feasibility | High — ready-made coverage, dashboards and alerts. |
| Cost | Monthly subscriptions; not approved. |
| Limitations | Cost; vendor lock-in; coverage of Malaysian/Malay-language content varies by vendor. |
| Why rejected | The project must not introduce paid subscriptions without approval. |
| Future use | If the client later wants broader coverage than free methods allow, this is the most effective upgrade. Several vendors offer exports/APIs that could feed this system as another collector. |

### M11 — Staff check of the company's own pages · **COMPLEMENTARY PROCEDURE**

Until M6–M8 are authorised, a staff member who administers the company's Facebook, Instagram and LinkedIn pages can review new comments on those pages weekly. This is not automated and not part of the software, but it closes the most obvious coverage gap at no cost. Recorded here as a recommendation to the client.

---

## 2. Company public website

| # | Method | Decision | Notes |
|---|---|---|---|
| W1 | RSS/Atom feed | **SELECTED if available** | Most stable; includes dates. |
| W2 | Public official endpoint (e.g. a public CMS JSON API) | **SELECTED if W1 absent and endpoint is public** | Structured data; confirm it is intended to be public. |
| W3 | `requests` + BeautifulSoup on listing/article pages | **FALLBACK** (likely in practice) | Free, simple; breaks if the layout changes. |
| W4 | Browser automation (Playwright) | **ONLY IF NECESSARY AND PERMITTED** | Heavier; only for content that needs JavaScript. Not expected. |

Cost: free for all. Limitation: the company's own site rarely contains adverse content; its value is comments (if any) and confirming what the company itself published.

---

## 3. Securities Commission Malaysia

| # | Method | Decision | Notes |
|---|---|---|---|
| S1 | `requests` + BeautifulSoup on public Investor Alert List, updates, media releases and enforcement pages | **SELECTED** | Free; public; low volume. Layout changes are the main risk → selectors in config, failures reported as FAILED. |
| S2 | Downloadable list / feed from SC, if offered | **PREFERRED over S1 where it exists** | Checked in Phase 2. |
| S3 | Manual check by staff | **FALLBACK** | If the page structure changes and a fix is pending. |

Classification is Regulatory / Potentially Adverse.

---

## 4. External news

**Current build:** no dedicated news collector (owner's decision, 29 Sep 2026). News is discovered through whole-web Google Alerts (M1) and reported as **Public website**. The methods below are kept on record only.

| # | Method | Decision | Feasibility / cost / limitations |
|---|---|---|---|
| N0 | Google Alerts whole-web queries (M1) | **SELECTED** | Free; same pipeline as social discovery; only what Google alerts on. |
| N1 | GDELT DOC 2.0 API | **NOT IN CURRENT BUILD** (owner's decision) | Free, no key; broad coverage; "seen date" ≠ publication date. Possible future collector. |
| N2 | RSS feeds of Malaysian/regional outlets | **NOT IN CURRENT BUILD** (owner's decision) | Free; good for local outlets; feeds keep recent items only. Possible future collector. |
| N3 | Google News RSS search | **NOT IN CURRENT BUILD** | Free; terms of use to be checked. |
| N4 | News APIs with free developer tiers (e.g. NewsAPI) | **REJECTED** | Free tiers are typically limited to development/non-commercial use or delayed results. |
| N5 | Paid media-monitoring databases (e.g. Factiva, LexisNexis) | **REJECTED (cost)** | Best adverse-media coverage; paid; possible future upgrade with approval. |

---

## 5. Supporting choices

| Area | Selected | Alternatives considered | Reason |
|---|---|---|---|
| Scheduling | Windows Task Scheduler starts the app every Monday; Python computes the period and never waits | Python infinite loop / `schedule` library (**rejected**: fragile, stops on reboot, wastes resources); cloud scheduler/hosting (**deferred**: may cost money; requires moving off the laptop) | Free, built into Windows, survives reboots, supports catch-up after missed runs |
| Manual runs | Same `negative_screening.py`, any day, same period rule | Separate manual script (**rejected**: duplicate logic) | One pipeline, consistent results |
| Storage | SQLite | Excel as database (**rejected**: no dedup/history integrity); a server database (**rejected**: unnecessary for one machine) | Free, file-based, reliable, supports re-run safety |
| Screening | Approved name + adverse keyword rules, with ambiguity flags and keyword-to-name proximity | mBERT / NLP sentiment (**EXCLUDED** by the owner, 29 Sep 2026 — only the owner can reinstate it); LLM API (**rejected**: cost, sends content to a third party) | Transparent, predictable, free; every flag can be explained by the rule that fired |
| Email | SMTP with app password from environment variables | Gmail API with OAuth (**fallback**: stronger but more setup) | Simple for the prototype; credentials never in code |

---

## 6. Simulation — one manual run, end to end

> **Illustrative only.** The items below are invented to show how the rules work. They are not real findings about any company or person, and the URLs are placeholders.

**Scenario:** a staff member runs `python negative_screening.py` on **Tuesday 22 September 2026**.

1. Reference date 2026-09-22 → reporting period **14 Sep 2026 00:00:00 – 20 Sep 2026 23:59:59 (MYT)**. Execution mode: Manual.
2. The Google Alerts collector reads alert emails received from 14 Sep to now. The Company website collector reads the company's RSS feed. The SC collector times out three times.

| # | Item (placeholder) | Key steps | Outcome |
|---|---|---|---|
| 1 | Alert (15 Sep): `linkedin.com/posts/<user>_…-activity-<id>-…`, snippet names the company and "fraud" | Hostname → **LinkedIn** · individual post · date derived from activity ID = 15 Sep · name ✓ keyword "fraud" (Financial Crime) near the name · specific URL + snippet match → VERIFIED | **Main findings**, HIGH, PENDING (R4) |
| 2 | Same LinkedIn post from a second alert query, URL with `?trk=…` | Tracking parameter removed → same activity ID → same `url_key` | Merged into #1; "found by 2 queries" |
| 3 | Alert (17 Sep): `facebook.com/<page>` (Page root), snippet with the company name and "ponzi", no date | Hostname → **Facebook** · container URL → PARTIAL · date UNKNOWN · name ✓ keyword ✓ | **Date Unknown — Manual Review** sheet, HIGH (R4 + date rule) |
| 4 | Alert (18 Sep): `instagram.com/explore/tags/<tag>/`, snippet names the company and "scam" | "scam" is not an approved keyword | **Not reported** (R7) — a keyword-only system cannot see it |
| 5 | Alert (18 Sep): `news.example.com/…`, article dated 18 Sep, "asset freeze" near the company name | Hostname not a social platform → **Public website** · page fetched → date VERIFIED · unambiguous immediate-action keyword · page text match → VERIFIED | **Main findings**, **CRITICAL / MANUAL REVIEW** (R2) |
| 6 | Alert: article dated 17 Sep about "management fees charged by" the company | Public website · ambiguous keyword "charged" near the name | **Main findings**, HIGH / NEEDS REVIEW (R3) — a person sees it is about fees and marks it FALSE POSITIVE |
| 7 | Company website article dated 24 Sep | After period end (current incomplete week) | **Excluded**; considered for the 21–27 Sep report |
| 8 | Alert: blog post dated 2 Sep, first surfaced this week | Public website · before the period | Not in main findings; counted as "surfaced this week but dated earlier" |
| 9 | Alert: page using one word of the company name in an unrelated sense | single word without the full company name → no name match | NOT RELEVANT (counted only) |
| 10 | SC Malaysia | 3 timeouts | Source **FAILED**; other sources continue |

**Resulting Summary (excerpt):**

```text
Reporting Period:  14 Sep 2026 – 20 Sep 2026
Report Generated:  22 Sep 2026 10:30 (MYT)
Execution Mode:    Manual
Reference Date:    22 Sep 2026

Google Alerts     SUCCESS    Facebook   SUCCESS (via Google Alerts)
Instagram         SUCCESS    LinkedIn   SUCCESS (via Google Alerts)
Public website    SUCCESS    Company website  SUCCESS
SC Malaysia       FAILED  — scan failed; absence of SC findings does not mean none exist

Candidates discovered 10 · relevant 7 · potentially adverse 3 · critical 1
manual review 3 · unknown date 1 · unverified URLs 0 · dated before period 1
```

**Email:** manual mode with `email.send_on_manual = false` → not sent (logged "manual mode default"). The report is saved as `reports/Negative_Screening_2026-09-14.xlsx`.

**Follow-up:** staff re-run on Thursday after SC recovers → same file name regenerated (previous archived), SC now SUCCESS, items 1–9 not duplicated, no email. On **Monday 28 Sep** the scheduled run scans **21–27 Sep**; item 7 is considered there, and that report is emailed automatically.

Item 4 shows the trade-off the owner accepted by excluding NLP: negative content that does not use an approved keyword is not reported. Adding such words (e.g. "scam", Malay/Chinese terms) to the keyword file is the remedy (PROJECT_STATE O-4).

---

## 7. Conclusion

The selected combination — Google Alerts for search-indexed discovery of public Facebook, Instagram, LinkedIn and other public web content, and direct public retrieval for the Company website and SC Malaysia, screened by transparent name + keyword rules — is the strongest option that is free, legitimate and maintainable within the owner's decisions. It gives **best-effort, not complete** coverage. Official platform APIs (M6–M8), dedicated news collectors (N1–N3) and paid services (M4, M10, N5) remain documented upgrade paths.
