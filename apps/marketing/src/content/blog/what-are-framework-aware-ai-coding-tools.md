---
title: 'What Are Framework-Aware AI Coding Tools?'
pubDate: 2026-03-17T10:00:00Z
description: 'Framework-aware AI coding tools understand the structure of your web framework—components, routes, server/client boundaries—not just source files. Here is what the category is, how the three architectures work, and which tools exist today.'
author: 'Danni Friedland'
image: '/blog/what-are-framework-aware-ai-coding-tools-cover.png'
tags: ['ai', 'developer-tools', 'comparison']
faq:
  - question: 'What is a framework-aware AI coding tool?'
    answer: >-
      A framework-aware AI coding tool is an AI code editor that understands the structure
      of your web framework—not only source files on disk. It knows about components, routes,
      server/client boundaries, the module graph, and runtime state. This deep framework
      context lets the AI make more accurate edits because it understands how your application
      is actually structured, not just what the code says.
  - question: 'How are framework-aware AI coding tools different from Cursor or Copilot?'
    answer: >-
      IDE-based tools like Cursor, Copilot, and Claude Code read source files and can run
      your app. But they don't understand the framework's architecture. They can't see the
      component tree, the route structure, server component boundaries in Next.js, or island
      hydration in Astro. Framework-aware tools hook into the framework itself and see the
      application the way the framework sees it.
  - question: 'What are the three architectures for framework-aware AI coding tools?'
    answer: >-
      The three architectures are framework middleware (installs inside the dev server for
      deep framework access), browser proxy (sits between browser and dev server, intercepts
      traffic to inject tooling), and MCP bridge (exposes framework state through the Model
      Context Protocol for existing agents). Each makes different tradeoffs between depth
      of framework context and ease of setup.
  - question: 'Which framework-aware AI coding tools exist in 2026?'
    answer: >-
      As of March 2026, the main framework-aware AI coding tools are Frontman (framework
      middleware for Next.js, Astro, Vite), Stagewise (browser proxy with CLI injection,
      YC-backed), Chrome DevTools MCP (Google's experimental MCP server for DevTools),
      Tidewave (MCP server focused on backend runtime for Phoenix/Rails), and Cursor's
      Visual Editor (built into Cursor IDE). Onlook is adjacent as a visual design tool
      for React.
  - question: 'Do framework-aware AI coding tools replace IDE-based tools like Cursor?'
    answer: >-
      No. They solve a different problem. IDE-based tools are better for pure logic,
      refactoring, multi-file edits, and backend code that doesn't depend on framework
      structure. Framework-aware tools are better for anything where understanding the
      framework architecture matters: component composition, route structure, server/client
      boundaries, and visual changes tied to runtime state. Some teams use both.
---

Framework-aware AI coding tools are AI code editors that understand the structure of your web framework. They know about components, routes, server/client boundaries, and runtime state—not just source files.

IDE-based tools like Claude Code, Cursor, and Copilot can read files, run the app, and read terminal output. But they don't understand the framework. When you say "move this component's logic to the server," a standard IDE tool reads the component file and rewrites it. A framework-aware tool knows whether it's a Next.js Server Component, an Astro island, or a Vite client-only component—and adjusts the edit to fit the framework's architecture. When you click an element in the browser, a framework-aware tool can trace it back through the component tree to the exact source file and line number, because it's hooked into the framework's module graph.

Three architectural approaches have emerged, each trading off depth of framework context against setup complexity. Five tools implement them. None has clearly won.

*Disclosure: I built Frontman, one of the tools in this category. I'll be transparent about tradeoffs.*

## The Three Architectures

### 1. Framework Middleware

Middleware installs inside the framework's dev server as a plugin or integration package (`npm install @frontman-ai/nextjs`). It injects client-side code into the page at build time and hooks into server-side lifecycle events through the framework's own plugin API.

This is the only architecture with native framework context. Because the middleware runs inside the bundler pipeline, it has access to the module graph—it knows which source file and line number produced a given DOM element. When a user clicks a `<button>` in the browser, the middleware can resolve that back to `src/components/Header.tsx:42` without parsing the source tree or guessing from class names. It also sees framework internals that never reach the browser: registered routes, middleware execution order, server component boundaries in Next.js, island hydration state in Astro, the HMR module graph in Vite, data loaders in Remix.

The engineering cost is that every supported framework needs its own integration. Next.js middleware, Astro integrations, and Vite plugins have different APIs, different lifecycle hooks, and different opinions about how to inject client code. Supporting a new framework means writing a new package from scratch and keeping it working across framework version updates. The middleware also touches the build pipeline, so bugs in the integration can break the dev server or slow down HMR. And because it's a dependency in the project's `package.json`, it needs to be added by a developer—a designer can't install it without repo access.

Frontman (Next.js, Astro, Vite) uses this architecture.

### 2. Browser Proxy

A proxy intercepts HTTP traffic between the browser and the dev server. A CLI command (`npx stagewise@latest`) starts a local proxy process, the browser connects through it, and the proxy injects JavaScript into every HTML response. That injected script renders a toolbar overlay and captures DOM state.

The engineering advantage is framework independence. The proxy doesn't know or care what framework generated the HTML—it works at the HTTP layer. No code changes to the project, no build pipeline involvement, no `package.json` entry. This makes it the fastest approach to get running on any stack.

The engineering costs show up in framework context depth. First, source mapping. The proxy sees the rendered DOM but has no access to the bundler's module graph. Mapping a DOM element back to its source file requires heuristics: parsing `data-*` attributes, walking React fiber trees via injected code, or using sourcemaps if available. This works for simple cases but breaks on dynamic rendering, code-split chunks, and server components where the DOM node was produced on the server. Second, framework internals. The proxy sits outside the dev server process, so it can't see routes, middleware state, server component boundaries, or island hydration state unless those are separately exposed through another channel. Third, transport interference. Proxying HTTP means rewriting URLs, handling HTTPS certificates, and passing through WebSocket upgrades for HMR. In practice, CORS issues and dropped WebSocket connections are common. Some frameworks' dev servers assume a direct connection and behave differently through a proxy.

Stagewise uses this architecture.

### 3. MCP Bridge

An MCP bridge exposes framework or server state as tools through the Model Context Protocol, so an existing AI agent (Claude Code, Cursor, Codex) can query them on demand. The bridge connects to Chrome DevTools Protocol for browser state, or to framework internals for server state, and wraps those capabilities as MCP tool calls.

The engineering advantage is composability. The bridge doesn't replace your agent or add a new UI—it extends whatever you're already using. If your workflow is Claude Code in a terminal, you add the MCP server to your config and the agent gains the ability to read the DOM, inspect network requests, or query framework state. There's no new process to manage beyond the MCP server itself.

The engineering costs come from the pull-based model. MCP is request-response: the agent has to decide to call a tool, and the response is a snapshot of that moment. There's no persistent connection streaming component updates or route changes in real time. The agent sees what it asks for, when it asks. If a user clicks an element, that event has no way to reach the agent unless the bridge implements its own notification channel outside MCP (which none currently do). This means MCP bridges can answer "what does the route structure look like right now?" but not "what component is the user looking at?"—which is the core interaction that framework-aware tools enable. Chrome DevTools MCP gives browser state only: DOM, console, network, screenshots. It doesn't know about framework structure. Tidewave goes deep on backend state (database queries, stack traces, runtime eval in Elixir) but has limited framework context for JS frameworks. Neither provides the click-to-edit interaction loop tied to framework structure.

Chrome DevTools MCP (Google) and Tidewave (Phoenix/Rails/Django) both use this architecture, with very different scopes.

## The Tools

### Frontman

[frontman.sh](https://frontman.sh) | Middleware | Apache 2.0 / AGPL-3.0

Next.js, Astro, and Vite (React, Vue, Svelte). BYOK (Claude, OpenAI, OpenRouter). No account required, no prompt limits. Early-stage with rough edges, small community, and incomplete documentation. Limited to the three supported framework integrations.

*I built this.*

### Stagewise

[stagewise.io](https://stagewise.io) | Proxy | AGPL-3.0 | YC-backed

Works with any web framework. Two modes: standalone agent (hosted, account required) or bridge mode (connects to Cursor, Copilot, Windsurf, Cline, Roo Code). About 6,500 GitHub stars. Around 10 free prompts per day, EUR 20/month for heavier use. Most people I've talked to who've tried multiple tools in this category say Stagewise feels the most polished. No BYOK on the standalone agent.

### Chrome DevTools MCP

MCP bridge | Apache 2.0

Google's experimental MCP server that exposes Chrome DevTools state to AI agents. Your agent can query the DOM, read console output, inspect network requests, and take screenshots. Works with any framework, costs nothing, and is open source. You need to bring your own agent, and the documentation is still thin. Think of it as a raw building block rather than a finished product.

### Tidewave

[tidewave.ai](https://tidewave.ai) | MCP bridge | Created by Jose Valim (Elixir creator)

Built primarily for Phoenix/Elixir. JS support exists but is thin. Works with your existing agent (Claude Code, Codex). I haven't seen any other tool in this list that exposes as much backend state: database queries, stack traces, runtime evaluation, live process state. Framework context for JS frameworks is limited, though, and JS framework support is early-stage.

### Cursor Visual Editor

Built-in (IDE-integrated) | Proprietary

If you already use Cursor, this is the easiest path: a visual editing mode where you interact with a preview of your app inside the IDE and request changes visually. No extra install. It's proprietary and locked to the Cursor IDE, and how much framework context it actually accesses under the hood isn't well documented.

## Comparison Table

| Feature | Frontman | Stagewise | Chrome MCP | Tidewave | Cursor Visual |
|---------|----------|-----------|------------|----------|---------------|
| Architecture | Middleware | Proxy | MCP | MCP | IDE built-in |
| Framework context | Deep | Limited | No | Deep (Phoenix) | Unknown |
| Source mapping | Native | Heuristic | No | No | Unknown |
| Server/client boundaries | Yes | No | No | Yes (Phoenix) | Unknown |
| Standalone agent | Yes | Yes | No | No | Yes |
| Free (no limits) | Yes | No (10/day) | Yes | No ($10/mo) | No (Cursor sub) |
| BYOK | Yes | No (standalone) | Yes | Yes | No |
| Framework-agnostic | No | Yes | Yes | No | No (React/Next) |
| Account required | No | Yes | No | Yes | Yes (Cursor) |
| Open source | Yes | Yes | Yes | Yes | No |

## When to Pick One

Framework-aware tools aren't a replacement for IDE-based AI coding. They're for work where understanding the framework architecture matters: component composition, route structure, server/client boundaries, visual changes tied to component state, and edits that need to respect framework conventions. For backend logic, API routes that don't depend on framework routing, database queries, large refactors across many files, or building a new app from scratch, IDE-based tools (Cursor, Aider, Claude Code) or app generators (Bolt, Lovable, v0) are better fits.

Within the category, the architecture choice depends on what you need. If your project runs on a supported framework and you want the deepest framework context—native source mapping, server/client boundary awareness, route structure—middleware is the right approach. If you need framework-agnostic coverage and don't want to touch your codebase, a proxy gets you DOM-level context with zero code changes, but you lose framework internals. If you already have an agent workflow you like and want to add framework or backend state to it without switching tools, an MCP bridge plugs into what you already use.
