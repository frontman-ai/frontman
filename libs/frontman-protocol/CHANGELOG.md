# @frontman-ai/frontman-protocol

## 0.6.0

### Minor Changes

- [#796](https://github.com/frontman-ai/frontman/pull/796) [`9ef1ae0`](https://github.com/frontman-ai/frontman/commit/9ef1ae0f5d284d916c8963e5d5edf14ca19d291e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add get_astro_audit browser tool that reads Astro dev toolbar accessibility and performance audit results

### Patch Changes

- [#762](https://github.com/frontman-ai/frontman/pull/762) [`e963100`](https://github.com/frontman-ai/frontman/commit/e963100f6fef33839cddc16c1a9bab850519c248) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Improve error UX: human-readable categorized errors, automatic retry with exponential backoff for transient failures, live countdown during retry, and manual retry button.

## 0.5.0

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

## 0.4.1

### Patch Changes

- [#461](https://github.com/frontman-ai/frontman/pull/461) [`746666e`](https://github.com/frontman-ai/frontman/commit/746666eec12531c56835a7e0e4da25efa136d927) Thanks [@itayadler](https://github.com/itayadler)! - Enforce pure bindings architecture: extract all business logic from `@frontman/bindings` to domain packages, delete dead code, rename Sentry modules, and fix circular dependency in frontman-protocol.

## 0.4.0

### Minor Changes

- Add list_tree, get_dom, and search_text to protocol tool name registry.

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
