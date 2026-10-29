# Source Access Blueprint

How each source is reached, what is collected from it, and what is never done. Processing rules (dates, names, keywords, URL verification) are in `DATA_COLLECTION_ANALYSIS.md`; the reasons behind each choice are in `METHOD_SELECTION_SIMULATION.md` and `DECISION_MATRIX.md`.

---

## 1. Access principles (apply to every source)

1. Use **free, legitimate and maintainable** access only. No paid subscription is introduced without client approval.
2. **Direct Google Search HTML scraping and anti-bot-evasion methods are NOT selected** as the production architecture.
3. Never used, for any source:
   - CAPTCHA solving
   - proxy rotation
   - browser fingerprint spoofing
   - anti-bot bypassing, or "undetected" browser automation built to evade detection
   - scraping with personal login cookies or a personal account
   - bypassing platform access controls
4. Facebook, Instagram and LinkedIn are **never crawled directly** (no Selenium/Playwright/requests against those sites). Their content is discovered only where it is publicly indexed by Google, or later through official APIs the client authorises.
5. Direct retrieval (Company website, SC Malaysia, and non-social public web pages returned by Google Alerts) uses a descriptive User-Agent, respects `robots.txt`, keeps request rates low (one site, one request at a time, with a delay), and caches within a run.
6. Every source reports a health status each run: **SUCCESS**, **FAILED** or **SKIPPED** (not configured / disabled). "No results" and "could not scan" are never the same thing.
7. No source is assumed to be complete. The report always carries the coverage statement.

---

## 2. Google-indexed public-content discovery (Google Alerts)

**Classification:** search-indexed public-content discovery. This is *not* direct social-media access and *not* a complete social-media database. It finds pages Google has indexed and chosen to alert on.

### 2.1 Flow

```text
Google Search index
       ↓
Google Alerts (configured queries)
       ↓
Alert email → designated mailbox (Gmail label, e.g. "NS-Alerts")
       ↓
Python email collector (IMAP, read-only)
       ↓
Extract per result: title, snippet, alert received time,
                    target URL, source/publisher text, alert query id
       ↓
URL decoding + normalisation → platform from the URL hostname
       (Facebook / Instagram / LinkedIn / anything else = Public website)
       ↓
Public website results only: page fetched once, politely, for text + date
(Facebook / Instagram / LinkedIn pages are never fetched)
       ↓
name + keyword screening (rule-based, no NLP) → URL verification
```

### 2.2 Collector rules

- Reads only emails from the Google Alerts sender in the designated label/folder. It does not read other mail.
- Alert links are Google redirect links (`https://www.google.com/url?...&url=<target>...`). The collector **decodes the `url` parameter** to get the target URL. It does not follow the redirect and does not visit social-media URLs.
- The alert query text (e.g. `site:linkedin.com "<Company Name>"`) is stored as the query identifier so each finding records how it was discovered.
- **Mail window:** the collector reads alerts received from `period_start` until the time of the run. This catches content from late Sunday whose alert arrives on Monday, and means a manual re-run later in the week picks up late alerts. Inclusion in the report is then decided by the **content date**, not the email date (see DATA_COLLECTION_ANALYSIS §2).
- **Platform identification:** every result URL is classified from its hostname — `facebook.com` → Facebook, `instagram.com` → Instagram, `linkedin.com` → LinkedIn. Anything that cannot be identified is listed as **Public website** (news sites, blogs, forums, other pages). The alert query never decides the platform.
- **Public website results** may be fetched once (setting `fetch_public_web_pages`) to read the page text and its publication date. Social-platform result pages are never fetched.
- Emails are not deleted or modified. The mailbox doubles as an audit trail and allows any past week to be re-processed.

### 2.3 Alert query plan

Google Alerts only surfaces what matches its query, so the plan balances recall against alert volume. Python performs the real keyword screening, so alerts do not need one query per keyword.

Only results that contain an approved name **and** an approved adverse keyword are reported (DATA_COLLECTION_ANALYSIS §7). Tier 1 alerts widen recall; the keyword filter is applied in Python.

**Tier 1 — entity alerts (broad recall).** One alert per strong entity term per scope:

| Scope | Company (full) | Company (short) | Company (Chinese, D-28) | Founder |
|---|---|---|---|---|
| `site:facebook.com` | `"<Company Name> Sdn Bhd"` | `"<Company Name>"` | `"<Chinese name, Simplified>"`, `"<Chinese name, Traditional>"` | `"<Founder Name>"` |
| `site:instagram.com` | same | same | same | same |
| `site:linkedin.com` | same | same | same | same |
| whole web (no `site:`) | same | same | same | same |

= up to 20 alerts. The founder's Chinese name is not an alert: it is a common Chinese name (D-29). (The full name is a subset of the short name for matching purposes; both are kept because Google Alerts' ranking of exact long phrases can differ. Drop the full-name alerts if they only produce duplicates.)

**Tier 2 — entity + adverse-category alerts (targeted recall).** One alert per strong entity term per keyword *category*, with the category's keywords joined by `OR`, for example:

```text
"<Company Name>" ("money laundering" OR aml OR fraud OR embezzlement OR "tax evasion")
"<Company Name>" (sanctions OR "enforcement action" OR "regulatory penalty" OR "asset freeze" OR "cease and desist")
"<Founder Name>" (arrested OR charged OR convicted OR indictment OR prosecution)
```

Tier 2 uses the shortest **English** name of each entity, because its keywords are English. Long categories (Sanctions/Regulatory has 23 terms) are split into 2–3 alerts. This gives roughly 40 alerts in total (42 with the Chinese company names), well inside Google Alerts' per-account limit and small enough to maintain by hand.

**Rules**

- A single word of the company name on its own is **never** used as an alert query, and since D-27 (5 Oct 2026) it is not matched in Python either: only the full company name (and its approved forms) counts (see DATA_COLLECTION_ANALYSIS §3).
- Personnel alerts are created only for approved names.
- The full query list is generated from `config/entities.json` and `config/adverse_keywords.json` by a helper command (`python negative_screening.py --print-alert-queries`) so the alerts always match the dictionaries. Creating the alerts in the Google account is a manual, one-time step (OPERATIONS_GUIDE §3).
- Support for `site:` and `OR` inside Google Alerts must be confirmed during Phase 2 by checking that test alerts return matching results. If an operator is not honoured, the query is simplified and Python filtering compensates.

**Recommended alert settings:** How often = *At most once a day*; Sources = *Automatic*; Language = *Any language*; Region = *Any region*; How many = *All results*; Deliver to = the designated mailbox.

### 2.4 Fallback: Google Alerts RSS delivery

Google Alerts can deliver to an RSS feed instead of email. This avoids mailbox credentials, but a feed only keeps recent entries, so a missed week can lose results, and there is no mailbox audit trail. It is kept as a **documented fallback** behind the same collector interface (`collectors/google_alerts.py` supports `mode: "imap"` or `mode: "rss"`), not the initial choice.

### 2.5 Known limitations

- Google indexes only part of Facebook, Instagram and LinkedIn. Content that is private, in closed groups, behind login walls, in stories, or simply not indexed will **not** be found.
- Indexing delay can be days or weeks, so some content surfaces in a later week than it was posted (it is then reported by content date, or held for manual review if the date is unknown).
- Alert snippets are short and alerts rarely carry a publication date.
- Google decides which matches are "alert-worthy"; this cannot be controlled.

---

## 3. Social platforms

For all three platforms the **prototype discovery method is Google Alerts (§2)**. Official APIs are optional future connectors (`collectors/api/`), implemented only after the non-API pipeline works end-to-end *and* the client supplies authorised access.

What the system attempts to determine for each discovered social result: platform, content type, title/snippet, URL, date (if available), matched entity, matched adverse keyword, URL verification status. It **never claims a URL is a specific post or comment unless there is sufficient evidence** (DATA_COLLECTION_ANALYSIS §8).

### 3.1 Facebook

| Level | Method | Status |
|---|---|---|
| Prototype | Google-indexed public content via Google Alerts | Selected |
| Future (authorised) | Meta Graph API for the client's own Facebook Page (posts, comments, ratings/reviews on that Page) | Optional — needs client Page admin authorisation and Meta app review |
| Never | Direct Facebook scraping, logged-in browser automation | Rejected |

URL patterns used as classification *signals* (not proof):

| Pattern (path/query) | Likely content type |
|---|---|
| `/<page>/posts/<id>`, `/permalink.php?story_fbid=…`, `/story.php?story_fbid=…` | Post |
| `…&comment_id=<id>` on a post URL | Comment on a post |
| `/groups/<group>/posts/<id>`, `/groups/<group>/permalink/<id>` | Group post |
| `/reel/<id>`, `/watch/?v=<id>`, `/<page>/videos/<id>` | Video / reel |
| `/photo/?fbid=…`, `/photo.php?fbid=…` | Photo |
| `/share/p/…`, `/share/r/…` | Share link (type unknown until resolved — not resolved, so PARTIAL) |
| `/<page>` , `/<page>/about`, `/profile.php?id=…` | Page / profile |
| `/<page>/reviews` | Page reviews tab (not a specific review) |
| `/groups/<group>` | Group home |
| `/search/…`, `/hashtag/…`, `/login…` | Search / hashtag / login (rejected as evidence) |

### 3.2 Instagram

| Level | Method | Status |
|---|---|---|
| Prototype | Google-indexed public content via Google Alerts | Selected |
| Future (authorised) | Instagram Graph API for the client's own professional account (its media and comments on it) | Optional — needs client account authorisation |
| Never | Direct Instagram scraping | Rejected |

| Pattern | Likely content type |
|---|---|
| `/p/<shortcode>/` | Post |
| `/reel/<shortcode>/`, `/reels/<shortcode>/` | Reel |
| `/tv/<shortcode>/` | Video (IGTV) |
| `/<username>/` | Profile |
| `/stories/…` | Story (ephemeral; normally not indexed) |
| `/explore/tags/…`, `/explore/…` | Hashtag / explore page (rejected as evidence) |

URL structure alone does not prove content type; the snippet/title and alert query are used as additional signals.

### 3.3 LinkedIn

| Level | Method | Status |
|---|---|---|
| Prototype | Google-indexed public content via Google Alerts | Selected |
| Future (authorised) | LinkedIn Community Management API for the client's own Company Page (posts, comments, mentions of the Page) | Optional — needs client Page admin and LinkedIn app approval |
| Never | Selenium / Playwright / requests scraping of LinkedIn | Rejected |

| Pattern | Classified as |
|---|---|
| `/posts/<slug>-activity-<id>-…`, `/feed/update/urn:li:activity:<id>` | Individual post |
| `/pulse/<slug>` | Article (LinkedIn Pulse) |
| `/company/<name>` (and sub-pages) | Company page |
| `/in/<name>` | Profile |
| `/jobs/…`, `/school/…`, `/search/…` | Other — not evidence |
| anything else | Unknown |

---

## 4. Company public website

Direct public retrieval, in this preferred order:

1. RSS/Atom feed, if one exists
2. A public official endpoint, if confirmed (e.g. a WordPress REST API `/wp-json/wp/v2/posts`, only if the site exposes it publicly)
3. Public HTML retrieval with `requests` + `BeautifulSoup` (news/announcement/blog listing pages → article pages)
4. Browser automation (e.g. Playwright) **only** if the content genuinely requires JavaScript and this is permitted — not expected

Collected: title, publication date, URL, text/summary, publicly visible comments (if the site has any), source type (`Company website`).

Phase 2 task: inspect the site once to confirm which of 1–3 is available and record the chosen endpoint in `config/settings.json`.

**Inspection result (29 Sep 2026):** the site runs WordPress and publishes an RSS feed, so option 1 is used: the site's `/feed/` (10 newest posts; older posts via `?paged=N`, 404 past the last page) and the site-wide comments feed `/comments/feed/` (empty at the time of inspection). `robots.txt` only disallows `/wp-admin/`. The item `pubDate` (when the company posted it) is used as the publication date; a date printed inside a post (often the date of a re-posted news article) is kept as a note. A public WordPress REST API also exists but is not needed.

---

## 5. Securities Commission Malaysia

Treated **separately** from social-media results. Relevance matters more than tone: a neutral regulatory notice that names the entity is still relevant.

Monitored public pages (exact URLs confirmed and recorded in `config/settings.json` during Phase 2):

- Investor Alert List (full list — searched for entity names each run)
- Investor Alert updates / latest additions
- Public media releases and announcements
- Other relevant public regulatory/enforcement information pages

Method: `requests` + `BeautifulSoup`. If a page offers a downloadable list or feed, that is preferred over HTML parsing.

Output classification: **Regulatory / Potentially Adverse**. Any entity match on the Investor Alert List is automatically CRITICAL / MANUAL REVIEW.

Date handling: for announcements, the published date on the page; for the Investor Alert List, the "date added" if shown. If the list gives no full date, a newly appearing entity match is listed in the reporting week of the run in which it first appeared; that week is never presented as its date (date status `FIRST_SEEN` when the list gives no date at all).

**Pages confirmed (29 Sep 2026):** `robots.txt` allows all. Investor Alert List: `https://www.sc.com.my/investor-alert-list`; media releases: `https://www.sc.com.my/resources/media/media-release`. Both pages embed their complete data as JSON in a page script (about 1,970 alert-list entries; about 1,690 releases back to 1995), which is read instead of the visual layout; if that data disappears the source is reported FAILED ("layout changed"), never as "no hits". Alert-list entries state only a **year**, which becomes the entry's event / content date at year precision (`VERIFIED (year only)`, e.g. `2022`, Historical Status `HISTORICAL` in a 2026 report). The entry belongs to the reporting week of the run that first found it (looked up in the database), and is not repeated as new in later weeks. An entry is recognised across runs by its **name and website(s)**: the page's own data keys are random and change on every page load (found in validation, 30 Sep 2026), so they are never used as identity — otherwise the same entry would be reported as a new CRITICAL item every week. Media releases carry a day-precision date. Alert-list rows are pre-selected with the approved names, variants and ambiguous terms; the entity matcher then decides (e.g. an entry listing a look-alike website was pre-selected and judged by the single-word context rule before D-27).

---

## 6. External news

There is **no separate news collector** in the current build (owner's decision, 29 Sep 2026). News articles are discovered through the **whole-web Google Alerts** (Tier 1 and Tier 2 queries without a `site:` prefix) and appear in the report with platform **Public website**. Their pages are fetched once, politely, to confirm the name, the keyword and the publication date; paywalled or blocked pages keep the alert title/snippet only.

The GDELT DOC API and outlet RSS feeds remain documented alternatives in `METHOD_SELECTION_SIMULATION.md` §4, not part of the build. No paid news subscription is introduced.

---

## 7. Source health reporting

Each run records one status per source:

```text
Google Alerts     SUCCESS   (mailbox read, 14 alert emails, 37 results)
Facebook          SUCCESS   (via Google Alerts — 5 results)
Instagram         SUCCESS   (via Google Alerts — 0 results)
LinkedIn          SUCCESS   (via Google Alerts — 3 results)
Public website    SUCCESS   (via Google Alerts — 29 results)
Company website  SUCCESS
SC Malaysia       FAILED    (HTTP 503 after 3 retries)
```

- Facebook / Instagram / LinkedIn / Public website all depend on Google Alerts. If the mailbox cannot be read, all of them show `FAILED (Google Alerts unavailable)` — they are never shown as SUCCESS with zero results.
- A source with some sub-parts failing (e.g. one of several Company website listing pages unreachable) is SUCCESS with a warning listing what failed. If its main path fails, it is FAILED.
- When an optional API connector is enabled later, it gets its own row.
- A FAILED row in the report reads "*<Source>: scan failed — absence of findings for this source does not mean no adverse content exists.*"

### 7.1 Live access status (validation runs, 30 Sep 2026)

Validation runs (`--validate`, staging database) for 14–20 Sep 2026 and — via `--scheduled` — 21–27 Sep 2026, from Python and from the packaged `NegativeScreening.exe`:

| Source | Code | Live access on the development machine |
|---|---|---|
| Company website (RSS feed) | verified by self-tests | **working** — feed read, SUCCESS (0 items in either week) |
| SC Malaysia (Investor Alert List + media releases) | verified by self-tests | **working** — SUCCESS; the one alert-list match is CRITICAL in its first week and not repeated as new in the next |
| Google Alerts → Facebook / Instagram / LinkedIn / Public website | verified by self-tests (fake mailbox and feeds) | **not yet configured** — no mailbox app password saved, so all five rows show FAILED with "Google Alerts email access is not configured", as designed |

When the mailbox password is missing, the source is **FAILED** (never "no findings"); the staff window says "Google Alerts email access has not been configured — open Setup → Email accounts and passwords" instead of showing an error trace. The password is never logged.

Google Alerts remains the only discovery path for social and whole-web content: no Google Search scraping, browser automation or anti-bot measures are used (§1, PROJECT_STATE D-02).
