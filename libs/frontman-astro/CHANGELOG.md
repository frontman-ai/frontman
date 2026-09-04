# @frontman-ai/astro

## 3.0.0

### Major Changes

- [#1590](https://github.com/frontman-ai/frontman/pull/1590) [`77fb937`](https://github.com/frontman-ai/frontman/commit/77fb937a7630553e4cdbd5de2635b74435be20b8) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Preserve official MCP tool, content annotation, and implementation metadata through relay boundaries. Relay tools now require protocol version 2.0 and the MCP `_meta["ai.frontman/tool-metadata"]` shape instead of legacy top-level metadata fields.

### Minor Changes

- [#1617](https://github.com/frontman-ai/frontman/pull/1617) [`5782bd7`](https://github.com/frontman-ai/frontman/commit/5782bd77a59f105ffd34bb3093a1f64d8b8e5c38) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Enrich `get_client_pages` with Astro route pathname, segments, redirect metadata, fallback routes, and serialized route regex details.

### Patch Changes

- [#1601](https://github.com/frontman-ai/frontman/pull/1601) [`b447a4a`](https://github.com/frontman-ai/frontman/commit/b447a4ad2cb8aedb3c62e2f7a8df803eba7b5ee7) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add `get_resolved_astro_config` so Astro agents can inspect sanitized resolved config before routing, rendering, adapter, i18n, image, Markdown, redirect, session, security, or deployment changes.

## 2.0.3

### Patch Changes

- [#1482](https://github.com/frontman-ai/frontman/pull/1482) [`62e1cd5`](https://github.com/frontman-ai/frontman/commit/62e1cd5ca9647ef420006254e647988d0d904468) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Pin the vendored WebAPI bindings to the newest upstream revision compatible with ReScript 12 and add the typed DOM operations required by Frontman.

## 2.0.2

### Patch Changes

- [#1415](https://github.com/frontman-ai/frontman/pull/1415) [`3ab55f5`](https://github.com/frontman-ai/frontman/commit/3ab55f5efc38b66f3ee380a9dae6e1580c63efa7) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Give annotated elements the same bounded DOM context as `get_dom`, including their parent and direct children, so agents can follow selectors instead of broadly searching source files. Keep `get_dom` shadow traversal compatible with navigable indexed `>>>` paths. Resolve Next.js React Server Component annotations through server-side source maps without issuing invalid browser requests for React's virtual source URLs, while preserving client-component source locations beneath server components.

- [#1430](https://github.com/frontman-ai/frontman/pull/1430) [`2646d4c`](https://github.com/frontman-ai/frontman/commit/2646d4cb4c9aaae0973d597b6f0df81b33fce75c) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Load packaged ripgrep binaries at runtime so grep and file search work from bundled integrations.

## 2.0.1

### Patch Changes

- [#1336](https://github.com/frontman-ai/frontman/pull/1336) [`01667f2`](https://github.com/frontman-ai/frontman/commit/01667f23231e9d63a6ff201a82ed1581bea8f85a) Thanks [@dependabot](https://github.com/apps/dependabot)! - Align the Sury runtime and PPX on `sury@11.0.0-alpha.10`.

- [#1329](https://github.com/frontman-ai/frontman/pull/1329) [`4f61a67`](https://github.com/frontman-ai/frontman/commit/4f61a671b15563359126931a5db3b5d4fa54183f) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Preserve honest optional output schemas across framework server tool relays.

- [#1316](https://github.com/frontman-ai/frontman/pull/1316) [`9402b2e`](https://github.com/frontman-ai/frontman/commit/9402b2e91b4133b56db5448ad818bd1e82ba4c85) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Preserve structured MCP tool results through ACP `rawOutput`.

## 2.0.0

### Major Changes

- [#1292](https://github.com/frontman-ai/frontman/pull/1292) [`6097f0b`](https://github.com/frontman-ai/frontman/commit/6097f0be83ab3ff3a79f06306fd63fae21534481) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add Astro 7 support while preserving Astro 5 and 6 compatibility. Raise the minimum Node.js version to 22.19, support Sätteri and unified Markdown processors, restore source annotations under Astro's Rust compiler, harden component prop capture, honor Astro's trailing-slash policy, and keep preview URLs synchronized during client-side navigation.

### Patch Changes

- [#1305](https://github.com/frontman-ai/frontman/pull/1305) [`a5e12f0`](https://github.com/frontman-ai/frontman/commit/a5e12f035a3fe485661e82014d0dacf5d4f6a61c) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Explain required Frontman sign-in and AI provider setup in package guidance and installer completion output.

## 1.0.3

### Patch Changes

- [#1252](https://github.com/frontman-ai/frontman/pull/1252) [`5ff6278`](https://github.com/frontman-ai/frontman/commit/5ff6278294b1aba5bfd422eeaccdd69cff81ad49) Thanks [@dependabot](https://github.com/apps/dependabot)! - Update Lighthouse to 13.4.0 across framework integrations.

- [#1237](https://github.com/frontman-ai/frontman/pull/1237) [`7ebe6be`](https://github.com/frontman-ai/frontman/commit/7ebe6be9c1d5bfc8a80b38b2be7ef57351777391) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add read/write access metadata to browser, backend, framework, and WordPress tool definitions.

## 1.0.2

### Patch Changes

- [#1184](https://github.com/frontman-ai/frontman/pull/1184) [`55a3f92`](https://github.com/frontman-ai/frontman/commit/55a3f928267b233430830c1e0c9aeb4ab44e528e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add `get_content_collections` tool for Astro projects.

## 1.0.1

### Patch Changes

- [#1130](https://github.com/frontman-ai/frontman/pull/1130) [`c2d7e23`](https://github.com/frontman-ai/frontman/commit/c2d7e23a7fc79f0941bf1abcfe86181070f5620d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Return MCP-standard tool results for text and image content.

- [#1160](https://github.com/frontman-ai/frontman/pull/1160) [`ed80e09`](https://github.com/frontman-ai/frontman/commit/ed80e09ab233e5097c8e70ce7c33be674a08854a) Thanks [@dependabot](https://github.com/apps/dependabot)! - Update ReScript/Sury integration for `sury@11.0.0-alpha.5` and regenerate protocol JSON schemas.

## 1.0.0

### Major Changes

- [#1117](https://github.com/frontman-ai/frontman/pull/1117) [`bd25abe`](https://github.com/frontman-ai/frontman/commit/bd25abeae89df34517dfd2c87cbe9818f58f4c9d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Rename the ChatGPT OAuth surface to OpenAI and simplify provider auth resolution.

  Breaking change: client state, actions, selectors, and OAuth endpoints now use OpenAI names instead of ChatGPT names. Existing selected-model localStorage values with the `openai:` prefix are migrated to `openai_codex:` automatically.

## 0.6.3

### Patch Changes

- [#1047](https://github.com/frontman-ai/frontman/pull/1047) [`9ac299c`](https://github.com/frontman-ai/frontman/commit/9ac299c380a64f4c03bd9e3874d3950e7382a41f) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Drive task prompt guidance from explicit project traits emitted by each framework adapter.

## 0.6.1

### Patch Changes

- [#890](https://github.com/frontman-ai/frontman/pull/890) [`05942f0`](https://github.com/frontman-ai/frontman/commit/05942f0bdaf3a60710a903542ec68200a58be6aa) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Centralize path normalization and filename pattern matching to shared helpers across core and framework packages. This removes duplicate `toForwardSlashes` logic from client/Next.js/Astro path conversion and moves search/file matching logic into reusable frontman-core utilities, while adding focused regression tests for mixed separators and wildcard/case-insensitive pattern matching.

- [#966](https://github.com/frontman-ai/frontman/pull/966) [`de43db7`](https://github.com/frontman-ai/frontman/commit/de43db75fcaacd66af39ca000c037e3d90880c76) Thanks [@itayadler](https://github.com/itayadler)! - Consolidate duplicated framework log capture and edit-file log checking through shared core helpers.

- [#953](https://github.com/frontman-ai/frontman/pull/953) [`b2aef53`](https://github.com/frontman-ai/frontman/commit/b2aef533a79fcd0d96291eb40f812b5e926eec9e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Enable React Scan in Frontman UI shells when requested with `?debug=1` and keep the shell in dark mode consistently.

- [#951](https://github.com/frontman-ai/frontman/pull/951) [`dc65580`](https://github.com/frontman-ai/frontman/commit/dc6558045b8eaee5981afbc34e9d75b1b2db4fcc) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Patch vulnerable JavaScript dependencies across framework fixtures.

- [#976](https://github.com/frontman-ai/frontman/pull/976) [`5585afb`](https://github.com/frontman-ai/frontman/commit/5585afb0f0a1e715133ede2fa97f0d32abc3b648) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Update the ReScript compiler and runtime dependencies to 12.2.0 across the workspace.

## 0.6.0

### Minor Changes

- [#660](https://github.com/frontman-ai/frontman/pull/660) [`f64d652`](https://github.com/frontman-ai/frontman/commit/f64d652a5341a20d111acfcf4f12d527df15bf97) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Use Astro's `astro:routes:resolved` hook (v5+) for route discovery in `get_client_pages` tool

  The `get_client_pages` tool now returns routes resolved by Astro's router instead of scanning the filesystem. This catches routes that filesystem scanning misses: content collection routes, config-defined redirects, API endpoints, integration-injected routes (e.g. `@astrojs/sitemap`), and internal fallbacks. Each route now includes params, type, origin, and prerender status.

  On Astro v4, the tool falls back to the existing filesystem scanner.

### Patch Changes

- [#625](https://github.com/frontman-ai/frontman/pull/625) [`632b54e`](https://github.com/frontman-ai/frontman/commit/632b54e8a100cbc29ac940a23e7f872780e1ebfd) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix Frontman toolbar icon and trailing slash URL construction
  - Replace generic toolbar icon with Frontman "F" glyph in the Astro dev toolbar
  - Ensure trailing slashes on all constructed URLs in the Astro toolbar app

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
