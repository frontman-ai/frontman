# Marketing comparison pages

## Choose the page before writing

Use `/vs/` for browsing matchups, `/compare/` for a multi-tool matrix, and `/vs/<tool>/` for one decision between Frontman and a named tool. Keep broad “alternatives” coverage in an existing hub or guide unless the evidence shows a distinct reader need. Search existing routes and editorial guides first; refresh the closest fit rather than creating another URL.

For each candidate, record the reader’s decision, the query or customer evidence, the best existing URL, and what the reader cannot learn there today. Use Search Console page totals to prioritize and page/query rows to interpret intent. Record the property, dates, and filters. Query rows omit some searches and do not add up to page totals; impressions are exposure, not keyword volume or proof of purchase intent. If evidence supports only a factual correction, correct the existing page without creating a new one.

## Page contract

Use `ComparisonLayout.astro` rather than introducing another template.

| Section | Required content |
| --- | --- |
| Verdict (`hero-summary`) | Name both tools and say when to choose each before the table. State the audience, product edition and decision that changes the recommendation. |
| Evidence (`review`, `features`, body slots) | Show a short table of decision-making differences and a concrete workflow for each tool. Give both products credit for overlapping capabilities. Explain partial support, setup, and limitations in the row notes. Omit unverified rows rather than using “no” for “not documented.” |
| Pricing and licensing | Separate editor price, provider usage, and subscription requirements. Use current official terms and distinguish license coverage by component if it varies. Avoid stale plan numbers, historical tiers and implied free AI usage. |
| FAQs (`faqs`) | Answer real objections about fit, setup, existing projects, or cost. Keep answers self-contained. Reuse the same data for visible FAQs and existing structured data; don’t promise rich results. |
| Links and next step | Link to primary evidence near consequential claims. Link to the relevant Frontman setup or compatibility doc and one genuinely useful adjacent comparison. Ensure the comparison hub links back. Give readers one primary next step. |

Keep an editorial evidence record for substantive claims: source URL and relevant section, edition/version, date checked, and what the evidence supports. Prefer first-party docs, source and release notes; label firsthand testing only if it happened and record setup and result. Treat the verdict as editorial judgment, not a benchmark. Keep the visible Frontman disclosure and use a page-specific review date when rechecking one page; never advance the shared date for untouched pages.

Before handoff, build locally and check the rendered verdict, evidence links, FAQ parity, canonical, metadata, and hub entry. Keep the existing slug unless there is a separate migration plan. Recheck on major product releases and before refreshing pricing. Do not publish or submit URLs as part of drafting.

## Pilot: Onlook

Search Console, `sc-domain:frontman.sh`, web, 2026-10-20 through 2026-11-16, page URLs under `/vs/` or `/compare/`: Onlook led with **1,482 impressions / 15 clicks**, ahead of Stagewise (**634 / 3**) and Cursor (**366 / 4**). Visible Onlook query rows include `onlook` (157 impressions), `frontman.sh alternatives` (113), `onlook alternatives` (84), and a query about visual editors for local application code (9). The mixed intent favors improving the existing pairwise decision; it does not justify a generic alternatives page or treating every impression as a comparison search.

The [current Onlook README](https://github.com/onlook-dev/onlook#readme) documents the desktop canvas, local Git/dev-server workflow, connected agents and macOS download. Its License section distinguishes Apache-2.0 source from separately licensed assets. Frontman’s [annotation guide](https://frontman.sh/docs/using/annotations/) documents the screenshot, selector and conditional source location; the [compatibility guide](https://frontman.sh/docs/reference/compatibility/) owns framework support. These are documentation-backed claims, not hands-on benchmark results. The pilot removes legacy cloud, React-only and speculative popularity claims instead of carrying them forward.

Reuse `/vs/onlook/` and its `/vs/` hub card. The six-tool matrix does not include Onlook and does not need a new column. During wider marketing integration, check for legacy Onlook descriptions in editorial content before adding new inbound links. After an approved release, compare the same 28-day page/query filters for impressions, clicks and CTR alongside query mix and position; don’t attribute changes to copy alone.
