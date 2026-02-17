# @frontman-ai/astro

[![npm version](https://img.shields.io/npm/v/@frontman-ai/astro)](https://www.npmjs.com/package/@frontman-ai/astro)
[![astro ^5.0.0](https://img.shields.io/badge/astro-%5E5.0.0-blueviolet)](https://astro.build)

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

## What it does

The integration automatically (in dev mode only):

- Registers a dev toolbar app for element selection
- Captures Astro source annotations so the AI knows which `.astro` file and line each element comes from
- Serves the Frontman UI at `/<basePath>/` (default: `/frontman/`)
- Exposes tool endpoints for AI interactions (file edits, screenshots, etc.)

> **Note:** Element source detection requires `devToolbar.enabled: true` (the default). Astro only emits `data-astro-source-file` / `data-astro-source-loc` annotations when the dev toolbar is enabled. If you've disabled it, Frontman will log a warning and fall back to CSS selector-based detection.

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
| `isLightTheme` | `false` | Use a light theme for the Frontman UI |

### Environment variables

| Variable | Description |
|---|---|
| `FRONTMAN_HOST` | Override the default server host without changing config |
| `PROJECT_ROOT` | Override the project root path |
| `FRONTMAN_CLIENT_URL` | Override the client bundle URL |

## How it works

The integration uses two Astro hooks:

- **`astro:config:setup`** — Registers the dev toolbar app and injects the annotation capture script via `injectScript('head-inline', ...)`
- **`astro:server:setup`** — Registers Frontman API routes as Vite dev server middleware via `server.middlewares.use()`

No manual middleware file needed. No SSR adapter required. Works with static (`output: 'static'`) Astro projects.

## Requirements

- Astro ^5.0.0
- Node.js >= 18

## Links

- [Website](https://frontman.sh)
- [Documentation](https://frontman.sh/docs/astro)
- [Changelog](https://github.com/frontman-ai/frontman/blob/main/CHANGELOG.md)
- [Issues](https://github.com/frontman-ai/frontman/issues)

## License

[Apache-2.0](https://github.com/frontman-ai/frontman/blob/main/LICENSE)
