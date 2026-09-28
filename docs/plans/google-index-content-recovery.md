# Implementation Plan: Google Index Content Recovery

## Overview

Implement the approved indexing-recovery specification in risk-first slices. Behavioral SEO changes receive tests first. Content rewrites are grouped by search-intent cluster so each increment remains reviewable and the site builds between checkpoints.

## Architecture Decisions

- Derive tag indexability from post count at build time. Routes remain available; thin archives become `noindex,follow` and disappear from sitemap output.
- Keep taxonomy policy near existing tag and sitemap code rather than introducing a general SEO subsystem.
- Pass canonical page identity into shared structured-data rendering so non-home routes stop declaring themselves as homepage.
- Prefer real content dates. Omit `lastmod` where no trustworthy source date exists.
- Preserve all published article URLs and differentiate content rather than redirecting it.

## Task List

### Phase 1: Indexing Policy

#### Task 1: Test tag indexability policy

**Acceptance criteria:**

- A failing test requires archives with fewer than three posts to be noindexed and omitted from sitemap policy.
- A failing test requires populated retained archives to remain indexable.

**Verification:** `make test`

**Dependencies:** None

**Files likely touched:**

- `apps/marketing/src/content/tagIndexability.test.mjs`

#### Task 2: Implement tag indexability and navigation policy

**Acceptance criteria:**

- Thin tag routes render `noindex,follow`.
- Thin tags are excluded from generated sitemap output.
- Global tag navigation does not promote thin tags.

**Verification:** `make test && make build`

**Dependencies:** Task 1

**Files likely touched:**

- `apps/marketing/src/pages/blog/tags/[tag].astro`
- `apps/marketing/src/components/ui/blog/TagNavigation.astro`
- `apps/marketing/astro.config.mjs`
- `apps/marketing/src/content/tagIndexability.test.mjs`

### Checkpoint: Taxonomy

- Tests pass.
- Production build contains expected tag robots directives and sitemap membership.

### Phase 2: Semantic Signals

#### Task 3: Test and implement page-specific structured data

**Acceptance criteria:**

- A test fails against homepage-only `WebPage` identity.
- Shared structured data uses current canonical URL, page title, and description.
- Homepage organization/software/service entities remain intact.

**Verification:** `make test && make build`

**Dependencies:** None

**Files likely touched:**

- `apps/marketing/src/content/structuredData.test.mjs`
- `apps/marketing/src/components/blocks/head/partials/StructuredData.astro`
- `apps/marketing/src/components/blocks/head/Header.astro`
- `apps/marketing/src/layouts/Layout.astro`

#### Task 4: Correct sitemap freshness signals

**Acceptance criteria:**

- Blog and release entries retain real content dates.
- Unrelated static pages do not share a fabricated global modification date.
- Known current comparison dates can be represented without lying about other pages.

**Verification:** `make test && make build`

**Dependencies:** Task 2

**Files likely touched:**

- `apps/marketing/astro.config.mjs`
- relevant metadata test file if required

### Checkpoint: Technical SEO

- Tests pass.
- Production sitemap and JSON-LD checks pass.

### Phase 3: Documentation Value

#### Task 5: Expand thin task documentation

**Acceptance criteria:**

- API Keys explains setup, verification, replacement/removal, common failures, and security boundaries using verified behavior.
- Installation explains prerequisites, integration choice, success verification, updates, and removal paths where supported.
- Plans and Todos contains a complete example and clarifies user control and lifecycle.

**Verification:** `make test && make build`

**Dependencies:** None

**Files likely touched:**

- `apps/marketing/src/content/docs/docs/api-keys.md`
- `apps/marketing/src/content/docs/docs/installation.md`
- `apps/marketing/src/content/docs/docs/using/plans-and-todos.md`

#### Task 6: Clarify substantial documentation intent

**Acceptance criteria:**

- Ambiguous titles identify Frontman and the user task.
- Large pages remove stale or contradictory claims discovered during review.
- Cross-links establish one reference owner per repeated topic.

**Verification:** `make test && make build`

**Dependencies:** Task 5

**Files likely touched:**

- Up to five reviewed docs files per increment, split if needed

### Checkpoint: Documentation

- Metadata tests and broken-link build pass.
- New procedures match repository behavior.

### Phase 4: Article Differentiation

#### Task 7: Differentiate runtime-context articles

**Acceptance criteria:**

- `runtime-context-gap` owns technical architecture intent.
- `ai-coding-agents-blind-to-ui` owns UI-agent problem diagnosis.
- `introducing-frontman` owns product origin/category introduction.
- Each article uses distinct examples and links to sibling intent instead of repeating it.

**Verification:** `make test && make build`

**Dependencies:** None

**Files likely touched:**

- Three article Markdown files
- Metadata test if titles or required fields change

#### Task 8: Differentiate collaboration articles

**Acceptance criteria:**

- `edit-website-without-developer` owns governed self-service editing intent.
- `team-collaboration` owns role and review-process design.
- `multi-select` owns batch-selection product workflow with concrete constraints and output.
- Hypothetical timing claims are removed or labeled illustrative.

**Verification:** `make test && make build`

**Dependencies:** None

**Files likely touched:**

- Three article Markdown files

#### Task 9: Differentiate tutorials and announcements

**Acceptance criteria:**

- Next.js tutorial provides a reproducible, technically valid walkthrough distinct from integration docs.
- GPT model announcement becomes sourced release content with durable links to model reference.
- Lighthouse page removes placeholders and unsupported measurements; examples are reproducible or labeled illustrative.
- Security article uses verifiable architecture and policy references.

**Verification:** `make test && make build`

**Dependencies:** Task 5

**Files likely touched:**

- Split into increments of at most four article files

#### Task 10: Clarify comparison ownership

**Acceptance criteria:**

- Three-way blog article targets workflow selection across tool classes.
- `/vs/claude-code/` remains exact two-product comparison owner.
- Comparison methodology, dates, and sources are explicit.
- Unresolved table placeholder is removed.

**Verification:** `make test && make build`

**Dependencies:** None

**Files likely touched:**

- `apps/marketing/src/content/blog/frontman-vs-cursor-vs-claude-code.md`
- `apps/marketing/src/pages/vs/claude-code.astro`
- comparison metadata test if needed

### Checkpoint: Content

- Every article URL remains present.
- Metadata tests and broken-link build pass.
- Repository search finds no unresolved placeholders in rewritten pages.

### Phase 5: Delivery

#### Task 11: Add changeset and final verification

**Acceptance criteria:**

- Changeset describes indexing, taxonomy, and content-quality improvements.
- Changed files are formatted.
- Full marketing test suite and production build pass.
- Diff review finds no unsupported claims or unrelated changes.

**Verification:**

- `make test`
- `make build`
- `yarn prettier --check <changed-files>`

**Dependencies:** Tasks 1-10

**Files likely touched:**

- `.changeset/<generated-name>.md`

## Risks and Mitigations

| Risk                                          | Impact | Mitigation                                                                  |
| --------------------------------------------- | ------ | --------------------------------------------------------------------------- |
| Tag thresholds hide useful niche archives     | Medium | Keep routes available and use post-count threshold only for search exposure |
| Rewrites introduce unsupported claims         | High   | Verify behavior in source; label examples; prefer primary-source links      |
| Large content diff becomes unreviewable       | High   | Implement by intent cluster and build after each cluster                    |
| Structured-data change regresses rich results | Medium | Preserve global entities and add current-page identity tests                |
| Sitemap dates become incomplete               | Low    | Missing truthful dates are preferable to fabricated dates                   |
| Existing unrelated worktree changes conflict  | Medium | Inspect each touched file and preserve concurrent changes                   |

## Open Questions

None.
