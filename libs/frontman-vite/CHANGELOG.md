# @frontman-ai/vite

## 0.4.0

### Minor Changes

- [#426](https://github.com/frontman-ai/frontman/pull/426) [`1b6ecec`](https://github.com/frontman-ai/frontman/commit/1b6ecec8256a2630a71ef3b8d7b3d60c34c16f9a) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - URL-addressable preview: persist iframe URL in browser address bar using suffix-based routing. Navigation within the preview iframe is now reflected in the browser URL, enabling shareable deep links and browser back/forward support.

## 0.3.0

### Minor Changes

- [#398](https://github.com/frontman-ai/frontman/pull/398) [`8269bb4`](https://github.com/frontman-ai/frontman/commit/8269bb448c555420326f035f6f17b7eb2f69033b) Thanks [@itayadler](https://github.com/itayadler)! - Add `edit_file` tool with 9-strategy fuzzy text matching for robust LLM-driven file edits. Framework-specific wrappers (Vite, Astro, Next.js) check dev server logs for compilation errors after edits. Add `get_logs` tool to Vite and Astro for querying captured console/build output.

- [#418](https://github.com/frontman-ai/frontman/pull/418) [`930669c`](https://github.com/frontman-ai/frontman/commit/930669c179b02b79ae35af662479914746638754) Thanks [@itayadler](https://github.com/itayadler)! - Extract shared middleware (CORS, UI shell, request handlers, SSE streaming) into frontman-core, refactor Astro/Next.js/Vite adapters to thin wrappers

## 0.2.0

### Minor Changes

- [#355](https://github.com/frontman-ai/frontman/pull/355) [`84b6d9b`](https://github.com/frontman-ai/frontman/commit/84b6d9bc68bc17cc5eec3b81f0b06b057d1826a9) Thanks [@itayadler](https://github.com/itayadler)! - Add `@frontman-ai/vite` package — a ReScript-first Vite integration with CLI installer (`npx @frontman-ai/vite install`), replacing the old broken `@frontman/vite-plugin`.
  - Vite plugin with `configureServer` hook and Node.js ↔ Web API adapter for SSE streaming
  - Web API middleware serving Frontman UI, tool endpoints, and source location resolution
  - Config with automatic `isDev` inference from host (production = `api.frontman.sh`, everything else = dev)
  - CLI installer: auto-detects package manager, analyzes existing vite config, injects `frontmanPlugin()` call
  - Process shim for production client bundle (Vite doesn't polyfill Node.js globals in browser)
