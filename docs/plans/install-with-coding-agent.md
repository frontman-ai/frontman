# Implementation Plan: Install With a Coding Agent

## Overview

Implement issue #460 as a framework-aware clipboard handoff inside Step 1. Keep prompt generation and browser state testable, preserve current install flow, align safety documentation, then verify responsive behavior in a real browser.

## Architecture Decisions

- Extract prompt data and DOM wiring into `install-agent.mjs` because Astro inline scripts cannot be imported directly into focused Vitest/JSDOM tests.
- Keep four explicit handoff strings. Avoid generic prompt composition because each integration has materially different safety guidance.
- Keep the install command primary and render the coding-agent handoff as a compact, product-neutral secondary action.
- Keep UI in `InstallSteps.astro`; no new Astro component unless implementation exceeds a focused Step 1 block.

## Task List

### Phase 1: Tested Clipboard Behavior

#### Task 1: Specify Prompt and Copy States

**Description:** Add failing tests for four framework payloads, fixed-port avoidance, WordPress manual guidance, success feedback, failure feedback, and tab-driven selection.

**Acceptance criteria:**
- Tests describe all four framework handoffs.
- Tests require visible success and failure status.
- Tests fail because runtime behavior does not yet exist.

**Verification:**
- `make -C apps/marketing test` fails only on new expectations.

**Dependencies:** None.

**Files likely touched:**
- `apps/marketing/src/integrations/install-agent.test.mjs`

**Estimated scope:** Small.

#### Task 2: Implement Prompt and Copy Runtime

**Description:** Add minimal exported prompt data and browser event wiring needed to satisfy Task 1.

**Acceptance criteria:**
- Selected framework determines clipboard payload.
- Clipboard success and failure update accessible status.
- Existing terminal copy controls remain independent.

**Verification:**
- `make -C apps/marketing test`

**Dependencies:** Task 1.

**Files likely touched:**
- `apps/marketing/src/integrations/install-agent.mjs`
- `apps/marketing/src/integrations/install-agent.test.mjs`

**Estimated scope:** Small.

### Checkpoint: Runtime

- Marketing tests pass.
- Prompt payloads contain no credential automation or fixed-port assumptions.

### Phase 2: Step 1 User Interface

#### Task 3: Integrate Compact CTA

**Description:** Add the CTA, live status, analytics attributes, framework state, and responsive handoff inside Step 1.

**Acceptance criteria:**
- CTA appears inside Step 1 for every selected framework.
- Framework tabs update both existing install content and handoff selection.
- Terminal command remains visually primary.
- Handoff remains product-neutral and wraps cleanly on mobile.
- Astro command uses `npx astro add @frontman-ai/astro`.

**Verification:**
- `make -C apps/marketing test`
- `make -C apps/marketing build`

**Dependencies:** Task 2.

**Files likely touched:**
- `apps/marketing/src/components/blocks/install/InstallSteps.astro`
- `apps/marketing/src/integrations/install-agent.mjs`

**Estimated scope:** Medium.

### Checkpoint: UI

- Marketing tests and build pass.
- CTA is keyboard accessible and status is announced.

### Phase 3: Documentation and Release Metadata

#### Task 4: Align Next.js Production Guidance

**Description:** Replace conflicting development-only claims with canonical production-exposure guidance.

**Acceptance criteria:**
- Next.js integration guide matches installation guide.
- `llms.txt` no longer claims all integrations are tree-shaken from production.
- Guidance remains precise about framework differences.

**Verification:**
- Content search finds no remaining contradictory absolute claim in changed sources.
- `make -C apps/marketing build`

**Dependencies:** None.

**Files likely touched:**
- `apps/marketing/src/content/docs/docs/integrations/nextjs.mdx`
- `apps/marketing/src/pages/how-it-works.astro`
- `apps/marketing/public/llms.txt`

**Estimated scope:** Small.

#### Task 5: Add Changeset

**Description:** Add changelog fragment for user-visible marketing install handoff and corrected guidance.

**Acceptance criteria:**
- Changeset accurately describes user-facing change.
- Package and release level match repository convention.

**Verification:**
- Inspect changeset format against recent fragments.

**Dependencies:** Tasks 4 and 5.

**Files likely touched:**
- `.changeset/*.md`

**Estimated scope:** Extra small.

### Phase 4: End-to-End Verification

#### Task 6: Verify Homepage in Browser

**Description:** Run marketing site and verify all selected-framework clipboard paths, visual layout, accessibility state, and console health.

**Acceptance criteria:**
- All four tabs copy expected handoffs.
- Success and simulated failure feedback are visible.
- Layout works at 320px, 768px, 1024px, and 1440px.
- No console errors appear during flow.

**Verification:**
- Chrome DevTools DOM, accessibility snapshot, console, and screenshots.
- Final `make -C apps/marketing test` and `make -C apps/marketing build` after any browser-found fixes.

**Dependencies:** Tasks 3-5.

**Files likely touched:** None unless verification finds defects.

**Estimated scope:** Small.

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Inline Astro state diverges from tested module | High | Make Astro import and invoke the tested runtime rather than duplicate logic. |
| Clipboard API unavailable or denied | Medium | Expose visible failure state and retain existing manual command copy controls. |
| Longer success text shifts Step 1 layout | Low | Give CTA stable responsive dimensions and verify narrow viewport. |
| WordPress appears automated | High | Use manual admin verbs and explicit user-controlled authentication language. |

## Open Questions

None.
