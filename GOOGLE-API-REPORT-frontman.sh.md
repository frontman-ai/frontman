# Frontman search decline: diagnosis and recovery plan

Report date: October 23, 2026.

## Conclusion

Google Search traffic decreased, but the evidence does not show a uniform ranking collapse.
Three pages account for approximately 91% of the net decrease in page-level clicks.
The homepage has a click-through-rate problem that became sharper after its October 6 repositioning.
Several articles lost impressions before that change.

The recommended response is a targeted homepage experiment and a review of the affected articles.
A site-wide rollback, mass deletion, or new publishing campaign is not justified by this evidence.
No production changes were made during this diagnosis.

## Data and method

- Search Console property: `sc-domain:frontman.sh`.
- Search type: `web`, all countries and devices.
- Recent period: September 24–October 21, 2026.
- Previous period: August 27–September 23, 2026.
- Both periods contain 28 days and the same weekday distribution.
- Search Console requests used `dataState: final`.
- October 21 was the latest returned date in the daily request through October 22.
- The daily series covers June 1–October 21.
- Site totals come from dimensionless requests, not sums of query or page rows.
- GA4 property: `524112512`, timezone `America/Los_Angeles`.
- GA4 filters: `sessionSourceMedium = google / organic`, `hostName = frontman.sh`.
- All external calls used connected team tools or free TinyFish routes. Catalog charges totaled $0.

The local Google SEO helper was unavailable.
Connected OAuth tools supplied Search Console and GA4 access instead.

## Overall results

| Metric | Previous 28 days | Recent 28 days | Change |
| --- | ---: | ---: | ---: |
| Search clicks | 699 | 526 | -24.7% |
| Search impressions | 98,893 | 53,573 | -45.8% |
| Search CTR | 0.707% | 0.982% | +0.275 percentage points |
| Average position | 6.26 | 5.74 | Improved aggregate |
| GA4 Google organic sessions | 167 | 102 | -38.9% |
| GA4 engaged sessions | 107 | 61 | -43.0% |
| GA4 key events | 0 | 0 | No recorded outcomes in this segment |

GA4 supports a real traffic decrease, not only an impression-reporting change.
GA4 sessions and Search Console clicks measure different things and do not reconcile directly.
Consent and measurement changes can also affect GA4 comparisons.
Zero key events do not prove that no visitors converted.

## Where clicks decreased

| Page | Previous clicks | Recent clicks | Difference | Previous position | Recent position |
| --- | ---: | ---: | ---: | ---: | ---: |
| `/` | 172 | 104 | -68 | 6.31 | 4.84 |
| `/blog/wordpress-7-1-new-features-breaking-changes/` | 77 | 29 | -48 | 6.03 | 6.14 |
| `/blog/best-frontend-coding-agent/` | 116 | 73 | -43 | 5.58 | 6.55 |
| `/blog/best-ai-coding-agents-frontend-development-teams-2026/` | 18 | 5 | -13 | 5.79 | 6.68 |
| `/blog/puppeteer-mcp-alternatives-claude-code/` | 12 | 2 | -10 | 6.46 | 7.05 |
| `/vs/onlook/` | 20 | 10 | -10 | 5.49 | 5.37 |

The first three pages lost 159 clicks.
Page rows totaled 701 clicks previously and 526 recently, a net decrease of 175.
The three pages therefore account for 90.9% of that page-level decrease.
Property totals differ slightly because page and property aggregation use different counting rules.

## Finding 1: homepage CTR needs a controlled experiment

Homepage impressions increased from 12,436 to 14,352.
Clicks decreased from 172 to 104.
Homepage CTR decreased from 1.38% to 0.72%, despite an improved aggregate position.

A fixed-query comparison shows a sharper change around the homepage release:

| Homepage query | Period | Clicks | Impressions | CTR | Position |
| --- | --- | ---: | ---: | ---: | ---: |
| `frontman` | September 22–October 5 | 43 | 3,931 | 1.09% | 6.66 |
| `frontman` | October 6–19 | 9 | 3,751 | 0.24% | 6.60 |
| `frontman ai` | September 22–October 5 | 11 | 22 | 50.00% | 1.00 |
| `frontman ai` | October 6–19 | 12 | 23 | 52.17% | 1.17 |

The generic query `frontman` has mixed intent, including music-related searches.
It is not a clean measure of branded demand.
The `frontman ai` sample is very small.
These comparisons support investigation, not proof that the release caused the decrease.

Repository history records the WordPress-first homepage release on October 6 (`888b7aaa`, PR #1806).
The live homepage title is `Ship WordPress Updates Faster | Frontman AI Editor`.
The live page also links to framework setup.

Recommendation: retain the WordPress direction provisionally.
Experiment with a brand-first title and clearer recognition of existing framework users.
Inspect actual Google titles and snippets before selecting the final wording.
Do not change the URL or canonical during this experiment.

## Finding 2: article impression losses are not equivalent to ranking losses

The open-source coding-tools article lost 67.4% of impressions: 27,916 to 9,101.
Its clicks decreased only from 38 to 35.
Its aggregate position improved from 6.19 to 5.55.
That article alone explains approximately 40% of the net decrease in page-level impressions.

The WordPress 7.1 article lost impressions from 7,256 to 2,908.
Its aggregate position remained near 6.0.
Changing demand, query coverage, and search-result presentation remain plausible explanations.
The current evidence does not distinguish those explanations.

The frontend coding-agent article shows some ranking deterioration.
Its position changed from 5.58 to 6.55.
However, its weekly clicks recovered from 11 on September 24–30 to 26 on October 15–21.
The repository records a further article update on October 20.
The reporting window includes too little time to evaluate that latest update.

Recommendation: review the exact lost queries and current competing results before another rewrite.
For the WordPress article, check release facts, patch guidance, compatibility evidence, and current search intent.
For frontend comparisons, prioritize original task evidence and clear distinctions between overlapping articles.
Do not refresh dates without substantive corrections or new evidence.

## Finding 3: timing overlaps a Google update, but does not prove a penalty

[Google's ranking history](https://status.search.google.com/products/rGHU1u87FJnkP6W2GwMi/history)
lists a September 2026 spam update.
It started September 24 and lasted 13 days, 16 hours.
This period overlaps the sharper traffic decrease.
The broader impression decrease began earlier in September.
The homepage repositioning therefore cannot explain the full decline.

The update is a plausible contributor, not a demonstrated cause.
The diagnosis does not establish a manual action, spam classification, or site-wide quality penalty.

## Indexing evidence

Google URL Inspection returned the following results for the homepage and the three major affected articles:

- Coverage: `Submitted and indexed`.
- Robots access: `ALLOWED`.
- Indexing permission: `INDEXING_ALLOWED`.
- Fetch state: `SUCCESSFUL`.
- Google canonical matched the declared canonical.
- Last crawl dates were October 21–23.

The sitemap index had zero errors and one warning.
Google downloaded it on October 23.
The sitemap API's `indexed: 0` field is not evidence that the site has no indexed pages.
URL Inspection directly contradicts that interpretation for the sampled pages.
The warning details still require inspection in the Search Console interface.

## Recent trajectory

| Week | Clicks | Impressions |
| --- | ---: | ---: |
| September 3–9 | 177 | 28,700 |
| September 10–16 | 173 | 25,290 |
| September 17–23 | 170 | 19,976 |
| September 24–30 | 137 | 16,042 |
| October 1–7 | 126 | 10,878 |
| October 8–14 | 128 | 12,700 |
| October 15–21 | 135 | 13,953 |

The latest weeks show stabilization and partial recovery, not continued acceleration of the decline.
Traffic remains below the early-September baseline.

## Recovery sequence

### First: isolate the homepage problem

1. Inspect current Google titles and snippets for the homepage queries.
2. Check the sitemap warning, Manual Actions, and Security Issues in Search Console.
3. Define one homepage title and description experiment.
4. Preserve the WordPress offer and an obvious framework path.
5. Record the deployment date.
6. Compare complete 14-day periods after Google recrawls the page.
7. Segment results by query, country, and device.

### Next: improve the pages with demonstrated losses

1. Review the WordPress 7.1 article against current official release documentation.
2. Review the frontend articles against their current search results.
3. Preserve recent corrections and allow time to evaluate the October 20 changes.
4. Add original compatibility results or comparison evidence where the article lacks them.
5. Check contextual links between relevant tutorials, comparisons, and product destinations.

### Measure business outcomes

1. Check installation, signup, and paid-activation measurement.
2. Separate Google organic visitors by WordPress and framework landing pages.
3. Track qualified actions alongside clicks.
4. Use complete reporting days for weekly reviews.
5. Treat recovery to approximately 170 weekly clicks as a historical reference, not a forecast.

## Limits and remaining checks

Query rows expose only 215 of 699 previous clicks and 175 of 526 recent clicks.
Google omits anonymized queries, so named queries cannot explain the entire decrease.
Aggregate position can improve because poorly ranked impressions disappear.
It does not prove that every query retained its rank.

This diagnosis did not include a full crawl, a performance audit, historical SERP snapshots, or a backlink analysis.
It did not include year-over-year seasonality analysis or independent keyword-demand measurements.
Manual Actions, Security Issues, and sitemap warning details remain unchecked.
Repository commit dates do not establish exact production deployment times.
No ranking improvement or recovery date is guaranteed.

## Implementation record: October 23, 2026

### Prepared in this worktree

- Homepage title: `Frontman — AI WordPress Editor for Existing Sites`.
- Homepage description: concrete WordPress editing tasks, with the brand named in the first sentence.
- Framework navigation: visible in the homepage hero, with a separate intent event.
- Existing homepage URL, canonical, WordPress offer, and primary installation destination remain unchanged.
- WordPress article: added the official 7.1.3 security notice and media-finalization guidance.
- Article freshness: October 23 records substantive corrections, not a date-only refresh.
- Frontend articles: reviewed, preserved, and not redirected or merged.
- Analytics: preserved legacy event names and the existing consent gate.
- Installation intent: records successful command/manual-step copying with an allowlisted framework and site type.
- Reporting: added `make seo-monitor` with matched periods, final-day checks, landing pages, and separate event counts.

The live search check returned the previous homepage title for a site-restricted query.
This was a free web-search observation, not a controlled country/device Google SERP snapshot.
No historical search-result snapshot was available.

### Measurement findings

GA4 administration lists `close_convert_lead`, `qualify_lead`, `purchase`, and `generate_lead` as key events.
The existing WordPress click event already reaches Google: 14 events across all traffic during September 24–October 21.
Only two of those events occurred in the Google organic segment.
The all-traffic report also contains four `copy_agent_install_instructions` events.
Zero organic key events therefore does not establish a broken CTA collector.

GA4 metadata lists no custom dimensions.
Framework and site-type parameters need event-scoped custom dimensions for aggregate parameter reports.
Landing-page and event-name reports already work without those dimensions.
No GA4 key-event definitions or custom dimensions were changed during this work.
Confirmed installations, new accounts, and paid activation remain separate product-side attribution work.

### Verification

- `make build`: passed.
- `make -C libs/frontman-astro build`: passed and supplied the required workspace bundle.
- `make -C apps/marketing build`: passed, including Astro diagnostics and the internal-link checker.
- Local Chromium: checked rendered metadata, canonical, homepage destinations, and mobile width.
- Local Chromium: exercised real built installation controls and clipboard writes for Astro, Vite, and WordPress.
- Consent denial and revocation suppressed explicit acquisition events during that workflow.
- External browser requests were blocked, so the workflow sent no verification events to production analytics.
- The live `seo-monitor` command succeeded for `END_DATE=2026-10-21 DAYS=14`.
- No new unit-test files remain.

The live comparison returned 263 clicks in each 14-day period.
Impressions changed from 26,920 to 26,653.
GA4 Google organic sessions changed from 60 to 42.
That difference reinforces the need to keep Search Console and consent-dependent GA4 measures separate.

### Deployment and follow-up gates

Deployment timestamp: pending. These changes are not deployed.
First Google recrawl of the changed homepage: pending.
Scheduled recurring monitoring: not configured.

1. Before deployment, save a fresh snapshot with the latest complete reporting date.
2. Record the deployment timestamp and revision.
3. In Search Console, inspect Manual Actions, Security Issues, and the sitemap warning details.
4. Record the first homepage recrawl after deployment.
5. After 14 complete post-recrawl days, save another snapshot.
6. Compare its recent period with the saved predeployment baseline.
7. Exclude deployment and recrawl transition days from causal interpretation.
8. Review the same query/country/device segments, not only aggregate CTR.
9. Preserve the change only if qualified acquisition improves without a meaningful loss in the other audience.

The API still reports one sitemap warning and zero errors.
Public robots.txt allows search crawling, and public sitemap children are reachable.
The authenticated Search Console interface is not available through the connected API tools.
Manual-action status, security status, and the warning text therefore remain unverified, not clear.
