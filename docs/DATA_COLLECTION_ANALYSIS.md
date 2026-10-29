# Data Collection & Analysis

What each record contains and how raw results become report findings: dates, name matching, keyword screening, rule-based flagging, URL verification and deduplication. **No NLP or machine-learning classification is used** (owner's decision, PROJECT_STATE D-12). Source access is in `SOURCE_ACCESS_BLUEPRINT.md`; storage and report layout are in `FINAL_ARCHITECTURE.md`.

---

## 1. Record fields

Every collector returns items in one common shape (`RawItem`), whatever the source. Fields that a source cannot supply stay empty — they are never guessed.

| Field | Meaning |
|---|---|
| `source` | Collector that produced it: `google_alerts`, `website`, `sc_malaysia`, later `api_facebook` etc. |
| `discovery_method` | e.g. `Google Alerts (search index)`, `Direct public retrieval` |
| `discovery_query` | Alert query or page that surfaced it |
| `discovered_url` | URL exactly as delivered (after decoding a Google redirect) |
| `final_url` | URL after redirects of a page that was actually read (Public website result pages, SC Malaysia release pages); empty for social, which is never fetched |
| `title`, `snippet` | As delivered by the source |
| `content_text` | Article/page text where legally and technically available (never for social platforms in the prototype) |
| `publisher` | Outlet / site name where known |
| `alert_received_at` | Google Alerts only: email received time |
| `source_published_at` | Publication date stated by the source (article meta, feed `pubDate`, page date) |
| `content_date` + `date_status` + `date_basis` | Resolved date used for period filtering (see §2) |
| `language` | Detected or source-supplied |

Processing adds: `platform`, `content_class`, `content_type`, `url_type`, `url_verification`, `verification_basis`, `matched_entities`, `matched_keywords`, `keyword_categories`, `keyword_proximity`, `priority`, `rules_applied`, `review_status`, `notes`.

---

## 2. Date handling

Alert/email arrival time is **not** the content date. The system keeps three separate values — alert received date, source publication date, and the resolved content date — and never overwrites one with another.

### 2.1 Resolution order

| Priority | Basis (`date_basis`) | Applies to |
|---|---|---|
| 1 | Date stated in the content's own metadata (`article:published_time`, JSON-LD `datePublished`, `<time datetime>`, feed `pubDate`/`updated`) | Public website pages, Company website, SC announcements |
| 2 | Date shown on the source page next to the item (e.g. SC "date added") | SC Malaysia, website |
| 3 | Date deterministically encoded in the URL, where the encoding is documented and tested (candidate: LinkedIn activity IDs; to be validated in Phase 4 before use) | LinkedIn posts |
| 4 | Date given in the search result/alert snippet text (e.g. "3 days ago", "15 Sep 2026") — recorded as approximate | Google Alerts |
| — | None of the above | → `date_status = UNKNOWN` |

`date_status` values describe how reliable the **event / content date** is — never when the system found the item: `VERIFIED` (1–2), `DERIVED` (3), `APPROXIMATE` (4), `FIRST_SEEN` (an SC list entry that gives no date at all: it has no content date and is listed in the week the system first found it — see SOURCE_ACCESS_BLUEPRINT §5), `UNKNOWN`.

`date_precision` records how precisely the source states the date: `DAY` (a full date, with a time where given), `MONTH` or `YEAR`. A year or month is stored as the start of that year / month only so it can be compared; it is always shown as `2022` / `2022-03`, never as an exact day. A metadata value that is only a year, a month or an ISO week without a day (`2022-W10`) is not read as a date at all.

Implementation notes (S14): a snippet date is used only when the snippet **starts** with it (e.g. "3 days ago …", "Sep 15, 2026 …"), where Google Alerts places the result date; a date later in the snippet is usually an event date inside the content and is ignored, as is a date after the alert arrived. An SC Investor Alert List entry gives only a **year**: that year is its content date (`VERIFIED`, `YEAR` precision), and the entry is placed in the reporting week of the run that first found it, so it is reported once in that week and counts as "dated before the period" afterwards. The first-found week decides only *which report lists it*; it is never stored or shown as the content date. Priority 3 (LinkedIn activity-ID dates) is **not used yet**: it stays off until the decoding is validated against real posts with known dates.

### 2.2 Period filtering

All timestamps are converted to **Asia/Kuala_Lumpur** before comparison. The reporting period is the half-open interval `[period_start 00:00:00, period_end + 1 day 00:00:00)`, i.e. Monday 00:00:00 to Sunday 23:59:59.

| Resolved date | Where it goes |
|---|---|
| Inside the period (`VERIFIED`, `DERIVED`, `APPROXIMATE`), or an SC list entry in the week first found (year-only or `FIRST_SEEN`) | Main findings (date status and Historical Status shown in the row) |
| A year / month-only date that overlaps the period (no first-found week) | Treated as `UNKNOWN`: it cannot be shown to be inside the week |
| `UNKNOWN`, and discovered during the period | **"Date Unknown — Manual Review"** sheet, `review_status = MANUAL REVIEW`. Never placed in the main findings as if it were in-period. |
| Before the period (old content newly surfaced) | Not in the main findings. Stored in the database and counted in the summary as "surfaced this week but dated earlier". Optional audit sheet (`report.include_out_of_period_sheet`). |
| After the period (current incomplete week) | Excluded. It will be reported in the week it belongs to. |

Example: run on Friday 25 Sep 2026 → period 14–20 Sep. A post dated Thursday 24 Sep is excluded and will appear in the report for 21–27 Sep.

### 2.3 Event date, discovery date and Historical Status

The report keeps four date ideas apart:

| Report column | Meaning | Source |
|---|---|---|
| Report Week | The Monday–Sunday week screened | the run's reporting period |
| Event / Content Date | When the incident or source record is dated, at the source's precision (`2022`, `2022-03`, `2026-09-16 09:30`), or `UNKNOWN` | `findings.content_date` + `date_precision` |
| Date Status | Reliability (and, for a partial date, precision) of that date: `VERIFIED`, `VERIFIED (year only)`, `APPROXIMATE`, `FIRST_SEEN`, `UNKNOWN` | `findings.date_status` + `date_precision` |
| Discovery Date | When this system first found the item (its first run) — never the event date | `findings.first_discovered_at` |

**Historical Status** (computed for the report, not stored) compares the event / content date with the reporting week: `CURRENT` (in the week — or a year / month that includes it, which cannot be shown to be older), `HISTORICAL` (the whole date — all of its year or month — is before the week: an older record found or listed this week, not a new incident), `DATE UNKNOWN` (no reliable date). **Record Age** is shown for `HISTORICAL` items, measured to the end of the reporting week and never more precise than the date: e.g. year 2022 in a 2026 week → "approx. 4 years"; a full date → days, then months, then years to the nearest year.

Age does **not** change screening: a HISTORICAL SC Malaysia record keeps its rules, priority and review status and is reported for manual review. The Summary sheet explains each date column and states how many reported items are HISTORICAL.

---

## 3. Entity matching (`config/entities.json`)

Content is only relevant if it concerns a monitored entity. A keyword such as "fraud" on its own never flags anything.

### 3.1 Structure

```json
{
  "version": "2026-09-29",
  "entities": [
    {
      "id": "company",
      "type": "company",
      "display_name": "<Company Name> Sdn Bhd",
      "names": ["<Company Name> Sdn Bhd", "<Company Name>"],
      "variants": ["<Company Name> Sdn. Bhd."],
      "ambiguous_terms": [],
      "approved": true
    },
    {
      "id": "founder",
      "type": "person",
      "display_name": "<Founder Name>",
      "role": "Founder",
      "names": ["<Founder Name>"],
      "variants": ["<Founder Name, given name first>"],
      "ambiguous_terms": [],
      "approved": true
    }
  ]
}
```

The variants shown are formatting variants of approved names. Any new alias, spelling variant (including Chinese-character names) or additional personnel is added **only after client approval** (PROJECT_STATE O-1). Entries with `"approved": false` are ignored.

### 3.2 Matching rules

- Case-insensitive, whitespace- and punctuation-tolerant (`Sdn. Bhd.` = `Sdn Bhd`), whole-word boundaries.
- `names` and `variants` match on their own.
- **Full company name only (D-27, owner, 5 Oct 2026):** the company is matched only by its full name (with or without "Sdn Bhd") or its approved Chinese name. No single word of the name is ever screened, and other companies are out of scope, so `ambiguous_terms` is empty.
- **Chinese names (D-28, D-29, owner, 5 Oct 2026):** the company's Chinese name matches in Simplified and Traditional characters, as an exact character sequence — never part of it. The founder's Chinese name is a common name, so it is an `ambiguous_term`: it counts only when the same item also names the company (English or Chinese) or the founder's English name (`context_window_words` = the whole item). It is never used as a Google Alert.
- `ambiguous_terms` match only when one of `requires_any_context` appears within the context window.
- Text searched: title + snippet + content text (when available) + URL path (e.g. `/company/<company-name>`).
- Each match records which entity, which name form, and where it matched. Every mention is recorded (with its word position), so keyword proximity (§6) is measured to the **nearest** mention; where name forms overlap (e.g. "… Sdn Bhd" and the short name) the longest form is recorded once.
- The URL host is not searched (every page of the company's own website would otherwise "mention" the company); only the path is.
- Latin words are compared as whole words (a longer word that merely starts with a name is not that name). Chinese has no spaces, so each Chinese character is one token and a Chinese name or keyword matches as an exact character sequence; keyword proximity in Chinese text is counted in characters.

---

## 4. Adverse keyword dictionary (`config/adverse_keywords.json`)

The dictionary is the owner's list (confirmed 29 Sep 2026), with spelling corrected ("rrested" → "arrested") and intent preserved. It is configuration (`config/adverse_keywords.json`), not code. Searches target the approved company and personnel names with these keywords.

### 4.1 Categories and keywords

| Category | Priority (default) | Keywords |
|---|---|---|
| Financial Crime | HIGH* | money laundering, aml, ctf, fraud, embezzlement, tax evasion |
| Bribery / Corruption | HIGH* | bribery, corruption, kickback |
| Market Misconduct | HIGH* | insider trading, market manipulation |
| Investment Schemes | HIGH* | ponzi, pyramid scheme |
| Forgery / Counterfeit | HIGH* | forgery, counterfeit |
| Corporate / Financial Misconduct | HIGH* | structuring, shell company, misappropriation |
| **Sanctions & Regulatory Enforcement (Immediate Action)** | **CRITICAL** (owner-specified) | sanctions, ofac, enforcement action, regulatory penalty, indictment, prosecution, subpoena, blacklisted, debarred, asset freeze, cease and desist, seizure, fined, banned, disqualified, arrested, charged, convicted, guilty, sentenced, fugitive, wanted by, extradition |
| Financial Distress | HIGH* | bankrupt, insolvent, receivership |
| Cybersecurity | MEDIUM* | data breach, cyber attack, cybercrime, hacking, ransomware, identity theft, phishing |

\* Only the Sanctions & Regulatory Enforcement priority ("immediate action") was specified. Other priorities are proposed defaults pending confirmation (PROJECT_STATE O-3).

### 4.2 File structure

```json
{
  "version": "2026-09-29",
  "categories": [
    {
      "id": "sanctions_regulatory",
      "name": "Sanctions / Regulatory Enforcement",
      "priority": "CRITICAL",
      "keywords": [
        { "term": "asset freeze", "ambiguous": false },
        { "term": "charged", "ambiguous": true, "note": "also used for fees ('fees charged')" }
      ]
    }
  ]
}
```

Optional per-keyword `"variants"` (e.g. `fraudulent` for `fraud`, `bribe` for `bribery`) extend matching to inflected forms of an approved keyword. New variants are listed for client review before being enabled; no new concepts are added without approval (e.g. "scam", Malay equivalents — PROJECT_STATE O-4). **Chinese equivalents (D-28, owner, 5 Oct 2026)** are each keyword's `variants`, in Simplified and Traditional characters (e.g. `fraud`: 诈骗, 欺诈, 詐騙, 欺詐; `fined`: 罚款, 罰款), so they carry the English keyword's category, priority and ambiguity; the report's Keyword column shows the form found, e.g. "fraud (欺诈)".

### 4.3 Matching rules

- Case-insensitive, whole-word/phrase boundaries (`aml` does not match "Hamlet"; `fined` does not match "refined").
- Short acronyms (`aml`, `ctf`, `ofac`) also match their upper-case forms.
- A keyword counts only if an entity matched in the same item. Keyword–entity proximity (same sentence or within ~30 words) is recorded and raises confidence.

### 4.4 Ambiguous keywords

These terms have common non-adverse meanings and are marked `"ambiguous": true`. They never trigger an automatic CRITICAL flag; they are reported as NEEDS REVIEW for a person to judge (HIGH when the keyword is near the name, REVIEW otherwise — §6–7):

| Keyword | Common non-adverse use |
|---|---|
| charged | "fees charged", "management fee charged" — very common in asset-management text |
| guilty, banned, fined | opinion / unrelated usage, "fine-tuned" (boundaries handle most) |
| seizure | medical usage |
| sanctions | "sanctioned by the board" (approval) |
| structuring | "portfolio structuring", "deal structuring" |
| wanted by | "wanted by investors" |
| aml, ctf | the company describing its own AML/CTF compliance policy (compliant, not adverse) |
| phishing | company *warning customers* about scams impersonating it — relevant, but not an allegation against the company |
| hacking | "growth hacking" |

---

## 5. Candidate selection

```text
RawItem
  → normalise text & URL
  → platform from the URL hostname (§8)
  → approved name found?   ── no ──→ NOT RELEVANT (counted, not reported)
        │ yes
  → adverse keyword found? ── no ──→ not reported (SC Malaysia pages excepted: rules R1, R6)
        │ yes
  → keyword-to-name proximity (§6)
  → flagging rules (§7)
```

Only content that names an approved target **and** contains an approved keyword is reported. There is no sentiment or NLP step: complaints or articles that do not use one of the keywords are not flagged (accepted limitation, FEASIBILITY_GATE §4).

---

## 6. Rule-based context checks (no NLP)

Because no language model is used, two simple checks reduce false alarms:

1. **Keyword-to-name proximity.** Text is split into words; the distance in words between each keyword and the nearest name mention is recorded as `keyword_proximity`. A keyword is **near** the name when that distance is at most `screening.keyword_name_window_words` (default 30) — or when the distance cannot be measured (e.g. the name was only in the URL). Short alert snippets are almost always "near".
2. **Ambiguity flag.** Keywords marked ambiguous (§4.4) are never auto-escalated to CRITICAL; a person decides.

The window and the ambiguous list are configuration and should be reviewed after the first weeks of real results (PROJECT_STATE O-5).

---

## 7. Flagging and priority rules

| # | Condition | Priority | Review status |
|---|---|---|---|
| R1 | SC Malaysia Investor Alert List entry matching a target name | CRITICAL | MANUAL REVIEW |
| R2 | Target name + **unambiguous** Sanctions & Regulatory Enforcement keyword (e.g. asset freeze, indictment, cease and desist, ofac, extradition) **near** the name (D-30) | CRITICAL ("immediate action") | MANUAL REVIEW |
| R3 | Target name + **ambiguous** Sanctions & Regulatory keyword (e.g. charged, guilty) **near** the name | HIGH | NEEDS REVIEW |
| R4 | Target name + unambiguous keyword from another category **near** the name (D-30) | The category's priority (HIGH / MEDIUM) | PENDING |
| R5 | Target name + **any** keyword **not near** the name (D-30, 5 Oct 2026: e.g. an article quoting the founder that mentions "fraud" about someone else), or an ambiguous keyword from another category | REVIEW | NEEDS REVIEW |
| R6 | SC Malaysia regulatory page naming a target, no keyword | HIGH (Regulatory / Potentially Adverse) | MANUAL REVIEW |
| R7 | Anything else — name without keyword, or keyword without name | Not reported | — |
| R8 | A flagged item names **both** ends of an approved relationship (entities.json `relationships`, e.g. founder → Founder of → company) | Unchanged | at least NEEDS REVIEW |
| R9 | A flagged item whose **only** entity mentions are look-alikes: an ambiguous term (a single word of a name) confirmed only through a web address — the term inside a look-alike domain or an email address, or a context word that appears only in one. The company's own domain, full names, variants and aliases are never look-alikes (D-26) | Capped at REVIEW (never raised) | NEEDS REVIEW |

**Relationships (no NLP).** Links between targets exist only as client-approved entries in `entities.json` → `relationships`. A relationship never adds an entity that an item does not name: an article naming another person and the company is a company finding, never a founder finding. Naming both ends is not proof that the item is about their relationship, and keywords are not attributed to one entity, so R8 sends such items to a person.

Where several rules apply, the highest priority wins (`CRITICAL > HIGH > MEDIUM > REVIEW > LOW`), the review status follows the strongest rule (MANUAL REVIEW > NEEDS REVIEW > PENDING), and every rule that fired is listed in `rules_applied`.

Example (R2): *"asset freeze" + the company name → CRITICAL / MANUAL REVIEW.*
Example (R3): *"… <company> was charged …" → HIGH / NEEDS REVIEW* (could be a criminal charge or a fee — a person checks).

---

## 8. Platform detection and URL verification

### 8.1 Platform detection

Signals, in order: (1) URL hostname, (2) query/source group, (3) URL path, (4) result metadata.

| Hostname (after normalisation) | Platform |
|---|---|
| `facebook.com`, `fb.com`, `fb.watch` | Facebook |
| `instagram.com` | Instagram |
| `linkedin.com` (incl. country subdomains like `my.linkedin.com`) | LinkedIn |
| `sc.com.my` | SC Malaysia |
| the company's own domain (from `settings.json`) | Company website |
| anything else (news sites, blogs, forums, other pages) | **Public website** |

A platform is never invented: if the hostname is not recognised, the item is **Public website** even if the alert query was `site:facebook.com`.

### 8.2 Content type and URL type

Content type and URL type come from the path patterns in SOURCE_ACCESS_BLUEPRINT §3 plus title/snippet cues. `url_type` values: `SPECIFIC_CONTENT` (post, reel, comment, article, announcement), `CONTAINER` (page, profile, company page, group, reviews tab, listing page), `NON_EVIDENCE` (search, hashtag, explore, login, image-only, home page), `UNKNOWN`.

### 8.3 Verification status

| Status | Meaning | Typical cases |
|---|---|---|
| **VERIFIED** | The URL points to a specific piece of content, and there is sufficient evidence that this content is the matched item | Public website / Company website / SC page fetched and the name (and keyword, if any) found in its text; social URL with a specific-content pattern **and** the alert title/snippet containing the entity — basis recorded as `search-index snippet` |
| **PARTIAL** | The relevant platform/page is found, but the exact post/comment cannot be confirmed | Social `CONTAINER` URL whose snippet matched (e.g. a Page or profile); share links; specific-content URLs whose snippet does not itself contain the entity; fetched page where the matched text could not be re-located |
| **REJECTED** | Not usable as evidence where a specific evidence URL was expected | Search/hashtag/explore/login pages, image-only URLs, home pages, unrelated pages, URLs that fail to decode |

Rules:

- **URLs are never fabricated**, e.g. by guessing post IDs or building a post URL from a profile.
- Social URLs are not fetched in the prototype; verification uses URL structure and search-result metadata, and uncertain cases are PARTIAL.
- `verification_basis` records why the status was given (`page text match`, `search-index snippet`, `url pattern only`, `decode failed`, …).
- The report never presents a profile, page or PARTIAL URL as "the negative post". The URL Type and Verification columns sit next to the URL.
- **Which URL the report shows** (30 Sep 2026; unchanged in the staff application, which shows the report's path and opens it): the `final_url` when the page was read and matched (VERIFIED, basis `page text match`) and the redirect did not go up to the home page or a parent section of the discovered URL — e.g. an AMP or tracking link that resolves to the article's own address. Otherwise the `discovered_url`. The report also records both links in their own columns (1 Oct 2026): **Discovered URL** (as delivered by the source) and **Fetched URL** (the page the program downloaded, or why it was not fetched — social media pages never are). Both are URLs the source itself returned; nothing is constructed. URL Type and Verification are unchanged by this choice.
- REJECTED items with an entity match are not dropped silently: they appear on the "Unverified URLs — Manual Lookup" sheet so staff can search for the content themselves.

---

## 9. Deduplication

The same item can arrive through several alert queries or repeated runs.

### 9.1 URL key

1. Decode Google redirect wrappers.
2. Lower-case scheme and host; drop `www.`, `m.`, `mobile.`, `web.`, `l.` host prefixes; LinkedIn country subdomains → `linkedin.com`.
3. Remove fragments and trailing slashes — except a `#comment-<n>` fragment, which identifies a comment on a Company website post and must not merge into the post.
4. Remove tracking parameters (`utm_*`, `fbclid`, `gclid`, `igsh`, `igshid`, `__cft__`, `__tn__`, `ref`, `refid`, `trk`, `rcm`, `mibextid`, …); keep identity parameters (`story_fbid`, `id`, `fbid`, `v`, `comment_id`, `p`); sort the rest.
5. Platform keys where the same content has several URL shapes:
   - LinkedIn: activity ID (`/posts/…-activity-<id>-…` and `/feed/update/urn:li:activity:<id>` → same key)
   - Instagram: shortcode (`/p/<code>` and `/reel/<code>` → same key)
   - Facebook: `story_fbid` + page/user id where present (plus `comment_id` for comments)
6. `url_key = sha256(canonical_url or platform key)`.
7. Several items on one page (SC Investor Alert List entries) are keyed by a stable content key instead of the shared page URL: the entry's name and website(s) as words. The page's own per-entry keys change on every load and are never used.

### 9.2 Secondary checks

- **Content hash** of normalised text where content is legitimately available — catches the same article at two URLs on one site.
- **Same publisher + normalised title + same content date** — flagged as a probable duplicate and merged.
- Syndicated copies on *different* outlets are kept as separate findings (different sources). They are not cross-referenced in the report (owner's decision, 30 Sep 2026 — D-20).

### 9.3 Behaviour

- Within a run: items are de-duplicated immediately after normalisation (cheap, avoids classifying the same item twice), then again before storage.
- Across runs: the database upserts on `url_key`, updating `last_seen_at` and adding a discovery record; it never creates a second finding (FINAL_ARCHITECTURE §7).
- All discovery queries that surfaced a finding are kept in `discovery_hits`, so the report can show "found by 3 queries".
- A finding appears **once** in the main report.
