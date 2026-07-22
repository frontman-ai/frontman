# Spec: Marketing Content Alignment

## Objective

Resolve all marketing content, metadata, and editorial-policy drift identified in GitHub issue #1310 except price amounts and trial durations.

Customer-facing content must distinguish:

- browser-side UI and browser tools;
- filesystem tools executed by the local framework integration;
- hosted or self-hosted server orchestration and task-history persistence;
- context transmitted to the selected LLM provider; and
- package-specific licenses from the source-available combined product.

It must also provide canonical author identities, accurate image metadata, explicit article sections, review evidence for volatile comparisons, implementation-accurate editorial documentation, and one hosted availability state. Hosted Frontman is available now; existing price amounts and trial durations remain untouched.

## Source Of Truth

- `apps/marketing/src/content/docs/docs/reference/architecture.md` defines runtime boundaries and persistence.
- `apps/marketing/src/data/markdown-files/terms.md`, `privacy.md`, `dpa.md`, and `subprocessors.md` define hosted processing and provider transmission.
- Package `LICENSE` files define package licenses.
- `apps/frontman_server/LICENSE` and `AI-SUPPLEMENTARY-TERMS.md` jointly define Frontman Server terms.
- `apps/marketing/src/content/blog/best-open-source-ai-coding-tools-2026.md` provides reviewed editorial language for the combined-product classification.

When these sources conflict with older marketing copy, update the marketing copy rather than weakening the source-of-truth language.

## Canonical Claims

### Data flow

Frontman uses a distributed architecture. Browser tools run in the browser, filesystem tools run on the user's machine through the framework integration, and the Frontman server orchestrates the agent loop and persists task history. The server has no direct filesystem access, but relevant file content, screenshots, logs, metadata, tool results, and generated output may pass through the server to the selected LLM provider.

Hosted Frontman uses Frontman-operated orchestration and persistence. Self-hosting moves those server components to infrastructure controlled by the user; it does not imply offline operation or prevent transmission to the configured LLM provider.

### Licensing

Frontman's browser client and JavaScript framework integrations are Apache-2.0. The WordPress plugin is GPL-2.0-or-later. Frontman Server is AGPL-3.0-only with AI Supplementary Terms restricting AI training and AI-assisted competitive reproduction. Because those server terms impose field-of-use restrictions, describe the combined product as source-available rather than fully open source.

Short surfaces may use `Source-available` with `Apache-2.0 browser/JS; GPL-2.0-or-later WordPress; AGPL-3.0-only server plus supplementary terms`. Package-specific references may call Apache-2.0 or GPL-2.0-or-later components open source.

## Commands

- Test: `make -C apps/marketing test`
- Build: `make -C apps/marketing build`
- Container test: `./bin/pod-exec make -C apps/marketing test`
- Container build: `./bin/pod-exec make -C apps/marketing build`
- Diff validation: `git diff --check`

## Project Structure

- `apps/marketing/src/pages/`: marketing and comparison pages.
- `apps/marketing/src/components/`: shared customer-facing copy and UI.
- `apps/marketing/src/content/blog/`: long-form customer-facing articles.
- `apps/marketing/src/content/docs/`: product documentation.
- `apps/marketing/src/data/markdown-files/`: legal and policy content.
- `apps/marketing/src/data/json-files/`: shared structured content.
- `apps/marketing/src/config/`: navigation and global metadata.

## Code Style

Preserve each file's existing formatting and component structure. Prefer precise boundary language over absolute shorthand.

```md
Frontman's server does not have direct access to your filesystem. File operations run through the local framework integration, while relevant context may be sent to your selected AI provider.
```

Do not use claims such as `everything runs locally`, `code never leaves`, `there are no servers`, `local-only`, or whole-product `open source` language.

## Testing Strategy

- Add no new runtime behavior tests for copy-only changes.
- Run existing marketing integration tests and production build.
- Search all customer-facing source for prohibited absolute locality claims.
- Search all customer-facing source for unqualified whole-product open-source claims.
- Manually inspect generated homepage, About, Features, Compare, `/vs/`, Docs, Security, launch article, Terms, FAQ structured content, and RSS surfaces.
- Add automated metadata checks before making blog image, author, and article-section fields required.
- Verify every blog image exists and declared dimensions match the asset.
- Verify every `/vs/` page exposes a visible source-check date and matching `WebPage.dateModified`.

## Boundaries

- Always: preserve competitor-specific open-source and locality claims unless surrounding text incorrectly attributes them to Frontman.
- Always: retain package-specific license precision and mention supplementary terms whenever summarizing Frontman Server licensing.
- Always: distinguish local filesystem ownership from context transmission.
- Ask first: change legal meaning beyond aligning Terms with existing repository license files.
- Ask first: alter pricing or trial duration.
- Never: claim self-hosting means offline operation unless a local model and all required local services are explicitly part of the scenario.
- Never: rewrite attributed customer quotations as if the speaker used different words.
- Never: modify unrelated editorial, visual, or application behavior.
- Never: mark volatile comparison facts reviewed without checking linked primary sources.
- Never: map a missing author to a generic organization or About-page Person identity.

## Delivery Slices

1. Align legal, global, homepage, About, Features, Compare, and shared component claims.
2. Align docs, security content, launch content, and other high-risk architecture explanations.
3. Align all `/vs/` pages and remaining blog/release references.
4. Run repository-wide claim searches, tests, build, and manual browser checks.
5. Normalize author identities and remove generic author-schema fallbacks.
6. Require and backfill accurate blog image metadata and explicit article sections.
7. Add visible comparison review dates, primary-source links, and structured-data dates; refresh stale non-commercial Stagewise facts.
8. Correct internal content-system and public editorial summaries to match implementation and binding policy.
9. Make hosted availability consistently available-now without changing prices or trial durations.

Each slice must remain independently buildable and must not introduce commercial-term changes.

## Success Criteria

- No Frontman claim says code or conversations never leave the user's machine.
- No Frontman claim says the whole system runs entirely locally or has no server.
- Local filesystem access, hosted persistence, and LLM-provider transmission are described consistently.
- Hosted and self-hosted operation are explicitly distinguished where locality is discussed.
- Whole-product surfaces classify Frontman as source-available.
- Browser client and JavaScript framework integration licensing remains identified as Apache-2.0; WordPress plugin licensing remains identified as GPL-2.0-or-later where package licenses are summarized.
- Server licensing is identified as AGPL-3.0-only with AI Supplementary Terms.
- Existing marketing tests and production build pass.
- Every blog post uses `Danni Friedland` or `Itay Adler`, canonical role and URL, and matching Person structured data.
- Every blog post declares accurate image alt text, width, and height; declared dimensions match the asset.
- Every blog post declares one controlled `articleSection`; JSON-LD no longer derives it from `tags[0]`.
- Tag and article-section semantics are documented separately.
- Every `/vs/` page exposes a visible primary-source review date and matching structured-data date.
- Stale Stagewise architecture/model-support claims are refreshed from primary sources without changing pricing.
- Editorial documentation distinguishes observed implementation, binding policy, and proposed workflow.
- Hosted availability is consistently available-now across pricing schema and customer-facing CTAs.
- Price amounts and trial durations remain unchanged.

## Open Questions

- Price amounts and trial durations remain intentionally unchanged by user decision on 2026-07-21.
- Hosted availability is canonicalized as available now by user decision on 2026-07-21.
