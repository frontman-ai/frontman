# Spec: Install With a Coding Agent

## Objective

Add a compact coding-agent handoff inside Step 1 of the marketing homepage install flow. A visitor selects Next.js, Astro, Vite, or WordPress, then copies safe, framework-specific setup instructions to paste into a coding agent.

Success means the copied instructions help an agent install and verify Frontman without overwriting existing configuration, assuming fixed ports, or handling user credentials. WordPress receives a manual admin-oriented handoff instead of shell automation.

## Confirmed Product Decisions

- Place the handoff inside Step 1, after the existing install command or WordPress action.
- Keep the install command primary and present the coding-agent handoff as a compact secondary action without a compatibility or brand row.
- Add the CTA, behavioral tests, Astro command correction, and Next.js production-safety documentation corrections.
- Keep canonical installation details at `https://frontman.sh/docs/installation/` and include that URL in every copied handoff.

## Behavior

- Default CTA text: `Copy for agent`.
- Successful copy text: `Copied!`.
- Failed copy text: `Copy failed`.
- The button retains the stable accessible name `Copy setup instructions for coding agent` across visual feedback states.
- Copy status is exposed through an `aria-live="polite"` region.
- Selecting a framework updates the install command, displayed URL guidance, and copied handoff as one state change.
- Next.js, Astro, and Vite handoffs require the agent to inspect project framework, package manager, existing configuration, and git status before editing.
- JavaScript-framework handoffs include the exact selected install command and require the agent to start the project's normal development server, detect its actual local origin, verify `/frontman`, and report commands, changed files, verification results, and remaining manual steps.
- Next.js handoff calls out production exposure and requires review of generated middleware or proxy behavior.
- WordPress handoff requires a staging site, backup, administrator access, and user-completed wp-admin installation, OAuth, and provider setup. It does not claim the coding agent can perform privileged browser actions.
- No handoff requests, reads, stores, or enters credentials.
- CTA click uses existing delegated analytics attributes.

## Copied Instruction Shape

```text
Install Frontman for this [framework] project.

Before changing files:
- Confirm the project and package manager.
- Inspect existing configuration and git status.
- Preserve existing application behavior.
- Follow https://frontman.sh/docs/installation/.

Run: [selected canonical command]

Start the project's normal development server, detect its actual local origin,
and verify /frontman loads on that origin.

Do not enter credentials or complete OAuth. Report commands run, files changed,
verification results, and manual steps still required.
```

Framework-specific safety text extends this common shape. WordPress uses separate prose suitable for wp-admin instead of a `Run:` command.

## Visual Design

- Preserve current Step 1 yellow card, typography, spacing scale, border treatment, and responsive behavior.
- Keep the terminal command as the strongest action inside Step 1.
- Render the handoff as a compact text action below the terminal with the prompt `Using an AI coding agent?`.
- Copy feedback changes text and icon without changing button dimensions enough to shift surrounding layout.

## Presentation Scope

- Do not show vendor marks or imply compatibility, partnership, or endorsement for named coding-agent products.
- Keep the handoff product-neutral so visitors can paste the instructions into their preferred coding agent.

## Documentation Corrections

- Change homepage Astro command from `astro add @frontman-ai/astro` to canonical `npx astro add @frontman-ai/astro`.
- Align `apps/marketing/src/content/docs/docs/integrations/nextjs.mdx`, `apps/marketing/src/pages/how-it-works.astro`, and `apps/marketing/public/llms.txt` with the production warning in `apps/marketing/src/content/docs/docs/installation.md`.
- Do not weaken the canonical warning: generated Next.js middleware or proxy can be included in production unless users add an environment guard or remove the integration.

## Project Structure

- `apps/marketing/src/components/blocks/install/InstallSteps.astro`: install metadata, compact Step 1 CTA, styles, and DOM wiring.
- `apps/marketing/src/integrations/install-agent.mjs`: pure prompt selection and browser copy-state wiring if extraction is required for direct tests.
- `apps/marketing/src/integrations/install-agent.test.mjs`: prompt and DOM behavior tests.
- `apps/marketing/src/content/docs/docs/integrations/nextjs.mdx`: corrected Next.js production behavior.
- `apps/marketing/src/pages/how-it-works.astro`: corrected public production-build FAQ.
- `apps/marketing/public/llms.txt`: corrected machine-readable production behavior.

## Code Style

Follow existing Astro and browser-module patterns. Keep prompt data explicit rather than creating a generic prompt-building framework.

```js
const instructionsByFramework = {
  nextjs: "Install Frontman for this Next.js project...",
  astro: "Install Frontman for this Astro project...",
}

const copyInstructions = async framework => {
  await navigator.clipboard.writeText(instructionsByFramework[framework])
}
```

Use semantic buttons, `data-*` hooks for DOM behavior, and project Tailwind `@reference` styles. Do not add dependencies.

## Testing Strategy

- Write failing tests before implementation for selected-framework payloads, WordPress manual guidance, successful clipboard feedback, visible failure feedback, and framework switching.
- Use Vitest and JSDOM following `apps/marketing/src/integrations/consent.dom.test.mjs` conventions.
- Run marketing tests and production build.
- Verify in a real browser at 320px, 768px, 1024px, and 1440px widths.
- Verify keyboard focus, accessible names, live status, clipboard success/failure, all four framework tabs, and zero console errors.

## Commands

```bash
make -C apps/marketing test
make -C apps/marketing build
make -C apps/marketing dev PORT=4321
```

## Boundaries

- Always: preserve existing install flow, use canonical commands, show copy failures, keep credentials manual, and test each framework payload.
- Ask first: adding dependencies, changing CTA placement, changing canonical install commands, or expanding the public installation skill.
- Never: claim compatibility with every agent, automate credential entry, assume a fixed localhost port, overwrite existing middleware/configuration, or imply vendor endorsement.

## Success Criteria

1. Step 1 contains the coding-agent copy CTA for all four selected frameworks.
2. Clipboard receives correct framework-specific instructions.
3. WordPress receives manual, staging-first admin guidance.
4. Success and failure states are visible and announced accessibly.
5. The handoff remains visually secondary to the canonical install command and does not name or imply support for specific coding-agent products.
6. Astro homepage command matches canonical docs.
7. Next.js production-safety docs no longer contradict the canonical installation guide.
8. Marketing tests and build pass.
9. Homepage interaction and responsive layout pass real-browser verification.

## Open Questions

None. Product choices were confirmed before specification.
