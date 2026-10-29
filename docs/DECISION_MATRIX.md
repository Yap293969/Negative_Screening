# Decision Matrix

Weighted scoring behind the method decisions in `METHOD_SELECTION_SIMULATION.md`. Scores compare methods **within the same source group**; a website score is not comparable with a social-discovery score.

---

## 1. Hard constraints (applied before scoring)

A method that fails any of these cannot be selected, whatever its score:

| # | Constraint |
|---|---|
| H1 | No unauthorised scraping or anti-bot evasion (CAPTCHA solving, proxies, fingerprint spoofing, evasive automation, personal-cookie scraping, bypassing access controls). |
| H2 | No paid subscription without client approval. |
| H3 | Access must be obtainable for a commercial company's monitoring (not research-only). |
| H4 | No dependency on credentials the project does not legitimately hold. (Methods needing client authorisation are allowed only as optional connectors once it is given.) |

---

## 2. Criteria and weights

| Criterion | Weight | 5 means… | 1 means… |
|---|---|---|---|
| Legitimacy / terms compliance | 25 | Official or plainly permitted public access | Breaches terms or needs evasion |
| Cost | 20 | Free | Significant recurring fee |
| Discovery coverage | 20 | Finds most relevant items for that source group | Covers only a narrow slice |
| Reliability & auditability | 15 | Stable; results can be re-processed later | Breaks often or loses data between runs |
| Maintainability | 10 | Little upkeep, survives site changes | Constant fixes |
| Setup burden on client/developer | 10 | Works with what we have today | Needs approvals, admin rights or vendor onboarding |

Score = Σ (rating 1–5 × weight). Maximum 500.

---

## 3. Social-media discovery

| Method | Legit. | Cost | Cover. | Reliab. | Maint. | Setup | **Score** | Hard constraints | Decision |
|---|---|---|---|---|---|---|---|---|---|
| M1 Google Alerts (email) | 5 | 5 | 3 | 5 | 4 | 3 | **430** | Pass | **SELECTED** |
| M2 Google Alerts (RSS) | 5 | 5 | 3 | 3 | 4 | 4 | **410** | Pass | FALLBACK |
| M10 Paid social listening | 5 | 1 | 5 | 5 | 5 | 2 | **390** | Fails H2 | REJECTED (cost) — best upgrade if approved |
| M6 Meta Graph API (FB Page) | 5 | 5 | 2 | 4 | 3 | 1 | **365** | Fails H4 today | OPTIONAL FUTURE |
| M7 Instagram Graph API | 5 | 5 | 2 | 4 | 3 | 1 | **365** | Fails H4 today | OPTIONAL FUTURE |
| M4 Search APIs | 4 | 2 | 4 | 4 | 4 | 3 | **350** | H2 for paid tiers | DEFERRED |
| M8 LinkedIn Community Mgmt API | 5 | 5 | 1 | 4 | 3 | 1 | **345** | Fails H4 today | OPTIONAL FUTURE |
| M3 Google SERP scraping | 1 | 5 | 4 | 1 | 1 | 4 | **270** | Fails H1 | REJECTED |
| M5 Direct platform scraping | 1 | 4 | 4 | 1 | 1 | 2 | **230** | Fails H1 | REJECTED |
| M9 CrowdTangle / Meta Content Library | — | — | — | — | — | — | — | Fails H3 | NOT AVAILABLE |

Notes:

- M1 vs M2: identical discovery; M1 wins on reliability because the mailbox retains every alert, so a missed or failed run can be re-processed.
- M6–M8 score low on coverage because they only see the client's **own** pages. Their value is complementary: exact, dated comment URLs on channels the company controls. They are added once the client authorises them.

---

## 4. Company public website

| Method | Legit. | Cost | Cover. | Reliab. | Maint. | Setup | **Score** | Decision |
|---|---|---|---|---|---|---|---|---|
| W1 RSS/Atom feed | 5 | 5 | 5 | 5 | 5 | 5 | **500** | SELECTED if the site has a feed |
| W3 requests + BeautifulSoup | 5 | 5 | 5 | 3 | 3 | 5 | **450** | FALLBACK (likely in practice) |
| W4 Browser automation | 4 | 5 | 5 | 2 | 2 | 4 | **390** | Only if necessary and permitted |

W2 (public official endpoint) is scored like W1 when it exists and is clearly public.

---

## 5. Securities Commission Malaysia

| Method | Legit. | Cost | Cover. | Reliab. | Maint. | Setup | **Score** | Decision |
|---|---|---|---|---|---|---|---|---|
| S1 requests + BeautifulSoup | 5 | 5 | 5 | 3 | 3 | 5 | **450** | SELECTED (S2 download/feed preferred where offered) |
| S3 Manual staff check | 5 | 5 | 4 | 2 | 5 | 2 | **405** | FALLBACK |

---

## 6. External news

The current build has **no dedicated news collector** (owner's decision, 29 Sep 2026): news arrives through whole-web Google Alerts (M1, scored in §3) and is reported as Public website. The scores below are kept for the record.

| Method | Legit. | Cost | Cover. | Reliab. | Maint. | Setup | **Score** | Hard constraints | Decision |
|---|---|---|---|---|---|---|---|---|---|
| N1 GDELT DOC 2.0 API | 5 | 5 | 3 | 4 | 4 | 5 | **435** | Pass | NOT IN CURRENT BUILD (owner) |
| N2 Outlet RSS feeds | 5 | 5 | 3 | 3 | 3 | 5 | **410** | Pass | NOT IN CURRENT BUILD (owner) |
| N3 Google News RSS | 3 | 5 | 4 | 3 | 4 | 5 | **390** | Terms to check | NOT IN CURRENT BUILD |
| N5 Paid media databases | 5 | 1 | 5 | 5 | 5 | 2 | **390** | Fails H2 | REJECTED (cost) |
| N4 Free-tier news APIs | 3 | 3 | 3 | 4 | 4 | 4 | **335** | Free tiers usually non-production | REJECTED |

---

## 7. Resulting prototype configuration

| Source group | Primary | Fallback / complement | Future upgrade |
|---|---|---|---|
| Facebook / Instagram / LinkedIn | Google Alerts (email) — platform identified from the URL | Google Alerts (RSS) | Official APIs for own pages (M6–M8); paid listening (M10) |
| Public website results (news, blogs, forums) | Google Alerts whole-web queries — listed as **Public website** | — | GDELT / RSS collectors (N1, N2) if the owner re-adds them; paid media database (N5) |
| Company website | RSS/Atom or public endpoint | requests + BeautifulSoup | — |
| SC Malaysia | requests + BeautifulSoup (or SC download) | Manual staff check | — |
| Screening | Name + keyword rules (no NLP — owner's decision) | — | Only if the owner reinstates it |

Scores are judgements made at design time (29 Sep 2026). Re-score if a constraint changes — for example, if the client grants Page admin access (M6–M8 setup rises from 1) or approves a budget (M4, M10, N5 pass H2).
