---
title: 'I Built an AI Coding Agent That Lives in Your Browser'
pubDate: 2026-02-23T05:00:00Z
description: 'Frontman hooks into your dev server as middleware and sees the live DOM, styles, routes, and server logs. Click any element, describe changes in plain English. Open source, BYOK, no prompt limits.'
author: 'Frontman Team'
image: '/blog/frontman-launch-cover.png'
tags: ['announcement', 'open-source', 'ai', 'developer-tools']
---

Every AI coding tool I've used has the same blind spot: it edits source files without ever seeing the running application. You describe a layout bug. The AI reads your JSX, guesses what the DOM looks like, and generates a fix. You switch to the browser. Wrong. The AI didn't know about the inherited padding, the conditional render that adds a third child, or the CSS variable that resolves differently at this breakpoint. Switch back, describe it again. Repeat.

This loop — describe, edit, check, re-describe — is where a surprising amount of AI-assisted development time goes. Not on the AI generating code. On _you_ being the bridge between what the AI thinks the app looks like and what it actually looks like.

The same thing happens server-side. Your AI edits a Next.js API route but doesn't know what middleware is active, what the compiled module graph looks like, or what's in the server logs.

### What Frontman Does Differently

[Frontman](https://frontman.sh) is an open-source AI coding agent that lives inside your browser. Instead of working from source files alone, it hooks into your framework's dev server as middleware and sees both sides of the application.

**Client side:** the rendered DOM, component tree, computed styles, layout geometry, console output, click targets.

**Server side:** registered routes, compiled module graph, server logs, middleware state, framework-specific context like Astro island hydration, Next.js server/client component boundaries, and Vite's HMR state.

The workflow: open your app in the browser, click any element, describe what you want changed in plain English. Frontman maps the runtime element back to the source file and line number, gives the AI the full runtime context, and applies the edit. Hot reload shows you the result immediately.

### The Architecture Decision That Matters

Frontman installs as **actual middleware** inside your framework's dev server — not as an external proxy or browser extension.

This matters because the dev server already knows everything about both sides of your application. Next.js knows its route table and server/client component boundaries. Vite knows its HMR module graph and compiled output. Astro knows which islands hydrated. By running _inside_ the framework, Frontman gets native access to all of this without reimplementing it.

```bash
npx @frontman-ai/nextjs install   # for Next.js
npx @frontman-ai/vite install     # for Vite (React/Vue/Svelte)
astro add @frontman-ai/astro      # for Astro
```

One import in your framework config, start the dev server, and the agent is available at `localhost/frontman`.

Both client-side and server-side context are exposed via MCP (Model Context Protocol), so the AI agent works with structured runtime data rather than parsing HTML strings or grepping server logs.

### The Source Mapping Problem

The hardest part isn't getting runtime data — it's mapping it back to source code. "This `<div>` with these computed styles" needs to become "this component at `src/components/Card.tsx:47`." Frontman uses a combination of sourcemaps, React/Vue/Svelte fiber/instance metadata, and framework-specific component registries to make this connection. It's not perfect — deeply abstracted component libraries can break the mapping — but for most application code it's reliable.

### Honest Tradeoffs

**What works well:**

- CSS and layout fixes — the AI can see computed styles, so it knows _why_ something looks wrong
- Visual debugging — click the broken element instead of describing it
- Server-side debugging — the AI sees the actual error in server logs alongside the component that triggered it
- Onboarding — "what component renders this section?" is answered instantly
- Designer/PM collaboration — non-engineers can click elements and describe changes without opening an IDE

**What doesn't work well yet:**

- Complex state management changes — the visual output doesn't tell you if the logic is correct
- Performance optimization — Frontman sees the DOM and server state, not render cycles or bundle sizes
- Large refactors — runtime context helps with surgical edits, not architectural changes
- Unsupported frameworks — Angular, Remix, or SvelteKit standalone don't have middleware adapters yet

### Why Open Source

Frontman is licensed as Apache 2.0 (client libraries) and AGPL-3.0 (server). The BYOK model means your code and your AI interactions stay between you and your AI provider. Nothing routes through our servers. There's nothing to route through — there are no servers.

This isn't altruism. Open source is the only credible model for a tool that sits inside your dev server and sees your source code. If I can't read the code that has access to my codebase, I'm not installing it. You probably feel the same way.

### Try It

Full setup instructions: [frontman.sh](https://frontman.sh). Source code: [github.com/frontman-ai/frontman](https://github.com/frontman-ai/frontman).

Frontman is early-stage. There are rough edges. The documentation could be better. But the runtime context gap is real, and closing it saves real time on a specific class of problems. [Get started in under 5 minutes](/blog/getting-started/).
