<p align="center">
  <a href="https://frontman.sh">
    <img src="https://frontman.sh/og.png" alt="Frontman" width="600" />
  </a>
</p>

<h3 align="center">Ship frontend changes from your browser — no code editor needed</h3>

<p align="center">
  <a href="https://github.com/frontman-ai/frontman/actions"><img src="https://github.com/frontman-ai/frontman/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
  <a href="https://github.com/frontman-ai/frontman/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-Apache%202.0%20%2F%20AGPL--3.0-blue" alt="License" /></a>
  <a href="https://www.npmjs.com/package/@frontman-ai/nextjs"><img src="https://img.shields.io/npm/v/@frontman-ai/nextjs" alt="npm version" /></a>
  <a href="https://discord.gg/xk8uXJSvhC"><img src="https://img.shields.io/badge/Discord-Join%20Us-5865F2?logo=discord&logoColor=white" alt="Discord" /></a>
</p>

---

[Frontman](https://frontman.sh) is an open-source AI coding agent that lives in your browser. It hooks into your dev server as middleware and sees the live DOM, component tree, CSS styles, routes, and server logs. Click any element in your running app, describe what you want changed in plain English, and Frontman edits the actual source files with instant hot reload. It supports Next.js, Astro, and Vite (React, Vue, Svelte). Free and open-source — Apache 2.0 (client libraries) / AGPL-3.0 (server). Bring your own API keys (Claude, ChatGPT, or OpenRouter).

<p align="center">
  <a href="https://www.youtube.com/watch?v=-4GD1GYwH8Y">
    <img src="./assets/demo.webp" alt="Frontman Demo" width="600" />
  </a>
</p>

## Who Is This For?

**Frontend developers** who want richer context than terminal-based AI tools provide. Frontman reads the rendered page, not just the source files, so it knows what your CSS actually computes to and which component renders which DOM node.

**Designers and product managers** who want to change copy, adjust spacing, fix colors, or explore layout ideas without opening an IDE. They click the element they want to change, describe the edit, and the source code updates. The diff goes through your team's normal review process.

**Teams** where the back-and-forth between design and engineering costs more time than the actual change. Frontman lets anyone on the team iterate on the frontend directly.

## How Frontman Compares to Other AI Coding Tools

Most AI coding tools work from source files and never see the running application. Frontman takes the opposite approach — it starts from the browser and works backward to the source.

| | Frontman | Cursor | GitHub Copilot | v0 |
|---|---|---|---|---|
| **Context** | Live DOM, computed CSS, component tree, server logs | Source files in IDE | Source files in IDE | Sandboxed preview |
| **Editing interface** | Browser overlay | IDE (VS Code fork) | IDE extension | Web app |
| **What it edits** | Your existing codebase | Your existing codebase | Your existing codebase | Generates new code |
| **Sees rendered output** | Yes (framework middleware) | No | No | Own sandbox only |
| **Open source** | Yes (Apache 2.0 / AGPL-3.0) | No | No | No |
| **Pricing** | Free (BYOK) | $20/mo Pro | $10/mo Pro | $20/mo Premium |
| **Best for** | Visual frontend editing, designer/PM collaboration | Full-stack IDE replacement | Autocomplete, code review | Generating new UI from scratch |

Frontman and these tools are complementary. Many developers use Cursor or Copilot for backend work and general refactoring, then switch to Frontman when they need to see what they're editing in the browser.

## Works with OpenClaw

Frontman is available as an [OpenClaw](https://openclaw.ai) skill. Install it to give your AI agent specialized frontend editing capabilities — component tree awareness, computed CSS, source map resolution, and hot reload feedback that OpenClaw's general browser tool doesn't have.

```bash
openclaw skill install frontman-dev
```

Use OpenClaw for general-purpose automation (shell, messaging, files). Use Frontman for precise visual editing in your codebase. [Read the comparison](https://frontman.sh/vs/openclaw/).

## How It Works

1. **A developer adds Frontman to the project** — one command, works with Next.js, Astro, and Vite.
2. **Anyone on the team opens the app in their browser** — navigate to `localhost/frontman` to get a chat interface alongside a live view of your app.
3. **Click any element and describe the change** — Frontman sees the element's position in the component tree, its computed styles, and the server-side context. It edits the right source file and hot-reloads.

The framework integration turns your local dev server into an [MCP server](https://modelcontextprotocol.io/) that the AI agent queries for both client-side context (DOM tree, computed CSS, screenshots, element selection) and server-side context (routes, server logs, query timing, compiled modules).

Frontman only runs in development mode. Production builds strip it out. Your deployment bundle is identical whether Frontman is installed or not.

## Quickstart

### Next.js

```bash
npx @frontman-ai/nextjs install
npm run dev
# Open http://localhost:3000/frontman
```

Works with App Router and Pages Router. Compatible with Turbopack.

See the [Next.js integration guide](https://frontman.sh/integrations/nextjs/) for details.

### Astro

```bash
astro add @frontman-ai/astro
astro dev
# Open http://localhost:4321/frontman
```

Listed on the [Astro integration registry](https://astro.build/integrations/?search=frontman). Understands Islands architecture, content collections, and SSR/hybrid modes.

See the [Astro integration guide](https://frontman.sh/integrations/astro/) for details.

### Vite (React, Vue, Svelte)

```bash
npx @frontman-ai/vite install
npm run dev
# Open http://localhost:5173/frontman
```

Auto-detects your framework from `vite.config`. Works with React, Vue, and Svelte — including SvelteKit.

See the [Vite integration guide](https://frontman.sh/integrations/vite/) for details.

## AI Model Support

Frontman uses BYOK (bring your own key). Connect any LLM provider:

- **Anthropic** (Claude) — direct API key or OAuth with your Claude subscription
- **OpenAI** (ChatGPT) — direct API key or OAuth with your ChatGPT subscription
- **OpenRouter** — access to Claude, GPT, Llama, Mistral, and hundreds of other models

You pay your LLM provider directly at their standard rates. There are no prompt limits, usage caps, or subscription fees from Frontman.

## Architecture

```
┌─────────────────────────────────────────────────┐
│ Browser                                         │
│ ┌─────────────────┐  ┌────────────────────────┐ │
│ │ Your Running App│  │ Frontman Overlay        │ │
│ │                 │  │ (chat + live preview)   │ │
│ └────────┬────────┘  └───────────┬────────────┘ │
│          │                       │              │
│  ┌───────▼───────────────────────▼──────────┐   │
│  │ Browser-side MCP Server                  │   │
│  │ DOM tree, computed CSS, screenshots,     │   │
│  │ element selection, console logs          │   │
│  └──────────────────┬───────────────────────┘   │
└─────────────────────┼───────────────────────────┘
                      │
┌─────────────────────┼───────────────────────────┐
│ Dev Server          │                           │
│  ┌──────────────────▼───────────────────────┐   │
│  │ Framework Middleware                     │   │
│  │ (Next.js / Astro / Vite plugin)         │   │
│  │ Routes, server logs, compiled modules,  │   │
│  │ source maps, build errors               │   │
│  └──────────────────┬───────────────────────┘   │
└─────────────────────┼───────────────────────────┘
                      │
┌─────────────────────┼───────────────────────────┐
│ Frontman Server     │  (Elixir/Phoenix)         │
│  ┌──────────────────▼───────────────────────┐   │
│  │ AI Agent Orchestrator                    │   │
│  │ Queries MCP tools, generates edits,      │   │
│  │ writes source files, triggers hot reload │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

## Contributing

Contributions are welcome! Please read the [Contributing Guide](./CONTRIBUTING.md) to get started.

## License

This project uses a split license model:

- **Client libraries and framework integrations** (`libs/`) — [Apache License 2.0](./LICENSE)
- **Server** (`apps/frontman_server/`) — [GNU Affero General Public License v3](./apps/frontman_server/LICENSE)

See the respective `LICENSE` files for details.

## Star History

<a href="https://www.star-history.com/?repos=frontman-ai%2Ffrontman&type=date&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/image?repos=frontman-ai/frontman&type=date&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/image?repos=frontman-ai/frontman&type=date&legend=top-left" />
   <img alt="Star History Chart" src="https://api.star-history.com/image?repos=frontman-ai/frontman&type=date&legend=top-left" />
 </picture>
</a>

## Links

- [Website](https://frontman.sh)
- [Documentation](https://frontman.sh/docs/)
- [Integrations](https://frontman.sh/integrations/)
- [Comparisons](https://frontman.sh/vs/) — Frontman vs [OpenClaw](https://frontman.sh/vs/openclaw/), [Cursor](https://frontman.sh/vs/cursor/), [Copilot](https://frontman.sh/vs/copilot/), [v0](https://frontman.sh/vs/v0/), [Stagewise](https://frontman.sh/vs/stagewise/)
- [Changelog](./CHANGELOG.md)
- [Issues](https://github.com/frontman-ai/frontman/issues)
- [Discord](https://discord.gg/xk8uXJSvhC)
