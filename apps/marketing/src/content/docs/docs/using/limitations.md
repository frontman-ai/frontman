---
title: Limitations & Workarounds
description: What Frontman can't do, and practical workarounds for auth-gated pages, viewport limits, timeouts, and stuck loops.
---

Frontman is opinionated about safety and scope. The [architecture](/docs/reference/architecture/) keeps your code local, ships only DOM context through the browser, and routes tools through the dev-server plugin. That design prevents entire classes of mistakes—but it also creates limits you should know about. This page collects the common "why can't it…" questions and shows how to work around them.

## What the agent can (and can’t) see

| Capability | Supported? | Details |
|------------|------------|---------|
| **Rendered DOM in the preview iframe** | ✅ | Anything in the preview at the current URL and viewport is fair game (via screenshots, DOM inspection, text search, and element interaction). |
| **Other browser tabs, devtools, or cross-origin iframes** | ❌ | The agent only sees the embedded preview. Popped-out tabs, browser extensions, and remote iframes are invisible. |
| **Source files inside the current workspace** | ✅ | The framework plugin exposes files under your repo root. |
| **Files outside the repo, `.env` secrets, shell access** | ❌ | Tools like `read_file`/`edit_file` are sandboxed to your project root. There is no terminal/shell tool, so the agent can’t run commands or read arbitrary files on your machine. |
| **Remote URLs** | ⚠️ | `web_fetch` blocks private networks/localhost (SSRF protection in `FrontmanServer.Tools.WebFetch`). Public URLs are fine but capped at 5 MB and 60 s per request. |

### Workarounds
1. **Navigate first** — open the exact route/state you care about before prompting so the agent’s first screenshot is already relevant.
2. **Annotate elements** — when multiple similar elements exist, annotations eliminate ambiguity.
3. **Paste out-of-band context** — logs, stack traces, or code that lives outside the repo can be pasted or attached as files/images.

## Auth-gated pages & stateful flows

Frontman can’t complete OAuth pop-ups, 2FA prompts, or third-party SSO flows because the preview iframe can’t leave your dev origin.

**Workarounds**
1. **Log in manually** — authenticate in your dev build, then prompt the agent. Frontman inherits your session cookies because it runs in the same browser context.
2. **Use dev-only bypasses** — add `NODE_ENV === 'development'` switches, seed accounts, or feature flags that keep the page accessible without third-party auth.
3. **Stub data** — for flows that require real API calls (Stripe checkout, etc.), inject mock responses or local fixtures so the page renders without hitting the gated endpoint.

## Viewport, scrolling, and hidden UI

- The preview iframe matches the viewport listed in the **Current Page Context** (e.g., `1381×1001`). Anything outside the viewport requires scrolling; the agent normally scrolls via `execute_js`, but long/infinite scroll pages can be tedious.
- Device presets cap the visible area. If something only renders on ultra-wide desktops, switch to `Responsive` mode before prompting.
- Fixed-position overlays can block clicks. Temporarily hide them (dev flag, Esc to close) or annotate underlying elements after dismissing the overlay yourself.

**Workarounds**
- Provide scrolling instructions: “Scroll to the pricing section and …”
- Break work into sections: “First fix the hero, then I’ll send a new prompt for the footer.”

## External requests, APIs, and SSRF protections

`web_fetch` and all dev-server tools assume the target is safe:
- URLs must be HTTP(S), public, and ≤5 MB responses.
- Hosts that resolve to `localhost`, `10.x.x.x`, `192.168.x.x`, `fc00::/7`, etc., are rejected (`Requests to private/internal addresses are not allowed`).
- Redirect chains >10 hops fail.

**Workarounds**
1. Mirror private docs to a public URL (e.g., a temporary share link) if you need the agent to read them via `web_fetch`.
2. Paste the relevant excerpts instead of fetching gated sites.
3. For API responses, save fixtures under `src/mock-data/` and point the agent at those files.

## File-system and tooling limits

- The agent can only edit files under the workspace root that the plugin exposes. Monorepos work fine, but sibling repos or parent directories are invisible.
- No shell access: build scripts, migrations, or seeds must be run manually. If a change requires `make something`, mention that you’ll run it afterward.
- Binary assets: `write_file` can save attachments, but there’s no image editor. Provide ready-to-use assets or handle image manipulation yourself.

## Timeouts, loops, and long-running jobs

- Each tool call has a timeout (e.g., `web_fetch` 60 s, file edits wait for Astro/HMR errors). Long-running builds or requests should be avoided.
- LLM streaming is guarded by `StreamStallTimeout`—if the provider stops sending tokens, the task aborts with a clear error.
- If the agent seems stuck in a loop (repeating the same screenshot/edit cycle without progress), click **Stop** in the chat UI, clarify the instruction, or split the task.

**Workarounds**
1. **Scope aggressively** — “Change the CTA button copy” instead of “Finish the entire landing page redesign.”
2. **Plan multi-step work** — let the agent finish one todo before queuing the next; it automatically maintains a todo list for 3+ item tasks.
3. **Answer questions promptly** — the [Question Flow](/docs/using/question-flow/) pauses execution until you respond.

## Handling errors & flaky dev servers

- If your dev server throws a runtime or build error, Frontman surfaces the log output but can’t restart the server for you. Fix the issue locally and reload the preview.
- Hot-module reload failures (e.g., Vite/Astro crash) need manual intervention. Once the preview works again, re-run your prompt.
- When the preview is blank (network errors, 500s), annotate or describe the issue; the agent can open the offending file and inspect logs but can’t view browser devtools.

## Checklist before prompting

1. **Navigate** to the page/route and state you want edited.
2. **Authenticate** manually if the page requires it.
3. **Annotate** critical elements so the agent goes straight to the right file.
4. **Gather references** (mockups, text snippets, API payloads) and attach/paste them.
5. **Decide scope** — one intent per prompt; sequence follow-ups for multi-step work.

Keeping these constraints in mind lets you play to Frontman’s strengths (precise DOM-aware edits, tight screenshot→diff loops) while avoiding dead ends. If you need deeper architectural context, continue with the [Architecture Overview](/docs/reference/architecture/) and [How the Agent Works](/docs/using/how-the-agent-works/).
