# @frontman-ai/vite

Vite integration for Frontman - provides AI-powered development tools for any Vite-based application (React, Vue, Svelte, SolidJS, vanilla, etc.).

## Installation

### Quick Install (Recommended)

The fastest way to install Frontman is using our CLI installer:

```bash
npx @frontman-ai/vite install

# Or with a custom server host
npx @frontman-ai/vite install --server frontman.company.com
```

The installer will:
- Detect your Vite project and package manager
- Install `@frontman-ai/vite` as a dev dependency
- Add `frontmanPlugin()` to your `vite.config.ts` plugins array (or create one)

### CLI Options

```bash
npx @frontman-ai/vite install [options]

Options:
  --server <host>   Frontman server host (default: api.frontman.sh)
  --prefix <path>   Target directory (default: current directory)
  --dry-run         Preview changes without writing files
  --skip-deps       Skip dependency installation
  --help            Show help message
```

### Manual Installation

If you prefer to set things up manually or need to integrate with an existing configuration:

```bash
npm install -D @frontman-ai/vite
```

Then follow the [Manual Setup](#manual-setup) instructions below.

## Quick Start

After running the installer, you're ready to go! Start your Vite dev server:

```bash
npm run dev
```

Then open your browser to `http://localhost:5173/frontman` to access the Frontman UI.

## Manual Setup

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

That's it! The plugin hooks into Vite's dev server and serves the Frontman UI at `/frontman`.

## Adding to Existing Config

If you already have a `vite.config.ts` with plugins, add `frontmanPlugin()` to your existing plugins array:

```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { frontmanPlugin } from '@frontman-ai/vite';

export default defineConfig({
  plugins: [
    frontmanPlugin(),
    react(),
    // ...your other plugins
  ],
});
```

### Installer shows "manual modification required"

This happens when the installer can't find a `plugins: [` array in your Vite config. Manually add the import and plugin as shown above.

## Configuration Options

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

The plugin itself doesn't connect to the Frontman server - it only passes the host to the client.

**Examples:**
- Production: `host: 'api.frontman.sh'` → client connects to `wss://api.frontman.sh/socket`
- Local dev: `host: 'frontman.local:4000'` → client connects to `wss://frontman.local:4000/socket`

## Supported Frameworks

This plugin works with any Vite-based project:

- React (via `@vitejs/plugin-react`)
- Vue (via `@vitejs/plugin-vue`)
- Svelte (via `@sveltejs/vite-plugin-svelte`)
- SolidJS (via `vite-plugin-solid`)
- Vanilla JS/TS
- Any other Vite-compatible framework

| Version | Status |
|---------|--------|
| Vite 5.x | Fully supported |
| Vite 6.x | Fully supported |

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
├─> POST /frontman/tools/call
│   └─> Executes tool → returns SSE stream with results
│
└─> POST /frontman/resolve-source-location
    └─> Resolves source maps to original component locations
```

### Key Technical Details

**Node.js ↔ Web API Adapter**
- Vite's dev server uses Node.js `IncomingMessage`/`ServerResponse`
- Frontman middleware uses Web API `Request`/`Response`
- The plugin adapts between the two, including SSE stream piping

**Available Endpoints**

| Route | Method | Description |
|-------|--------|-------------|
| `GET /frontman` | GET | Serves the Frontman UI |
| `GET /frontman/tools` | GET | Returns available tool definitions |
| `POST /frontman/tools/call` | POST | Executes a tool call (SSE response) |
| `POST /frontman/resolve-source-location` | POST | Resolves source maps to original locations |
| `OPTIONS /frontman/*` | OPTIONS | CORS preflight handling |

Non-frontman routes pass through to Vite's normal dev server handling.

## Troubleshooting

### Frontman UI not loading

**Check 1: Verify the plugin is registered**
Make sure `frontmanPlugin()` is in your `vite.config.ts` plugins array and your dev server is running.

**Check 2: Check the URL**
The default path is `http://localhost:5173/frontman`. If you changed the `basePath` option, use that path instead.

**Check 3: Check for port conflicts**
If Vite is running on a different port, use that port in the URL (e.g., `http://localhost:3000/frontman`).

### Installer shows "manual modification required"

This happens when the installer can't find a `plugins: [` array in your Vite config to inject into. Manually add the import and plugin call as shown in [Manual Setup](#manual-setup).

### CORS errors in browser console

The plugin includes CORS headers for all `/frontman/*` routes. If you're seeing CORS errors, verify the request is going to the correct Vite dev server URL.

## API

### `frontmanPlugin(options?)`

Creates a Vite plugin that serves the Frontman UI and tool endpoints on the dev server.

```typescript
import { frontmanPlugin } from '@frontman-ai/vite';

const plugin = frontmanPlugin({
  host: string,                // Frontman server host (default: env FRONTMAN_HOST or "frontman.local:4000")
  basePath: string,            // Base path (default: "frontman")
  isDev: boolean,              // Dev mode (default: NODE_ENV !== "production")
  projectRoot: string,         // Project root (default: env PROJECT_ROOT or cwd)
  sourceRoot: string,          // Source root (default: projectRoot)
  clientUrl: string,           // Custom client bundle URL
  clientCssUrl: string,        // Custom client CSS URL
  entrypointUrl: string,       // Custom entrypoint URL
  isLightTheme: boolean,       // Light theme (default: false)
});
```

**Returns:** A Vite plugin object with `name: "frontman"` and a `configureServer` hook.

## License

Apache-2.0
