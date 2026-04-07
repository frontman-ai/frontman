# SEO Comparison Pages Redesign

**Issue:** #792 — SEO: Comparison pages (/vs/) getting almost no search visibility
**Branch:** `issue-792-seo-comparison-pages-vs`
**Scope:** Build a shared `ComparisonLayout` + new components, refactor `/vs/cursor/` as the template page. Other competitor pages migrated separately.

## Problem

Frontman's `/vs/` comparison pages generate near-zero organic traffic despite being indexed. GSC data (28 days ending April 3 2026) shows ~900 total impressions, 5 clicks, avg position 5.6-8.0. Pages don't rank for competitive queries ("cursor alternatives", "windsurf vs cursor") because of thin content, missing keyword targeting, and no Product structured data.

## Approach

**Option C: Shared Layout + Per-Page Content.** Create a `ComparisonLayout.astro` layout that handles common structure. Each competitor page imports the layout, passes data via props, and fills named slots with unique prose. This avoids the DRY problem of the current inline approach while preserving per-page narrative flexibility.

All styling uses Tailwind utility classes. No scoped `<style>` blocks.

## Architecture

### ComparisonLayout.astro

Location: `apps/marketing/src/layouts/ComparisonLayout.astro`

Accepts props + named slots. Renders the full page in this order:

1. `<Layout>` wrapper (existing) with SEO title/description
2. `<ComparisonStructuredData>` (new) — all JSON-LD in `<head>`
3. `<ComparisonHero>` (existing) + `hero-summary` slot + `<ComparisonDisclosure>` (existing)
4. `<ComparisonArchitectureDiagram>` (new) — inline SVG
5. `<ComparisonFeatureTable>` (existing)
6. `competitor-strengths` slot — "What [Competitor] Does Well"
7. `frontman-differentiators` slot — "Where Frontman Is Different"
8. `who-should-use-competitor` slot
9. `who-should-use-frontman` slot
10. `<ComparisonPricing>` (existing)
11. `<ComparisonAlternatives>` (new) — targets "[competitor] alternatives" queries
12. `<ComparisonFAQ>` (new, extracted from inline) — FAQ accordion + JSON-LD
13. `<ComparisonCTA>` (existing)

#### Props Interface

```typescript
type ComparisonLayoutProps = {
  seo: {
    title: string
    description: string
  }
  competitor: {
    name: string
    slug: string
    url: string
    category: string
    description: string
    pricing: {
      cost: string
      model: string
      features: string[]
    }
  }
  features: ComparisonFeature[]
  faqs: { question: string; answer: string }[]
  alternatives: { name: string; slug: string; oneLiner: string }[]
  architectureDiagram: string  // inline SVG string
}
```

#### Named Slots

- `hero-summary` — GEO lead paragraphs (AI-citable first 150 words)
- `competitor-strengths` — prose about what the competitor does well
- `frontman-differentiators` — prose about Frontman's advantages
- `who-should-use-competitor` — honest "use them if..." list
- `who-should-use-frontman` — "use us if..." list

### New Components

All in `apps/marketing/src/components/blocks/comparison/`.

#### ComparisonAlternatives.astro

Targets "[competitor] alternatives" search queries.

Props:
```typescript
type Props = {
  competitorName: string
  alternatives: { name: string; slug: string; oneLiner: string }[]
}
```

Structure:
- H2: "[Competitor] Alternatives"
- Intro paragraph positioning the context
- Grid of cards linking to other `/vs/` pages
- Frontman card highlighted with purple accent
- Tailwind utility classes only

#### ComparisonArchitectureDiagram.astro

Simple SVG diagram comparing architectural approaches.

Props:
```typescript
type Props = {
  competitorName: string
  diagramSvg: string
}
```

Structure:
- H2: "How Frontman and [Competitor] Work"
- Renders the SVG string inside a centered container
- SVGs are defined per-page since each competitor has different architecture
- For cursor: left side shows IDE-based flow, right side shows browser-based flow

#### ComparisonFAQ.astro

Extracted from current inline pattern. Renders the FAQ accordion.

Props:
```typescript
type Props = {
  faqs: { question: string; answer: string }[]
}
```

Replaces the per-page FAQ markup. JSON-LD for FAQPage is handled by `ComparisonStructuredData`.

#### ComparisonStructuredData.astro

Centralizes all comparison page JSON-LD.

Props:
```typescript
type Props = {
  competitor: {
    name: string
    url: string
    category: string
    description: string
    pricing: { cost: string; model: string }
  }
  faqs: { question: string; answer: string }[]
  seo: { title: string; description: string }
}
```

Emits these JSON-LD blocks:
1. **FAQPage** — migrated from current inline scripts
2. **SoftwareApplication** for Frontman — with `isSimilarTo` referencing competitor
3. **SoftwareApplication** for competitor — basic info, pricing, category
4. **WebPage** — with `reviewedBy` Organization to signal editorial comparison

### Existing Components (Unchanged)

These components are already shared and work as-is:
- `ComparisonHero.astro` — hero section with title/subtitle + slot
- `ComparisonFeatureTable.astro` — feature comparison table with desktop/mobile views
- `ComparisonPricing.astro` — pricing cards
- `ComparisonCTA.astro` — bottom CTA with install commands
- `ComparisonDisclosure.astro` — conflict-of-interest disclosure

### Existing Components (Modified)

These need Tailwind migration:
- `ComparisonFeatureTable.astro` — convert scoped `<style>` to Tailwind utility classes
- `ComparisonPricing.astro` — convert scoped `<style>` to Tailwind utility classes
- `ComparisonCTA.astro` — convert scoped `<style>` to Tailwind utility classes

## SEO & Keyword Strategy

### Title Tags

Pattern: `"Frontman vs [Competitor]: [Differentiator] ([Year])"`

Target the actual queries people search. Include both tool names + a benefit hook.

Example for cursor: `"Frontman vs Cursor: Open-Source AI Coding Tool Comparison (2026)"`

### Meta Descriptions

Lead with key differentiator, include both tool names, ~155 characters.

### H2 Headings (Optimized for Featured Snippets)

1. "Feature Comparison"
2. "How Frontman and [Competitor] Work" (new)
3. "What [Competitor] Does Well"
4. "Where Frontman Is Different"
5. "Who Should Use [Competitor]"
6. "Who Should Use Frontman"
7. "Pricing Comparison"
8. "[Competitor] Alternatives" (new)
9. "Frequently Asked Questions"

### Content Tone

Honest but opinionated. Lean into Frontman's differentiators (browser-based, designer/PM friendly, sees live DOM) while being genuinely fair about competitor strengths. Structure content around "when to pick which tool" rather than flat feature grids.

## Cursor Page (Template)

After refactor, `cursor.astro` contains:
1. Import `ComparisonLayout`
2. Data definitions: features array, FAQs, competitor info, pricing, alternatives, SEO metadata
3. Architecture SVG (inline, cursor-specific)
4. Named slot content: hero-summary, competitor-strengths, frontman-differentiators, who-should-use sections

Estimated size: ~200 lines (down from ~790). All prose content preserved — restructured, not rewritten.

## Out of Scope

- `/compare/` hub page — has its own matrix, not part of this redesign
- `/vs/index.astro` — hub page stays as-is
- Navigation config — already links comparison pages from nav + footer
- Other 9 competitor pages — stay as-is, migrated to layout in a follow-up
- Blog content or external link building
- Image/screenshot assets (diagrams are inline SVG only)

## File Changes Summary

**New files:**
- `apps/marketing/src/layouts/ComparisonLayout.astro`
- `apps/marketing/src/components/blocks/comparison/ComparisonAlternatives.astro`
- `apps/marketing/src/components/blocks/comparison/ComparisonArchitectureDiagram.astro`
- `apps/marketing/src/components/blocks/comparison/ComparisonFAQ.astro`
- `apps/marketing/src/components/blocks/comparison/ComparisonStructuredData.astro`

**Modified files:**
- `apps/marketing/src/pages/vs/cursor.astro` — refactored to use ComparisonLayout
- `apps/marketing/src/components/blocks/comparison/ComparisonFeatureTable.astro` — Tailwind migration
- `apps/marketing/src/components/blocks/comparison/ComparisonPricing.astro` — Tailwind migration
- `apps/marketing/src/components/blocks/comparison/ComparisonCTA.astro` — Tailwind migration

## Testing

- Build the marketing site (`make build` in `apps/marketing/`) — verify no build errors
- Visual inspection of `/vs/cursor/` — verify all sections render correctly
- Validate JSON-LD output — check all structured data blocks are present and valid
- Mobile responsive check — verify table/card toggle works
- Verify no regression on existing pages that use the shared components
