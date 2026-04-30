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
- Add `frontmanPlugin({ host: '...' })` to your `vite.config.ts` plugins array (or create one)

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

If you prefer to set things up manually:

```bash
npm install -D @frontman-ai/vite
```

Then add the plugin to your `vite.config.ts`:

```typescript
import { defineConfig } from 'vite';
import { frontmanPlugin } from '@frontman-ai/vite';

export default defineConfig({
  plugins: [
    frontmanPlugin({ host: 'api.frontman.sh' }),
    // ...your other plugins
  ],
});
```

## Quick Start

After running the installer, start your Vite dev server:

```bash
npm run dev
```

Then open your browser to `http://localhost:5173/frontman` to access the Frontman UI.

## Configuration Options

```typescript
frontmanPlugin({
  host: 'api.frontman.sh',         // Frontman server host (default: env FRONTMAN_HOST or "frontman.local:4000")
  basePath: 'frontman',            // Base path for Frontman routes (default: "frontman")
  isDev: false,                    // Dev mode (default: inferred from host — true unless host is "api.frontman.sh")
  projectRoot: '.',                // Project root directory (default: env PROJECT_ROOT or cwd)
  sourceRoot: '.',                 // Source root for resolving file paths (default: projectRoot)
  clientUrl: 'https://...',        // Custom client bundle URL (default: inferred from isDev)
  clientCssUrl: 'https://...',     // Custom client CSS URL (default: inferred from isDev)
  entrypointUrl: 'http://...',     // Custom entrypoint URL for the API
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

`api.frontman.sh` is the only production server. Any other host value is treated as dev mode, which changes the default `clientUrl` to load from a local dev server instead of the production CDN.

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
│   └─> Serves Frontman UI (HTML + client bundle + CSS)
│
├─> GET /frontman/tools
│   └─> Returns tool definitions (file read, write, search, etc.)
│
├─> POST /frontman/tools/call
│   └─> Executes tool → returns SSE stream with results
│
├─> POST /frontman/resolve-source-location
│   └─> Resolves source maps to original component locations
│
└─> OPTIONS /frontman/*
    └─> CORS preflight handling
```

Non-frontman routes pass through to Vite's normal dev server handling.

### Key Technical Details

**Node.js ↔ Web API Adapter**
- Vite's dev server uses Node.js `IncomingMessage`/`ServerResponse`
- Frontman middleware uses Web API `Request`/`Response`
- The plugin adapts between the two, including SSE stream piping

## Troubleshooting

### Frontman UI not loading

**Check 1: Verify the plugin is registered**
Make sure `frontmanPlugin()` is in your `vite.config.ts` plugins array and your dev server is running.

**Check 2: Check the URL**
The default path is `http://localhost:5173/frontman`. If you changed the `basePath` option, use that path instead. If Vite is running on a different port, use that port in the URL.

### Installer shows "manual modification required"

This happens when the installer can't find a `plugins: [` array in your Vite config to inject into. Manually add the import and plugin call as shown in [Manual Installation](#manual-installation).

### CORS errors in browser console

The plugin includes CORS headers for all `/frontman/*` routes. If you're seeing CORS errors, verify the request is going to the correct Vite dev server URL.

## License

Apache-2.0
