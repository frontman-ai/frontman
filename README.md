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
</p>

---

<p align="center">
  <a href="https://www.youtube.com/watch?v=-4GD1GYwH8Y">
    <img src="./assets/demo.webp" alt="Frontman Demo" width="600" />
  </a>
</p>

Open your running app in the browser, click on any element, and describe the change you want — Frontman edits the actual source code in your repo. No sandbox, no copy-paste. Real code changes your team can review and merge.

> **For designers and PMs** who want to tweak UI without waiting on a developer. **For developers** who want fewer "can you move this 2px" tickets.

## How It Works

1. **A developer adds Frontman to the project** — one command, works with Next.js, Astro, and Vite.
2. **Anyone on the team opens the app in their browser** — an overlay lets you click any element and describe the change you want in plain language.
3. **Frontman edits the source code and hot-reloads** — the change appears live in the browser, and the code diff is ready for the team to review.

Unlike screenshot-based AI tools, Frontman hooks into your framework's build pipeline — it understands your components, routes, and compilation errors, so it edits the right file every time.

## Quickstart

### Next.js

```bash
npx @frontman-ai/nextjs install
```

### Astro

```bash
astro add @frontman-ai/astro
```

See [Astro integration docs](https://frontman.sh/docs/astro) for configuration.

### Vite

```bash
npx @frontman-ai/vite install
```

See [Vite plugin docs](https://frontman.sh/docs/vite) for configuration.

- **Framework-aware** — Understands your components, routes, and build errors. Not just pixel screenshots.
- **Real-time streaming** — See edits appear in your editor as they're written, with live preview in the browser.
- **Open protocol** — Client, server, and framework adapters are decoupled and extensible. [Read the docs](./docs/).

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
