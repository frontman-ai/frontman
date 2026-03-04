# @frontman-ai/astro

## 0.5.0

### Minor Changes

- [#496](https://github.com/frontman-ai/frontman/pull/496) [`4641751`](https://github.com/frontman-ai/frontman/commit/46417511374ef0d69f8b8ac94defa1eabd279044) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Show in-browser banner when a newer integration package is available. Integration packages now report their real version (instead of hardcoded "1.0.0"), the server proxies npm registry lookups with a 30-minute cache, and the client displays a dismissible amber banner with an "Update" button that prompts the LLM to perform the upgrade.

### Patch Changes

- [#463](https://github.com/frontman-ai/frontman/pull/463) [`2179444`](https://github.com/frontman-ai/frontman/commit/2179444a41cb90442ccaa3975d4aad56d1f1bb11) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix trailing-slash 404 on Frontman API routes behind reverse proxy and mixed-content URL scheme mismatch when running behind TLS-terminating proxy (Caddy). Add containerized worktree infrastructure with Podman pods for parallel isolated development.

- [#438](https://github.com/frontman-ai/frontman/pull/438) [`1648416`](https://github.com/frontman-ai/frontman/commit/164841645854156c646acb350821c92fbfa11354) Thanks [@itayadler](https://github.com/itayadler)! - Add Playwright + Vitest end-to-end test infrastructure with test suites for Next.js, Astro, and Vite. Tests validate the core product loop: open framework dev server, navigate to `/frontman`, log in, send a prompt, and verify the AI agent modifies source code.

- [#486](https://github.com/frontman-ai/frontman/pull/486) [`2f979b4`](https://github.com/frontman-ai/frontman/commit/2f979b4ba0f1058284f5780ab8ff2fdbf9fde760) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix framework-specific prompt guidance never being applied in production. The middleware sent display labels like "Next.js" but the server matched on "nextjs", so 120+ lines of Next.js expert guidance were silently skipped. Introduces a `Framework` module as single source of truth for framework identity, normalizes at the server boundary, and updates client adapters to send normalized IDs.

- [#461](https://github.com/frontman-ai/frontman/pull/461) [`746666e`](https://github.com/frontman-ai/frontman/commit/746666eec12531c56835a7e0e4da25efa136d927) Thanks [@itayadler](https://github.com/itayadler)! - Enforce pure bindings architecture: extract all business logic from `@frontman/bindings` to domain packages, delete dead code, rename Sentry modules, and fix circular dependency in frontman-protocol.

## 0.4.2

### Patch Changes

- Fix Windows path handling in GetPages tool by normalizing backslash separators to forward slashes for route conversion and segment splitting.

## 0.4.0

### Minor Changes

- [#426](https://github.com/frontman-ai/frontman/pull/426) [`1b6ecec`](https://github.com/frontman-ai/frontman/commit/1b6ecec8256a2630a71ef3b8d7b3d60c34c16f9a) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - URL-addressable preview: persist iframe URL in browser address bar using suffix-based routing. Navigation within the preview iframe is now reflected in the browser URL, enabling shareable deep links and browser back/forward support.

## 0.3.0

### Minor Changes

- [#425](https://github.com/frontman-ai/frontman/pull/425) [`3198368`](https://github.com/frontman-ai/frontman/commit/31983683f7bf503e3831ac80baf347f00291e37d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Astro dev toolbar icon now navigates to the Frontman UI route instead of logging diagnostics. Expanded Astro bindings with full dev toolbar API coverage.

- [#398](https://github.com/frontman-ai/frontman/pull/398) [`8269bb4`](https://github.com/frontman-ai/frontman/commit/8269bb448c555420326f035f6f17b7eb2f69033b) Thanks [@itayadler](https://github.com/itayadler)! - Add `edit_file` tool with 9-strategy fuzzy text matching for robust LLM-driven file edits. Framework-specific wrappers (Vite, Astro, Next.js) check dev server logs for compilation errors after edits. Add `get_logs` tool to Vite and Astro for querying captured console/build output.

- [#418](https://github.com/frontman-ai/frontman/pull/418) [`930669c`](https://github.com/frontman-ai/frontman/commit/930669c179b02b79ae35af662479914746638754) Thanks [@itayadler](https://github.com/itayadler)! - Extract shared middleware (CORS, UI shell, request handlers, SSE streaming) into frontman-core, refactor Astro/Next.js/Vite adapters to thin wrappers

## 0.2.0

### Minor Changes

- [#405](https://github.com/frontman-ai/frontman/pull/405) [`8a68462`](https://github.com/frontman-ai/frontman/commit/8a684623cde19966788d31fd1754d9dc94e0e031) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - ### Added
  - **Image saving via write_file** — LLM can now save user-pasted images to disk using a new `image_ref` parameter referencing attachment URIs (`attachment://{id}/{filename}`). The browser MCP server intercepts `write_file` calls containing `image_ref`, resolves image data from client state, and rewrites to base64 content before forwarding to the dev-server.
  - **Astro component props injection** — New Vite plugin that captures component display names and prop values during Astro rendering, giving the AI agent richer context when users click elements in the browser.
  - **ToolNames module** — Centralized all 12 tool name constants (7 server + 5 browser) into a shared `ToolNames` module in `frontman-protocol`, eliminating hardcoded string literals across packages.

  ### Changed
  - `write_file` tool now accepts optional `encoding` param (`"base64"` for binary writes) and validates mutual exclusion between `content` and `image_ref`.
  - `AstroAnnotations.loc` field changed from `string` to `Nullable.t<string>` to handle missing `data-astro-source-loc` attributes.
  - MCP server uses `switch` pattern matching consistently instead of `if/else` chains.
  - Task reducer uses `Option.getOrThrow` consistently for `id`, `mediaType`, and `filename` fields (crash-early philosophy).
  - Vite props injection plugin scoped to dev-only (`apply: 'serve'`) with `markHTMLString` guard for Astro compatibility.

## 0.1.7

### Patch Changes

- [#393](https://github.com/frontman-ai/frontman/pull/393) [`d4cd503`](https://github.com/frontman-ai/frontman/commit/d4cd503c97e14edc4d4f8f7a2d5b9226a1956347) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix Astro integration defaulting to dev host instead of production when FRONTMAN_HOST is not set, which broke production deployments. Also add stderr maxBuffer enforcement to spawnPromise to prevent unbounded memory growth from misbehaving child processes.

## 0.1.6

### Patch Changes

- [#384](https://github.com/frontman-ai/frontman/pull/384) [`59ee255`](https://github.com/frontman-ai/frontman/commit/59ee25581b2252636fb7cacb5cec118a38c00ced) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - fix(astro): load client from production CDN instead of localhost

  The Astro integration defaulted `clientUrl` to `http://localhost:5173/src/Main.res.mjs` unconditionally, which only works during local frontman development. When installed from npm, users saw requests to localhost:5173 instead of the production client.

  Now infers `isDev` from the host (matching the Vite plugin pattern): production host loads the client from `https://app.frontman.sh/frontman.es.js` with CSS from `https://app.frontman.sh/frontman.css`.

  Also fixes the standalone client bundle crashing with `process is not defined` in browsers by replacing `process.env.NODE_ENV` at build time (Vite lib mode doesn't do this automatically).

## 0.1.5

### Patch Changes

- [#379](https://github.com/frontman-ai/frontman/pull/379) [`68b7f53`](https://github.com/frontman-ai/frontman/commit/68b7f53d10c82fe5b462021cc2e866c0822fa0d8) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix source location detection for selected elements in Astro projects.
  - Refactor Astro integration from Astro middleware to Vite Connect middleware for more reliable request interception
  - Capture `data-astro-source-file`/`data-astro-source-loc` annotations on `DOMContentLoaded` before Astro's dev toolbar strips them
  - Add ancestor walk fallback (up to 20 levels) so clicking child elements resolves to the nearest annotated Astro component
  - Harden integration: `ensureConfig` guard for no-args usage, `duplex: 'half'` for POST requests, `headersSent` guard in error handler, skip duplicate capture on initial `astro:page-load`
  - Add LLM error chunk propagation so API rejections (e.g., oversized images) surface to the client instead of silently failing
  - Account for `devicePixelRatio` in screenshot scaling to avoid exceeding API dimension limits on hi-DPI displays

- [`99f8e90`](https://github.com/frontman-ai/frontman/commit/99f8e90e312cfb2d33a1392b0c0a241622583248) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix missing `host` param in Astro config that caused the client to crash on boot. Both Astro and Next.js configs now assert at construction time that `clientUrl` contains the required `host` query param, using the URL API for proper query-string handling.
