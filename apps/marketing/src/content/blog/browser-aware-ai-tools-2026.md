---
title: 'Browser-Aware AI Coding Tools in 2026 — Compared by Architecture'
pubDate: 2026-02-23T06:00:00Z
description: "Frontman, Stagewise, Tidewave, Chrome DevTools MCP, and Onlook: how each one connects to your running app, what they can and can't see, and who each is for."
author: 'Danni Friedland'
image: '/blog/browser-aware-ai-tools-2026-cover.png'
tags: ['comparison', 'ai', 'developer-tools']
updatedDate: 2026-03-10T00:00:00Z
---

There's a new category of AI coding tools emerging: ones that connect to your running application instead of just reading source files. The pitch is the same across all of them — give the AI runtime context so it stops guessing about what your app actually looks like and does.

The implementations are very different. Some hook into the dev server. Some proxy the browser. Some expose DevTools via MCP. Some are free, some charge monthly, some are experimental. Most "tool roundup" articles are either thinly disguised ads or surface-level feature lists. This is neither — we're involved with Frontman (one of the tools listed), and we'll be transparent about where it's stronger and where it's weaker.

### Why This Category Exists

AI coding tools — Cursor, Copilot, Claude Code, Windsurf — work from source files. They don't see the rendered DOM, computed styles, or layout geometry on the client side. They don't see the compiled module graph, registered routes, server logs, or middleware state on the server side. For any web application with a runtime, the AI is guessing about a significant chunk of the application's behavior.

Runtime-aware tools try to close this gap — what we call [the runtime context gap](/blog/runtime-context-gap/). Here's how each one does it.

### Frontman

**Website:** [frontman.sh](https://frontman.sh) | **License:** Apache 2.0 / AGPL-3.0 | **Stars:** ~131

Framework middleware for Next.js, Astro, and Vite. Installs _inside_ the framework's dev server, so it has native access to both client-side context (DOM, component tree, computed styles) and server-side context (routes, compiled module graph, server logs). Both exposed via MCP.

**Strengths:** Deepest framework integration. Fully free, no prompt limits, no account. BYOK — connect Claude, OpenAI, or OpenRouter directly. Open source with permissive client library licensing.

**Weaknesses:** Early stage. Rough edges, incomplete documentation, small community. Limited to supported frameworks. Source mapping breaks on deeply abstracted component libraries.

_Disclosure: We built this._

### Stagewise

**Website:** [stagewise.io](https://stagewise.io) | **License:** AGPL-3.0 | **Stars:** ~6,500 | **Backing:** YC S25

Started as a browser toolbar, now evolving into a standalone agent with CLI injection. `npx stagewise@latest` starts a proxy and injects a toolbar into your running app. Two modes: standalone (hosted agent, account required) or bridge (connects to Cursor/Copilot).

**Strengths:** Most polished UX. Active community. Supports React, Next.js, Vue, Angular plus CSS frameworks. YC credibility.

**Weaknesses:** ~10 free prompts/day, EUR 20/month for ~100/day. Requires account and OAuth. Proxy architecture means limited server-side visibility. No BYOK — inference goes through their servers. No Astro or Svelte support.

### Tidewave

**Website:** [tidewave.ai](https://tidewave.ai) | **Stars:** ~1,600 | **Created by:** José Valim (Elixir creator)

Not a coding agent itself — an MCP enhancement layer that gives your existing agent (Claude Code, Codex) access to runtime state. Deep backend integration: database queries, runtime evaluation, stack traces, live process state. Built for Phoenix/Elixir primarily.

**Strengths:** Deep backend integration unmatched by anything else. Built by José Valim. Works with your existing agent.

**Weaknesses:** JS framework support is thin (~28 stars on `tidewave_js`). $10/month. Not standalone. If you're a JS/TS developer, this isn't built for you yet.

### Chrome DevTools MCP (Google)

Google's experimental MCP server exposing DevTools state to AI agents. Your agent can query the DOM, read console output, inspect network requests.

**Strengths:** Official Google project. Framework-agnostic. Free and open.

**Weaknesses:** Raw — no agent included. Browser-only (no server-side context). Experimental. Requires manual setup.

### Onlook (Honorable Mention)

**Website:** [onlook.dev](https://onlook.dev) | **Stars:** ~24,700 | **Backing:** YC

"Cursor for Designers" — a Figma-like visual editor for React/Next.js. Different category (visual design tool, not runtime-aware coding agent), but overlaps in the "non-engineers editing code" use case. Uses a sandboxed web container, not your real dev server.

### Comparison Table

| Feature          | Frontman             | Stagewise     | Tidewave    | Chrome MCP |
| ---------------- | -------------------- | ------------- | ----------- | ---------- |
| Architecture     | Framework middleware | Browser proxy | MCP server  | MCP server |
| Client runtime   | Yes                  | Yes           | Yes         | Yes        |
| Server runtime   | Yes                  | Limited       | Yes (deep)  | No         |
| Standalone agent | Yes                  | Yes           | No          | No         |
| Free (no limits) | Yes                  | No (10/day)   | No ($10/mo) | Yes        |
| BYOK             | Yes                  | No            | Yes         | Yes        |
| Next.js          | Yes                  | Yes           | Thin        | Yes        |
| Astro            | Yes                  | No            | No          | Yes        |
| Svelte           | Yes                  | No            | No          | Yes        |
| Vue              | Yes                  | Yes           | No          | Yes        |
| Account required | No                   | Yes           | Yes         | No         |

### Which One Should You Use?

**Phoenix/Rails/Django developer:** Tidewave. Deep backend runtime that nothing else matches.

**Want the most polished UX and don't mind paying:** Stagewise. The YC backing shows.

**Want free + deep framework integration + full control:** Frontman. See [how deep framework integration affects design system consistency](/blog/what-are-framework-aware-ai-coding-tools/). No prompt limits, no account, BYOK, open source. The tradeoff is that it's early-stage with rougher edges.

**Want to add browser context to your existing agent:** Chrome DevTools MCP. Bare-bones but framework-agnostic and free.

**Designer who wants a visual editor:** Onlook. Different category entirely.

The category is real — and it's part of a broader wave of [open-source AI coding tools](/blog/best-open-source-ai-coding-tools-2026/). Six months ago this wasn't a thing. Now there are five projects with different architectures attacking the same problem. Some will be dead in a year. Some will be table stakes. Try them on a real project and decide for yourself. [Get started with Frontman](/blog/getting-started/), [see how it compares to Cursor and Claude Code](/blog/frontman-vs-cursor-vs-claude-code/), or read the detailed [Frontman vs Cursor](/vs/cursor/) and [Frontman vs Stagewise](/vs/stagewise/) comparisons.
