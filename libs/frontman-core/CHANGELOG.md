# @frontman-ai/frontman-core

## 0.6.1

### Patch Changes

- [#1013](https://github.com/frontman-ai/frontman/pull/1013) [`70dff99`](https://github.com/frontman-ai/frontman/commit/70dff99ade62f96071e0d20e362a181860d442de) Thanks [@itayadler](https://github.com/itayadler)! - Fix path validation when Vite reports `sourceRoot: "."` so normal project-relative paths like `src/main.tsx` can be read and edited.

## 0.6.0

### Minor Changes

- [#875](https://github.com/frontman-ai/frontman/pull/875) [`0d53ccc`](https://github.com/frontman-ai/frontman/commit/0d53ccc5a3552f3665db198deb80f817535546b2) Thanks [@itayadler](https://github.com/itayadler)! - Add Fireworks Fire Pass support, including Fireworks API key setup and Kimi K2.5 Turbo in the provider picker.

### Patch Changes

- [#890](https://github.com/frontman-ai/frontman/pull/890) [`05942f0`](https://github.com/frontman-ai/frontman/commit/05942f0bdaf3a60710a903542ec68200a58be6aa) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Centralize path normalization and filename pattern matching to shared helpers across core and framework packages. This removes duplicate `toForwardSlashes` logic from client/Next.js/Astro path conversion and moves search/file matching logic into reusable frontman-core utilities, while adding focused regression tests for mixed separators and wildcard/case-insensitive pattern matching.

- [#966](https://github.com/frontman-ai/frontman/pull/966) [`de43db7`](https://github.com/frontman-ai/frontman/commit/de43db75fcaacd66af39ca000c037e3d90880c76) Thanks [@itayadler](https://github.com/itayadler)! - Consolidate duplicated framework log capture and edit-file log checking through shared core helpers.

- [#953](https://github.com/frontman-ai/frontman/pull/953) [`b2aef53`](https://github.com/frontman-ai/frontman/commit/b2aef533a79fcd0d96291eb40f812b5e926eec9e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Enable React Scan in Frontman UI shells when requested with `?debug=1` and keep the shell in dark mode consistently.

- [#890](https://github.com/frontman-ai/frontman/pull/890) [`05942f0`](https://github.com/frontman-ai/frontman/commit/05942f0bdaf3a60710a903542ec68200a58be6aa) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Harden tool-call path handling for discovery workflows by adding a per-source-root path hints cache, a zero-result guardrail between `search_files` and `read_file`, nearest-parent recovery for missing paths, and structured `search_files` backend error payloads (command, cwd, exit code, stderr, target path). Add T1-T4 taxonomy regression tests plus a replay test modeled on the 3addabc6 failure sequence.

- [#920](https://github.com/frontman-ai/frontman/pull/920) [`d25da4c`](https://github.com/frontman-ai/frontman/commit/d25da4c32611a4e79df49a44ee86234cd982e9bf) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Refactor Swarm and Frontman streaming to consume ReqLLM chunk shapes end-to-end, removing the Swarm-specific chunk reconstruction layer. Preserve early tool-call announcements in channel streaming, keep deterministic malformed/dropped tool-argument handling, and align test mocks/fixtures with ReqLLM stream chunks.

- [#967](https://github.com/frontman-ai/frontman/pull/967) [`8adb8e4`](https://github.com/frontman-ai/frontman/commit/8adb8e45e2d476a912f71cd60539f642ee37d19f) Thanks [@itayadler](https://github.com/itayadler)! - Trim duplicated CLI package-manager helpers and remove stale client tool summary helpers.

- [#976](https://github.com/frontman-ai/frontman/pull/976) [`5585afb`](https://github.com/frontman-ai/frontman/commit/5585afb0f0a1e715133ede2fa97f0d32abc3b648) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Update the ReScript compiler and runtime dependencies to 12.2.0 across the workspace.

## 0.5.5

### Patch Changes

- Updated dependencies [[`9ef1ae0`](https://github.com/frontman-ai/frontman/commit/9ef1ae0f5d284d916c8963e5d5edf14ca19d291e), [`e963100`](https://github.com/frontman-ai/frontman/commit/e963100f6fef33839cddc16c1a9bab850519c248)]:
  - @frontman-ai/frontman-protocol@0.6.0

## 0.5.4

### Patch Changes

- [#625](https://github.com/frontman-ai/frontman/pull/625) [`632b54e`](https://github.com/frontman-ai/frontman/commit/632b54e8a100cbc29ac940a23e7f872780e1ebfd) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Minor improvements: tree navigation for annotation markers, stderr log capture fix, and publish guard for npm packages
  - Add parent/child tree navigation controls to annotation markers in the web preview
  - Fix log capture to intercept process.stderr in addition to process.stdout (captures Astro [ERROR] messages)
  - Add duplicate-publish guard to `make publish` in nextjs, vite, and react-statestore packages

## 0.5.3

### Patch Changes

- [#617](https://github.com/frontman-ai/frontman/pull/617) [`181e673`](https://github.com/frontman-ai/frontman/commit/181e673325024570f81e4935d5a239278177d59d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Replace raw string `type_` field in `toolResultContent` with a typed `toolResultContentType` variant (`Text | Image | Resource`) per MCP spec. Provides compile-time validation that content type values are valid — typos like `"txt"` are now caught at build time.

- Updated dependencies [[`fbbc2f6`](https://github.com/frontman-ai/frontman/commit/fbbc2f60f05f96b010fa4d593e6845fcfd8a8a2f), [`15607ba`](https://github.com/frontman-ai/frontman/commit/15607ba50fee4902372f0dcc2175d014396917d2), [`18054d0`](https://github.com/frontman-ai/frontman/commit/18054d0bec4a971f1c1a676b02cfaea9833d4b66), [`94f2505`](https://github.com/frontman-ai/frontman/commit/94f25055ba110db087843c4f80506eba8e281c86), [`cea1cff`](https://github.com/frontman-ai/frontman/commit/cea1cff2e7d84e5d66ffa42562a862f9fa447dac), [`181e673`](https://github.com/frontman-ai/frontman/commit/181e673325024570f81e4935d5a239278177d59d), [`418d99c`](https://github.com/frontman-ai/frontman/commit/418d99cd9b48e6c7948cdddea97ca13bd0f079b4), [`f6b16d0`](https://github.com/frontman-ai/frontman/commit/f6b16d08d36aea693b4218566b30fed3d9d00c18), [`08d8af6`](https://github.com/frontman-ai/frontman/commit/08d8af6b4e0e1acf86480924514ffacca937de2b)]:
  - @frontman-ai/frontman-protocol@0.5.0

## 0.5.2

### Patch Changes

- [#486](https://github.com/frontman-ai/frontman/pull/486) [`2f979b4`](https://github.com/frontman-ai/frontman/commit/2f979b4ba0f1058284f5780ab8ff2fdbf9fde760) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix framework-specific prompt guidance never being applied in production. The middleware sent display labels like "Next.js" but the server matched on "nextjs", so 120+ lines of Next.js expert guidance were silently skipped. Introduces a `Framework` module as single source of truth for framework identity, normalizes at the server boundary, and updates client adapters to send normalized IDs.

- [#489](https://github.com/frontman-ai/frontman/pull/489) [`5599f92`](https://github.com/frontman-ai/frontman/commit/5599f929b6ded4a818c14cebfe9b8d8d8c9ea7b9) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix ENOTDIR crash in grep tool when LLM passes a file path. Harden all search tools (grep, search_files, list_files, list_tree) to gracefully handle file paths instead of crashing. Catch synchronous spawn() throws in spawnPromise so errors flow through the result type. Rewrite tool descriptions for clarity and remove duplicated tool selection guidance from system prompt.

- [#461](https://github.com/frontman-ai/frontman/pull/461) [`746666e`](https://github.com/frontman-ai/frontman/commit/746666eec12531c56835a7e0e4da25efa136d927) Thanks [@itayadler](https://github.com/itayadler)! - Enforce pure bindings architecture: extract all business logic from `@frontman/bindings` to domain packages, delete dead code, rename Sentry modules, and fix circular dependency in frontman-protocol.

- [#492](https://github.com/frontman-ai/frontman/pull/492) [`4e6c80f`](https://github.com/frontman-ai/frontman/commit/4e6c80fcdb1f6886792853f0358aa6e38d846f68) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix shallow UI edits by giving the agent visual context and structural awareness. Add component name detection (React/Vue/Astro) to `get_dom` output, add UI & Layout Changes guidance to the system prompt with before/after screenshot workflow, add large-file comprehension strategy to `read_file`, and require edit summaries with trade-off analysis. Includes a manual test fixture (`test/manual/vite-dashboard/`) with a 740-line component to reproduce the original issue.

- Updated dependencies [[`746666e`](https://github.com/frontman-ai/frontman/commit/746666eec12531c56835a7e0e4da25efa136d927)]:
  - @frontman/bindings@0.3.1
  - @frontman-ai/frontman-protocol@0.4.1

## 0.5.1

### Patch Changes

- Updated dependencies []:
  - @frontman/frontman-protocol@0.4.0

## 0.5.0

### Minor Changes

- [#434](https://github.com/frontman-ai/frontman/pull/434) [`40c3932`](https://github.com/frontman-ai/frontman/commit/40c393263902d91be7af7db80fbfa875528b2361) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add `list_tree` tool for project structure discovery during MCP initialization. The tool provides a compact, monorepo-aware directory tree view that is injected into the system prompt and available as an on-demand callable tool. Supports workspace detection (package.json workspaces, pnpm, turbo, nx), smart noise filtering, and git-aware file listing.

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
