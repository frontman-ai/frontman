# @frontman-ai/client

## 0.6.0

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

## 0.5.1

### Patch Changes

- [#437](https://github.com/frontman-ai/frontman/pull/437) [`bc43aec`](https://github.com/frontman-ai/frontman/commit/bc43aeca56832fe7793d6c38f8dc68a92a4aa161) Thanks [@itayadler](https://github.com/itayadler)! - Fix chatbox rendering jank during streaming by adding React.memo to leaf components, buffering text deltas with requestAnimationFrame, removing unnecessary CSS transitions, and switching scroll resize mode to instant.

## 0.5.0

### Minor Changes

- [#426](https://github.com/frontman-ai/frontman/pull/426) [`1b6ecec`](https://github.com/frontman-ai/frontman/commit/1b6ecec8256a2630a71ef3b8d7b3d60c34c16f9a) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - URL-addressable preview: persist iframe URL in browser address bar using suffix-based routing. Navigation within the preview iframe is now reflected in the browser URL, enabling shareable deep links and browser back/forward support.

## 0.4.0

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

## 0.3.0

### Minor Changes

- [#391](https://github.com/frontman-ai/frontman/pull/391) [`9bcc19a`](https://github.com/frontman-ai/frontman/commit/9bcc19ab3681673f1e63451c6b7d3c25007af130) Thanks [@itayadler](https://github.com/itayadler)! - Add Heap Analytics integration with automatic user identification. Heap is initialized in the client bundle with environment-aware env IDs (dev vs production). When a user session connects, the client fetches the user profile and calls `heap.identify()` and `heap.addUserProperties()` with the user's ID, email, and name. The server's `/api/user/me` endpoint now returns `id` and `name` in addition to `email`, and the user profile is stored in global state for reuse across components.

- [#368](https://github.com/frontman-ai/frontman/pull/368) [`ef6f38d`](https://github.com/frontman-ai/frontman/commit/ef6f38dc0ec0de5a98bca31dad576ee9e14ed0e8) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add device mode / viewport emulation to the web preview. Developers can now simulate specific device viewports (phones, tablets, desktop) with 12 built-in presets, custom dimensions, and orientation toggle. The preview iframe auto-scales to fit the available space with a checkerboard background. Device mode state is per-task, so switching tasks restores that task's viewport. A new `set_device_mode` MCP tool allows the AI agent to programmatically change viewports with actions for presets, custom sizes, responsive mode, orientation, and listing available devices.

### Patch Changes

- [#394](https://github.com/frontman-ai/frontman/pull/394) [`40abf99`](https://github.com/frontman-ai/frontman/commit/40abf99f81731557d57f44288de98af50220660c) Thanks [@itayadler](https://github.com/itayadler)! - Fix web preview URL bar syncing so iframe link navigations update the displayed URL without forcing iframe reloads. The URL input is now editable and supports Enter-to-navigate while preserving in-iframe navigation state.

## 0.2.1

### Patch Changes

- [#384](https://github.com/frontman-ai/frontman/pull/384) [`59ee255`](https://github.com/frontman-ai/frontman/commit/59ee25581b2252636fb7cacb5cec118a38c00ced) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - fix(astro): load client from production CDN instead of localhost

  The Astro integration defaulted `clientUrl` to `http://localhost:5173/src/Main.res.mjs` unconditionally, which only works during local frontman development. When installed from npm, users saw requests to localhost:5173 instead of the production client.

  Now infers `isDev` from the host (matching the Vite plugin pattern): production host loads the client from `https://app.frontman.sh/frontman.es.js` with CSS from `https://app.frontman.sh/frontman.css`.

  Also fixes the standalone client bundle crashing with `process is not defined` in browsers by replacing `process.env.NODE_ENV` at build time (Vite lib mode doesn't do this automatically).

## 0.2.0

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
