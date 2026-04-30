# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed

- Refactor: move `env_api_keys` into `Scope` struct — eliminates ad-hoc `env_api_key` parameter threading across `Providers`, channels, and the execution pipeline. `Providers.prepare_api_key`, `resolve_api_key`, `available_provider_tiers`, and `model_config_data` all drop their `env_api_key` parameter and read from `scope.env_api_keys` instead.
- Allow `.net` and `.org` origins in the server's allowed origin and external return URL allowlists.
- Align E2E to a first-class `MIX_ENV=e2e` environment, remove `E2E=true` dev-branch config toggles, and standardize strict boolean env parsing across runtime and E2E setup.
- Update `req_llm` to latest upstream commit and preserve OpenAI Responses metadata (`response_id`, phased assistant output) across stream conversion, persistence, and interaction replay so follow-up turns keep reasoning continuity.
- Add GPT-5.5 to OpenAI and OpenRouter model catalogs, making it the default direct OpenAI model.

### Fixed

- Bootstrap the WordPress file API before managed-theme writes so `wp_create_managed_theme` works in runtimes like WordPress Playground where `FS_CHMOD_FILE` is not pre-defined.

## [0.15.0] - 2026-04-08


#### @frontman-ai/client


### Minor Changes

- [#788](https://github.com/frontman-ai/frontman/pull/788) [`38b50d3`](https://github.com/frontman-ai/frontman/commit/38b50d38def48d1a1b6f233dced12231c8d5a817) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - feat: add framework-conditional browser tool registration

  Introduces `Client__ToolRegistry.forFramework` which composes core browser
  tools with framework-specific tools based on the active runtime framework.
  Creates `@frontman-ai/astro-browser` package as the first framework browser
  tool package (empty for now — actual tools land in #782).

### Patch Changes

- [#796](https://github.com/frontman-ai/frontman/pull/796) [`9ef1ae0`](https://github.com/frontman-ai/frontman/commit/9ef1ae0f5d284d916c8963e5d5edf14ca19d291e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add get_astro_audit browser tool that reads Astro dev toolbar accessibility and performance audit results

- [`d8d15c1`](https://github.com/frontman-ai/frontman/commit/d8d15c1b34bb4d886b10fbaaa57d900843bce989) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - fix: move ScrollButton outside contentRef to break ResizeObserver feedback loop

  The scroll-to-bottom button was rendered inside the ResizeObserver-watched div.
  Its 32px show/hide cycle (driven by `isAtBottom`) caused the ResizeObserver to
  snap scroll position, which toggled `isAtBottom`, which toggled the button —
  creating an infinite oscillation that made it impossible to scroll up.

- [#800](https://github.com/frontman-ai/frontman/pull/800) [`a9eb0cf`](https://github.com/frontman-ai/frontman/commit/a9eb0cf675be44cf437e4aebe47904ad5ac11010) Thanks [@itayadler](https://github.com/itayadler)! - Fix WordPress Playground relay requests to preserve the leading `/scope:...` prefix so tool calls and source-location POSTs do not get redirected to GET.

- [#741](https://github.com/frontman-ai/frontman/pull/741) [`3dd6c04`](https://github.com/frontman-ai/frontman/commit/3dd6c0419b02904bad1bbe92b8aa40804820f528) Thanks [@itayadler](https://github.com/itayadler)! - Strip rich text formatting from short clipboard pastes in the chat input so contentEditable inserts plain text consistently.

- [#762](https://github.com/frontman-ai/frontman/pull/762) [`e963100`](https://github.com/frontman-ai/frontman/commit/e963100f6fef33839cddc16c1a9bab850519c248) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Improve error UX: human-readable categorized errors, automatic retry with exponential backoff for transient failures, live countdown during retry, and manual retry button.

#### @frontman-ai/astro-browser


### Minor Changes

- [#796](https://github.com/frontman-ai/frontman/pull/796) [`9ef1ae0`](https://github.com/frontman-ai/frontman/commit/9ef1ae0f5d284d916c8963e5d5edf14ca19d291e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add get_astro_audit browser tool that reads Astro dev toolbar accessibility and performance audit results

#### @frontman-ai/frontman-core


### Patch Changes

- Updated dependencies [[`9ef1ae0`](https://github.com/frontman-ai/frontman/commit/9ef1ae0f5d284d916c8963e5d5edf14ca19d291e), [`e963100`](https://github.com/frontman-ai/frontman/commit/e963100f6fef33839cddc16c1a9bab850519c248)]:
  - @frontman-ai/frontman-protocol@0.6.0

#### @frontman-ai/frontman-protocol


### Minor Changes

- [#796](https://github.com/frontman-ai/frontman/pull/796) [`9ef1ae0`](https://github.com/frontman-ai/frontman/commit/9ef1ae0f5d284d916c8963e5d5edf14ca19d291e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add get_astro_audit browser tool that reads Astro dev toolbar accessibility and performance audit results

### Patch Changes

- [#762](https://github.com/frontman-ai/frontman/pull/762) [`e963100`](https://github.com/frontman-ai/frontman/commit/e963100f6fef33839cddc16c1a9bab850519c248) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Improve error UX: human-readable categorized errors, automatic retry with exponential backoff for transient failures, live countdown during retry, and manual retry button.

## [0.14.0] - 2026-03-27


### Changed
- Package version bumps (see per-package changelogs for details)

## [0.13.0] - 2026-03-26


### Changed
- Package version bumps (see per-package changelogs for details)

## [0.12.0] - 2026-03-26


#### @frontman-ai/client


### Minor Changes

- [#682](https://github.com/frontman-ai/frontman/pull/682) [`509a0d7`](https://github.com/frontman-ai/frontman/commit/509a0d7a90413bd9e04f9a5a7bec5e0602ffcc25) Thanks [@itayadler](https://github.com/itayadler)! - Add production-ready WordPress support with PHP-native filesystem tools, safer mutation history snapshots, richer WordPress editing tools for menus/blocks/templates/cache, and plugin ZIP release packaging.

  The WordPress plugin now runs normal file operations directly in PHP, requires confirmation before destructive delete tools run, preserves freeform HTML during block mutations, limits widget mutations to safe supported widget types, and removes the old standalone package/release flow entirely.

### Patch Changes

- [#672](https://github.com/frontman-ai/frontman/pull/672) [`7292b3d`](https://github.com/frontman-ai/frontman/commit/7292b3dbd7dc148954262a33710cf837966e1327) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Replace 4 incremental todo tools (todo_add, todo_update, todo_remove, todo_list) with a single atomic `todo_write` tool. The LLM now sends the complete todo list every call, eliminating hallucinated IDs, duplicate entries, and state drift between turns. Adds priority field (high/medium/low) to todos.

- [#711](https://github.com/frontman-ai/frontman/pull/711) [`71cc747`](https://github.com/frontman-ai/frontman/commit/71cc747b71d5d369091ed582f15cb6db4a303123) Thanks [@itayadler](https://github.com/itayadler)! - Preserve the initial FTUE state during ACP authentication so first-time users still see onboarding instead of being treated as returning users after other client preferences are persisted.

- [#625](https://github.com/frontman-ai/frontman/pull/625) [`632b54e`](https://github.com/frontman-ai/frontman/commit/632b54e8a100cbc29ac940a23e7f872780e1ebfd) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Minor improvements: tree navigation for annotation markers, stderr log capture fix, and publish guard for npm packages
  - Add parent/child tree navigation controls to annotation markers in the web preview
  - Fix log capture to intercept process.stderr in addition to process.stdout (captures Astro [ERROR] messages)
  - Add duplicate-publish guard to `make publish` in nextjs, vite, and react-statestore packages

#### @frontman-ai/astro


### Minor Changes

- [#660](https://github.com/frontman-ai/frontman/pull/660) [`f64d652`](https://github.com/frontman-ai/frontman/commit/f64d652a5341a20d111acfcf4f12d527df15bf97) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Use Astro's `astro:routes:resolved` hook (v5+) for route discovery in `get_client_pages` tool

  The `get_client_pages` tool now returns routes resolved by Astro's router instead of scanning the filesystem. This catches routes that filesystem scanning misses: content collection routes, config-defined redirects, API endpoints, integration-injected routes (e.g. `@astrojs/sitemap`), and internal fallbacks. Each route now includes params, type, origin, and prerender status.

  On Astro v4, the tool falls back to the existing filesystem scanner.

### Patch Changes

- [#625](https://github.com/frontman-ai/frontman/pull/625) [`632b54e`](https://github.com/frontman-ai/frontman/commit/632b54e8a100cbc29ac940a23e7f872780e1ebfd) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix Frontman toolbar icon and trailing slash URL construction
  - Replace generic toolbar icon with Frontman "F" glyph in the Astro dev toolbar
  - Ensure trailing slashes on all constructed URLs in the Astro toolbar app

#### @frontman-ai/frontman-core


### Patch Changes

- [#625](https://github.com/frontman-ai/frontman/pull/625) [`632b54e`](https://github.com/frontman-ai/frontman/commit/632b54e8a100cbc29ac940a23e7f872780e1ebfd) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Minor improvements: tree navigation for annotation markers, stderr log capture fix, and publish guard for npm packages
  - Add parent/child tree navigation controls to annotation markers in the web preview
  - Fix log capture to intercept process.stderr in addition to process.stdout (captures Astro [ERROR] messages)
  - Add duplicate-publish guard to `make publish` in nextjs, vite, and react-statestore packages

#### @frontman-ai/nextjs


### Patch Changes

- [#625](https://github.com/frontman-ai/frontman/pull/625) [`632b54e`](https://github.com/frontman-ai/frontman/commit/632b54e8a100cbc29ac940a23e7f872780e1ebfd) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Minor improvements: tree navigation for annotation markers, stderr log capture fix, and publish guard for npm packages
  - Add parent/child tree navigation controls to annotation markers in the web preview
  - Fix log capture to intercept process.stderr in addition to process.stdout (captures Astro [ERROR] messages)
  - Add duplicate-publish guard to `make publish` in nextjs, vite, and react-statestore packages

#### @frontman-ai/vite


### Patch Changes

- [#625](https://github.com/frontman-ai/frontman/pull/625) [`632b54e`](https://github.com/frontman-ai/frontman/commit/632b54e8a100cbc29ac940a23e7f872780e1ebfd) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Minor improvements: tree navigation for annotation markers, stderr log capture fix, and publish guard for npm packages
  - Add parent/child tree navigation controls to annotation markers in the web preview
  - Fix log capture to intercept process.stderr in addition to process.stdout (captures Astro [ERROR] messages)
  - Add duplicate-publish guard to `make publish` in nextjs, vite, and react-statestore packages

#### @frontman-ai/react-statestore


### Patch Changes

- [#625](https://github.com/frontman-ai/frontman/pull/625) [`632b54e`](https://github.com/frontman-ai/frontman/commit/632b54e8a100cbc29ac940a23e7f872780e1ebfd) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Minor improvements: tree navigation for annotation markers, stderr log capture fix, and publish guard for npm packages
  - Add parent/child tree navigation controls to annotation markers in the web preview
  - Fix log capture to intercept process.stderr in addition to process.stdout (captures Astro [ERROR] messages)
  - Add duplicate-publish guard to `make publish` in nextjs, vite, and react-statestore packages

## [0.11.0] - 2026-03-19


#### @frontman-ai/client


### Minor Changes

- [#568](https://github.com/frontman-ai/frontman/pull/568) [`63765ed`](https://github.com/frontman-ai/frontman/commit/63765edcbc32873b0b05c59f0c8b56bbb349860d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add Anthropic API key support as alternative to OAuth
  - Introduce Provider as first-class domain concept with Registry, Model, and Codex modules
  - Centralize LLM wiring in ResolvedKey.to_llm_args with enforced context boundaries
  - Drive image dimension constraints from Provider Registry
  - Add Anthropic API key configuration UI in client settings
  - Extract shared parsing helpers into domain modules

- [#555](https://github.com/frontman-ai/frontman/pull/555) [`18054d0`](https://github.com/frontman-ai/frontman/commit/18054d0bec4a971f1c1a676b02cfaea9833d4b66) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Model ContentBlock as a discriminated union per ACP spec instead of a flat record with optional fields. Adds TextContent, ImageContent, AudioContent, ResourceLink, and EmbeddedResource variants with compile-time type safety. Wire format unchanged.

- [#549](https://github.com/frontman-ai/frontman/pull/549) [`d489b10`](https://github.com/frontman-ai/frontman/commit/d489b10bedde0d00583a5993aadb40a0a4922d68) Thanks [@itayadler](https://github.com/itayadler)! - Add support for GPT-5.4 and GPT-5.4 Pro models
  - Added GPT-5.4 to ChatGPT OAuth provider list (default model for ChatGPT users)
  - Added GPT-5.4 and GPT-5.4 Pro to OpenRouter provider list
  - Configured LLMDB capabilities with 1M context window for both models
  - Added blog post announcing GPT-5.4 support

- [#604](https://github.com/frontman-ai/frontman/pull/604) [`cea1cff`](https://github.com/frontman-ai/frontman/commit/cea1cff2e7d84e5d66ffa42562a862f9fa447dac) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add ACP-compliant LoadSessionResponse type and unify model selection with SessionConfigOption. Replaces the bespoke /api/models REST endpoint with channel-based config option delivery via session/new, session/load responses and config_option_update notifications. Adds full type tree: SessionModeState, SessionMode, SessionConfigOption (grouped/ungrouped select with category enum), sessionLoadResult. Server pushes config updates after API key saves and OAuth connect/disconnect via PubSub.

- [#598](https://github.com/frontman-ai/frontman/pull/598) [`418d99c`](https://github.com/frontman-ai/frontman/commit/418d99cd9b48e6c7948cdddea97ca13bd0f079b4) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add interactive question tool as a client-side MCP tool. Agents can ask users questions via a drawer UI with multi-step navigation, option selection, custom text input, and skip/cancel. Includes history replay ordering fixes (flush TextDeltaBuffer at message boundaries, use server timestamps for tool calls) and disconnect resilience: unresolved tool calls are re-dispatched on reconnect via MCP tools/call, tool results carry \_meta with env API keys + model for agent resume after server restart, and persistence is moved to the SwarmAi runtime process (persist-then-broadcast) so data survives channel disconnects.

- [#614](https://github.com/frontman-ai/frontman/pull/614) [`ec1f378`](https://github.com/frontman-ai/frontman/commit/ec1f3786615f017272e67f05870fc2230adb12a3) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Automatically sync new OAuth signups to the Resend Contacts audience. A new `SyncResendContact` Oban worker is enqueued atomically with user creation and calls the Resend Contacts API to add the user to the configured audience, enabling product update emails and announcements.

- [#560](https://github.com/frontman-ai/frontman/pull/560) [`8ea2a31`](https://github.com/frontman-ai/frontman/commit/8ea2a31f8e29ae62871456f220ad59ebb239fd46) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add tool suspension primitives to SwarmAi
  - New `ToolResult.suspended/1` constructor for creating suspended tool results
  - `ToolCall.completed?/1` returns false for suspended results; new `ToolCall.suspended?/1` predicate
  - `Step.has_suspended_tools?/1` checks if any tool calls in a step are suspended
  - `run_streaming/3` and `run_blocking/3` return `{:suspended, loop_id}` when a tool executor returns `:suspended`
  - `Runtime.run/5` supports `on_suspended` lifecycle callback

- [#587](https://github.com/frontman-ai/frontman/pull/587) [`08d8af6`](https://github.com/frontman-ai/frontman/commit/08d8af6b4e0e1acf86480924514ffacca937de2b) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Replace suspension/resume with blocking interactive tools, fix agent message loss on session reload
  - Interactive tools (e.g. question) block with a 2-minute receive timeout instead of suspending the agent
  - Remove ResumeContext, ETS suspension state, on_suspended callback, resume_execution
  - Simplify add_tool_result to return {:ok, interaction} directly (no resume signals)
  - Pass mcp_tool_defs through for execution mode lookups (interactive vs synchronous timeout)
  - Fix race condition: flush TextDeltaBuffer before LoadComplete to prevent agent messages from being silently dropped during history replay
  - Thread server timestamps through agent_message_chunk for correct message ordering
  - Add timestamp to agent_message_chunk in ACP protocol schema

### Patch Changes

- [#573](https://github.com/frontman-ai/frontman/pull/573) [`fbbc2f6`](https://github.com/frontman-ai/frontman/commit/fbbc2f60f05f96b010fa4d593e6845fcfd8a8a2f) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add ACP elicitation protocol support and enforce compliance across server, protocol, and client layers. Wire up elicitation schema conversion, typed status constants, AgentTurnComplete notification, and idempotent TurnCompleted state transitions. Fix flaky tests and nil description handling in elicitation schemas.

- [#601](https://github.com/frontman-ai/frontman/pull/601) [`15607ba`](https://github.com/frontman-ai/frontman/commit/15607ba50fee4902372f0dcc2175d014396917d2) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Make AgentMessageChunk content field required per ACP ContentChunk spec. Removes unnecessary option wrapper and simplifies downstream consumer code.

- [#603](https://github.com/frontman-ai/frontman/pull/603) [`7e0c3b6`](https://github.com/frontman-ai/frontman/commit/7e0c3b62c53d0fd1704b06912a9b4f0a2b59da6f) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - ### Fixed
  - **Annotation enrichment failures are no longer silent** — the three async enrichment fields (`selector`, `screenshot`, `sourceLocation`) now use `result<option<T>, string>` instead of `option<T>`, capturing per-field error details for debugging.
  - **Send-before-ready race condition** — the submit button is now disabled while any annotation is still enriching, preventing empty annotation stubs from being sent to the LLM.
  - **Missing error dispatch on outer catch** — when the entire `FetchAnnotationDetails` promise chain fails, a `Failed` status with error details is now dispatched instead of only logging to console.

  ### Added
  - `enrichmentStatus` field on `Annotation.t` (`Enriching | Enriched | Failed({error: string})`) to track the enrichment lifecycle.
  - `hasEnrichingAnnotations` selector for gating the send button.
  - Visual feedback on annotation markers: pulsing badge while enriching, amber badge with error tooltip on failure.
  - Status indicator in the selected element display (spinner while enriching, warning icon on failure).

- [#542](https://github.com/frontman-ai/frontman/pull/542) [`94f2505`](https://github.com/frontman-ai/frontman/commit/94f25055ba110db087843c4f80506eba8e281c86) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix ACP spec deviation: make Plan.entries a required field instead of optional. The ACP spec defines entries as required, so the Option wrapper was incorrect.

- [#608](https://github.com/frontman-ai/frontman/pull/608) [`48e688a`](https://github.com/frontman-ai/frontman/commit/48e688a73f5b4a8ecb5e6d6860cd767a7f8fcd77) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - ### Fixed
  - **Infinite reload loop with locale-based URL rewriting middleware** — four root causes fixed for apps using locale middleware (e.g. `next-intl`, `@formatjs/intl`):
    - `stripSuffix` unconditionally appended a trailing slash to every path even without a `/frontman` suffix, causing false-positive navigate intercepts. A new `hasSuffix` predicate now gates the intercept correctly.
    - Server-side redirects (e.g. `/en/` → `/en`) fire a `navigate` event before `onLoad`, causing a trailing-slash difference in the `url` prop to reload the iframe while `hasLoaded` was still `false`. The url-prop effect now normalizes trailing slashes before comparing.
    - Session restore mounted all persisted task iframes eagerly (20+ concurrent requests). Inactive iframes now start with `src=""` and load lazily on first activation.
    - The generated `proxy.ts` (Next.js ≥16) used a path guard that missed `/en/frontman/` (the trailing-slash URL written by `syncBrowserUrl`). The template now delegates directly to the core middleware via `await frontman(req)`, matching the `middleware.ts` pattern. The `/:path*/frontman/` matcher is also added to all generated configs.

- [#522](https://github.com/frontman-ai/frontman/pull/522) [`79a0411`](https://github.com/frontman-ai/frontman/commit/79a0411aabecc32ecb306bcbe8c0616497d6fbe5) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix version check banner always showing in monorepo dev. Remove hardcoded serverVersion from marketing config and replace string equality with semver comparison so the banner only appears when the installed version is strictly behind the latest.

- [#617](https://github.com/frontman-ai/frontman/pull/617) [`181e673`](https://github.com/frontman-ai/frontman/commit/181e673325024570f81e4935d5a239278177d59d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Replace raw string `type_` field in `toolResultContent` with a typed `toolResultContentType` variant (`Text | Image | Resource`) per MCP spec. Provides compile-time validation that content type values are valid — typos like `"txt"` are now caught at build time.

- [#511](https://github.com/frontman-ai/frontman/pull/511) [`3ba5208`](https://github.com/frontman-ai/frontman/commit/3ba5208f0ef332653a199a7b78e210c5a6ee0190) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Open-source `@frontman-ai/react-statestore` as an independent npm package. Remove internal logging dependency, disable ReScript namespace for cleaner module imports, rename package from `@frontman/react-statestore` to `@frontman-ai/react-statestore`, and migrate all consumer references in `libs/client/`.

- [#613](https://github.com/frontman-ai/frontman/pull/613) [`e24c2e8`](https://github.com/frontman-ai/frontman/commit/e24c2e84a60af2df73fa7c79fb951f43009ec63e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Remove dead "Calling " prefix stripping from tool label helpers. No production server code sends tool names with this prefix; the branches were unreachable legacy code.

- [#575](https://github.com/frontman-ai/frontman/pull/575) [`f6b16d0`](https://github.com/frontman-ai/frontman/commit/f6b16d08d36aea693b4218566b30fed3d9d00c18) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Make StopReason a typed enum per ACP spec instead of a raw string. Defines the 5 ACP-specified values (end_turn, max_tokens, max_turn_requests, refusal, cancelled) as a closed variant type in the protocol layer, with corresponding Elixir module attributes and guard clauses on the server side.

#### @frontman-ai/frontman-client


### Minor Changes

- [#555](https://github.com/frontman-ai/frontman/pull/555) [`18054d0`](https://github.com/frontman-ai/frontman/commit/18054d0bec4a971f1c1a676b02cfaea9833d4b66) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Model ContentBlock as a discriminated union per ACP spec instead of a flat record with optional fields. Adds TextContent, ImageContent, AudioContent, ResourceLink, and EmbeddedResource variants with compile-time type safety. Wire format unchanged.

- [#604](https://github.com/frontman-ai/frontman/pull/604) [`cea1cff`](https://github.com/frontman-ai/frontman/commit/cea1cff2e7d84e5d66ffa42562a862f9fa447dac) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add ACP-compliant LoadSessionResponse type and unify model selection with SessionConfigOption. Replaces the bespoke /api/models REST endpoint with channel-based config option delivery via session/new, session/load responses and config_option_update notifications. Adds full type tree: SessionModeState, SessionMode, SessionConfigOption (grouped/ungrouped select with category enum), sessionLoadResult. Server pushes config updates after API key saves and OAuth connect/disconnect via PubSub.

- [#598](https://github.com/frontman-ai/frontman/pull/598) [`418d99c`](https://github.com/frontman-ai/frontman/commit/418d99cd9b48e6c7948cdddea97ca13bd0f079b4) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add interactive question tool as a client-side MCP tool. Agents can ask users questions via a drawer UI with multi-step navigation, option selection, custom text input, and skip/cancel. Includes history replay ordering fixes (flush TextDeltaBuffer at message boundaries, use server timestamps for tool calls) and disconnect resilience: unresolved tool calls are re-dispatched on reconnect via MCP tools/call, tool results carry \_meta with env API keys + model for agent resume after server restart, and persistence is moved to the SwarmAi runtime process (persist-then-broadcast) so data survives channel disconnects.

### Patch Changes

- [#573](https://github.com/frontman-ai/frontman/pull/573) [`fbbc2f6`](https://github.com/frontman-ai/frontman/commit/fbbc2f60f05f96b010fa4d593e6845fcfd8a8a2f) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add ACP elicitation protocol support and enforce compliance across server, protocol, and client layers. Wire up elicitation schema conversion, typed status constants, AgentTurnComplete notification, and idempotent TurnCompleted state transitions. Fix flaky tests and nil description handling in elicitation schemas.

- [#601](https://github.com/frontman-ai/frontman/pull/601) [`15607ba`](https://github.com/frontman-ai/frontman/commit/15607ba50fee4902372f0dcc2175d014396917d2) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Make AgentMessageChunk content field required per ACP ContentChunk spec. Removes unnecessary option wrapper and simplifies downstream consumer code.

- [#607](https://github.com/frontman-ai/frontman/pull/607) [`eec075b`](https://github.com/frontman-ai/frontman/commit/eec075b7d246a584dd2a8c84919f5e22b63093ab) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - ### Fixed
  - **MCP `handleMessage` promise rejections are no longer silently swallowed** — async errors in the channel message handler are now caught, logged, and reported to Sentry instead of disappearing into an unhandled promise rejection that causes the agent to hang indefinitely.

- [#587](https://github.com/frontman-ai/frontman/pull/587) [`08d8af6`](https://github.com/frontman-ai/frontman/commit/08d8af6b4e0e1acf86480924514ffacca937de2b) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Replace suspension/resume with blocking interactive tools, fix agent message loss on session reload
  - Interactive tools (e.g. question) block with a 2-minute receive timeout instead of suspending the agent
  - Remove ResumeContext, ETS suspension state, on_suspended callback, resume_execution
  - Simplify add_tool_result to return {:ok, interaction} directly (no resume signals)
  - Pass mcp_tool_defs through for execution mode lookups (interactive vs synchronous timeout)
  - Fix race condition: flush TextDeltaBuffer before LoadComplete to prevent agent messages from being silently dropped during history replay
  - Thread server timestamps through agent_message_chunk for correct message ordering
  - Add timestamp to agent_message_chunk in ACP protocol schema

#### @frontman-ai/frontman-core


### Patch Changes

- [#617](https://github.com/frontman-ai/frontman/pull/617) [`181e673`](https://github.com/frontman-ai/frontman/commit/181e673325024570f81e4935d5a239278177d59d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Replace raw string `type_` field in `toolResultContent` with a typed `toolResultContentType` variant (`Text | Image | Resource`) per MCP spec. Provides compile-time validation that content type values are valid — typos like `"txt"` are now caught at build time.

- Updated dependencies [[`fbbc2f6`](https://github.com/frontman-ai/frontman/commit/fbbc2f60f05f96b010fa4d593e6845fcfd8a8a2f), [`15607ba`](https://github.com/frontman-ai/frontman/commit/15607ba50fee4902372f0dcc2175d014396917d2), [`18054d0`](https://github.com/frontman-ai/frontman/commit/18054d0bec4a971f1c1a676b02cfaea9833d4b66), [`94f2505`](https://github.com/frontman-ai/frontman/commit/94f25055ba110db087843c4f80506eba8e281c86), [`cea1cff`](https://github.com/frontman-ai/frontman/commit/cea1cff2e7d84e5d66ffa42562a862f9fa447dac), [`181e673`](https://github.com/frontman-ai/frontman/commit/181e673325024570f81e4935d5a239278177d59d), [`418d99c`](https://github.com/frontman-ai/frontman/commit/418d99cd9b48e6c7948cdddea97ca13bd0f079b4), [`f6b16d0`](https://github.com/frontman-ai/frontman/commit/f6b16d08d36aea693b4218566b30fed3d9d00c18), [`08d8af6`](https://github.com/frontman-ai/frontman/commit/08d8af6b4e0e1acf86480924514ffacca937de2b)]:
  - @frontman-ai/frontman-protocol@0.5.0

#### @frontman-ai/nextjs


### Patch Changes

- [#567](https://github.com/frontman-ai/frontman/pull/567) [`331d899`](https://github.com/frontman-ai/frontman/commit/331d899bfdf69d370fe810ac0d0f0f941f661b76) Thanks [@itayadler](https://github.com/itayadler)! - Fix Next.js installer failing in monorepo setups where node_modules are hoisted
  - Use Node.js `createRequire` for module resolution instead of a hardcoded `node_modules/next/package.json` path
  - Add `hasNextDependency` check to prevent false detection in sibling workspaces
  - Remove E2E symlink workaround that was papering over the root cause

- [#608](https://github.com/frontman-ai/frontman/pull/608) [`48e688a`](https://github.com/frontman-ai/frontman/commit/48e688a73f5b4a8ecb5e6d6860cd767a7f8fcd77) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - ### Fixed
  - **Infinite reload loop with locale-based URL rewriting middleware** — four root causes fixed for apps using locale middleware (e.g. `next-intl`, `@formatjs/intl`):
    - `stripSuffix` unconditionally appended a trailing slash to every path even without a `/frontman` suffix, causing false-positive navigate intercepts. A new `hasSuffix` predicate now gates the intercept correctly.
    - Server-side redirects (e.g. `/en/` → `/en`) fire a `navigate` event before `onLoad`, causing a trailing-slash difference in the `url` prop to reload the iframe while `hasLoaded` was still `false`. The url-prop effect now normalizes trailing slashes before comparing.
    - Session restore mounted all persisted task iframes eagerly (20+ concurrent requests). Inactive iframes now start with `src=""` and load lazily on first activation.
    - The generated `proxy.ts` (Next.js ≥16) used a path guard that missed `/en/frontman/` (the trailing-slash URL written by `syncBrowserUrl`). The template now delegates directly to the core middleware via `await frontman(req)`, matching the `middleware.ts` pattern. The `/:path*/frontman/` matcher is also added to all generated configs.

#### @frontman-ai/frontman-protocol


### Minor Changes

- [#573](https://github.com/frontman-ai/frontman/pull/573) [`fbbc2f6`](https://github.com/frontman-ai/frontman/commit/fbbc2f60f05f96b010fa4d593e6845fcfd8a8a2f) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add ACP elicitation protocol support and enforce compliance across server, protocol, and client layers. Wire up elicitation schema conversion, typed status constants, AgentTurnComplete notification, and idempotent TurnCompleted state transitions. Fix flaky tests and nil description handling in elicitation schemas.

- [#555](https://github.com/frontman-ai/frontman/pull/555) [`18054d0`](https://github.com/frontman-ai/frontman/commit/18054d0bec4a971f1c1a676b02cfaea9833d4b66) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Model ContentBlock as a discriminated union per ACP spec instead of a flat record with optional fields. Adds TextContent, ImageContent, AudioContent, ResourceLink, and EmbeddedResource variants with compile-time type safety. Wire format unchanged.

- [#604](https://github.com/frontman-ai/frontman/pull/604) [`cea1cff`](https://github.com/frontman-ai/frontman/commit/cea1cff2e7d84e5d66ffa42562a862f9fa447dac) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add ACP-compliant LoadSessionResponse type and unify model selection with SessionConfigOption. Replaces the bespoke /api/models REST endpoint with channel-based config option delivery via session/new, session/load responses and config_option_update notifications. Adds full type tree: SessionModeState, SessionMode, SessionConfigOption (grouped/ungrouped select with category enum), sessionLoadResult. Server pushes config updates after API key saves and OAuth connect/disconnect via PubSub.

- [#617](https://github.com/frontman-ai/frontman/pull/617) [`181e673`](https://github.com/frontman-ai/frontman/commit/181e673325024570f81e4935d5a239278177d59d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Replace raw string `type_` field in `toolResultContent` with a typed `toolResultContentType` variant (`Text | Image | Resource`) per MCP spec. Provides compile-time validation that content type values are valid — typos like `"txt"` are now caught at build time.

- [#598](https://github.com/frontman-ai/frontman/pull/598) [`418d99c`](https://github.com/frontman-ai/frontman/commit/418d99cd9b48e6c7948cdddea97ca13bd0f079b4) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add interactive question tool as a client-side MCP tool. Agents can ask users questions via a drawer UI with multi-step navigation, option selection, custom text input, and skip/cancel. Includes history replay ordering fixes (flush TextDeltaBuffer at message boundaries, use server timestamps for tool calls) and disconnect resilience: unresolved tool calls are re-dispatched on reconnect via MCP tools/call, tool results carry \_meta with env API keys + model for agent resume after server restart, and persistence is moved to the SwarmAi runtime process (persist-then-broadcast) so data survives channel disconnects.

- [#575](https://github.com/frontman-ai/frontman/pull/575) [`f6b16d0`](https://github.com/frontman-ai/frontman/commit/f6b16d08d36aea693b4218566b30fed3d9d00c18) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Make StopReason a typed enum per ACP spec instead of a raw string. Defines the 5 ACP-specified values (end_turn, max_tokens, max_turn_requests, refusal, cancelled) as a closed variant type in the protocol layer, with corresponding Elixir module attributes and guard clauses on the server side.

### Patch Changes

- [#601](https://github.com/frontman-ai/frontman/pull/601) [`15607ba`](https://github.com/frontman-ai/frontman/commit/15607ba50fee4902372f0dcc2175d014396917d2) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Make AgentMessageChunk content field required per ACP ContentChunk spec. Removes unnecessary option wrapper and simplifies downstream consumer code.

- [#542](https://github.com/frontman-ai/frontman/pull/542) [`94f2505`](https://github.com/frontman-ai/frontman/commit/94f25055ba110db087843c4f80506eba8e281c86) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix ACP spec deviation: make Plan.entries a required field instead of optional. The ACP spec defines entries as required, so the Option wrapper was incorrect.

- [#587](https://github.com/frontman-ai/frontman/pull/587) [`08d8af6`](https://github.com/frontman-ai/frontman/commit/08d8af6b4e0e1acf86480924514ffacca937de2b) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Replace suspension/resume with blocking interactive tools, fix agent message loss on session reload
  - Interactive tools (e.g. question) block with a 2-minute receive timeout instead of suspending the agent
  - Remove ResumeContext, ETS suspension state, on_suspended callback, resume_execution
  - Simplify add_tool_result to return {:ok, interaction} directly (no resume signals)
  - Pass mcp_tool_defs through for execution mode lookups (interactive vs synchronous timeout)
  - Fix race condition: flush TextDeltaBuffer before LoadComplete to prevent agent messages from being silently dropped during history replay
  - Thread server timestamps through agent_message_chunk for correct message ordering
  - Add timestamp to agent_message_chunk in ACP protocol schema

#### @frontman-ai/react-statestore


### Minor Changes

- [#511](https://github.com/frontman-ai/frontman/pull/511) [`3ba5208`](https://github.com/frontman-ai/frontman/commit/3ba5208f0ef332653a199a7b78e210c5a6ee0190) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Open-source `@frontman-ai/react-statestore` as an independent npm package. Remove internal logging dependency, disable ReScript namespace for cleaner module imports, rename package from `@frontman/react-statestore` to `@frontman-ai/react-statestore`, and migrate all consumer references in `libs/client/`.

## [0.10.0] - 2026-03-04


#### @frontman/bindings


### Patch Changes

- [#461](https://github.com/frontman-ai/frontman/pull/461) [`746666e`](https://github.com/frontman-ai/frontman/commit/746666eec12531c56835a7e0e4da25efa136d927) Thanks [@itayadler](https://github.com/itayadler)! - Enforce pure bindings architecture: extract all business logic from `@frontman/bindings` to domain packages, delete dead code, rename Sentry modules, and fix circular dependency in frontman-protocol.

#### @frontman-ai/client


### Minor Changes

- [#332](https://github.com/frontman-ai/frontman/pull/332) [`995762f`](https://github.com/frontman-ai/frontman/commit/995762f4c9149216b0af10355493a0865e80eafc) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Replace element picker with annotation system. Users can now pin multiple elements on the page as numbered annotations, add/remove them freely, and reference them in chat. The server interaction schema and prompts are updated to handle annotation-based context instead of single element selections.

- [#485](https://github.com/frontman-ai/frontman/pull/485) [`a5530b7`](https://github.com/frontman-ai/frontman/commit/a5530b704d5ac3c4e8df186da026fbfd5553186b) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Attach annotations to messages instead of task state. Annotations are now stored as serializable snapshots on each `Message.User` record, rendered as compact chips in the conversation history. This fixes empty purple chat bubbles when sending annotation-only messages and preserves annotation context in the message timeline.

- [#492](https://github.com/frontman-ai/frontman/pull/492) [`4e6c80f`](https://github.com/frontman-ai/frontman/commit/4e6c80fcdb1f6886792853f0358aa6e38d846f68) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix shallow UI edits by giving the agent visual context and structural awareness. Add component name detection (React/Vue/Astro) to `get_dom` output, add UI & Layout Changes guidance to the system prompt with before/after screenshot workflow, add large-file comprehension strategy to `read_file`, and require edit summaries with trade-off analysis. Includes a manual test fixture (`test/manual/vite-dashboard/`) with a 740-line component to reproduce the original issue.

- [#496](https://github.com/frontman-ai/frontman/pull/496) [`4641751`](https://github.com/frontman-ai/frontman/commit/46417511374ef0d69f8b8ac94defa1eabd279044) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Show in-browser banner when a newer integration package is available. Integration packages now report their real version (instead of hardcoded "1.0.0"), the server proxies npm registry lookups with a 30-minute cache, and the client displays a dismissible amber banner with an "Update" button that prompts the LLM to perform the upgrade.

- [#461](https://github.com/frontman-ai/frontman/pull/461) [`746666e`](https://github.com/frontman-ai/frontman/commit/746666eec12531c56835a7e0e4da25efa136d927) Thanks [@itayadler](https://github.com/itayadler)! - Add Vue 3 + Vite support: source location capture in `.vue` SFCs via a Vite transform plugin, client-side Vue component instance detection for click-to-source, and a Vue E2E test fixture with installer integration.

### Patch Changes

- [#463](https://github.com/frontman-ai/frontman/pull/463) [`2179444`](https://github.com/frontman-ai/frontman/commit/2179444a41cb90442ccaa3975d4aad56d1f1bb11) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix trailing-slash 404 on Frontman API routes behind reverse proxy and mixed-content URL scheme mismatch when running behind TLS-terminating proxy (Caddy). Add containerized worktree infrastructure with Podman pods for parallel isolated development.

- [#486](https://github.com/frontman-ai/frontman/pull/486) [`2f979b4`](https://github.com/frontman-ai/frontman/commit/2f979b4ba0f1058284f5780ab8ff2fdbf9fde760) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix framework-specific prompt guidance never being applied in production. The middleware sent display labels like "Next.js" but the server matched on "nextjs", so 120+ lines of Next.js expert guidance were silently skipped. Introduces a `Framework` module as single source of truth for framework identity, normalizes at the server boundary, and updates client adapters to send normalized IDs.

- [#465](https://github.com/frontman-ai/frontman/pull/465) [`fe1e276`](https://github.com/frontman-ai/frontman/commit/fe1e2761dfa58d7fc17ed6cbf90ebf9c46b7b037) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix selection mode cursor reverting to pointer/hand on interactive elements inside iframe. Replaced body-level inline cursor style with an injected `<style>` tag using `* { cursor: crosshair !important; }` so that buttons, links, and inputs can't override the crosshair during selection mode.

- [#472](https://github.com/frontman-ai/frontman/pull/472) [`0e02a6a`](https://github.com/frontman-ai/frontman/commit/0e02a6ab637979e8f1276390e8608d998ec6edc1) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Migrate direct Console.\* calls to structured @frontman/logs logging in client-side packages. Replaces ~40 Console.log/error/warn calls across 11 files with component-tagged, level-filtered Log.info/error/warning/debug calls. Extends LogComponent.t with 10 new component variants for the migrated modules.

- [#488](https://github.com/frontman-ai/frontman/pull/488) [`453bcd5`](https://github.com/frontman-ai/frontman/commit/453bcd5cecb44c4ec133cc7dca45b11b25a64477) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Replace manual Dict JSON building with Sury schema types in annotation meta builders for compile-time field name safety.

- [#482](https://github.com/frontman-ai/frontman/pull/482) [`604fe62`](https://github.com/frontman-ai/frontman/commit/604fe6291bbb696ae71aab0fd661a0e8fd7858fc) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Track all tool execution failures in Sentry. Adds error reporting for backend tool soft errors, MCP tool errors/timeouts, agent execution failures/crashes, and JSON argument parse failures. Normalizes backend tool result status from "error" to "failed" to fix client-side silent drop, and replaces silent catch-all in the client with a warning log for unexpected statuses.

#### @frontman-ai/astro


### Minor Changes

- [#496](https://github.com/frontman-ai/frontman/pull/496) [`4641751`](https://github.com/frontman-ai/frontman/commit/46417511374ef0d69f8b8ac94defa1eabd279044) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Show in-browser banner when a newer integration package is available. Integration packages now report their real version (instead of hardcoded "1.0.0"), the server proxies npm registry lookups with a 30-minute cache, and the client displays a dismissible amber banner with an "Update" button that prompts the LLM to perform the upgrade.

### Patch Changes

- [#463](https://github.com/frontman-ai/frontman/pull/463) [`2179444`](https://github.com/frontman-ai/frontman/commit/2179444a41cb90442ccaa3975d4aad56d1f1bb11) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix trailing-slash 404 on Frontman API routes behind reverse proxy and mixed-content URL scheme mismatch when running behind TLS-terminating proxy (Caddy). Add containerized worktree infrastructure with Podman pods for parallel isolated development.

- [#438](https://github.com/frontman-ai/frontman/pull/438) [`1648416`](https://github.com/frontman-ai/frontman/commit/164841645854156c646acb350821c92fbfa11354) Thanks [@itayadler](https://github.com/itayadler)! - Add Playwright + Vitest end-to-end test infrastructure with test suites for Next.js, Astro, and Vite. Tests validate the core product loop: open framework dev server, navigate to `/frontman`, log in, send a prompt, and verify the AI agent modifies source code.

- [#486](https://github.com/frontman-ai/frontman/pull/486) [`2f979b4`](https://github.com/frontman-ai/frontman/commit/2f979b4ba0f1058284f5780ab8ff2fdbf9fde760) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix framework-specific prompt guidance never being applied in production. The middleware sent display labels like "Next.js" but the server matched on "nextjs", so 120+ lines of Next.js expert guidance were silently skipped. Introduces a `Framework` module as single source of truth for framework identity, normalizes at the server boundary, and updates client adapters to send normalized IDs.

- [#461](https://github.com/frontman-ai/frontman/pull/461) [`746666e`](https://github.com/frontman-ai/frontman/commit/746666eec12531c56835a7e0e4da25efa136d927) Thanks [@itayadler](https://github.com/itayadler)! - Enforce pure bindings architecture: extract all business logic from `@frontman/bindings` to domain packages, delete dead code, rename Sentry modules, and fix circular dependency in frontman-protocol.

#### @frontman-ai/frontman-client


### Patch Changes

- [#455](https://github.com/frontman-ai/frontman/pull/455) [`ed92762`](https://github.com/frontman-ai/frontman/commit/ed92762d46a3d26957eba8e68077398628e74f30) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Filter third-party errors from Frontman's internal Sentry reporting. Extracts shared Sentry types, config (DSN, internal-dev detection), and a `beforeSend` filter into `@frontman/bindings` so all framework integrations share a single source of truth. The filter inspects stacktrace frames and drops events that don't originate from Frontman code, preventing noise from framework internals (e.g. Next.js/Turbopack source-map WASM fetch failures). Both `@frontman-ai/nextjs` and `@frontman-ai/frontman-client` now use this shared filter.

- [#461](https://github.com/frontman-ai/frontman/pull/461) [`746666e`](https://github.com/frontman-ai/frontman/commit/746666eec12531c56835a7e0e4da25efa136d927) Thanks [@itayadler](https://github.com/itayadler)! - Enforce pure bindings architecture: extract all business logic from `@frontman/bindings` to domain packages, delete dead code, rename Sentry modules, and fix circular dependency in frontman-protocol.

- Updated dependencies [[`0e02a6a`](https://github.com/frontman-ai/frontman/commit/0e02a6ab637979e8f1276390e8608d998ec6edc1)]:
  - @frontman/logs@0.1.1

#### @frontman-ai/frontman-core


### Patch Changes

- [#486](https://github.com/frontman-ai/frontman/pull/486) [`2f979b4`](https://github.com/frontman-ai/frontman/commit/2f979b4ba0f1058284f5780ab8ff2fdbf9fde760) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix framework-specific prompt guidance never being applied in production. The middleware sent display labels like "Next.js" but the server matched on "nextjs", so 120+ lines of Next.js expert guidance were silently skipped. Introduces a `Framework` module as single source of truth for framework identity, normalizes at the server boundary, and updates client adapters to send normalized IDs.

- [#489](https://github.com/frontman-ai/frontman/pull/489) [`5599f92`](https://github.com/frontman-ai/frontman/commit/5599f929b6ded4a818c14cebfe9b8d8d8c9ea7b9) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix ENOTDIR crash in grep tool when LLM passes a file path. Harden all search tools (grep, search_files, list_files, list_tree) to gracefully handle file paths instead of crashing. Catch synchronous spawn() throws in spawnPromise so errors flow through the result type. Rewrite tool descriptions for clarity and remove duplicated tool selection guidance from system prompt.

- [#461](https://github.com/frontman-ai/frontman/pull/461) [`746666e`](https://github.com/frontman-ai/frontman/commit/746666eec12531c56835a7e0e4da25efa136d927) Thanks [@itayadler](https://github.com/itayadler)! - Enforce pure bindings architecture: extract all business logic from `@frontman/bindings` to domain packages, delete dead code, rename Sentry modules, and fix circular dependency in frontman-protocol.

- [#492](https://github.com/frontman-ai/frontman/pull/492) [`4e6c80f`](https://github.com/frontman-ai/frontman/commit/4e6c80fcdb1f6886792853f0358aa6e38d846f68) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix shallow UI edits by giving the agent visual context and structural awareness. Add component name detection (React/Vue/Astro) to `get_dom` output, add UI & Layout Changes guidance to the system prompt with before/after screenshot workflow, add large-file comprehension strategy to `read_file`, and require edit summaries with trade-off analysis. Includes a manual test fixture (`test/manual/vite-dashboard/`) with a 740-line component to reproduce the original issue.

- Updated dependencies [[`746666e`](https://github.com/frontman-ai/frontman/commit/746666eec12531c56835a7e0e4da25efa136d927)]:
  - @frontman/bindings@0.3.1
  - @frontman-ai/frontman-protocol@0.4.1

#### @frontman-ai/nextjs


### Minor Changes

- [#496](https://github.com/frontman-ai/frontman/pull/496) [`4641751`](https://github.com/frontman-ai/frontman/commit/46417511374ef0d69f8b8ac94defa1eabd279044) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Show in-browser banner when a newer integration package is available. Integration packages now report their real version (instead of hardcoded "1.0.0"), the server proxies npm registry lookups with a 30-minute cache, and the client displays a dismissible amber banner with an "Update" button that prompts the LLM to perform the upgrade.

### Patch Changes

- [#457](https://github.com/frontman-ai/frontman/pull/457) [`bbd6900`](https://github.com/frontman-ai/frontman/commit/bbd6900c35c7a22e4773faa24a04357ee479f793) Thanks [@itayadler](https://github.com/itayadler)! - E2E tests now run the Frontman installer CLI on bare fixture projects instead of using pre-wired configs, verifying that the installer produces working integrations for Next.js, Vite, and Astro.

- [#438](https://github.com/frontman-ai/frontman/pull/438) [`1648416`](https://github.com/frontman-ai/frontman/commit/164841645854156c646acb350821c92fbfa11354) Thanks [@itayadler](https://github.com/itayadler)! - Add Playwright + Vitest end-to-end test infrastructure with test suites for Next.js, Astro, and Vite. Tests validate the core product loop: open framework dev server, navigate to `/frontman`, log in, send a prompt, and verify the AI agent modifies source code.

- [#455](https://github.com/frontman-ai/frontman/pull/455) [`ed92762`](https://github.com/frontman-ai/frontman/commit/ed92762d46a3d26957eba8e68077398628e74f30) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Filter third-party errors from Frontman's internal Sentry reporting. Extracts shared Sentry types, config (DSN, internal-dev detection), and a `beforeSend` filter into `@frontman/bindings` so all framework integrations share a single source of truth. The filter inspects stacktrace frames and drops events that don't originate from Frontman code, preventing noise from framework internals (e.g. Next.js/Turbopack source-map WASM fetch failures). Both `@frontman-ai/nextjs` and `@frontman-ai/frontman-client` now use this shared filter.

- [#486](https://github.com/frontman-ai/frontman/pull/486) [`2f979b4`](https://github.com/frontman-ai/frontman/commit/2f979b4ba0f1058284f5780ab8ff2fdbf9fde760) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix framework-specific prompt guidance never being applied in production. The middleware sent display labels like "Next.js" but the server matched on "nextjs", so 120+ lines of Next.js expert guidance were silently skipped. Introduces a `Framework` module as single source of truth for framework identity, normalizes at the server boundary, and updates client adapters to send normalized IDs.

- [#461](https://github.com/frontman-ai/frontman/pull/461) [`746666e`](https://github.com/frontman-ai/frontman/commit/746666eec12531c56835a7e0e4da25efa136d927) Thanks [@itayadler](https://github.com/itayadler)! - Enforce pure bindings architecture: extract all business logic from `@frontman/bindings` to domain packages, delete dead code, rename Sentry modules, and fix circular dependency in frontman-protocol.

#### @frontman-ai/frontman-protocol


### Patch Changes

- [#461](https://github.com/frontman-ai/frontman/pull/461) [`746666e`](https://github.com/frontman-ai/frontman/commit/746666eec12531c56835a7e0e4da25efa136d927) Thanks [@itayadler](https://github.com/itayadler)! - Enforce pure bindings architecture: extract all business logic from `@frontman/bindings` to domain packages, delete dead code, rename Sentry modules, and fix circular dependency in frontman-protocol.

#### @frontman-ai/vite


### Minor Changes

- [#496](https://github.com/frontman-ai/frontman/pull/496) [`4641751`](https://github.com/frontman-ai/frontman/commit/46417511374ef0d69f8b8ac94defa1eabd279044) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Show in-browser banner when a newer integration package is available. Integration packages now report their real version (instead of hardcoded "1.0.0"), the server proxies npm registry lookups with a 30-minute cache, and the client displays a dismissible amber banner with an "Update" button that prompts the LLM to perform the upgrade.

- [#461](https://github.com/frontman-ai/frontman/pull/461) [`746666e`](https://github.com/frontman-ai/frontman/commit/746666eec12531c56835a7e0e4da25efa136d927) Thanks [@itayadler](https://github.com/itayadler)! - Add Vue 3 + Vite support: source location capture in `.vue` SFCs via a Vite transform plugin, client-side Vue component instance detection for click-to-source, and a Vue E2E test fixture with installer integration.

### Patch Changes

- [#457](https://github.com/frontman-ai/frontman/pull/457) [`bbd6900`](https://github.com/frontman-ai/frontman/commit/bbd6900c35c7a22e4773faa24a04357ee479f793) Thanks [@itayadler](https://github.com/itayadler)! - E2E tests now run the Frontman installer CLI on bare fixture projects instead of using pre-wired configs, verifying that the installer produces working integrations for Next.js, Vite, and Astro.

- [#438](https://github.com/frontman-ai/frontman/pull/438) [`1648416`](https://github.com/frontman-ai/frontman/commit/164841645854156c646acb350821c92fbfa11354) Thanks [@itayadler](https://github.com/itayadler)! - Add Playwright + Vitest end-to-end test infrastructure with test suites for Next.js, Astro, and Vite. Tests validate the core product loop: open framework dev server, navigate to `/frontman`, log in, send a prompt, and verify the AI agent modifies source code.

- [#486](https://github.com/frontman-ai/frontman/pull/486) [`2f979b4`](https://github.com/frontman-ai/frontman/commit/2f979b4ba0f1058284f5780ab8ff2fdbf9fde760) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix framework-specific prompt guidance never being applied in production. The middleware sent display labels like "Next.js" but the server matched on "nextjs", so 120+ lines of Next.js expert guidance were silently skipped. Introduces a `Framework` module as single source of truth for framework identity, normalizes at the server boundary, and updates client adapters to send normalized IDs.

#### @frontman/logs


### Patch Changes

- [#472](https://github.com/frontman-ai/frontman/pull/472) [`0e02a6a`](https://github.com/frontman-ai/frontman/commit/0e02a6ab637979e8f1276390e8608d998ec6edc1) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Migrate direct Console.\* calls to structured @frontman/logs logging in client-side packages. Replaces ~40 Console.log/error/warn calls across 11 files with component-tagged, level-filtered Log.info/error/warning/debug calls. Extends LogComponent.t with 10 new component variants for the migrated modules.

#### @frontman/react-statestore


### Patch Changes

- [#472](https://github.com/frontman-ai/frontman/pull/472) [`0e02a6a`](https://github.com/frontman-ai/frontman/commit/0e02a6ab637979e8f1276390e8608d998ec6edc1) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Migrate direct Console.\* calls to structured @frontman/logs logging in client-side packages. Replaces ~40 Console.log/error/warn calls across 11 files with component-tagged, level-filtered Log.info/error/warning/debug calls. Extends LogComponent.t with 10 new component variants for the migrated modules.

- Updated dependencies [[`0e02a6a`](https://github.com/frontman-ai/frontman/commit/0e02a6ab637979e8f1276390e8608d998ec6edc1)]:
  - @frontman/logs@0.1.1

## [0.9.0] - 2026-02-26


#### @frontman/client


### Patch Changes

- [#437](https://github.com/frontman-ai/frontman/pull/437) [`bc43aec`](https://github.com/frontman-ai/frontman/commit/bc43aeca56832fe7793d6c38f8dc68a92a4aa161) Thanks [@itayadler](https://github.com/itayadler)! - Fix chatbox rendering jank during streaming by adding React.memo to leaf components, buffering text deltas with requestAnimationFrame, removing unnecessary CSS transitions, and switching scroll resize mode to instant.

#### @frontman/frontman-client


### Patch Changes

- [#452](https://github.com/frontman-ai/frontman/pull/452) [`2d87685`](https://github.com/frontman-ai/frontman/commit/2d87685c436281dda18f5416782d9f6b9d85bc1c) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix 8 Dependabot security alerts by upgrading Sentry SDK from v8 to v9, sentry-testkit to v6, and adding yarn resolutions for vulnerable transitive dependencies (rollup, basic-ftp, minimatch, devalue, hono).

#### @frontman/frontman-core


### Minor Changes

- [#434](https://github.com/frontman-ai/frontman/pull/434) [`40c3932`](https://github.com/frontman-ai/frontman/commit/40c393263902d91be7af7db80fbfa875528b2361) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add `list_tree` tool for project structure discovery during MCP initialization. The tool provides a compact, monorepo-aware directory tree view that is injected into the system prompt and available as an on-demand callable tool. Supports workspace detection (package.json workspaces, pnpm, turbo, nx), smart noise filtering, and git-aware file listing.

#### @frontman-ai/nextjs


### Patch Changes

- [#452](https://github.com/frontman-ai/frontman/pull/452) [`2d87685`](https://github.com/frontman-ai/frontman/commit/2d87685c436281dda18f5416782d9f6b9d85bc1c) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix 8 Dependabot security alerts by upgrading Sentry SDK from v8 to v9, sentry-testkit to v6, and adding yarn resolutions for vulnerable transitive dependencies (rollup, basic-ftp, minimatch, devalue, hono).

## [0.8.0] - 2026-02-24


#### @frontman/client


### Minor Changes

- [#426](https://github.com/frontman-ai/frontman/pull/426) [`1b6ecec`](https://github.com/frontman-ai/frontman/commit/1b6ecec8256a2630a71ef3b8d7b3d60c34c16f9a) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - URL-addressable preview: persist iframe URL in browser address bar using suffix-based routing. Navigation within the preview iframe is now reflected in the browser URL, enabling shareable deep links and browser back/forward support.

#### @frontman-ai/astro


### Minor Changes

- [#426](https://github.com/frontman-ai/frontman/pull/426) [`1b6ecec`](https://github.com/frontman-ai/frontman/commit/1b6ecec8256a2630a71ef3b8d7b3d60c34c16f9a) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - URL-addressable preview: persist iframe URL in browser address bar using suffix-based routing. Navigation within the preview iframe is now reflected in the browser URL, enabling shareable deep links and browser back/forward support.

#### @frontman/frontman-core


### Minor Changes

- [#426](https://github.com/frontman-ai/frontman/pull/426) [`1b6ecec`](https://github.com/frontman-ai/frontman/commit/1b6ecec8256a2630a71ef3b8d7b3d60c34c16f9a) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - URL-addressable preview: persist iframe URL in browser address bar using suffix-based routing. Navigation within the preview iframe is now reflected in the browser URL, enabling shareable deep links and browser back/forward support.

#### @frontman-ai/nextjs


### Minor Changes

- [#426](https://github.com/frontman-ai/frontman/pull/426) [`1b6ecec`](https://github.com/frontman-ai/frontman/commit/1b6ecec8256a2630a71ef3b8d7b3d60c34c16f9a) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - URL-addressable preview: persist iframe URL in browser address bar using suffix-based routing. Navigation within the preview iframe is now reflected in the browser URL, enabling shareable deep links and browser back/forward support.

#### @frontman-ai/vite


### Minor Changes

- [#426](https://github.com/frontman-ai/frontman/pull/426) [`1b6ecec`](https://github.com/frontman-ai/frontman/commit/1b6ecec8256a2630a71ef3b8d7b3d60c34c16f9a) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - URL-addressable preview: persist iframe URL in browser address bar using suffix-based routing. Navigation within the preview iframe is now reflected in the browser URL, enabling shareable deep links and browser back/forward support.

## [0.7.0] - 2026-02-24


#### @frontman/bindings


### Minor Changes

- [#425](https://github.com/frontman-ai/frontman/pull/425) [`3198368`](https://github.com/frontman-ai/frontman/commit/31983683f7bf503e3831ac80baf347f00291e37d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Astro dev toolbar icon now navigates to the Frontman UI route instead of logging diagnostics. Expanded Astro bindings with full dev toolbar API coverage.

### Patch Changes

- [#415](https://github.com/frontman-ai/frontman/pull/415) [`38cff04`](https://github.com/frontman-ai/frontman/commit/38cff0417d24fffd225dde6125e2734c0ebdf5df) Thanks [@itayadler](https://github.com/itayadler)! - Add Lighthouse tool for web performance auditing. The `lighthouse` tool runs Google Lighthouse audits on URLs and returns scores (0-100) for performance, accessibility, best practices, and SEO categories, along with the top 3 issues to fix in each category. In DevPod environments, URLs are automatically rewritten to localhost to avoid TLS/interstitial issues. The Next.js config now falls back to PHX_HOST for automatic host detection in DevPod setups.

### Patch Changes

- Updated dependencies [[`3198368`](https://github.com/frontman-ai/frontman/commit/31983683f7bf503e3831ac80baf347f00291e37d), [`38cff04`](https://github.com/frontman-ai/frontman/commit/38cff0417d24fffd225dde6125e2734c0ebdf5df)]:
  - @frontman/bindings@0.3.0

#### @frontman-ai/astro


### Minor Changes

- [#425](https://github.com/frontman-ai/frontman/pull/425) [`3198368`](https://github.com/frontman-ai/frontman/commit/31983683f7bf503e3831ac80baf347f00291e37d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Astro dev toolbar icon now navigates to the Frontman UI route instead of logging diagnostics. Expanded Astro bindings with full dev toolbar API coverage.

- [#398](https://github.com/frontman-ai/frontman/pull/398) [`8269bb4`](https://github.com/frontman-ai/frontman/commit/8269bb448c555420326f035f6f17b7eb2f69033b) Thanks [@itayadler](https://github.com/itayadler)! - Add `edit_file` tool with 9-strategy fuzzy text matching for robust LLM-driven file edits. Framework-specific wrappers (Vite, Astro, Next.js) check dev server logs for compilation errors after edits. Add `get_logs` tool to Vite and Astro for querying captured console/build output.

- [#418](https://github.com/frontman-ai/frontman/pull/418) [`930669c`](https://github.com/frontman-ai/frontman/commit/930669c179b02b79ae35af662479914746638754) Thanks [@itayadler](https://github.com/itayadler)! - Extract shared middleware (CORS, UI shell, request handlers, SSE streaming) into frontman-core, refactor Astro/Next.js/Vite adapters to thin wrappers

#### @frontman/frontman-core


### Minor Changes

- [#398](https://github.com/frontman-ai/frontman/pull/398) [`8269bb4`](https://github.com/frontman-ai/frontman/commit/8269bb448c555420326f035f6f17b7eb2f69033b) Thanks [@itayadler](https://github.com/itayadler)! - Add `edit_file` tool with 9-strategy fuzzy text matching for robust LLM-driven file edits. Framework-specific wrappers (Vite, Astro, Next.js) check dev server logs for compilation errors after edits. Add `get_logs` tool to Vite and Astro for querying captured console/build output.

- [#418](https://github.com/frontman-ai/frontman/pull/418) [`930669c`](https://github.com/frontman-ai/frontman/commit/930669c179b02b79ae35af662479914746638754) Thanks [@itayadler](https://github.com/itayadler)! - Extract shared middleware (CORS, UI shell, request handlers, SSE streaming) into frontman-core, refactor Astro/Next.js/Vite adapters to thin wrappers

- [#415](https://github.com/frontman-ai/frontman/pull/415) [`38cff04`](https://github.com/frontman-ai/frontman/commit/38cff0417d24fffd225dde6125e2734c0ebdf5df) Thanks [@itayadler](https://github.com/itayadler)! - Add Lighthouse tool for web performance auditing. The `lighthouse` tool runs Google Lighthouse audits on URLs and returns scores (0-100) for performance, accessibility, best practices, and SEO categories, along with the top 3 issues to fix in each category. In DevPod environments, URLs are automatically rewritten to localhost to avoid TLS/interstitial issues. The Next.js config now falls back to PHX_HOST for automatic host detection in DevPod setups.

### Patch Changes

- [#350](https://github.com/frontman-ai/frontman/pull/350) [`0cb1e38`](https://github.com/frontman-ai/frontman/commit/0cb1e38204629a679fe73c60fe783927ff90d7c8) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Extract Swarm agent execution framework from frontman_server into standalone swarm_ai Hex package. Rename all Swarm._ modules to SwarmAi._ and update telemetry atoms accordingly. frontman_server now depends on swarm_ai via path dep for monorepo development.

- [#416](https://github.com/frontman-ai/frontman/pull/416) [`893684e`](https://github.com/frontman-ai/frontman/commit/893684e451be815f9cc0fadf29e4dca1449ffa25) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix swarm_ai documentation: correct broken examples, add missing @doc/@moduledoc annotations, fix inaccurate descriptions, and add README.md for Hex publishing. Bump swarm_ai to 0.1.1.

- Updated dependencies [[`3198368`](https://github.com/frontman-ai/frontman/commit/31983683f7bf503e3831ac80baf347f00291e37d), [`38cff04`](https://github.com/frontman-ai/frontman/commit/38cff0417d24fffd225dde6125e2734c0ebdf5df)]:
  - @frontman/bindings@0.3.0

#### @frontman-ai/nextjs


### Minor Changes

- [#398](https://github.com/frontman-ai/frontman/pull/398) [`8269bb4`](https://github.com/frontman-ai/frontman/commit/8269bb448c555420326f035f6f17b7eb2f69033b) Thanks [@itayadler](https://github.com/itayadler)! - Add `edit_file` tool with 9-strategy fuzzy text matching for robust LLM-driven file edits. Framework-specific wrappers (Vite, Astro, Next.js) check dev server logs for compilation errors after edits. Add `get_logs` tool to Vite and Astro for querying captured console/build output.

- [#418](https://github.com/frontman-ai/frontman/pull/418) [`930669c`](https://github.com/frontman-ai/frontman/commit/930669c179b02b79ae35af662479914746638754) Thanks [@itayadler](https://github.com/itayadler)! - Extract shared middleware (CORS, UI shell, request handlers, SSE streaming) into frontman-core, refactor Astro/Next.js/Vite adapters to thin wrappers

- [#415](https://github.com/frontman-ai/frontman/pull/415) [`38cff04`](https://github.com/frontman-ai/frontman/commit/38cff0417d24fffd225dde6125e2734c0ebdf5df) Thanks [@itayadler](https://github.com/itayadler)! - Add Lighthouse tool for web performance auditing. The `lighthouse` tool runs Google Lighthouse audits on URLs and returns scores (0-100) for performance, accessibility, best practices, and SEO categories, along with the top 3 issues to fix in each category. In DevPod environments, URLs are automatically rewritten to localhost to avoid TLS/interstitial issues. The Next.js config now falls back to PHX_HOST for automatic host detection in DevPod setups.

#### @frontman-ai/vite


### Minor Changes

- [#398](https://github.com/frontman-ai/frontman/pull/398) [`8269bb4`](https://github.com/frontman-ai/frontman/commit/8269bb448c555420326f035f6f17b7eb2f69033b) Thanks [@itayadler](https://github.com/itayadler)! - Add `edit_file` tool with 9-strategy fuzzy text matching for robust LLM-driven file edits. Framework-specific wrappers (Vite, Astro, Next.js) check dev server logs for compilation errors after edits. Add `get_logs` tool to Vite and Astro for querying captured console/build output.

- [#418](https://github.com/frontman-ai/frontman/pull/418) [`930669c`](https://github.com/frontman-ai/frontman/commit/930669c179b02b79ae35af662479914746638754) Thanks [@itayadler](https://github.com/itayadler)! - Extract shared middleware (CORS, UI shell, request handlers, SSE streaming) into frontman-core, refactor Astro/Next.js/Vite adapters to thin wrappers

## [0.6.0] - 2026-02-20


#### @frontman/bindings


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

#### @frontman/client


### Minor Changes

- [#401](https://github.com/frontman-ai/frontman/pull/401) [`3f3fd3e`](https://github.com/frontman-ai/frontman/commit/3f3fd3ef9ddb3a6b0ae42831e62b789f08acd273) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add browser element interaction tools: `get_interactive_elements` for discovering interactive elements via accessibility tree analysis, and `interact_with_element` for clicking, hovering, or focusing elements by CSS selector, role+name, or text content.

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
  - @frontman/bindings@0.2.0

#### @frontman-ai/astro


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

#### @frontman/frontman-client


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

#### @frontman/frontman-core


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

#### @frontman/frontman-protocol


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

## [0.5.0] - 2026-02-19


#### @frontman/bindings


### Patch Changes

- [#393](https://github.com/frontman-ai/frontman/pull/393) [`d4cd503`](https://github.com/frontman-ai/frontman/commit/d4cd503c97e14edc4d4f8f7a2d5b9226a1956347) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix Astro integration defaulting to dev host instead of production when FRONTMAN_HOST is not set, which broke production deployments. Also add stderr maxBuffer enforcement to spawnPromise to prevent unbounded memory growth from misbehaving child processes.

#### @frontman/client


### Minor Changes

- [#391](https://github.com/frontman-ai/frontman/pull/391) [`9bcc19a`](https://github.com/frontman-ai/frontman/commit/9bcc19ab3681673f1e63451c6b7d3c25007af130) Thanks [@itayadler](https://github.com/itayadler)! - Add Heap Analytics integration with automatic user identification. Heap is initialized in the client bundle with environment-aware env IDs (dev vs production). When a user session connects, the client fetches the user profile and calls `heap.identify()` and `heap.addUserProperties()` with the user's ID, email, and name. The server's `/api/user/me` endpoint now returns `id` and `name` in addition to `email`, and the user profile is stored in global state for reuse across components.

- [#368](https://github.com/frontman-ai/frontman/pull/368) [`ef6f38d`](https://github.com/frontman-ai/frontman/commit/ef6f38dc0ec0de5a98bca31dad576ee9e14ed0e8) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add device mode / viewport emulation to the web preview. Developers can now simulate specific device viewports (phones, tablets, desktop) with 12 built-in presets, custom dimensions, and orientation toggle. The preview iframe auto-scales to fit the available space with a checkerboard background. Device mode state is per-task, so switching tasks restores that task's viewport. A new `set_device_mode` MCP tool allows the AI agent to programmatically change viewports with actions for presets, custom sizes, responsive mode, orientation, and listing available devices.

### Patch Changes

- [#394](https://github.com/frontman-ai/frontman/pull/394) [`40abf99`](https://github.com/frontman-ai/frontman/commit/40abf99f81731557d57f44288de98af50220660c) Thanks [@itayadler](https://github.com/itayadler)! - Fix web preview URL bar syncing so iframe link navigations update the displayed URL without forcing iframe reloads. The URL input is now editable and supports Enter-to-navigate while preserving in-iframe navigation state.

### Patch Changes

- Updated dependencies [[`d4cd503`](https://github.com/frontman-ai/frontman/commit/d4cd503c97e14edc4d4f8f7a2d5b9226a1956347)]:
  - @frontman/bindings@0.1.1

#### @frontman-ai/astro


### Patch Changes

- [#393](https://github.com/frontman-ai/frontman/pull/393) [`d4cd503`](https://github.com/frontman-ai/frontman/commit/d4cd503c97e14edc4d4f8f7a2d5b9226a1956347) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix Astro integration defaulting to dev host instead of production when FRONTMAN_HOST is not set, which broke production deployments. Also add stderr maxBuffer enforcement to spawnPromise to prevent unbounded memory growth from misbehaving child processes.

#### @frontman/frontman-core


### Patch Changes

- [#388](https://github.com/frontman-ai/frontman/pull/388) [`cf885f6`](https://github.com/frontman-ai/frontman/commit/cf885f65e54bb1bb579448d882d9a60d8a5e14cf) Thanks [@itayadler](https://github.com/itayadler)! - fix: resolve Dependabot security vulnerabilities

  Replace deprecated `vscode-ripgrep` with `@vscode/ripgrep` (same API, officially renamed package). Add yarn resolutions for 15 transitive dependencies to patch known CVEs (tar, @modelcontextprotocol/sdk, devalue, node-forge, h3, lodash, js-yaml, and others). Upgrade astro, next, and jsdom to patched versions.

- Updated dependencies [[`d4cd503`](https://github.com/frontman-ai/frontman/commit/d4cd503c97e14edc4d4f8f7a2d5b9226a1956347)]:
  - @frontman/bindings@0.1.1

## [0.4.1] - 2026-02-17


#### @frontman/client


### Patch Changes

- [#384](https://github.com/frontman-ai/frontman/pull/384) [`59ee255`](https://github.com/frontman-ai/frontman/commit/59ee25581b2252636fb7cacb5cec118a38c00ced) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - fix(astro): load client from production CDN instead of localhost

  The Astro integration defaulted `clientUrl` to `http://localhost:5173/src/Main.res.mjs` unconditionally, which only works during local frontman development. When installed from npm, users saw requests to localhost:5173 instead of the production client.

  Now infers `isDev` from the host (matching the Vite plugin pattern): production host loads the client from `https://app.frontman.sh/frontman.es.js` with CSS from `https://app.frontman.sh/frontman.css`.

  Also fixes the standalone client bundle crashing with `process is not defined` in browsers by replacing `process.env.NODE_ENV` at build time (Vite lib mode doesn't do this automatically).

#### @frontman-ai/astro


### Patch Changes

- [#384](https://github.com/frontman-ai/frontman/pull/384) [`59ee255`](https://github.com/frontman-ai/frontman/commit/59ee25581b2252636fb7cacb5cec118a38c00ced) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - fix(astro): load client from production CDN instead of localhost

  The Astro integration defaulted `clientUrl` to `http://localhost:5173/src/Main.res.mjs` unconditionally, which only works during local frontman development. When installed from npm, users saw requests to localhost:5173 instead of the production client.

  Now infers `isDev` from the host (matching the Vite plugin pattern): production host loads the client from `https://app.frontman.sh/frontman.es.js` with CSS from `https://app.frontman.sh/frontman.css`.

  Also fixes the standalone client bundle crashing with `process is not defined` in browsers by replacing `process.env.NODE_ENV` at build time (Vite lib mode doesn't do this automatically).

## [0.4.0] - 2026-02-17


#### @frontman/client


### Minor Changes

- [`99f8e90`](https://github.com/frontman-ai/frontman/commit/99f8e90e312cfb2d33a1392b0c0a241622583248) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add file and image attachment support in the chat input. Users can attach images and files via drag & drop, clipboard paste, or a file picker button. Pasted multi-line text (3+ lines or >150 chars) is collapsed into a chip. Attachments are sent as ACP resource content blocks with base64-encoded blob data and rendered as thumbnails in both the input area and message history with a lightbox preview.

- [`99f8e90`](https://github.com/frontman-ai/frontman/commit/99f8e90e312cfb2d33a1392b0c0a241622583248) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add cancel/stop generation support. Users can now stop an in-progress AI agent response by clicking a stop button in the prompt input. Implements the ACP `session/cancel` notification protocol for clean cancellation across client, protocol, and server layers.

- [#342](https://github.com/frontman-ai/frontman/pull/342) [`023e9a4`](https://github.com/frontman-ai/frontman/commit/023e9a49037f7303dd13b98a5cd21ac429249756) Thanks [@itayadler](https://github.com/itayadler)! - Add current page context to agent system prompt. The client now implicitly collects page metadata (URL, viewport dimensions, device pixel ratio, page title, color scheme preference, scroll position) from the preview iframe and sends it as an ACP content block with every prompt. The server extracts this data and appends a `[Current Page Context]` section to user messages, giving the AI agent awareness of the user's browsing context for better responsive design decisions and route-aware suggestions.

- [#372](https://github.com/frontman-ai/frontman/pull/372) [`2fad09d`](https://github.com/frontman-ai/frontman/commit/2fad09d2672ef61baddfabee93250a4dcd13e7a9) Thanks [@itayadler](https://github.com/itayadler)! - Add first-time user experience (FTUE) with welcome modal, confetti celebration, and provider connection nudge. New users see a welcome screen before auth redirect, a confetti celebration after first sign-in, and a gentle nudge to connect an AI provider. Existing users are auto-detected via localStorage and skip all onboarding flows.

### Patch Changes

- [#379](https://github.com/frontman-ai/frontman/pull/379) [`68b7f53`](https://github.com/frontman-ai/frontman/commit/68b7f53d10c82fe5b462021cc2e866c0822fa0d8) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix source location detection for selected elements in Astro projects.
  - Refactor Astro integration from Astro middleware to Vite Connect middleware for more reliable request interception
  - Capture `data-astro-source-file`/`data-astro-source-loc` annotations on `DOMContentLoaded` before Astro's dev toolbar strips them
  - Add ancestor walk fallback (up to 20 levels) so clicking child elements resolves to the nearest annotated Astro component
  - Harden integration: `ensureConfig` guard for no-args usage, `duplex: 'half'` for POST requests, `headersSent` guard in error handler, skip duplicate capture on initial `astro:page-load`
  - Add LLM error chunk propagation so API rejections (e.g., oversized images) surface to the client instead of silently failing
  - Account for `devicePixelRatio` in screenshot scaling to avoid exceeding API dimension limits on hi-DPI displays

- [`99f8e90`](https://github.com/frontman-ai/frontman/commit/99f8e90e312cfb2d33a1392b0c0a241622583248) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fixed click-through on interactive elements (links, buttons) during element selection mode by using event capture with preventDefault/stopPropagation instead of disabling pointer events on anchors

- [`99f8e90`](https://github.com/frontman-ai/frontman/commit/99f8e90e312cfb2d33a1392b0c0a241622583248) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Remove dead initialization timeout code (`StartInitializationTimeout`, `InitializationTimeoutExpired`, `ReceivedDiscoveredProjectRule`) that was never wired up — `sessionInitialized` is set via `SetAcpSession` on connection

- [#357](https://github.com/frontman-ai/frontman/pull/357) [`ebec53a`](https://github.com/frontman-ai/frontman/commit/ebec53afadc28ce8c4d09a89a107b721c1c23c38) Thanks [@itayadler](https://github.com/itayadler)! - Redesign authentication UI with dark Frontman branding. The server-side login page now features a dark theme with the Frontman logo and GitHub/Google OAuth buttons only (no email/password forms). Registration routes redirect to login. The root URL redirects to the sign-in page in dev and to frontman.sh in production. The client-side settings modal General tab now shows the logged-in user's email, avatar, and a sign-out button. The sign-out flow preserves a `return_to` URL so users are redirected back to the client app after re-authenticating.

- [#377](https://github.com/frontman-ai/frontman/pull/377) [`15c3c8c`](https://github.com/frontman-ai/frontman/commit/15c3c8ccaf8ff65a160981493b4d46d98de42be5) Thanks [@itayadler](https://github.com/itayadler)! - ### Fixed
  - Stream `tool_call_start` events to client for immediate UI feedback when the LLM begins generating tool calls (e.g., `write_file`), eliminating multi-second blank gaps
  - Show "Waiting for file path..." / "Waiting for URL..." shimmer placeholder while tool arguments stream in
  - Display navigate tool URL/action inline instead of hiding it in an expandable body

#### @frontman-ai/astro


### Patch Changes

- [#379](https://github.com/frontman-ai/frontman/pull/379) [`68b7f53`](https://github.com/frontman-ai/frontman/commit/68b7f53d10c82fe5b462021cc2e866c0822fa0d8) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix source location detection for selected elements in Astro projects.
  - Refactor Astro integration from Astro middleware to Vite Connect middleware for more reliable request interception
  - Capture `data-astro-source-file`/`data-astro-source-loc` annotations on `DOMContentLoaded` before Astro's dev toolbar strips them
  - Add ancestor walk fallback (up to 20 levels) so clicking child elements resolves to the nearest annotated Astro component
  - Harden integration: `ensureConfig` guard for no-args usage, `duplex: 'half'` for POST requests, `headersSent` guard in error handler, skip duplicate capture on initial `astro:page-load`
  - Add LLM error chunk propagation so API rejections (e.g., oversized images) surface to the client instead of silently failing
  - Account for `devicePixelRatio` in screenshot scaling to avoid exceeding API dimension limits on hi-DPI displays

- [`99f8e90`](https://github.com/frontman-ai/frontman/commit/99f8e90e312cfb2d33a1392b0c0a241622583248) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix missing `host` param in Astro config that caused the client to crash on boot. Both Astro and Next.js configs now assert at construction time that `clientUrl` contains the required `host` query param, using the URL API for proper query-string handling.

#### @frontman/frontman-client


### Minor Changes

- [`99f8e90`](https://github.com/frontman-ai/frontman/commit/99f8e90e312cfb2d33a1392b0c0a241622583248) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add file and image attachment support in the chat input. Users can attach images and files via drag & drop, clipboard paste, or a file picker button. Pasted multi-line text (3+ lines or >150 chars) is collapsed into a chip. Attachments are sent as ACP resource content blocks with base64-encoded blob data and rendered as thumbnails in both the input area and message history with a lightbox preview.

- [`99f8e90`](https://github.com/frontman-ai/frontman/commit/99f8e90e312cfb2d33a1392b0c0a241622583248) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add cancel/stop generation support. Users can now stop an in-progress AI agent response by clicking a stop button in the prompt input. Implements the ACP `session/cancel` notification protocol for clean cancellation across client, protocol, and server layers.

### Patch Changes

- [#336](https://github.com/frontman-ai/frontman/pull/336) [`b98bc4f`](https://github.com/frontman-ai/frontman/commit/b98bc4f2b2369dd6bc448f883b1a7dce3476b5ae) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Suppress Sentry error reporting during Frontman internal development via FRONTMAN_INTERNAL_DEV env var

#### @frontman/frontman-core


### Patch Changes

- Updated dependencies [[`99f8e90`](https://github.com/frontman-ai/frontman/commit/99f8e90e312cfb2d33a1392b0c0a241622583248)]:
  - @frontman/frontman-protocol@0.2.0

#### @frontman-ai/nextjs


### Minor Changes

- Thanks [@itayadler](https://github.com/itayadler)! - Add AI-powered auto-edit for existing files during `npx @frontman-ai/nextjs install` and colorized CLI output with brand purple theme.
  - When existing middleware/proxy/instrumentation files are detected, the installer now offers to automatically merge Frontman using an LLM (OpenCode Zen, free, no API key)
  - Model fallback chain (gpt-5-nano → big-pickle → grok-code) with output validation
  - Privacy disclosure: users are informed before file contents are sent to a public LLM
  - Colorized terminal output: purple banner, green checkmarks, yellow warnings, structured manual instructions
  - Fixed duplicate manual instructions in partial-success output

### Patch Changes

- Thanks [@itayadler](https://github.com/itayadler)! - Move installer to npx-only, remove curl|bash endpoint, make --server optional
  - Remove API server install endpoint (InstallController + /install routes)
  - Make `--server` optional with default `api.frontman.sh`
  - Simplify Readline.res: remove /dev/tty hacks, just use process.stdin
  - Add `config.matcher` to proxy.ts template and auto-edit LLM rules
  - Update marketing site install command from curl to `npx @frontman-ai/nextjs install`
  - Update README install instructions

- [#336](https://github.com/frontman-ai/frontman/pull/336) [`b98bc4f`](https://github.com/frontman-ai/frontman/commit/b98bc4f2b2369dd6bc448f883b1a7dce3476b5ae) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Suppress Sentry error reporting during Frontman internal development via FRONTMAN_INTERNAL_DEV env var

- [`99f8e90`](https://github.com/frontman-ai/frontman/commit/99f8e90e312cfb2d33a1392b0c0a241622583248) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix missing `host` param in Astro config that caused the client to crash on boot. Both Astro and Next.js configs now assert at construction time that `clientUrl` contains the required `host` query param, using the URL API for proper query-string handling.

#### @frontman/frontman-protocol


### Minor Changes

- [`99f8e90`](https://github.com/frontman-ai/frontman/commit/99f8e90e312cfb2d33a1392b0c0a241622583248) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add protocol versioning, JSON Schema export, and cross-language contract tests. Protocol types are now the single source of truth, with schemas auto-generated from Sury types and validated in both ReScript and Elixir. Includes CI checks for schema drift and breaking changes.

#### @frontman-ai/vite


### Minor Changes

- Thanks [@itayadler](https://github.com/itayadler)! - Add `@frontman-ai/vite` package — a ReScript-first Vite integration with CLI installer (`npx @frontman-ai/vite install`), replacing the old broken `@frontman/vite-plugin`.
  - Vite plugin with `configureServer` hook and Node.js ↔ Web API adapter for SSE streaming
  - Web API middleware serving Frontman UI, tool endpoints, and source location resolution
  - Config with automatic `isDev` inference from host (production = `api.frontman.sh`, everything else = dev)
  - CLI installer: auto-detects package manager, analyzes existing vite config, injects `frontmanPlugin()` call
  - Process shim for production client bundle (Vite doesn't polyfill Node.js globals in browser)

## [0.3.0] - 2025-06-01

### Added
- Logs library (`@frontman/logs`) with pluggable handlers and log-level filtering
- Console log handler with colored output and component tagging
- Functor-based logger creation per component

### Changed
- Standardized package structure across all libraries with Makefiles

## [0.2.0] - 2025-03-15

### Added
- State management architecture with reducer, effects, and selectors
- Chat widget core with streaming message support
- Storybook integration for component development
- ReScript Vitest testing setup across all packages

### Fixed
- Floating blob visibility in install section

## [0.1.0] - 2025-01-15

### Added
- Initial release of Frontman
- Core chat widget functionality
- Marketing site with Astro
- Monorepo setup with yarn workspaces
- ReScript 12 toolchain integration
