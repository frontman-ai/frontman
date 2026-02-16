---
"@frontman-ai/vite": minor
---

Add `@frontman-ai/vite` package — a ReScript-first Vite integration with CLI installer (`npx @frontman-ai/vite install`), replacing the old broken `@frontman/vite-plugin`.

- Vite plugin with `configureServer` hook and Node.js ↔ Web API adapter for SSE streaming
- Web API middleware serving Frontman UI, tool endpoints, and source location resolution
- Config with automatic `isDev` inference from host (production = `api.frontman.sh`, everything else = dev)
- CLI installer: auto-detects package manager, analyzes existing vite config, injects `frontmanPlugin()` call
- Process shim for production client bundle (Vite doesn't polyfill Node.js globals in browser)
