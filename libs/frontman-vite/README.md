# @frontman-ai/vite

Vite integration for Frontman - provides AI-powered development tools for any Vite-based application (React, Vue, Svelte, SolidJS, vanilla, etc.).

## Stack

- [ReScript](https://rescript-lang.org) with ES6 modules
- [Vite](https://vitejs.dev) 5.0+ / 6.0+ / 7.0+
- Vite plugin (`configureServer` hook)
- SSE (Server-Sent Events) for streaming responses

## Installation

```bash
npm install @frontman-ai/vite
```

## Quick Start

Add the plugin to your `vite.config.ts`:

```typescript
import { defineConfig } from 'vite';
import { frontmanPlugin } from '@frontman-ai/vite';

export default defineConfig({
  plugins: [
    frontmanPlugin(),
  ],
});
```

Start your Vite dev server and open `http://localhost:5173/frontman` to access the Frontman UI.

## Configuration

```typescript
import { frontmanPlugin } from '@frontman-ai/vite';

frontmanPlugin({
  // All options are optional
  isDev: true,                    // Development mode (default: NODE_ENV !== "production")
  basePath: 'frontman',           // Base path for Frontman routes (default: "frontman")
  host: 'frontman.local:4000',    // Frontman server host (default: env FRONTMAN_HOST or "frontman.local:4000")
  clientUrl: 'https://...',       // Custom client bundle URL
  clientCssUrl: 'https://...',    // Custom client CSS URL
  entrypointUrl: 'http://...',    // Custom entrypoint URL for the API
  isLightTheme: false,            // Use light theme (default: false / dark)
  projectRoot: '.',               // Project root directory (default: env PROJECT_ROOT or cwd)
  sourceRoot: '.',                // Source root for resolving file paths (default: projectRoot)
});
```

### Understanding the `host` Option

The `host` option specifies the Frontman server that the client UI will connect to for AI capabilities. When you visit `/frontman` in your Vite app:

1. The plugin serves the Frontman UI HTML
2. The UI loads the client JavaScript with `?host=<your-host>`
3. The client establishes a WebSocket connection to `wss://<host>/socket`
4. AI interactions and tool calls flow through this connection

**Examples:**
- Production: `host: 'api.frontman.sh'` → client connects to `wss://api.frontman.sh/socket`
- Local dev: `host: 'frontman.local:4000'` → client connects to `wss://frontman.local:4000/socket`

## How It Works

The plugin registers middleware on Vite's dev server via the `configureServer` hook. It adapts Web API `Request`/`Response` to Node.js `IncomingMessage`/`ServerResponse`, routing requests to these endpoints:

| Route | Method | Description |
|-------|--------|-------------|
| `GET /frontman` | GET | Serves the Frontman UI |
| `GET /frontman/tools` | GET | Returns available tool definitions |
| `POST /frontman/tools/call` | POST | Executes a tool call (SSE response) |
| `POST /frontman/resolve-source-location` | POST | Resolves source maps to original locations |
| `OPTIONS /frontman/*` | OPTIONS | CORS preflight handling |

Non-frontman routes pass through to Vite's normal dev server handling.

## Architecture

```
Vite Dev Server
│
├─> configureServer hook
│   └─> frontmanPlugin registers Connect middleware
│       └─> Adapts Node.js req/res ↔ Web API Request/Response
│
├─> GET /frontman
│   └─> Serves Frontman UI (HTML + client bundle)
│       └─> Client connects to Frontman server via WebSocket
│
├─> GET /frontman/tools
│   └─> Returns tool definitions from ToolRegistry
│       └─> Core tools (file read, write, search, etc.)
│
└─> POST /frontman/tools/call
    └─> Executes tool → returns SSE stream with results
```

### Module Structure

| Module | Purpose |
|--------|---------|
| `FrontmanVite__Plugin` | Vite plugin with `configureServer` hook and Node.js adapter |
| `FrontmanVite__Middleware` | Web API middleware returning `option<Response>` |
| `FrontmanVite__Server` | HTTP handlers for tools, tool calls, source location |
| `FrontmanVite__Config` | Configuration type and defaults |
| `FrontmanVite__ToolRegistry` | Core tools registry (from `frontman-core`) |

## Supported Frameworks

This plugin works with any Vite-based project:

- React (via `@vitejs/plugin-react`)
- Vue (via `@vitejs/plugin-vue`)
- Svelte (via `@sveltejs/vite-plugin-svelte`)
- SolidJS (via `vite-plugin-solid`)
- Vanilla JS/TS
- Any other Vite-compatible framework

## Dependencies

- `@frontman/frontman-core` - Tool registry and SSE utilities (bundled)
- `@frontman/frontman-protocol` - MCP protocol types (bundled)
- `vite` >=5.0.0 (peer dependency)

## Commands

Run `make` or `make help` to see all available commands.

## License

Apache-2.0
