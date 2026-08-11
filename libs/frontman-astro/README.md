# @frontman-ai/astro

[![npm version](https://img.shields.io/npm/v/@frontman-ai/astro)](https://www.npmjs.com/package/@frontman-ai/astro)
[![Astro 5, 6, and 7](https://img.shields.io/badge/Astro-5%20%7C%206%20%7C%207-blueviolet)](https://astro.build)

Astro integration for [Frontman](https://frontman.sh) — AI-powered development tools that let you edit your frontend from the browser.

## Installation

```bash
npx astro add @frontman-ai/astro
```

Or manually:

```bash
npm install @frontman-ai/astro
```

## Usage

Add the integration to your `astro.config.mjs`:

```javascript
import { defineConfig } from 'astro/config';
import frontman from '@frontman-ai/astro';

export default defineConfig({
  integrations: [
    frontman({ projectRoot: import.meta.dirname }),
  ],
});
```

Then start your dev server and open `http://localhost:4321/frontman/`.

With the default hosted setup, Frontman redirects you to `api.frontman.sh` to sign in with GitHub or Google, then returns you to the local `/frontman` URL. Before your first prompt, connect a supported AI provider with OAuth or add an API key. If you configured another Frontman server, sign in on that server instead.

## What it does

The integration automatically (in dev mode only):

- Registers a dev toolbar app for element selection
- Captures source annotations so the AI knows which `.astro` file and line each element comes from
- Maps Markdown and MDX output back to its content file with both Sätteri and unified processors
- Serves the Frontman UI at `/<basePath>/` (default: `/frontman/`)
- Exposes tool endpoints for AI interactions (file edits, screenshots, etc.)

> **Note:** Astro 5 and 6 element source detection requires `devToolbar.enabled: true` (the default). Astro 7 uses Frontman-owned source annotations and does not depend on Dev Toolbar attributes.

## Configuration

All options are optional with sensible defaults:

| Option | Default | Description |
|---|---|---|
| `projectRoot` | `PROJECT_ROOT` env var, `PWD`, or `"."` | Path to the project root directory |
| `sourceRoot` | Same as `projectRoot` | Root for source file resolution (useful in monorepos) |
| `basePath` | `"frontman"` | URL prefix for Frontman routes |
| `host` | `FRONTMAN_HOST` env var or `"api.frontman.sh"` | Frontman server host for client connections |
| `serverName` | `"frontman-astro"` | Server name included in tool responses |
| `serverVersion` | `"1.0.0"` | Server version included in tool responses |
| `clientUrl` | Auto-generated from `host` | URL to the Frontman client bundle (must include a `host` query parameter) |

### Environment variables

| Variable | Description |
|---|---|
| `FRONTMAN_HOST` | Override the default server host without changing config |
| `PROJECT_ROOT` | Override the project root path |
| `FRONTMAN_CLIENT_URL` | Override the client bundle URL |

## How it works

The integration uses four Astro hooks:

- **`astro:config:setup`** — Registers the dev toolbar app and injects the annotation capture script via `injectScript('head-inline', ...)`
- **`astro:config:done`** — Captures the final trailing-slash policy
- **`astro:server:setup`** — Registers Frontman API routes as Vite dev server middleware via `server.middlewares.use()`
- **`astro:routes:resolved`** — Captures Astro's resolved route manifest

No manual middleware file needed. No SSR adapter required. Works with static (`output: 'static'`) Astro projects.

## Requirements

- Astro 5.x, 6.x, or 7.x
- Node.js >= 22.19.0

## Links

- [Website](https://frontman.sh)
- [Documentation](https://frontman.sh/docs/astro)
- [Changelog](https://github.com/frontman-ai/frontman/blob/main/CHANGELOG.md)
- [Issues](https://github.com/frontman-ai/frontman/issues)

## License

[Apache-2.0](https://github.com/frontman-ai/frontman/blob/main/LICENSE)
