# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
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

- [#335](https://github.com/frontman-ai/frontman/pull/335) [`389fff7`](https://github.com/frontman-ai/frontman/commit/389fff728ccbeaf6d73ca80497f1b8b4bd7c6c63) Thanks [@itayadler](https://github.com/itayadler)! - Add AI-powered auto-edit for existing files during `npx @frontman-ai/nextjs install` and colorized CLI output with brand purple theme.
  - When existing middleware/proxy/instrumentation files are detected, the installer now offers to automatically merge Frontman using an LLM (OpenCode Zen, free, no API key)
  - Model fallback chain (gpt-5-nano → big-pickle → grok-code) with output validation
  - Privacy disclosure: users are informed before file contents are sent to a public LLM
  - Colorized terminal output: purple banner, green checkmarks, yellow warnings, structured manual instructions
  - Fixed duplicate manual instructions in partial-success output

### Patch Changes

- [#337](https://github.com/frontman-ai/frontman/pull/337) [`7e4386f`](https://github.com/frontman-ai/frontman/commit/7e4386fc5fdeea349efa61de97ed119f99f9585a) Thanks [@itayadler](https://github.com/itayadler)! - Move installer to npx-only, remove curl|bash endpoint, make --server optional
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

- [#355](https://github.com/frontman-ai/frontman/pull/355) [`84b6d9b`](https://github.com/frontman-ai/frontman/commit/84b6d9bc68bc17cc5eec3b81f0b06b057d1826a9) Thanks [@itayadler](https://github.com/itayadler)! - Add `@frontman-ai/vite` package — a ReScript-first Vite integration with CLI installer (`npx @frontman-ai/vite install`), replacing the old broken `@frontman/vite-plugin`.
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
