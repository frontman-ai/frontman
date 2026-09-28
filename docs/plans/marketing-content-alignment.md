# Implementation Plan: Marketing Content Alignment

## Overview

Apply all approved issue #1310 alignment work except price amounts and trial durations. Existing locality/licensing work remains the foundation; metadata, comparison evidence, editorial documentation, and hosted availability follow in dependency order.

## Architecture Decisions

- Edit copy in place; do not add a content abstraction for static prose.
- Treat architecture, legal processing documents, package licenses, and supplementary terms as authority.
- Use concise `source-available` labels on comparison surfaces and fuller package-specific language in explanatory prose.
- Preserve attributed quotations and competitor-specific claims.
- Verify copy-only claims with searches, existing tests, build, and browser rendering; add focused contract tests for required metadata.

## Task List

### Phase 1: Global And Legal Surfaces

- [ ] Task 1: Align legal and global metadata
  - Acceptance: Terms mention server supplementary terms; global FAQ, RSS, tag, index, and footer copy no longer classify whole product as open source.
  - Verify: targeted claim search and `git diff --check`.
  - Files: `terms.md`, `faqData.json`, `rss.xml.ts`, `pages/blog/tags/[tag].astro`, `pages/index.md.ts`, `footerNavigation.ts` split across two edit increments.

- [ ] Task 2: Align homepage shared components
  - Acceptance: Homepage labels combined product source-available and package details remain accurate.
  - Verify: targeted claim search and marketing build checkpoint.
  - Files: `ComparisonTable.astro`, `FeatureHighlights.astro`, `HomeCTA.astro`, `OpenSourceBadge.astro`, `socialproof/Basic.astro`.

- [ ] Task 3: Align primary overview pages
  - Acceptance: About, Features, How It Works, and Compare distinguish distributed architecture and source availability.
  - Verify: targeted claim search and manual copy review.
  - Files: `about.astro`, `features.astro`, `how-it-works.astro`, `compare.astro`, `use-cases/designers.astro`.

### Checkpoint: Global Surfaces

- [ ] Existing tests pass.
- [ ] Marketing build succeeds.
- [ ] Homepage and primary overview pages render.

### Phase 2: Architecture And Security Content

- [ ] Task 4: Align product documentation
  - Acceptance: Docs index, self-hosting, limitations, and agent flow state filesystem, server, persistence, and provider boundaries accurately.
  - Verify: prohibited-locality search and docs build.
  - Files: docs `index.md`, `reference/self-hosting.md`, `using/limitations.md`, `using/how-the-agent-works.md`.

- [ ] Task 5: Align high-risk security and launch articles
  - Acceptance: Security and launch content no longer claims no server, no persistence, or no provider-bound context; licensing is source-available.
  - Verify: prohibited-locality and licensing searches.
  - Files: `security.md`, `frontman-launch.md`, `frontman-openclaw-skill.md`, `gpt-5.4-support.md`.

### Checkpoint: Authority Surfaces

- [ ] Existing tests pass.
- [ ] Marketing build succeeds.
- [ ] Docs architecture, self-hosting, security, and launch pages render consistently.

### Phase 3: Comparison Pages

- [ ] Task 6: Align shared comparison pricing and first comparison group
  - Acceptance: Shared defaults and Windsurf, v0, Stagewise pages use source-available and distributed/self-hosted wording.
  - Verify: targeted searches for those files.
  - Files: `ComparisonPricing.astro`, `windsurf.astro`, `v0.astro`, `stagewise.astro`.

- [ ] Task 7: Align second comparison group
  - Acceptance: OpenClaw, Onlook, and Lovable pages contain no whole-product open-source or never-leaves claims.
  - Verify: targeted searches for those files.
  - Files: `openclaw.astro`, `onlook.astro`, `lovable.astro`.

- [ ] Task 8: Align third comparison group
  - Acceptance: Cursor, Copilot, and Claude Code pages use canonical license and architecture wording.
  - Verify: targeted searches for those files.
  - Files: `cursor.astro`, `copilot.astro`, `claude-code.astro`.

- [ ] Task 9: Align final comparison page
  - Acceptance: Bolt page uses canonical license wording.
  - Verify: targeted search for file.
  - Files: `bolt.astro`.

### Checkpoint: Comparisons

- [ ] Existing tests pass.
- [ ] Marketing build succeeds.
- [ ] Every `/vs/` page renders.

### Phase 4: Remaining Articles And Verification

- [ ] Task 10: Align browser-aware and production-tool articles
  - Acceptance: Four high-traffic articles classify Frontman consistently.
  - Verify: targeted licensing search.
  - Files: `6-ai-coding-tools-production.md`, `browser-aware-ai-tools-2026.md`, `what-are-browser-aware-ai-coding-tools.md`, `wordpress-integration.md`.

- [ ] Task 11: Align remaining explanatory articles
  - Acceptance: Remaining direct whole-product claims use source-available language.
  - Verify: targeted licensing search.
  - Files: `runtime-context-gap.md`, `building-agentic-harness-agent-client-protocol.md`, `best-ai-tools-ui-ux-designers-2026.md`, `introducing-frontman.md`.

- [ ] Task 12: Align repeated CTA and release copy
  - Acceptance: Repeated open-source-core CTA wording and release license summary are canonical.
  - Verify: targeted licensing search.
  - Files: `frontman-vs-cursor-vs-claude-code.md`, `edit-nextjs-visually.md`, `edit-website-without-developer.md`, `releases/march-2026.md`.

- [ ] Task 13: Complete repository-wide verification
  - Acceptance: No prohibited Frontman locality absolutes or unqualified whole-product open-source claims remain; expected competitor and package-specific matches are manually reviewed.
  - Verify: `git diff --check`, claim searches, `make -C apps/marketing test`, `make -C apps/marketing build`, browser checks.
  - Files: no planned source changes; corrections only if verification finds scoped misses.

## Risks And Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Search-and-replace changes competitor claims | High | Edit manually and inspect every diff hunk. |
| Legal wording exceeds source alignment | High | Keep Terms change limited to explicit repository license references. |
| Concise labels lose package nuance | Medium | Pair `Source-available` with package detail or canonical linked explanation. |
| Large content sweep creates inconsistent phrasing | Medium | Use approved canonical claims and rerun claim scans after each phase. |
| Commercial contradictions get changed incidentally | Medium | Preserve price amounts and trial durations; canonicalize hosted availability as available now; verify competitor capability facts against primary sources. |

## Open Questions

- None. Hosted availability is available-now; price amounts and trial durations remain unchanged.

### Phase 5: Author And Article Metadata

- [ ] Task 14: Add failing metadata completeness tests
  - Acceptance: Tests fail for missing canonical author fields, image metadata, explicit article sections, and mismatched dimensions.
  - Verify: targeted Vitest run fails for expected reasons.
  - Files: metadata test and marketing Makefile.

- [ ] Task 15: Harden content schema and structured-data mapping
  - Acceptance: Author identity/role/URL, image metadata, and article section are required; `PostLayout` uses explicit canonical fields without `/about/` fallback.
  - Verify: Astro check and metadata tests.
  - Files: `content.config.ts`, `PostLayout.astro`, `BlogPostHero.astro` if needed.

- [ ] Task 16: Backfill all blog frontmatter
  - Acceptance: All posts have canonical author fields, accurate image metadata, and one controlled article section.
  - Verify: metadata tests compare frontmatter with actual assets.
  - Files: blog Markdown files in small batches.

- [ ] Task 17: Add canonical Itay Adler author page
  - Acceptance: `/authors/itay-adler/` emits matching Person identity and article links.
  - Verify: production build and generated-page inspection.
  - Files: author page and any shared author data if justified.

### Phase 6: Taxonomy And Editorial Documentation

- [ ] Task 18: Define taxonomy and metadata semantics
  - Acceptance: Writing guide separates controlled article sections from free-form topic/product/audience tags and documents author/image fields.
  - Verify: documentation review against schema and layout.
  - Files: `writing-style.md`.

- [ ] Task 19: Correct content-system implementation descriptions
  - Acceptance: Docs accurately describe intent path, proposed workflows, conditional tutorial safety, comparison dates, optional `/vs/` sections, structured data, integration routes, and `CodeFromFile` limits.
  - Verify: references match current code paths.
  - Files: `writing-style.md`, `docs/architecture.md`.

- [ ] Task 20: Resolve weak exemplar and evidence-image policy
  - Acceptance: Weak article is removed as exemplar unless revised; guide states evidence-led articles require claim-specific visuals when useful and covers are not inserted automatically.
  - Verify: editorial review.
  - Files: `writing-style.md` and article only if revision is chosen.

### Phase 7: Comparison Freshness

- [ ] Task 21: Add required comparison review metadata
  - Acceptance: Shared layout requires ISO review date and at least one source, displays both visibly, and emits matching `dateModified`.
  - Verify: Astro check plus generated HTML assertions.
  - Files: comparison layout, disclosure, structured-data component.

- [ ] Task 22: Add reviewed primary sources to all detailed comparisons
  - Acceptance: All ten `/vs/` pages provide checked date and official source links.
  - Verify: source metadata count and build.
  - Files: ten `/vs/` pages in small batches.

- [ ] Task 23: Refresh stale Stagewise non-commercial facts
  - Acceptance: Stagewise is described as current agentic IDE/browser-preview product with direct BYOK/custom providers/local inference; obsolete DOM-only/bridge-only claims are absent.
  - Verify: targeted claim scan and source review.
  - Files: Stagewise page, `/vs/` index/alternatives, `/compare`.

### Phase 8: Hosted Availability

- [ ] Task 24: Align available-now status
  - Acceptance: Pricing JSON-LD and customer-facing CTAs no longer say PreOrder or coming soon; price and trial text is byte-for-byte unchanged except surrounding availability sentence where unavoidable.
  - Verify: commercial diff scan and build.
  - Files: pricing schema, shared CTA, remaining coming-soon references.

### Phase 9: Final Verification

- [ ] Task 25: Run complete quality gate
  - Acceptance: Metadata tests, marketing tests, Astro check/build, claim scans, generated schema inspection, and independent review pass.
  - Verify: commands in spec plus browser checks when browser backend is available.
  - Files: corrections only for scoped findings.
