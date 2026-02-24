# @frontman/frontman-core

## 0.4.0

### Minor Changes

- [#426](https://github.com/frontman-ai/frontman/pull/426) [`1b6ecec`](https://github.com/frontman-ai/frontman/commit/1b6ecec8256a2630a71ef3b8d7b3d60c34c16f9a) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - URL-addressable preview: persist iframe URL in browser address bar using suffix-based routing. Navigation within the preview iframe is now reflected in the browser URL, enabling shareable deep links and browser back/forward support.

## 0.3.0

### Minor Changes

- [#398](https://github.com/frontman-ai/frontman/pull/398) [`8269bb4`](https://github.com/frontman-ai/frontman/commit/8269bb448c555420326f035f6f17b7eb2f69033b) Thanks [@itayadler](https://github.com/itayadler)! - Add `edit_file` tool with 9-strategy fuzzy text matching for robust LLM-driven file edits. Framework-specific wrappers (Vite, Astro, Next.js) check dev server logs for compilation errors after edits. Add `get_logs` tool to Vite and Astro for querying captured console/build output.

- [#418](https://github.com/frontman-ai/frontman/pull/418) [`930669c`](https://github.com/frontman-ai/frontman/commit/930669c179b02b79ae35af662479914746638754) Thanks [@itayadler](https://github.com/itayadler)! - Extract shared middleware (CORS, UI shell, request handlers, SSE streaming) into frontman-core, refactor Astro/Next.js/Vite adapters to thin wrappers

- [#415](https://github.com/frontman-ai/frontman/pull/415) [`38cff04`](https://github.com/frontman-ai/frontman/commit/38cff0417d24fffd225dde6125e2734c0ebdf5df) Thanks [@itayadler](https://github.com/itayadler)! - Add Lighthouse tool for web performance auditing. The `lighthouse` tool runs Google Lighthouse audits on URLs and returns scores (0-100) for performance, accessibility, best practices, and SEO categories, along with the top 3 issues to fix in each category. In DevPod environments, URLs are automatically rewritten to localhost to avoid TLS/interstitial issues. The Next.js config now falls back to PHX_HOST for automatic host detection in DevPod setups.

### Patch Changes

- [#350](https://github.com/frontman-ai/frontman/pull/350) [`0cb1e38`](https://github.com/frontman-ai/frontman/commit/0cb1e38204629a679fe73c60fe783927ff90d7c8) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Extract Swarm agent execution framework from frontman*server into standalone swarm_ai Hex package. Rename all Swarm.* modules to SwarmAi.\_ and update telemetry atoms accordingly. frontman_server now depends on swarm_ai via path dep for monorepo development.

- [#416](https://github.com/frontman-ai/frontman/pull/416) [`893684e`](https://github.com/frontman-ai/frontman/commit/893684e451be815f9cc0fadf29e4dca1449ffa25) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix swarm_ai documentation: correct broken examples, add missing @doc/@moduledoc annotations, fix inaccurate descriptions, and add README.md for Hex publishing. Bump swarm_ai to 0.1.1.

- Updated dependencies [[`3198368`](https://github.com/frontman-ai/frontman/commit/31983683f7bf503e3831ac80baf347f00291e37d), [`38cff04`](https://github.com/frontman-ai/frontman/commit/38cff0417d24fffd225dde6125e2734c0ebdf5df)]:
  - @frontman/bindings@0.3.0

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

### Patch Changes

- Updated dependencies [[`8a68462`](https://github.com/frontman-ai/frontman/commit/8a684623cde19966788d31fd1754d9dc94e0e031)]:
  - @frontman/frontman-protocol@0.3.0
  - @frontman/bindings@0.2.0

## 0.1.2

### Patch Changes

- [#388](https://github.com/frontman-ai/frontman/pull/388) [`cf885f6`](https://github.com/frontman-ai/frontman/commit/cf885f65e54bb1bb579448d882d9a60d8a5e14cf) Thanks [@itayadler](https://github.com/itayadler)! - fix: resolve Dependabot security vulnerabilities

  Replace deprecated `vscode-ripgrep` with `@vscode/ripgrep` (same API, officially renamed package). Add yarn resolutions for 15 transitive dependencies to patch known CVEs (tar, @modelcontextprotocol/sdk, devalue, node-forge, h3, lodash, js-yaml, and others). Upgrade astro, next, and jsdom to patched versions.

- Updated dependencies [[`d4cd503`](https://github.com/frontman-ai/frontman/commit/d4cd503c97e14edc4d4f8f7a2d5b9226a1956347)]:
  - @frontman/bindings@0.1.1

## 0.1.1

### Patch Changes

- Updated dependencies [[`99f8e90`](https://github.com/frontman-ai/frontman/commit/99f8e90e312cfb2d33a1392b0c0a241622583248)]:
  - @frontman/frontman-protocol@0.2.0
