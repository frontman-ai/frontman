---
title: Astro
description: Complete reference for the @frontman-ai/astro integration — installation, configuration options, dev server hooks, element source detection, and troubleshooting.
---

## Overview

`@frontman-ai/astro` is an Astro integration that embeds the Frontman AI agent directly into your Astro dev server. It combines Astro integration lifecycle hooks with a Vite plugin chain, giving the AI access to your source files, dev server logs, and resolved route manifest.

**Frontman is a development-only tool.** The integration is a no-op in production builds — nothing is injected into your deployment bundle.

## Requirements

- Node.js 18 or later
- Astro 5.x or 6.x

## Installation

Use Astro's built-in integration installer:

```sh
npx astro add @frontman-ai/astro
```

This adds the integration to your `astro.config.mjs` automatically. Alternatively, install the package manually:

```sh
npm install --save-dev @frontman-ai/astro
```

Then register it in your config:

```js
import frontman from '@frontman-ai/astro';
import path from 'node:path';

const appRoot = path.resolve(import.meta.dirname);

export default defineConfig({
  integrations: [
    frontman({
      projectRoot: appRoot,
    }),
  ],
});
```

## Configuration

All options are optional. Defaults are inferred from environment variables and the Astro config.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `projectRoot` | `string` | `process.env.PROJECT_ROOT` \| `process.env.PWD` \| `"."` | Absolute path to your project root. Scopes all file operations performed by the AI. |
| `sourceRoot` | `string` | Same as `projectRoot` | Root for resolving source file paths. Set this to the monorepo root when `projectRoot` is a workspace package so the AI can reach files outside the Astro package. |
| `basePath` | `string` | `"frontman"` | URL prefix for all Frontman routes. Leading and trailing slashes are stripped automatically. |
| `host` | `string` | `process.env.FRONTMAN_HOST` \| `"api.frontman.sh"` | Frontman server host used for WebSocket client connections. Accepts bare hostnames, full URLs, or local dev server addresses (e.g. `frontman.local:4000`). |
| `serverName` | `string` | `"frontman-astro"` | Identifier included in every tool response. Useful when multiple Frontman instances run concurrently. |
| `serverVersion` | `string` | Package version | Version string included in tool responses. |
| `clientUrl` | `string` | Auto-derived from `host` | Override the URL of the Frontman client JS bundle. Must include a `host` query parameter. |
| `clientCssUrl` | `string` | Production CDN URL; `undefined` in dev | Override the URL of the Frontman client CSS stylesheet. |
| `entrypointUrl` | `string` | — | Custom entrypoint URL for the AI API. |
| `isLightTheme` | `boolean` | `false` | Render the Frontman UI with a light color scheme instead of the default dark theme. |

### Monorepo configuration

For monorepos where the Astro app is a workspace package but source files span the whole repository, set `sourceRoot` to the repo root:

```js
import path from 'node:path';

const appRoot = path.resolve(import.meta.dirname);
const monorepoRoot = path.resolve(appRoot, '../..');

frontman({
  projectRoot: appRoot,
  sourceRoot: monorepoRoot,
})
```

File edits are resolved relative to `sourceRoot`, letting the AI reach files outside the Astro package boundary.

## Accessing Frontman

Start your dev server (`astro dev`) and open `http://localhost:4321/frontman`. The port matches whatever Astro binds to. If you've set a custom `basePath`, replace `frontman` in the URL accordingly.

## How It Works

### Astro lifecycle hooks

The integration registers handlers at three Astro lifecycle points:

**`astro:config:setup`** — Registers the Vite plugin chain (described below), injects the element annotation capture script into every page, and registers a Dev Toolbar app that provides element-to-source-file mapping.

**`astro:server:setup`** — Initializes the log capture buffer, registers the Frontman request handler on the Vite Connect server, and rewrites bare `/frontman` requests (no trailing slash) to `/frontman/`.

**`astro:routes:resolved`** *(Astro 5+ only)* — Captures the complete resolved route manifest from Astro's internal routing system. This catches content collection routes, config-level redirects, API endpoints, and routes injected by other integrations. On Astro 4, routes are discovered by scanning the `src/pages/` filesystem instead.

### Vite plugin chain

Three Vite plugins run inside the Astro Vite instance:

**`frontman-middleware`** — Installs a Connect middleware that intercepts all `/{basePath}/*` requests. Serves the Frontman UI, handles tool call requests (`POST /frontman/tools/call`), manages SSE streams for streaming responses (`GET /frontman/tools`), and resolves source locations. CORS is enabled for all `/frontman/*` routes.

**`frontman-props-injection`** — During HTML transformation, injects component props as HTML comments. The Frontman client reads these comments to give the AI component props without requiring a React/Vue runtime on the page.

**`rehype-content-file`** — Enriches rendered content with source file metadata, mapping DOM elements back to their originating content collection or Markdown files.

### Log capture

A circular buffer of 1024 entries is maintained for the lifetime of the dev server. It captures:

- All `console.*` methods (`log`, `warn`, `error`, `info`, `debug`)
- Astro/Vite build and HMR output (compilation results, module graph updates, hot reload events)
- Uncaught exceptions with full stack traces

The AI queries this buffer with the `get_logs` tool. Queries support: `pattern` (regex), `level` (log level filter), `since` (ISO 8601 timestamp lower bound), and `tail` (N most recent entries).

### Element source detection

Frontman identifies the source file and line number for a clicked DOM element using two mechanisms:

**Dev Toolbar attributes** *(default)* — Astro's dev toolbar injects `data-astro-source-file` and `data-astro-source-loc` attributes onto elements during development. Frontman reads these for exact file and line information.

**CSS selector fallback** — When `devToolbar.enabled` is `false` in your Astro config, Frontman falls back to matching DOM elements by CSS selector against the parsed AST. This is less precise.

Keep `devToolbar.enabled: true` (the Astro default) for accurate source detection.

## Available Tools

### Astro-specific

| Tool | Description |
|------|-------------|
| `get_client_pages` | Returns all Astro pages with their file paths and URL route patterns. On Astro 5+, uses the resolved route manifest (includes content collection routes and integration-injected routes). On Astro 4, scans `src/pages/`. |
| `get_logs` | Queries the dev server log buffer. Parameters: `pattern` (regex string), `level` (`log`/`warn`/`error`/`info`/`debug`), `since` (ISO 8601 timestamp), `tail` (integer). |

### File system

| Tool | Description |
|------|-------------|
| `read_file` | Read a file with an optional line range. |
| `edit_file` | Apply targeted edits or replace file contents. Runs a post-edit log check to surface errors introduced by the change. |
| `write_file` | Write a new file. |
| `search_files` | Search file contents with a regex pattern. |
| `list_files` | List files in a directory. |
| `list_tree` | Recursive directory tree. |
| `file_exists` | Check whether a path exists. |

### Other

| Tool | Description |
|------|-------------|
| `lighthouse` | Run a Lighthouse performance audit against a URL using a local Chrome instance. |
| `load_agent_instructions` | Fetch agent instructions from the project (e.g. `AGENTS.md`). |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `FRONTMAN_HOST` | Override the default server host. Takes precedence over the `host` config option. |
| `PROJECT_ROOT` | Override the default project root. Takes precedence over `projectRoot`. |

## Troubleshooting

**`/frontman` returns 404**

The middleware is not registered. Verify the integration appears in `integrations` in `astro.config.mjs` and that you are running the dev server (`astro dev`), not `astro build` or `astro preview`.

**Clicked element shows the wrong source file**

Ensure `devToolbar.enabled` is not set to `false` in your Astro config. Without dev toolbar attributes, Frontman falls back to CSS selector-based detection, which is less precise for deeply nested elements or generated markup.

**`get_client_pages` returns no routes**

On Astro 4, routes are discovered by scanning `src/pages/`. If your pages live in a custom `srcDir`, the scanner will not find them. Upgrade to Astro 5+ to use the hook-based route manifest, which is `srcDir`-agnostic.

**The log buffer is empty**

Logs are captured from the moment the dev server starts. Earlier logs are gone after a restart. Reproduce the action that generates the log you need, then query immediately.
