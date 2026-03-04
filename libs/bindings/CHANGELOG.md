# @frontman/bindings

## 0.3.1

### Patch Changes

- [#461](https://github.com/frontman-ai/frontman/pull/461) [`746666e`](https://github.com/frontman-ai/frontman/commit/746666eec12531c56835a7e0e4da25efa136d927) Thanks [@itayadler](https://github.com/itayadler)! - Enforce pure bindings architecture: extract all business logic from `@frontman/bindings` to domain packages, delete dead code, rename Sentry modules, and fix circular dependency in frontman-protocol.

## 0.3.0

### Minor Changes

- [#425](https://github.com/frontman-ai/frontman/pull/425) [`3198368`](https://github.com/frontman-ai/frontman/commit/31983683f7bf503e3831ac80baf347f00291e37d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Astro dev toolbar icon now navigates to the Frontman UI route instead of logging diagnostics. Expanded Astro bindings with full dev toolbar API coverage.

### Patch Changes

- [#415](https://github.com/frontman-ai/frontman/pull/415) [`38cff04`](https://github.com/frontman-ai/frontman/commit/38cff0417d24fffd225dde6125e2734c0ebdf5df) Thanks [@itayadler](https://github.com/itayadler)! - Add Lighthouse tool for web performance auditing. The `lighthouse` tool runs Google Lighthouse audits on URLs and returns scores (0-100) for performance, accessibility, best practices, and SEO categories, along with the top 3 issues to fix in each category. In DevPod environments, URLs are automatically rewritten to localhost to avoid TLS/interstitial issues. The Next.js config now falls back to PHX_HOST for automatic host detection in DevPod setups.

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

## 0.1.1

### Patch Changes

- [#393](https://github.com/frontman-ai/frontman/pull/393) [`d4cd503`](https://github.com/frontman-ai/frontman/commit/d4cd503c97e14edc4d4f8f7a2d5b9226a1956347) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix Astro integration defaulting to dev host instead of production when FRONTMAN_HOST is not set, which broke production deployments. Also add stderr maxBuffer enforcement to spawnPromise to prevent unbounded memory growth from misbehaving child processes.
