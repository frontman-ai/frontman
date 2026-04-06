# Open Source AI Releases — Monthly Resource Pages

**Issue**: #791 — SEO: Fix 'best open source' blog post — 11,872 impressions, 0 clicks
**Date**: 2026-04-06
**Status**: Approved

## Problem

The blog post `/blog/best-open-source-ai-coding-tools-2026/` has 11,872 impressions over 28 days but 0 clicks. The queries driving impressions are variations of "open source ai projects released march 2026" — people searching for a live feed of recent AI project releases. The comparison post doesn't match that intent.

## Decision

Keep the comparison post for comparison-intent queries. Create a separate monthly releases resource page targeting the "recently released" search intent.

## Architecture

### URL Structure

- **Index**: `/open-source-ai-releases/` — lists all monthly editions
- **Monthly pages**: `/open-source-ai-releases/april-2026/`, `/open-source-ai-releases/march-2026/`, etc.

Each month gets its own page (too many launches per month for a single page). The index links to the latest month first.

### Content Collection

New `releases` collection in `src/content/releases/`.

**Zod schema fields**:
- `title` (string, required)
- `description` (string, required) — meta description
- `month` (string, required) — e.g. "April"
- `year` (number, required) — e.g. 2026
- `pubDate` (date, required) — publication date of this edition
- `updatedDate` (date, optional) — last update within the month
- `image` (string, optional) — OG image
- `faq` (array of {question, answer}, optional) — for FAQPage schema

**Markdown content**: Curated editorial roundup of 5-10 notable open-source AI project releases/updates for that month.

### Pages

**Index page**: `src/pages/open-source-ai-releases/index.astro`
- Queries all entries from the `releases` collection
- Sorts by year desc, then month desc
- Renders a list of links to each monthly edition
- Structured data: `CollectionPage` + `ItemList`

**Monthly page**: `src/pages/open-source-ai-releases/[slug].astro`
- Renders a single monthly edition from the collection
- Structured data: `FAQPage` (if FAQ present), `WebPage` with `dateModified`
- Footer callout linking to the comparison post

### Structured Data

**Index page**:
- `CollectionPage` with `ItemList` pointing to each monthly edition

**Monthly pages**:
- `FAQPage` if `faq` array is present in frontmatter
- `WebPage` with `dateModified` matching `updatedDate` or `pubDate`

### SEO

**Title tags**:
- Index: `Open Source AI Releases — Monthly Roundups | Frontman`
- Monthly: `New Open Source AI Releases — April 2026 | Frontman`

**Meta descriptions**:
- Index: `Monthly curated roundups of notable open-source AI project releases. New tools, major updates, and emerging projects.`
- Monthly: `Notable open-source AI projects released in April 2026. Curated picks with context on what shipped and why it matters.`

**FAQ per monthly page** (targeting long-tail queries):
- "What open source AI projects were released in [month] [year]?"
- "What are the newest open source AI tools in [month] [year]?"

**OG tags**: Same pattern as blog posts. Reuse existing comparison post cover image or create a generic releases cover.

**Canonical**: Each page is its own canonical. No cross-canonicalization.

**No `noindex`** on any page.

**Sitemap**: Monthly pages included via existing sitemap integration using frontmatter date for `lastmod`.

### Internal Links

- Comparison post (`/blog/best-open-source-ai-coding-tools-2026/`) gets a callout near the top linking to the releases index
- Each monthly release page links to the comparison post (footer callout)
- Releases index links to the comparison post

### Changes to Existing Comparison Post

1. Update `updatedDate` to `2026-04-06T00:00:00Z`
2. Add callout after intro paragraph: "Looking for the latest releases? See our [monthly open source AI releases roundup](/open-source-ai-releases/)."
3. No title or meta description changes

### Seed Content

Two monthly editions at launch:
- **March 2026** — backfill with notable releases from that month
- **April 2026** — current month's releases so far

## Out of Scope

- Automated release detection/scraping
- RSS feed for releases
- Email notifications for new editions
- Programmatic star count updates
