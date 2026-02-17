# @frontman-ai/astro

Astro integration for Frontman — adds AI-powered development tools to your Astro project.

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

That's it. The integration automatically:

- Registers a dev toolbar app (dev mode only)
- Injects annotation capture for source location resolution (dev mode only)
- Serves the Frontman UI at `/<basePath>/` (default: `/frontman/`)
- Exposes tool endpoints for AI interactions

## Configuration

All options are optional with sensible defaults:

| Option | Default | Description |
|---|---|---|
| `projectRoot` | `PROJECT_ROOT` env var or `PWD` | Path to the project root |
| `sourceRoot` | Same as `projectRoot` | Root for source file resolution (monorepo root) |
| `basePath` | `"frontman"` | URL prefix for Frontman routes |
| `serverName` | `"frontman-astro"` | Server name for tool responses |
| `serverVersion` | `"1.0.0"` | Server version for tool responses |
| `host` | `FRONTMAN_HOST` env var or `"frontman.local:4000"` | Host for client connection |

## How it works

The integration uses two Astro hooks:

- **`astro:config:setup`** — Registers the dev toolbar app and injects the annotation capture script via `injectScript('head-inline', ...)`
- **`astro:server:setup`** — Registers Frontman API routes as Vite dev server middleware via `server.middlewares.use()`

No manual middleware file needed. No SSR mode required.

## Dependencies

- `astro` ^5.0.0 (peer dependency)
- `@frontman/frontman-core` — Tool registry and SSE utilities

## Commands

Run `make` or `make help` to see all available commands.
