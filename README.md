<p align="center">
  <a href="https://frontman.sh">
    <img src="https://frontman.sh/og-image.png" alt="Frontman" width="600" />
  </a>
</p>

<h3 align="center">AI Frontend Editing Directly in Your Browser</h3>

<p align="center">
  <a href="https://github.com/frontman-ai/frontman/actions"><img src="https://github.com/frontman-ai/frontman/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
  <a href="https://github.com/frontman-ai/frontman/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-Apache%202.0%20%2F%20AGPL--3.0-blue" alt="License" /></a>
  <a href="https://www.npmjs.com/package/@frontman-ai/nextjs"><img src="https://img.shields.io/npm/v/@frontman-ai/nextjs" alt="npm version" /></a>
</p>

---

Frontman is a framework-integrated AI coding agent that embeds directly into your web development stack. Point at any element in your running app, describe the change you want, and Frontman edits the source code for you — no copy-pasting, no context switching.

## Quickstart

### Next.js

```bash
npx @frontman-ai/nextjs@latest init
```

### Astro

```bash
npm install @frontman/frontman-astro
```

```js
// astro.config.mjs
import frontman from "@frontman/frontman-astro/integration";

export default defineConfig({
  integrations: [frontman()],
});
```

### Vite

```bash
npm install @frontman/vite-plugin
```

```js
// vite.config.js
import frontman from "@frontman/vite-plugin";

export default defineConfig({
  plugins: [frontman()],
});
```

## Features

- **Point-and-click editing** — Select any element in the browser, describe the change, and Frontman modifies the source file directly.
- **Framework-aware context** — Hooks into compilation errors, runtime logs, route changes, and build status for each supported framework.
- **Real-time streaming** — See AI-generated edits appear in your editor as they're written, with live preview in the browser.
- **Multi-framework support** — First-class integrations for Next.js, Astro, and Vite.
- **Open protocol** — A documented protocol layer so the client, server, and framework adapters stay decoupled and extensible.

## Project Structure

```
frontman/
├── apps/
│   ├── chrome-extension/      # Browser extension
│   ├── dogfooding/            # Internal testing app
│   ├── frontman_server/       # Elixir/Phoenix backend
│   └── marketing/             # Marketing website
├── libs/
│   ├── bindings/              # ReScript bindings for Node/browser APIs
│   ├── client/                # React UI component library
│   ├── context-loader/        # Config file discovery and loading
│   ├── frontman-astro/        # Astro framework integration
│   ├── frontman-client/       # Browser-side MCP client
│   ├── frontman-core/         # Core server-side tools
│   ├── frontman-nextjs/       # Next.js integration
│   ├── frontman-protocol/     # Protocol definitions
│   ├── react-statestore/      # React state management library
│   └── vite-plugin/           # Vite plugin
├── docs/                      # Protocol documentation
└── infra/                     # Infrastructure configs
```

## Tech Stack

| Layer | Technology |
|-------|------------|
| Language | [ReScript](https://rescript-lang.org/) |
| Backend | [Elixir](https://elixir-lang.org/) / [Phoenix](https://phoenixframework.org/) |
| UI | [React](https://react.dev/) |
| Runtime | [Node.js](https://nodejs.org/) |

## Contributing

Contributions are welcome! Please read the [Contributing Guide](./CONTRIBUTING.md) to get started.

## License

This project uses a split license model:

- **Client libraries and framework integrations** (`libs/`) — [Apache License 2.0](./LICENSE)
- **Server** (`apps/frontman_server/`) — [GNU Affero General Public License v3](./apps/frontman_server/LICENSE)

See the respective `LICENSE` files for details.

## Links

- [Website](https://frontman.sh)
- [Changelog](./CHANGELOG.md)
- [Issues](https://github.com/frontman-ai/frontman/issues)
