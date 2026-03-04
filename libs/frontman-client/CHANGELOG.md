# @frontman-ai/frontman-client

## 0.3.2

### Patch Changes

- [#455](https://github.com/frontman-ai/frontman/pull/455) [`ed92762`](https://github.com/frontman-ai/frontman/commit/ed92762d46a3d26957eba8e68077398628e74f30) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Filter third-party errors from Frontman's internal Sentry reporting. Extracts shared Sentry types, config (DSN, internal-dev detection), and a `beforeSend` filter into `@frontman/bindings` so all framework integrations share a single source of truth. The filter inspects stacktrace frames and drops events that don't originate from Frontman code, preventing noise from framework internals (e.g. Next.js/Turbopack source-map WASM fetch failures). Both `@frontman-ai/nextjs` and `@frontman-ai/frontman-client` now use this shared filter.

- [#461](https://github.com/frontman-ai/frontman/pull/461) [`746666e`](https://github.com/frontman-ai/frontman/commit/746666eec12531c56835a7e0e4da25efa136d927) Thanks [@itayadler](https://github.com/itayadler)! - Enforce pure bindings architecture: extract all business logic from `@frontman/bindings` to domain packages, delete dead code, rename Sentry modules, and fix circular dependency in frontman-protocol.

- Updated dependencies [[`0e02a6a`](https://github.com/frontman-ai/frontman/commit/0e02a6ab637979e8f1276390e8608d998ec6edc1)]:
  - @frontman/logs@0.1.1

## 0.3.1

### Patch Changes

- [#452](https://github.com/frontman-ai/frontman/pull/452) [`2d87685`](https://github.com/frontman-ai/frontman/commit/2d87685c436281dda18f5416782d9f6b9d85bc1c) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix 8 Dependabot security alerts by upgrading Sentry SDK from v8 to v9, sentry-testkit to v6, and adding yarn resolutions for vulnerable transitive dependencies (rollup, basic-ftp, minimatch, devalue, hono).

## 0.3.0

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

## 0.2.0

### Minor Changes

- [`99f8e90`](https://github.com/frontman-ai/frontman/commit/99f8e90e312cfb2d33a1392b0c0a241622583248) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add file and image attachment support in the chat input. Users can attach images and files via drag & drop, clipboard paste, or a file picker button. Pasted multi-line text (3+ lines or >150 chars) is collapsed into a chip. Attachments are sent as ACP resource content blocks with base64-encoded blob data and rendered as thumbnails in both the input area and message history with a lightbox preview.

- [`99f8e90`](https://github.com/frontman-ai/frontman/commit/99f8e90e312cfb2d33a1392b0c0a241622583248) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add cancel/stop generation support. Users can now stop an in-progress AI agent response by clicking a stop button in the prompt input. Implements the ACP `session/cancel` notification protocol for clean cancellation across client, protocol, and server layers.

### Patch Changes

- [#336](https://github.com/frontman-ai/frontman/pull/336) [`b98bc4f`](https://github.com/frontman-ai/frontman/commit/b98bc4f2b2369dd6bc448f883b1a7dce3476b5ae) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Suppress Sentry error reporting during Frontman internal development via FRONTMAN_INTERNAL_DEV env var
