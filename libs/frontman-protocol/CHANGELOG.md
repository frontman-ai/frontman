# @frontman/frontman-protocol

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

- [`99f8e90`](https://github.com/frontman-ai/frontman/commit/99f8e90e312cfb2d33a1392b0c0a241622583248) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add protocol versioning, JSON Schema export, and cross-language contract tests. Protocol types are now the single source of truth, with schemas auto-generated from Sury types and validated in both ReScript and Elixir. Includes CI checks for schema drift and breaking changes.
