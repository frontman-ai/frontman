<p align="center">
  <a href="https://frontman.sh">
    <img src="https://frontman.sh/og.png" alt="Frontman" width="600" />
  </a>
</p>

<h3 align="center">Let product and design ship frontend fixes without opening an IDE</h3>

<p align="center">
  <a href="https://github.com/frontman-ai/frontman/actions"><img src="https://github.com/frontman-ai/frontman/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
  <a href="https://github.com/frontman-ai/frontman/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-Apache%202.0%20%2F%20AGPL--3.0-blue" alt="License" /></a>
  <a href="https://www.npmjs.com/package/@frontman-ai/nextjs"><img src="https://img.shields.io/npm/v/@frontman-ai/nextjs" alt="npm version" /></a>
  <a href="https://discord.gg/xk8uXJSvhC"><img src="https://img.shields.io/badge/Discord-Join%20Us-5865F2?logo=discord&logoColor=white" alt="Discord" /></a>
</p>

---

[Frontman](https://frontman.sh) is an open-source AI coding agent that lives in your browser. Click any element in your running app, describe the change in plain English, and Frontman edits the actual source files with instant hot reload. It sees the live DOM, component tree, computed CSS, routes, source maps, and server logs, so non-technical teammates can make precise frontend fixes without guessing which file owns the UI.

<p align="center">
  <a href="https://frontman.sh/docs/"><strong>Docs</strong></a> ·
  <a href="https://frontman.sh/integrations/nextjs/">Next.js</a> ·
  <a href="https://frontman.sh/integrations/astro/">Astro</a> ·
  <a href="https://frontman.sh/integrations/vite/">Vite</a> ·
  <a href="https://discord.gg/xk8uXJSvhC">Discord</a> ·
  <a href="https://www.youtube.com/watch?v=-4GD1GYwH8Y">Demo</a>
</p>

<p align="center">
  <a href="https://www.youtube.com/watch?v=-4GD1GYwH8Y">
    <img src="./assets/demo.webp" alt="Frontman Demo" width="600" />
  </a>
</p>

## What You Can Ask Frontman

Frontman is built for small frontend changes that usually get stuck in design QA, product review, or internal tooling backlogs:

- **"Fix this element across all browsers and devices"** — select the broken UI, explain the issue, and Frontman uses browser context plus source maps to update the right component or styles.
- **"Fix this button on an internal sub-page"** — navigate to the exact route, click the button, and Frontman edits the source behind that rendered element.
- **"Change the empty-state copy across the app"** — describe the messaging change once and review the generated diff before it lands.
- **"Make the mobile cards match desktop spacing"** — Frontman reads computed CSS and layout context instead of relying only on static source files.

## Who Is This For?

**Product managers and designers** who need to fix copy, spacing, colors, layout issues, and internal UI polish without waiting for a developer to open an IDE.

**Frontend developers** who want richer context than terminal-based AI tools provide. Frontman reads the rendered page, not just source files, so it knows what your CSS computes to and which component renders each DOM node.

**Teams** where the handoff costs more than the actual change. Frontman lets teammates make the edit in-browser, then send the diff through your normal review process.

## How Frontman Compares to Other AI Coding Tools

Most AI coding tools work from source files and never see the running application. Frontman takes the opposite approach — it starts from the browser and works backward to the source.

| | Frontman | Cursor | GitHub Copilot | v0 |
|---|---|---|---|---|
| **Context** | Live DOM, computed CSS, component tree, server logs | Source files in IDE | Source files in IDE | Sandboxed preview |
| **Editing interface** | Browser overlay | IDE (VS Code fork) | IDE extension | Web app |
| **What it edits** | Your existing codebase | Your existing codebase | Your existing codebase | Generates new code |
| **Sees rendered output** | Yes (framework middleware) | No | No | Own sandbox only |
| **Open source** | Yes (Apache 2.0 / AGPL-3.0) | No | No | No |
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

Need setup help? Join the [Discord](https://discord.gg/xk8uXJSvhC) or open a [GitHub issue](https://github.com/frontman-ai/frontman/issues).

## Supported Stacks

| Status | Frameworks |
|---|---|
| **Supported now** | Next.js App Router, Next.js Pages Router, Astro, Vite, React, Vue, Svelte, SvelteKit |
| **Coming soon** | Remix, Nuxt, SolidStart, Qwik, Phoenix LiveView |

Framework integrations run in development mode only. Production builds strip Frontman out, so your deployed bundle is identical whether Frontman is installed or not.

## AI Model Support

Frontman uses BYOK (bring your own key). Connect any LLM provider:

- **OpenAI** — GPT and Codex models
- **Anthropic** — Claude Pro/Max models
- **OpenRouter** — Claude, GPT, Gemini, Kimi, MiniMax, and hundreds of other models
- **Fireworks AI**, **NVIDIA**, **Google**, and **xAI**

You pay your LLM provider directly at their standard rates. Self-hosting remains free under the project's open-source licenses; hosted Frontman service plans are moving to paid subscriptions.

## Self-Hosting and License

Frontman is open source and can be self-hosted from source. Official hosted and self-hosting packaging is still evolving.

The project uses a split license model:

- **Framework integrations and client libraries** (`libs/`) — [Apache License 2.0](./LICENSE)
- **Server** (`apps/frontman_server/`) — [GNU Affero General Public License v3](./apps/frontman_server/LICENSE)

You can use Frontman in commercial apps. The AGPL applies to the server so hosted services built on top of Frontman stay open.

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

See [Self-Hosting and License](#self-hosting-and-license) above, plus the respective `LICENSE` files for details.

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
- [GitHub Pages](https://frontman-ai.github.io/frontman)
- [Documentation](https://frontman.sh/docs/)
- [Integrations](https://frontman.sh/integrations/)
- [Comparisons](https://frontman.sh/vs/) — Frontman vs [OpenClaw](https://frontman.sh/vs/openclaw/), [Cursor](https://frontman.sh/vs/cursor/), [Copilot](https://frontman.sh/vs/copilot/), [v0](https://frontman.sh/vs/v0/), [Stagewise](https://frontman.sh/vs/stagewise/)
- [Changelog](./CHANGELOG.md)
- [Issues](https://github.com/frontman-ai/frontman/issues)
- [Discord](https://discord.gg/xk8uXJSvhC)
