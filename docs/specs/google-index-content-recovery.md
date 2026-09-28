# Spec: Google Index Content Recovery

## Objective

Improve the independent search value and indexing signals of Frontman's marketing and documentation pages after Google classified 33 sitemap URLs as `Crawled - currently not indexed`.

The work must retain every published article URL and rewrite overlapping articles around distinct search intents. It must reduce low-value taxonomy exposure, strengthen genuinely thin documentation, clarify which page owns each topic, and correct semantic and sitemap signals without adding filler.

## Scope

### Blog taxonomy

- Keep tag routes available for site navigation.
- Mark tag archives with fewer than three posts as `noindex,follow` and exclude them from sitemap output.
- Keep only coherent, sufficiently populated tag archives indexable.
- Stop exposing every thin tag archive through global tag navigation.
- Give retained indexable archives distinct editorial purpose rather than generic archive copy.

### Overlapping articles

- Retain every published article and URL.
- Rewrite each overlapping article around a distinct audience, intent, evidence set, and outcome.
- Remove repeated ticket-delay, click-and-describe, runtime-context, and PR-review passages where they do not serve that page's intent.
- Replace placeholders and hypothetical performance claims with verifiable examples, source citations, reproducible steps, or explicitly labeled illustrative examples.
- Establish internal-link hierarchy between conceptual hubs, tutorials, product announcements, and comparison pages.

### Documentation

- Expand genuinely thin pages: API Keys, Installation, and Plans and Todos.
- Improve task-specific titles and descriptions for ambiguous documentation pages.
- Keep substantial pages concise and focused; do not add prose solely to increase word count.
- Verify new procedures and claims against implementation or existing authoritative documentation.

### Commercial and static pages

- Make `/vs/claude-code/` the owner of exact two-product comparison intent while retaining the three-way article for multi-tool workflow selection.
- Preserve `/features/` content depth and improve its capability-page differentiation.
- Accept `/terms/` as non-acquisition content; do not pad it for indexing.

### Technical SEO

- Emit page-specific `WebPage` structured data instead of homepage identity on every route.
- Preserve organization, software, and service entities globally.
- Emit accurate sitemap `lastmod` values where source dates exist; do not assign one synthetic date to unrelated pages.
- Add automated tests for tag indexability/sitemap policy and page-specific structured data.
- Add a changeset describing public marketing and documentation improvements.

## Tech Stack

- Astro 7
- TypeScript and JavaScript
- Astro Content Collections and Starlight
- `@astrojs/sitemap`
- Vitest
- Markdown and MDX content

## Commands

- Marketing tests: `make test` from `apps/marketing`
- Marketing build and Astro checks: `make build` from `apps/marketing`
- Formatting check for changed files: `yarn prettier --check <changed-files>` from repository root
- Production-output checks: inspect generated files under `apps/marketing/dist` after build

## Project Structure

- `apps/marketing/src/content/blog/`: published blog articles
- `apps/marketing/src/content/docs/docs/`: Starlight documentation
- `apps/marketing/src/pages/blog/tags/`: tag archive routes
- `apps/marketing/src/components/ui/blog/`: blog taxonomy navigation
- `apps/marketing/src/components/blocks/head/`: metadata and structured data
- `apps/marketing/astro.config.mjs`: sitemap and Starlight configuration
- `apps/marketing/src/content/*.test.mjs`: metadata and content policy tests
- `.changeset/`: changelog fragments

## Code Style

Follow existing Astro and content conventions. Keep policy logic explicit and local rather than introducing a general SEO framework.

```astro
---
const shouldIndex = posts.length >= 3
---

<Layout noindex={!shouldIndex}>
  <!-- Existing archive rendering -->
</Layout>
```

Content must use concrete, attributable language. Claims based on examples rather than measured production data must be labeled as examples.

## Testing Strategy

- Add a failing content-policy test before changing tag indexability and sitemap behavior.
- Add a failing structured-data test before changing global `WebPage` output.
- Extend metadata tests for rewritten article titles, descriptions, and unique intent where practical.
- Run all existing marketing tests after each behavioral slice.
- Build production marketing output and verify:
  - thin tags contain `noindex,follow`;
  - thin tags are absent from generated sitemaps;
  - retained tag hubs remain indexable;
  - non-home pages identify their own canonical URL in structured data;
  - internal links are valid.

Static Markdown rewrites do not require unit tests individually, but must pass metadata tests, broken-link build checks, and formatting checks.

## Boundaries

### Always

- Preserve all currently published article URLs.
- Preserve factual product behavior and licensing language.
- Label illustrative data as illustrative.
- Keep canonical URLs self-referencing unless a separate redirect decision is approved.
- Use existing Makefile targets for tests and builds.

### Ask first

- Delete or redirect any published article.
- Add dependencies.
- Change product behavior, pricing, licensing, or security policy.
- Make all tag archives indexable regardless of corpus size.

### Never

- Invent customer results, benchmark outcomes, citations, or product capabilities.
- Add generic text solely to meet a word-count target.
- Submit ordinary marketing URLs through Google's restricted Indexing API.
- Modify unrelated application code.

## Success Criteria

- Every published article URL remains available.
- Each overlapping article has a distinct primary intent documented by title, opening, structure, and internal-link destination.
- No unresolved content placeholders remain on rewritten pages.
- Performance and comparison claims are sourced, reproducible, or explicitly illustrative.
- Tag archives with fewer than three posts render `noindex,follow` and do not appear in generated sitemap files.
- Retained tag hubs include meaningful unique editorial organization and do not duplicate another retained hub's purpose.
- API Keys, Installation, and Plans and Todos provide complete task outcomes, verification, and next steps.
- Ambiguous documentation titles identify Frontman and user task.
- `/vs/claude-code/` owns exact Frontman-versus-Claude-Code intent; three-way article owns multi-tool workflow selection.
- Every rendered page emits correct page-specific `WebPage` URL and identity.
- Sitemap dates reflect source modification dates where known and omit fabricated dates where unknown.
- Marketing tests and production build pass.
- Changeset exists.

## Open Questions

None. User selected rewriting every published page instead of redirects or search exclusion for overlapping articles.
