# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
## [5.0.0] - 2026-09-04


#### @frontman/bindings


### Patch Changes

- [#1620](https://github.com/frontman-ai/frontman/pull/1620) [`17ca764`](https://github.com/frontman-ai/frontman/commit/17ca7644677ad2c96c4fb0d3d0c9bb8364b93551) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Use Node path.relative for relative path display and reject out-of-root search paths instead of falling back to the source root.

#### @frontman-ai/client


### Minor Changes

- [#1496](https://github.com/frontman-ai/frontman/pull/1496) [`f5f2b9b`](https://github.com/frontman-ai/frontman/commit/f5f2b9b5f4c21a28283663fb009d637b1c8970e8) Thanks [@kevin-ho](https://github.com/kevin-ho)! - Add Custom Providers to Settings so users can configure per-user, publicly reachable OpenAI-compatible providers. Providers save their model IDs atomically, support optional API keys, reject stale updates, and appear as model-picker groups once configured. Outbound requests resolve and pin public destinations before connecting.

- [#1559](https://github.com/frontman-ai/frontman/pull/1559) [`d64a09c`](https://github.com/frontman-ai/frontman/commit/d64a09c81349e446ec73aed02e284998ef13db3f) Thanks [@uinstinct](https://github.com/uinstinct)! - Add an execute control to element annotations: Ctrl/Cmd+Enter or the send button sends the selected elements and comments through the chatbox flow.

- [#1538](https://github.com/frontman-ai/frontman/pull/1538) [`76efaeb`](https://github.com/frontman-ai/frontman/commit/76efaeb1bb90633cbeb6793c2b40e945f67ddcf6) Thanks [@uinstinct](https://github.com/uinstinct)! - Add the ability to remove a queued message before the agent picks it up. Each row in the queued-messages drawer now has a remove button, which deletes the pending message server-side.

### Patch Changes

- [#1564](https://github.com/frontman-ai/frontman/pull/1564) [`2424a52`](https://github.com/frontman-ai/frontman/commit/2424a52d1a60773292605d85df9e1c7ff4048c36) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Require every final agent response to include a concise TL;DR covering outcomes and relevant next steps.

- [#1598](https://github.com/frontman-ai/frontman/pull/1598) [`1516deb`](https://github.com/frontman-ai/frontman/commit/1516deb61a02186d52f072d2c8a435618f916dfb) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Show the five most recent tasks in the empty chat starter so users can resume previous work.

- [#1589](https://github.com/frontman-ai/frontman/pull/1589) [`373d94e`](https://github.com/frontman-ai/frontman/commit/373d94e1575d7c99368f7ac8dfa0086dfab1f7f8) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Make the embedded Frontman approval popup clearer for non-technical users by explaining why it appears, what access is granted, and when to allow it.

- [#1589](https://github.com/frontman-ai/frontman/pull/1589) [`373d94e`](https://github.com/frontman-ai/frontman/commit/373d94e1575d7c99368f7ac8dfa0086dfab1f7f8) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Complete embedded bearer-token authentication for client sockets, remove the legacy socket-token path, and disable credentialed API CORS.

- [#1573](https://github.com/frontman-ai/frontman/pull/1573) [`0e7830c`](https://github.com/frontman-ai/frontman/commit/0e7830c482032ba57501865b3af476535cfafef7) Thanks [@uinstinct](https://github.com/uinstinct)! - Pressing Escape while the element inspector is active now closes the open comment popup, then clears all selected elements, and finally exits selection mode when nothing is selected.

- [#1589](https://github.com/frontman-ai/frontman/pull/1589) [`373d94e`](https://github.com/frontman-ai/frontman/commit/373d94e1575d7c99368f7ac8dfa0086dfab1f7f8) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Prevent the app from crashing when an existing loaded task was created before completed file-change snapshots were added.

- [#1562](https://github.com/frontman-ai/frontman/pull/1562) [`35726d0`](https://github.com/frontman-ai/frontman/commit/35726d07f7ee2e540e2a2d489d8734cf69ff2928) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Keep task channels alive when MCP tools return audio, resource links, or embedded resources by reporting unsupported content as tool errors.

- [#1561](https://github.com/frontman-ai/frontman/pull/1561) [`e0fc341`](https://github.com/frontman-ai/frontman/commit/e0fc34139a40b21235547932c36618fddcf60528) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Reject MCP catalogs containing duplicate tool names before publishing any discovered tools.

- [#1566](https://github.com/frontman-ai/frontman/pull/1566) [`efb4fbf`](https://github.com/frontman-ai/frontman/commit/efb4fbf27f6485c8ed0321ab8f794ed38e108df3) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Remove unused ACP, MCP, and relay progress observers so diagnostic callbacks cannot interrupt protocol delivery.

- [#1556](https://github.com/frontman-ai/frontman/pull/1556) [`45b62c4`](https://github.com/frontman-ai/frontman/commit/45b62c48e31d7c5bda9852120ea56313bc5d0bc4) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Prevent message submission until a model is selected.

- [#1594](https://github.com/frontman-ai/frontman/pull/1594) [`033e90f`](https://github.com/frontman-ai/frontman/commit/033e90f1f36a223ba66cb9413f85feb6c91e939d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Track first-task feedback dialog impressions, closes, share clicks, and Discord clicks in Heap.

- [#1599](https://github.com/frontman-ai/frontman/pull/1599) [`991732d`](https://github.com/frontman-ai/frontman/commit/991732da8d93384e186759bbff9524d1c173c8f9) Thanks [@dependabot](https://github.com/apps/dependabot)! - Update Tiptap core to 3.30.4.

#### @frontman-ai/astro


### Major Changes

- [#1590](https://github.com/frontman-ai/frontman/pull/1590) [`77fb937`](https://github.com/frontman-ai/frontman/commit/77fb937a7630553e4cdbd5de2635b74435be20b8) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Preserve official MCP tool, content annotation, and implementation metadata through relay boundaries. Relay tools now require protocol version 2.0 and the MCP `_meta["ai.frontman/tool-metadata"]` shape instead of legacy top-level metadata fields.

### Minor Changes

- [#1617](https://github.com/frontman-ai/frontman/pull/1617) [`5782bd7`](https://github.com/frontman-ai/frontman/commit/5782bd77a59f105ffd34bb3093a1f64d8b8e5c38) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Enrich `get_client_pages` with Astro route pathname, segments, redirect metadata, fallback routes, and serialized route regex details.

### Patch Changes

- [#1601](https://github.com/frontman-ai/frontman/pull/1601) [`b447a4a`](https://github.com/frontman-ai/frontman/commit/b447a4ad2cb8aedb3c62e2f7a8df803eba7b5ee7) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add `get_resolved_astro_config` so Astro agents can inspect sanitized resolved config before routing, rendering, adapter, i18n, image, Markdown, redirect, session, security, or deployment changes.

#### @frontman-ai/frontman-client


### Major Changes

- [#1590](https://github.com/frontman-ai/frontman/pull/1590) [`77fb937`](https://github.com/frontman-ai/frontman/commit/77fb937a7630553e4cdbd5de2635b74435be20b8) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Preserve official MCP tool, content annotation, and implementation metadata through relay boundaries. Relay tools now require protocol version 2.0 and the MCP `_meta["ai.frontman/tool-metadata"]` shape instead of legacy top-level metadata fields.

### Patch Changes

- [#1622](https://github.com/frontman-ai/frontman/pull/1622) [`0bc42d9`](https://github.com/frontman-ai/frontman/commit/0bc42d9ce3a0cfd8d29e0bcbd758f7bf53a35ec8) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Handle ACP Phoenix push replies and clean up failed initialize connections after request timeouts.

- [#1589](https://github.com/frontman-ai/frontman/pull/1589) [`373d94e`](https://github.com/frontman-ai/frontman/commit/373d94e1575d7c99368f7ac8dfa0086dfab1f7f8) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Complete embedded bearer-token authentication for client sockets, remove the legacy socket-token path, and disable credentialed API CORS.

- [#1619](https://github.com/frontman-ai/frontman/pull/1619) [`e2cd5a0`](https://github.com/frontman-ai/frontman/commit/e2cd5a0099cdfbc8dd7f1d43bb29ff2cdf72c2f7) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Reject ACP client requests after a timeout instead of leaving the UI stuck when the server never responds.

- [#1566](https://github.com/frontman-ai/frontman/pull/1566) [`efb4fbf`](https://github.com/frontman-ai/frontman/commit/efb4fbf27f6485c8ed0321ab8f794ed38e108df3) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Remove unused ACP, MCP, and relay progress observers so diagnostic callbacks cannot interrupt protocol delivery.

- [#1557](https://github.com/frontman-ai/frontman/pull/1557) [`0c813c5`](https://github.com/frontman-ai/frontman/commit/0c813c5ee7fd90be929eb81a44dba7b9254761e9) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Preserve integral JSON-RPC numeric IDs above signed 32-bit range.

#### @frontman-ai/frontman-core


### Major Changes

- [#1590](https://github.com/frontman-ai/frontman/pull/1590) [`77fb937`](https://github.com/frontman-ai/frontman/commit/77fb937a7630553e4cdbd5de2635b74435be20b8) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Preserve official MCP tool, content annotation, and implementation metadata through relay boundaries. Relay tools now require protocol version 2.0 and the MCP `_meta["ai.frontman/tool-metadata"]` shape instead of legacy top-level metadata fields.

### Patch Changes

- [#1621](https://github.com/frontman-ai/frontman/pull/1621) [`361d5c9`](https://github.com/frontman-ai/frontman/commit/361d5c9e45e9f3c1c0039290d1e37ff23740b18b) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Keep path recovery scoped when source roots are relative.

- [#1620](https://github.com/frontman-ai/frontman/pull/1620) [`17ca764`](https://github.com/frontman-ai/frontman/commit/17ca7644677ad2c96c4fb0d3d0c9bb8364b93551) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Use Node path.relative for relative path display and reject out-of-root search paths instead of falling back to the source root.

- [#1566](https://github.com/frontman-ai/frontman/pull/1566) [`efb4fbf`](https://github.com/frontman-ai/frontman/commit/efb4fbf27f6485c8ed0321ab8f794ed38e108df3) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Remove unused ACP, MCP, and relay progress observers so diagnostic callbacks cannot interrupt protocol delivery.

- Updated dependencies [[`77fb937`](https://github.com/frontman-ai/frontman/commit/77fb937a7630553e4cdbd5de2635b74435be20b8), [`17ca764`](https://github.com/frontman-ai/frontman/commit/17ca7644677ad2c96c4fb0d3d0c9bb8364b93551), [`efb4fbf`](https://github.com/frontman-ai/frontman/commit/efb4fbf27f6485c8ed0321ab8f794ed38e108df3), [`0c813c5`](https://github.com/frontman-ai/frontman/commit/0c813c5ee7fd90be929eb81a44dba7b9254761e9)]:
  - @frontman-ai/frontman-protocol@4.0.0
  - @frontman/bindings@0.3.2

#### @frontman-ai/nextjs


### Major Changes

- [#1590](https://github.com/frontman-ai/frontman/pull/1590) [`77fb937`](https://github.com/frontman-ai/frontman/commit/77fb937a7630553e4cdbd5de2635b74435be20b8) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Preserve official MCP tool, content annotation, and implementation metadata through relay boundaries. Relay tools now require protocol version 2.0 and the MCP `_meta["ai.frontman/tool-metadata"]` shape instead of legacy top-level metadata fields.

### Minor Changes

- [#1496](https://github.com/frontman-ai/frontman/pull/1496) [`f5f2b9b`](https://github.com/frontman-ai/frontman/commit/f5f2b9b5f4c21a28283663fb009d637b1c8970e8) Thanks [@kevin-ho](https://github.com/kevin-ho)! - Add Custom Providers to Settings so users can configure per-user, publicly reachable OpenAI-compatible providers. Providers save their model IDs atomically, support optional API keys, reject stale updates, and appear as model-picker groups once configured. Outbound requests resolve and pin public destinations before connecting.

### Patch Changes

- [#1572](https://github.com/frontman-ai/frontman/pull/1572) [`45c9872`](https://github.com/frontman-ai/frontman/commit/45c9872e4f11c0eb06380176c3a2e8cc3539e3de) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fail closed for Next.js Frontman routes outside development unless explicitly enabled with `FRONTMAN_ENABLE_IN_PRODUCTION=1` or `FRONTMAN_ENABLED=1`.

- [#1574](https://github.com/frontman-ai/frontman/pull/1574) [`7a2776a`](https://github.com/frontman-ai/frontman/commit/7a2776ab9d556a7cccf37ad7c30ccd59112f86b6) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix generated instrumentation type resolution during Next.js production builds and add a CI compatibility matrix for packed Next.js consumers.

#### @frontman-ai/frontman-preview-bridge


### Patch Changes

- Updated dependencies [[`77fb937`](https://github.com/frontman-ai/frontman/commit/77fb937a7630553e4cdbd5de2635b74435be20b8), [`17ca764`](https://github.com/frontman-ai/frontman/commit/17ca7644677ad2c96c4fb0d3d0c9bb8364b93551), [`efb4fbf`](https://github.com/frontman-ai/frontman/commit/efb4fbf27f6485c8ed0321ab8f794ed38e108df3), [`0c813c5`](https://github.com/frontman-ai/frontman/commit/0c813c5ee7fd90be929eb81a44dba7b9254761e9)]:
  - @frontman-ai/frontman-protocol@4.0.0
  - @frontman/bindings@0.3.2

#### @frontman-ai/frontman-protocol


### Major Changes

- [#1590](https://github.com/frontman-ai/frontman/pull/1590) [`77fb937`](https://github.com/frontman-ai/frontman/commit/77fb937a7630553e4cdbd5de2635b74435be20b8) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Preserve official MCP tool, content annotation, and implementation metadata through relay boundaries. Relay tools now require protocol version 2.0 and the MCP `_meta["ai.frontman/tool-metadata"]` shape instead of legacy top-level metadata fields.

### Patch Changes

- [#1566](https://github.com/frontman-ai/frontman/pull/1566) [`efb4fbf`](https://github.com/frontman-ai/frontman/commit/efb4fbf27f6485c8ed0321ab8f794ed38e108df3) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Remove unused ACP, MCP, and relay progress observers so diagnostic callbacks cannot interrupt protocol delivery.

- [#1557](https://github.com/frontman-ai/frontman/pull/1557) [`0c813c5`](https://github.com/frontman-ai/frontman/commit/0c813c5ee7fd90be929eb81a44dba7b9254761e9) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Preserve integral JSON-RPC numeric IDs above signed 32-bit range.

#### @frontman-ai/vite


### Major Changes

- [#1590](https://github.com/frontman-ai/frontman/pull/1590) [`77fb937`](https://github.com/frontman-ai/frontman/commit/77fb937a7630553e4cdbd5de2635b74435be20b8) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Preserve official MCP tool, content annotation, and implementation metadata through relay boundaries. Relay tools now require protocol version 2.0 and the MCP `_meta["ai.frontman/tool-metadata"]` shape instead of legacy top-level metadata fields.

## [Unreleased]

### Added

- Add an `agent_feedback` backend tool that lets agents send Frontman product feedback and feature requests to Discord.

### Fixed

- Fix hosted Google/GitHub sign-in redirects after the WorkOS v3 SDK upgrade and add automatic OAuth-start smoke coverage.
- Replace generic HTML error pages with support guidance that links to `support@frontman.sh` and Discord.

## [4.0.0] - 2026-08-27


#### @frontman-ai/client


### Minor Changes

- [#1439](https://github.com/frontman-ai/frontman/pull/1439) [`c73f19f`](https://github.com/frontman-ai/frontman/commit/c73f19fcff40aa7bf28a4af72ca956d30e9cf360) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add an animated border beam to the idle chat composer.

- [#1483](https://github.com/frontman-ai/frontman/pull/1483) [`e79958f`](https://github.com/frontman-ai/frontman/commit/e79958f170f89917cac72007a2bdf407ffc83fe1) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Establish the typed Reworker parent runtime for preview iframes.

- [#1522](https://github.com/frontman-ai/frontman/pull/1522) [`19d0059`](https://github.com/frontman-ai/frontman/commit/19d005992bdcd9215c5a086e1c51ead8d4fae786) Thanks [@uinstinct](https://github.com/uinstinct)! - Click an annotation chip in a sent user message to highlight and scroll to that element in the web preview. Click the chip again to clear the highlight.

- [#1479](https://github.com/frontman-ai/frontman/pull/1479) [`434bbf1`](https://github.com/frontman-ai/frontman/commit/434bbf1b3c0aa10eeffd33848a603e4fa952cefb) Thanks [@uinstinct](https://github.com/uinstinct)! - Add a Changes view that shows file edits made during a conversation as diffs. File-editing tools now emit file change events over a new file change protocol message, and the client renders them with `@pierre/diffs`.

- [#1432](https://github.com/frontman-ai/frontman/pull/1432) [`b3c6bb1`](https://github.com/frontman-ai/frontman/commit/b3c6bb1c7a60d3e142449b69976827250889cb3b) Thanks [@uinstinct](https://github.com/uinstinct)! - Add an "Execute plan" button after the planner agent finishes, which hands the plan off to the executor agent in the same conversation.

- [#1498](https://github.com/frontman-ai/frontman/pull/1498) [`d9a58c6`](https://github.com/frontman-ai/frontman/commit/d9a58c653487dd9132c8ff16958f2356c6a6044f) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Require `_meta["frontman.dev/messageId"]` on `session/prompt` requests and use it as the canonical persisted user-message UUID for live updates and history replay. Missing, malformed, and duplicate IDs now return invalid params; older clients that omit this metadata are incompatible.

### Patch Changes

- [#1507](https://github.com/frontman-ai/frontman/pull/1507) [`34022ed`](https://github.com/frontman-ai/frontman/commit/34022ed99de9284132e97c8729ffabe71a2307e0) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Improve screenshot compatibility and return actionable guidance when browser image decoding fails.

- [#1484](https://github.com/frontman-ai/frontman/pull/1484) [`aa8e5bb`](https://github.com/frontman-ai/frontman/commit/aa8e5bb830d2443508d69ab4bc4b696f46a75a5d) Thanks [@uinstinct](https://github.com/uinstinct)! - Focus the prompt editor after starting a new task.

- [#1526](https://github.com/frontman-ai/frontman/pull/1526) [`5a0c81a`](https://github.com/frontman-ai/frontman/commit/5a0c81abdf9025bd90f8d2fa2ea99216021b1620) Thanks [@uinstinct](https://github.com/uinstinct)! - Show three starter task suggestions in an empty conversation. Clicking one sends it as a message.

- [#1461](https://github.com/frontman-ai/frontman/pull/1461) [`143ece0`](https://github.com/frontman-ai/frontman/commit/143ece0b957d3045878908a6bddcc10476fe1904) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Stop creating a todo after every WordPress recommendation while continuing to require inspected evidence for state-dependent guidance.

- [#1485](https://github.com/frontman-ai/frontman/pull/1485) [`3297b58`](https://github.com/frontman-ai/frontman/commit/3297b58d81cc74f6f92e567dc8b0a8f6c29188e0) Thanks [@uinstinct](https://github.com/uinstinct)! - Keep failed exploration tool calls inside their group and show the failure count in the group summary.

- [#1529](https://github.com/frontman-ai/frontman/pull/1529) [`1e72d46`](https://github.com/frontman-ai/frontman/commit/1e72d46673ce19378050de0a7dff5fb97a688c41) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Celebrate a user's first completed task with framework-specific rating and sharing actions.

- [#1505](https://github.com/frontman-ai/frontman/pull/1505) [`f4dcc2b`](https://github.com/frontman-ai/frontman/commit/f4dcc2b5d8734d3107977312f1046cfc0ddf7874) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Restore backend tool calls when loading existing task history.

- [#1499](https://github.com/frontman-ai/frontman/pull/1499) [`02dc31a`](https://github.com/frontman-ai/frontman/commit/02dc31a9b84aab1c74ae7f84b96c80d3c13315bc) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Restore NVIDIA model execution through NVIDIA NIM and guard every advertised model with executable provider coverage.

- [#1506](https://github.com/frontman-ai/frontman/pull/1506) [`f8dac8e`](https://github.com/frontman-ai/frontman/commit/f8dac8e8fcf91a229824183786a1e7a02c094f4a) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Complete todo tool cards without breaking reconnecting sessions, restore the current todo plan when reopening a task, and hide the plan after every item is complete.

- [#1536](https://github.com/frontman-ai/frontman/pull/1536) [`8cc17d5`](https://github.com/frontman-ai/frontman/commit/8cc17d55a17aa53b7c15d09a3a542022006d145a) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Keep queued messages with different models in separate agent turns.

- [#1504](https://github.com/frontman-ai/frontman/pull/1504) [`5b5f180`](https://github.com/frontman-ai/frontman/commit/5b5f1805e491e8803bc6c6f7da961c29c2cf6d9e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Show submitted messages in the queued-message drawer while awaiting server acceptance.

- [#1494](https://github.com/frontman-ai/frontman/pull/1494) [`84959cb`](https://github.com/frontman-ai/frontman/commit/84959cb57e446ee684bc8ac5ba447959597eee7f) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Centralize browser URL synchronization and simplify iframe lifecycle handling.

- [#1477](https://github.com/frontman-ai/frontman/pull/1477) [`ab663ad`](https://github.com/frontman-ai/frontman/commit/ab663adb2e580e84c4732ca3c36fce9e9919c1c9) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Derive provider setup from ACP model availability and resolve each selected model once before request preflight and streaming.

- [#1539](https://github.com/frontman-ai/frontman/pull/1539) [`817c623`](https://github.com/frontman-ai/frontman/commit/817c623bdcafc20c15bc25ea29070565064fd0ed) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Prevent concurrent connections from owning the same task channel.

- [#1517](https://github.com/frontman-ai/frontman/pull/1517) [`cff8e50`](https://github.com/frontman-ai/frontman/commit/cff8e503b702f2c7b7f47a1fe31ece84a1b9750b) Thanks [@dependabot](https://github.com/apps/dependabot)! - Update diff to version 9.

#### @rescript/webapi


### Patch Changes

- [#1482](https://github.com/frontman-ai/frontman/pull/1482) [`62e1cd5`](https://github.com/frontman-ai/frontman/commit/62e1cd5ca9647ef420006254e647988d0d904468) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Pin the vendored WebAPI bindings to the newest upstream revision compatible with ReScript 12 and add the typed DOM operations required by Frontman.

#### @frontman-ai/astro


### Patch Changes

- [#1482](https://github.com/frontman-ai/frontman/pull/1482) [`62e1cd5`](https://github.com/frontman-ai/frontman/commit/62e1cd5ca9647ef420006254e647988d0d904468) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Pin the vendored WebAPI bindings to the newest upstream revision compatible with ReScript 12 and add the typed DOM operations required by Frontman.

#### @frontman-ai/frontman-client


### Major Changes

- [#1490](https://github.com/frontman-ai/frontman/pull/1490) [`0b65076`](https://github.com/frontman-ai/frontman/commit/0b650768e35f354950ebb991c11985cfcd04f7e3) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Migrate browser MCP discovery, tool listing, and tool calls to MCP 2026-07-28.

### Patch Changes

- [#1491](https://github.com/frontman-ai/frontman/pull/1491) [`65b195a`](https://github.com/frontman-ai/frontman/commit/65b195ac0ee61f89a16b99bd59c762f3e3227238) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Keep malformed tool arguments out of diagnostic reports while retaining safe tool failure context.

#### @frontman-ai/frontman-core


### Minor Changes

- [#1479](https://github.com/frontman-ai/frontman/pull/1479) [`434bbf1`](https://github.com/frontman-ai/frontman/commit/434bbf1b3c0aa10eeffd33848a603e4fa952cefb) Thanks [@uinstinct](https://github.com/uinstinct)! - Add a Changes view that shows file edits made during a conversation as diffs. File-editing tools now emit file change events over a new file change protocol message, and the client renders them with `@pierre/diffs`.

### Patch Changes

- [#1280](https://github.com/frontman-ai/frontman/pull/1280) [`7ba266e`](https://github.com/frontman-ai/frontman/commit/7ba266e997996c549c132022aebba7371cca69c3) Thanks [@ntheanh201](https://github.com/ntheanh201)! - Cap `read_file` requests at 1,000 lines.

- Updated dependencies [[`434bbf1`](https://github.com/frontman-ai/frontman/commit/434bbf1b3c0aa10eeffd33848a603e4fa952cefb), [`df5cd88`](https://github.com/frontman-ai/frontman/commit/df5cd88060cefeaebb95e1e3d6b2edc4b432117f), [`0b65076`](https://github.com/frontman-ai/frontman/commit/0b650768e35f354950ebb991c11985cfcd04f7e3)]:
  - @frontman-ai/frontman-protocol@3.0.0

#### @frontman-ai/nextjs


### Patch Changes

- [#1503](https://github.com/frontman-ai/frontman/pull/1503) [`ec2afdb`](https://github.com/frontman-ai/frontman/commit/ec2afdb9f2e7e1bf89d716e9f30d5caa31c5d760) Thanks [@mikemikimike](https://github.com/mikemikimike)! - Fail installation when dependencies cannot be installed or resolved.

- [#1482](https://github.com/frontman-ai/frontman/pull/1482) [`62e1cd5`](https://github.com/frontman-ai/frontman/commit/62e1cd5ca9647ef420006254e647988d0d904468) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Pin the vendored WebAPI bindings to the newest upstream revision compatible with ReScript 12 and add the typed DOM operations required by Frontman.

- [#1530](https://github.com/frontman-ai/frontman/pull/1530) [`bc0ef3c`](https://github.com/frontman-ai/frontman/commit/bc0ef3ccffc617bc3b5992f89351ab397a46c8f4) Thanks [@uinstinct](https://github.com/uinstinct)! - Reject Next.js versions below 15.5 before installing dependencies or generating middleware, and align peer dependency metadata and documentation with that support range.

- [#1515](https://github.com/frontman-ai/frontman/pull/1515) [`9d6c858`](https://github.com/frontman-ai/frontman/commit/9d6c858d6aebc96a4d62b8358619292aa9bfa591) Thanks [@dependabot](https://github.com/apps/dependabot)! - Raise the minimum React peer version to 19.2.8 alongside React DOM.

#### @frontman-ai/frontman-preview-bridge


### Minor Changes

- [#1478](https://github.com/frontman-ai/frontman/pull/1478) [`15887fb`](https://github.com/frontman-ai/frontman/commit/15887fb252312bdb77e6c386a98db5e2adfc8b4d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Establish the capsule-ready Reworker child runtime and classic preview bridge bundle.

### Patch Changes

- Updated dependencies [[`434bbf1`](https://github.com/frontman-ai/frontman/commit/434bbf1b3c0aa10eeffd33848a603e4fa952cefb), [`df5cd88`](https://github.com/frontman-ai/frontman/commit/df5cd88060cefeaebb95e1e3d6b2edc4b432117f), [`0b65076`](https://github.com/frontman-ai/frontman/commit/0b650768e35f354950ebb991c11985cfcd04f7e3)]:
  - @frontman-ai/frontman-protocol@3.0.0

#### @frontman-ai/frontman-protocol


### Major Changes

- [#1490](https://github.com/frontman-ai/frontman/pull/1490) [`0b65076`](https://github.com/frontman-ai/frontman/commit/0b650768e35f354950ebb991c11985cfcd04f7e3) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Migrate browser MCP discovery, tool listing, and tool calls to MCP 2026-07-28.

### Minor Changes

- [#1479](https://github.com/frontman-ai/frontman/pull/1479) [`434bbf1`](https://github.com/frontman-ai/frontman/commit/434bbf1b3c0aa10eeffd33848a603e4fa952cefb) Thanks [@uinstinct](https://github.com/uinstinct)! - Add a Changes view that shows file edits made during a conversation as diffs. File-editing tools now emit file change events over a new file change protocol message, and the client renders them with `@pierre/diffs`.

- [#1473](https://github.com/frontman-ai/frontman/pull/1473) [`df5cd88`](https://github.com/frontman-ai/frontman/commit/df5cd88060cefeaebb95e1e3d6b2edc4b432117f) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Establish lockstep Reworker preview protocol types and structured errors.

#### @frontman-ai/vite


### Patch Changes

- [#1482](https://github.com/frontman-ai/frontman/pull/1482) [`62e1cd5`](https://github.com/frontman-ai/frontman/commit/62e1cd5ca9647ef420006254e647988d0d904468) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Pin the vendored WebAPI bindings to the newest upstream revision compatible with ReScript 12 and add the typed DOM operations required by Frontman.

#### @frontman-ai/frontman-wordpress


### Patch Changes

- [#1472](https://github.com/frontman-ai/frontman/pull/1472) [`b79c611`](https://github.com/frontman-ai/frontman/commit/b79c611e32c07db04150e05bd7de0097e8140e5e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Stop exposing the administrator email through bulk WordPress option discovery while preserving explicit option reads.

- [#1490](https://github.com/frontman-ai/frontman/pull/1490) [`0b65076`](https://github.com/frontman-ai/frontman/commit/0b650768e35f354950ebb991c11985cfcd04f7e3) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Migrate browser MCP discovery, tool listing, and tool calls to MCP 2026-07-28.

#### @frontman-ai/react-statestore


### Patch Changes

- [#1515](https://github.com/frontman-ai/frontman/pull/1515) [`9d6c858`](https://github.com/frontman-ai/frontman/commit/9d6c858d6aebc96a4d62b8358619292aa9bfa591) Thanks [@dependabot](https://github.com/apps/dependabot)! - Raise the minimum React peer version to 19.2.8 alongside React DOM.

## [3.1.0] - 2026-08-18


#### @frontman-ai/client


### Patch Changes

- [#1415](https://github.com/frontman-ai/frontman/pull/1415) [`3ab55f5`](https://github.com/frontman-ai/frontman/commit/3ab55f5efc38b66f3ee380a9dae6e1580c63efa7) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Give annotated elements the same bounded DOM context as `get_dom`, including their parent and direct children, so agents can follow selectors instead of broadly searching source files. Keep `get_dom` shadow traversal compatible with navigable indexed `>>>` paths. Resolve Next.js React Server Component annotations through server-side source maps without issuing invalid browser requests for React's virtual source URLs, while preserving client-component source locations beneath server components.

- [#1416](https://github.com/frontman-ai/frontman/pull/1416) [`f8c6c52`](https://github.com/frontman-ai/frontman/commit/f8c6c52a79a148168e061db6f3aec36839519d80) Thanks [@uinstinct](https://github.com/uinstinct)! - Allow a second paste within five seconds to expand a pasted-text chip in place.

- [#1415](https://github.com/frontman-ai/frontman/pull/1415) [`3ab55f5`](https://github.com/frontman-ai/frontman/commit/3ab55f5efc38b66f3ee380a9dae6e1580c63efa7) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Prevent task failures from rendering duplicate error banners and reconnect cleanly after React Strict Mode lifecycle cleanup.

- [#1415](https://github.com/frontman-ai/frontman/pull/1415) [`3ab55f5`](https://github.com/frontman-ai/frontman/commit/3ab55f5efc38b66f3ee380a9dae6e1580c63efa7) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Stop reporting Astro DOM ancestors as component invocation callsites, attach React component props instead of selected host-element props when ownership matches, and preserve current-page context in task diagnostics.

- [#1402](https://github.com/frontman-ai/frontman/pull/1402) [`c30f33e`](https://github.com/frontman-ai/frontman/commit/c30f33ea32ecb3d50c4e8aef41c42c54a8274277) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Make Frontman work immediately on WordPress sites using Plain permalinks.

- [#1410](https://github.com/frontman-ai/frontman/pull/1410) [`f0868c4`](https://github.com/frontman-ai/frontman/commit/f0868c487e4f1d8cbf42d3b75c583921d657bbe4) Thanks [@uinstinct](https://github.com/uinstinct)! - Keep the thinking indicator visible for the whole AI turn, including while text is streaming.

- [#1436](https://github.com/frontman-ai/frontman/pull/1436) [`0224d40`](https://github.com/frontman-ai/frontman/commit/0224d40b3b6b61800553e6833ca90ea8f68b0096) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Align Tiptap packages on version 3.30.1 and upgrade the repository to Yarn 4.18.

- [#1409](https://github.com/frontman-ai/frontman/pull/1409) [`6732667`](https://github.com/frontman-ai/frontman/commit/673266773033f17eb9b6a7ad6929a753b18fdd75) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Use explicit new-tab sign-in and sign-out flows in top-level and embedded Frontman clients. Ensure WordPress installations receive the updated hosted client instead of a browser-cached bundle.

#### @rescript/webapi


### Patch Changes

- [#1415](https://github.com/frontman-ai/frontman/pull/1415) [`3ab55f5`](https://github.com/frontman-ai/frontman/commit/3ab55f5efc38b66f3ee380a9dae6e1580c63efa7) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Give annotated elements the same bounded DOM context as `get_dom`, including their parent and direct children, so agents can follow selectors instead of broadly searching source files. Keep `get_dom` shadow traversal compatible with navigable indexed `>>>` paths. Resolve Next.js React Server Component annotations through server-side source maps without issuing invalid browser requests for React's virtual source URLs, while preserving client-component source locations beneath server components.

#### @frontman-ai/astro


### Patch Changes

- [#1415](https://github.com/frontman-ai/frontman/pull/1415) [`3ab55f5`](https://github.com/frontman-ai/frontman/commit/3ab55f5efc38b66f3ee380a9dae6e1580c63efa7) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Give annotated elements the same bounded DOM context as `get_dom`, including their parent and direct children, so agents can follow selectors instead of broadly searching source files. Keep `get_dom` shadow traversal compatible with navigable indexed `>>>` paths. Resolve Next.js React Server Component annotations through server-side source maps without issuing invalid browser requests for React's virtual source URLs, while preserving client-component source locations beneath server components.

- [#1430](https://github.com/frontman-ai/frontman/pull/1430) [`2646d4c`](https://github.com/frontman-ai/frontman/commit/2646d4cb4c9aaae0973d597b6f0df81b33fce75c) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Load packaged ripgrep binaries at runtime so grep and file search work from bundled integrations.

#### @frontman-ai/frontman-core


### Patch Changes

- [#1415](https://github.com/frontman-ai/frontman/pull/1415) [`3ab55f5`](https://github.com/frontman-ai/frontman/commit/3ab55f5efc38b66f3ee380a9dae6e1580c63efa7) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Give annotated elements the same bounded DOM context as `get_dom`, including their parent and direct children, so agents can follow selectors instead of broadly searching source files. Keep `get_dom` shadow traversal compatible with navigable indexed `>>>` paths. Resolve Next.js React Server Component annotations through server-side source maps without issuing invalid browser requests for React's virtual source URLs, while preserving client-component source locations beneath server components.

#### @frontman-ai/nextjs


### Patch Changes

- [#1415](https://github.com/frontman-ai/frontman/pull/1415) [`3ab55f5`](https://github.com/frontman-ai/frontman/commit/3ab55f5efc38b66f3ee380a9dae6e1580c63efa7) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Give annotated elements the same bounded DOM context as `get_dom`, including their parent and direct children, so agents can follow selectors instead of broadly searching source files. Keep `get_dom` shadow traversal compatible with navigable indexed `>>>` paths. Resolve Next.js React Server Component annotations through server-side source maps without issuing invalid browser requests for React's virtual source URLs, while preserving client-component source locations beneath server components.

- [#1430](https://github.com/frontman-ai/frontman/pull/1430) [`2646d4c`](https://github.com/frontman-ai/frontman/commit/2646d4cb4c9aaae0973d597b6f0df81b33fce75c) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Load packaged ripgrep binaries at runtime so grep and file search work from bundled integrations.

#### @frontman-ai/vite


### Patch Changes

- [#1415](https://github.com/frontman-ai/frontman/pull/1415) [`3ab55f5`](https://github.com/frontman-ai/frontman/commit/3ab55f5efc38b66f3ee380a9dae6e1580c63efa7) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Give annotated elements the same bounded DOM context as `get_dom`, including their parent and direct children, so agents can follow selectors instead of broadly searching source files. Keep `get_dom` shadow traversal compatible with navigable indexed `>>>` paths. Resolve Next.js React Server Component annotations through server-side source maps without issuing invalid browser requests for React's virtual source URLs, while preserving client-component source locations beneath server components.

- [#1430](https://github.com/frontman-ai/frontman/pull/1430) [`2646d4c`](https://github.com/frontman-ai/frontman/commit/2646d4cb4c9aaae0973d597b6f0df81b33fce75c) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Load packaged ripgrep binaries at runtime so grep and file search work from bundled integrations.

#### @frontman-ai/frontman-wordpress


### Patch Changes

- [#1402](https://github.com/frontman-ai/frontman/pull/1402) [`c30f33e`](https://github.com/frontman-ai/frontman/commit/c30f33ea32ecb3d50c4e8aef41c42c54a8274277) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Make Frontman work immediately on WordPress sites using Plain permalinks.

- [#1409](https://github.com/frontman-ai/frontman/pull/1409) [`6732667`](https://github.com/frontman-ai/frontman/commit/673266773033f17eb9b6a7ad6929a753b18fdd75) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Use explicit new-tab sign-in and sign-out flows in top-level and embedded Frontman clients. Ensure WordPress installations receive the updated hosted client instead of a browser-cached bundle.

## [3.0.0] - 2026-08-11

### Added

- Structured tool results now stay intact from MCP calls through ACP, live UI updates, and restored session history.
- Frontman can display typed tool content, including text, images, audio, links, and resources.
- Review and restore WordPress Additional CSS revisions with theme-aware history, conflict checks, and clear before-and-after details.
- New TypeScript declarations improve autocomplete and type safety for Next.js package exports.

### Changed

- Output schemas now appear only for tools that return structured data, keeping tool contracts accurate.
- Next.js setup now installs middleware and proxy files correctly for both root and `src/` project layouts.
- The WordPress.org listing now explains setup requirements, compatibility, and a complete editing workflow before installation.
- **Breaking:** `@frontman-ai/frontman-protocol` and `@frontman-ai/frontman-client` now use structured tool-result contracts. Integrations that import `jsonResult` must migrate to `structuredResult` or `unstructuredResult`.

### Security

- Browser runtime configuration no longer includes unsupported provider keys or unused source paths. Stored tool results now strip metadata.
- Server dependency updates address denial-of-service, cross-site scripting, and SQL injection vulnerabilities.
- OAuth activation analytics exclude prompts and relay error details.

## [2.0.0] - 2026-07-20


#### @frontman-ai/client


### Patch Changes

- [#1292](https://github.com/frontman-ai/frontman/pull/1292) [`6097f0b`](https://github.com/frontman-ai/frontman/commit/6097f0be83ab3ff3a79f06306fd63fae21534481) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add Astro 7 support while preserving Astro 5 and 6 compatibility. Raise the minimum Node.js version to 22.19, support Sätteri and unified Markdown processors, restore source annotations under Astro's Rust compiler, harden component prop capture, honor Astro's trailing-slash policy, and keep preview URLs synchronized during client-side navigation.

#### @frontman-ai/astro


### Major Changes

- [#1292](https://github.com/frontman-ai/frontman/pull/1292) [`6097f0b`](https://github.com/frontman-ai/frontman/commit/6097f0be83ab3ff3a79f06306fd63fae21534481) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add Astro 7 support while preserving Astro 5 and 6 compatibility. Raise the minimum Node.js version to 22.19, support Sätteri and unified Markdown processors, restore source annotations under Astro's Rust compiler, harden component prop capture, honor Astro's trailing-slash policy, and keep preview URLs synchronized during client-side navigation.

### Patch Changes

- [#1305](https://github.com/frontman-ai/frontman/pull/1305) [`a5e12f0`](https://github.com/frontman-ai/frontman/commit/a5e12f035a3fe485661e82014d0dacf5d4f6a61c) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Explain required Frontman sign-in and AI provider setup in package guidance and installer completion output.

#### @frontman-ai/frontman-client


### Patch Changes

- [#1303](https://github.com/frontman-ai/frontman/pull/1303) [`1e04b55`](https://github.com/frontman-ai/frontman/commit/1e04b553677ed045415dde90b89cadd682860b2d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Recover when an agent requests a tool unavailable under its current access policy instead of crashing the task or leaving unresolved tool history.

#### @frontman-ai/nextjs


### Patch Changes

- [#1305](https://github.com/frontman-ai/frontman/pull/1305) [`a5e12f0`](https://github.com/frontman-ai/frontman/commit/a5e12f035a3fe485661e82014d0dacf5d4f6a61c) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Explain required Frontman sign-in and AI provider setup in package guidance and installer completion output.

#### @frontman-ai/vite


### Patch Changes

- [#1305](https://github.com/frontman-ai/frontman/pull/1305) [`a5e12f0`](https://github.com/frontman-ai/frontman/commit/a5e12f035a3fe485661e82014d0dacf5d4f6a61c) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Explain required Frontman sign-in and AI provider setup in package guidance and installer completion output.

#### @frontman-ai/frontman-wordpress


### Minor Changes

- [#1306](https://github.com/frontman-ai/frontman/pull/1306) [`84d9997`](https://github.com/frontman-ai/frontman/commit/84d9997834cdf0d77f42f744458e056b81602260) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add verified WordPress 7 support, including nested Gutenberg block paths, block-theme navigation tools, and WordPress 7.0.2 runtime coverage on PHP 7.4 and 8.4.

### Patch Changes

- [#1305](https://github.com/frontman-ai/frontman/pull/1305) [`a5e12f0`](https://github.com/frontman-ai/frontman/commit/a5e12f035a3fe485661e82014d0dacf5d4f6a61c) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Explain required Frontman sign-in and AI provider setup in package guidance and installer completion output.

## [1.4.0] - 2026-07-18


#### @frontman-ai/client


### Patch Changes

- [#1287](https://github.com/frontman-ai/frontman/pull/1287) [`89a4d04`](https://github.com/frontman-ai/frontman/commit/89a4d04fc756630e1b20882af1db32480b53b8c5) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add supported GPT-5.6 variants and Claude 5 models through native providers and OpenRouter, with GPT-5.6 Terra and Claude Sonnet 5 as provider defaults.

- [#1239](https://github.com/frontman-ai/frontman/pull/1239) [`be420bc`](https://github.com/frontman-ai/frontman/commit/be420bc7df28ca0955f18440e38ea20c30ec9470) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add Railway deploy configuration and self-hosting docs for publishing Frontman as a one-click Railway template.

- [#1230](https://github.com/frontman-ai/frontman/pull/1230) [`6d04707`](https://github.com/frontman-ai/frontman/commit/6d047076a003b8a6de359cd6f3dabcce4523b808) Thanks [@dependabot](https://github.com/apps/dependabot)! - Align React peer dependencies with React DOM 19.2.7.

- [#1209](https://github.com/frontman-ai/frontman/pull/1209) [`a363505`](https://github.com/frontman-ai/frontman/commit/a363505c228aeafd2ea6186c8004d25ccc983c48) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Reopened tasks now show accepted follow-up prompts as normal user messages, preserving the full conversation history.

- [#1261](https://github.com/frontman-ai/frontman/pull/1261) [`27d6ac6`](https://github.com/frontman-ai/frontman/commit/27d6ac66f410f0023b8315715754fead45aa6c3e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Align development dependencies with supported Vite, React, Tiptap, and Astro peer ranges.

- [#1259](https://github.com/frontman-ai/frontman/pull/1259) [`e7bdadf`](https://github.com/frontman-ai/frontman/commit/e7bdadf286d8a8a8c69342d169d266e54db40d59) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Replace prompt editor internals with a Tiptap-based composer while preserving file, paste, drop, and annotation submit behavior.

- [#1286](https://github.com/frontman-ai/frontman/pull/1286) [`a557acf`](https://github.com/frontman-ai/frontman/commit/a557acfb2a8ec3422cd24e8d146bbf5b8a863746) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Replace misleading post-signup celebration with a required provider setup modal where chat is unavailable.

- [#1282](https://github.com/frontman-ai/frontman/pull/1282) [`80369df`](https://github.com/frontman-ai/frontman/commit/80369df055f984d17ddf279d124e79c67aa8278a) Thanks [@ntheanh201](https://github.com/ntheanh201)! - Allow the chat panel to collapse into a compact Frontman logo control, giving the browser preview the full workspace.

- [#1209](https://github.com/frontman-ai/frontman/pull/1209) [`a363505`](https://github.com/frontman-ai/frontman/commit/a363505c228aeafd2ea6186c8004d25ccc983c48) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Follow-up prompts sent while an agent is busy now appear in a queue drawer, making it clear what will run next.

- [#1236](https://github.com/frontman-ai/frontman/pull/1236) [`a5f8945`](https://github.com/frontman-ai/frontman/commit/a5f8945cb58f6ac598d37785fdc4c543fa334578) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Replace Radix-backed TSX UI wrappers with ReScript-native Base UI shadcn primitives and remove direct Radix wrapper dependencies.

- [#1262](https://github.com/frontman-ai/frontman/pull/1262) [`f081562`](https://github.com/frontman-ai/frontman/commit/f081562d24f17c09b2ae8bfe20467980e224ce81) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add prompt-level Executor and Planner selection, negotiated connection agent catalogs, stable
  message IDs, explicit agent colors, and migration of persisted session history.

- [#1192](https://github.com/frontman-ai/frontman/pull/1192) [`c7848c6`](https://github.com/frontman-ai/frontman/commit/c7848c6cd137afdb8df9298789dded95675ac5e1) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Carry stable agent error IDs through retry error updates.

- [#1288](https://github.com/frontman-ai/frontman/pull/1288) [`945cde1`](https://github.com/frontman-ai/frontman/commit/945cde14a3e5ec66e725b5be4305a940b2dc14fb) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix Fireworks API-key setup so saved keys expose Fireworks models and use the provider ID expected by the server.

- [#1237](https://github.com/frontman-ai/frontman/pull/1237) [`7ebe6be`](https://github.com/frontman-ai/frontman/commit/7ebe6be9c1d5bfc8a80b38b2be7ef57351777391) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add read/write access metadata to browser, backend, framework, and WordPress tool definitions.

#### @rescript/webapi


### Patch Changes

- [#1261](https://github.com/frontman-ai/frontman/pull/1261) [`27d6ac6`](https://github.com/frontman-ai/frontman/commit/27d6ac66f410f0023b8315715754fead45aa6c3e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Align development dependencies with supported Vite, React, Tiptap, and Astro peer ranges.

- [#1259](https://github.com/frontman-ai/frontman/pull/1259) [`e7bdadf`](https://github.com/frontman-ai/frontman/commit/e7bdadf286d8a8a8c69342d169d266e54db40d59) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Update vendored experimental ReScript WebAPI bindings from upstream.

#### @frontman-ai/astro


### Patch Changes

- [#1252](https://github.com/frontman-ai/frontman/pull/1252) [`5ff6278`](https://github.com/frontman-ai/frontman/commit/5ff6278294b1aba5bfd422eeaccdd69cff81ad49) Thanks [@dependabot](https://github.com/apps/dependabot)! - Update Lighthouse to 13.4.0 across framework integrations.

- [#1237](https://github.com/frontman-ai/frontman/pull/1237) [`7ebe6be`](https://github.com/frontman-ai/frontman/commit/7ebe6be9c1d5bfc8a80b38b2be7ef57351777391) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add read/write access metadata to browser, backend, framework, and WordPress tool definitions.

#### @frontman-ai/frontman-client


### Patch Changes

- [#1209](https://github.com/frontman-ai/frontman/pull/1209) [`a363505`](https://github.com/frontman-ai/frontman/commit/a363505c228aeafd2ea6186c8004d25ccc983c48) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Reopened tasks now show accepted follow-up prompts as normal user messages, preserving the full conversation history.

- [#1189](https://github.com/frontman-ai/frontman/pull/1189) [`b3451f2`](https://github.com/frontman-ai/frontman/commit/b3451f26d47104af6f5673e4f2fcad4f81344ef9) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Avoid sending empty text content blocks for attachment-only prompts.

- [#1262](https://github.com/frontman-ai/frontman/pull/1262) [`f081562`](https://github.com/frontman-ai/frontman/commit/f081562d24f17c09b2ae8bfe20467980e224ce81) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add prompt-level Executor and Planner selection, negotiated connection agent catalogs, stable
  message IDs, explicit agent colors, and migration of persisted session history.

- [#1192](https://github.com/frontman-ai/frontman/pull/1192) [`c7848c6`](https://github.com/frontman-ai/frontman/commit/c7848c6cd137afdb8df9298789dded95675ac5e1) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Carry stable agent error IDs through retry error updates.

- [#1237](https://github.com/frontman-ai/frontman/pull/1237) [`7ebe6be`](https://github.com/frontman-ai/frontman/commit/7ebe6be9c1d5bfc8a80b38b2be7ef57351777391) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add read/write access metadata to browser, backend, framework, and WordPress tool definitions.

- [#1209](https://github.com/frontman-ai/frontman/pull/1209) [`a363505`](https://github.com/frontman-ai/frontman/commit/a363505c228aeafd2ea6186c8004d25ccc983c48) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Saved tasks now restore their interaction history more reliably, including prompts, tool activity, and agent responses.

#### @frontman-ai/frontman-core


### Patch Changes

- [#1259](https://github.com/frontman-ai/frontman/pull/1259) [`e7bdadf`](https://github.com/frontman-ai/frontman/commit/e7bdadf286d8a8a8c69342d169d266e54db40d59) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Replace prompt editor internals with a Tiptap-based composer while preserving file, paste, drop, and annotation submit behavior.

- [#1252](https://github.com/frontman-ai/frontman/pull/1252) [`5ff6278`](https://github.com/frontman-ai/frontman/commit/5ff6278294b1aba5bfd422eeaccdd69cff81ad49) Thanks [@dependabot](https://github.com/apps/dependabot)! - Update Lighthouse to 13.4.0 across framework integrations.

- [#1237](https://github.com/frontman-ai/frontman/pull/1237) [`7ebe6be`](https://github.com/frontman-ai/frontman/commit/7ebe6be9c1d5bfc8a80b38b2be7ef57351777391) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add read/write access metadata to browser, backend, framework, and WordPress tool definitions.

- Updated dependencies [[`f081562`](https://github.com/frontman-ai/frontman/commit/f081562d24f17c09b2ae8bfe20467980e224ce81), [`c7848c6`](https://github.com/frontman-ai/frontman/commit/c7848c6cd137afdb8df9298789dded95675ac5e1), [`7ebe6be`](https://github.com/frontman-ai/frontman/commit/7ebe6be9c1d5bfc8a80b38b2be7ef57351777391), [`a363505`](https://github.com/frontman-ai/frontman/commit/a363505c228aeafd2ea6186c8004d25ccc983c48)]:
  - @frontman-ai/frontman-protocol@1.0.2

#### @frontman-ai/nextjs


### Patch Changes

- [#1235](https://github.com/frontman-ai/frontman/pull/1235) [`5a5a284`](https://github.com/frontman-ai/frontman/commit/5a5a284ce87b839a12824eec8f8d05ef0ff0e54a) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix dependency metadata so Yarn installs without peer warnings.

- [#1252](https://github.com/frontman-ai/frontman/pull/1252) [`5ff6278`](https://github.com/frontman-ai/frontman/commit/5ff6278294b1aba5bfd422eeaccdd69cff81ad49) Thanks [@dependabot](https://github.com/apps/dependabot)! - Update Lighthouse to 13.4.0 across framework integrations.

- [#1233](https://github.com/frontman-ai/frontman/pull/1233) [`2bedc65`](https://github.com/frontman-ai/frontman/commit/2bedc656b4c2b1497e528bbeb704afb39bdce410) Thanks [@dependabot](https://github.com/apps/dependabot)! - Update @sentry/nextjs to 10.56.0.

- [#1237](https://github.com/frontman-ai/frontman/pull/1237) [`7ebe6be`](https://github.com/frontman-ai/frontman/commit/7ebe6be9c1d5bfc8a80b38b2be7ef57351777391) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add read/write access metadata to browser, backend, framework, and WordPress tool definitions.

#### @frontman-ai/frontman-protocol


### Patch Changes

- [#1262](https://github.com/frontman-ai/frontman/pull/1262) [`f081562`](https://github.com/frontman-ai/frontman/commit/f081562d24f17c09b2ae8bfe20467980e224ce81) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add prompt-level Executor and Planner selection, negotiated connection agent catalogs, stable
  message IDs, explicit agent colors, and migration of persisted session history.

- [#1192](https://github.com/frontman-ai/frontman/pull/1192) [`c7848c6`](https://github.com/frontman-ai/frontman/commit/c7848c6cd137afdb8df9298789dded95675ac5e1) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Carry stable agent error IDs through retry error updates.

- [#1237](https://github.com/frontman-ai/frontman/pull/1237) [`7ebe6be`](https://github.com/frontman-ai/frontman/commit/7ebe6be9c1d5bfc8a80b38b2be7ef57351777391) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add read/write access metadata to browser, backend, framework, and WordPress tool definitions.

- [#1209](https://github.com/frontman-ai/frontman/pull/1209) [`a363505`](https://github.com/frontman-ai/frontman/commit/a363505c228aeafd2ea6186c8004d25ccc983c48) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Saved tasks now restore their interaction history more reliably, including prompts, tool activity, and agent responses.

#### @frontman-ai/vite


### Patch Changes

- [#1252](https://github.com/frontman-ai/frontman/pull/1252) [`5ff6278`](https://github.com/frontman-ai/frontman/commit/5ff6278294b1aba5bfd422eeaccdd69cff81ad49) Thanks [@dependabot](https://github.com/apps/dependabot)! - Update Lighthouse to 13.4.0 across framework integrations.

- [#1237](https://github.com/frontman-ai/frontman/pull/1237) [`7ebe6be`](https://github.com/frontman-ai/frontman/commit/7ebe6be9c1d5bfc8a80b38b2be7ef57351777391) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add read/write access metadata to browser, backend, framework, and WordPress tool definitions.

#### @frontman-ai/frontman-wordpress


### Patch Changes

- [#1211](https://github.com/frontman-ai/frontman/pull/1211) [`114ec48`](https://github.com/frontman-ai/frontman/commit/114ec487cc76fd30dfdf9cfac5512bd10ce7be20) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Optimize the WordPress.org readme for plugin-directory search and conversion.

- [#1237](https://github.com/frontman-ai/frontman/pull/1237) [`7ebe6be`](https://github.com/frontman-ai/frontman/commit/7ebe6be9c1d5bfc8a80b38b2be7ef57351777391) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add read/write access metadata to browser, backend, framework, and WordPress tool definitions.

#### @frontman-ai/react-statestore


### Patch Changes

- [#1230](https://github.com/frontman-ai/frontman/pull/1230) [`6d04707`](https://github.com/frontman-ai/frontman/commit/6d047076a003b8a6de359cd6f3dabcce4523b808) Thanks [@dependabot](https://github.com/apps/dependabot)! - Align React peer dependencies with React DOM 19.2.7.

- [#1235](https://github.com/frontman-ai/frontman/pull/1235) [`5a5a284`](https://github.com/frontman-ai/frontman/commit/5a5a284ce87b839a12824eec8f8d05ef0ff0e54a) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix dependency metadata so Yarn installs without peer warnings.

## [1.3.0] - 2026-06-25


#### @frontman-ai/astro


### Patch Changes

- [#1184](https://github.com/frontman-ai/frontman/pull/1184) [`55a3f92`](https://github.com/frontman-ai/frontman/commit/55a3f928267b233430830c1e0c9aeb4ab44e528e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add `get_content_collections` tool for Astro projects.

## [1.2.0] - 2026-06-24


#### @frontman-ai/frontman-client


### Patch Changes

- [#1175](https://github.com/frontman-ai/frontman/pull/1175) [`8c07721`](https://github.com/frontman-ai/frontman/commit/8c077219700fbe773cadf7d55acb3165540ad7aa) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Improve MCP tool schema validation error diagnostics in Sentry.

#### @frontman-ai/frontman-wordpress


### Patch Changes

- [#1180](https://github.com/frontman-ai/frontman/pull/1180) [`6d4f43c`](https://github.com/frontman-ai/frontman/commit/6d4f43c883c3c634f2a905681daee117b3dcbcac) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Update the WordPress.org listing copy to position Frontman as an AI website editor for non-developer WordPress teams.

## [1.1.0] - 2026-06-24


#### @frontman-ai/client


### Patch Changes

- [#1112](https://github.com/frontman-ai/frontman/pull/1112) [`9b8fea7`](https://github.com/frontman-ai/frontman/commit/9b8fea73ab3ba4354ede9157deade5cb920b6f16) Thanks [@itayadler](https://github.com/itayadler)! - Serialize annotated element CSS selectors and clarify that `execute_js` is for inspection/navigation, not source-of-truth edits.

- [#1154](https://github.com/frontman-ai/frontman/pull/1154) [`2786253`](https://github.com/frontman-ai/frontman/commit/2786253055f47bc2715884acd61b71b256f31727) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Cleanly leave ACP channels and disconnect the Phoenix socket when Frontman unmounts.

- [#1130](https://github.com/frontman-ai/frontman/pull/1130) [`c2d7e23`](https://github.com/frontman-ai/frontman/commit/c2d7e23a7fc79f0941bf1abcfe86181070f5620d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Return MCP-standard tool results for text and image content.

- [#1172](https://github.com/frontman-ai/frontman/pull/1172) [`0f87d0d`](https://github.com/frontman-ai/frontman/commit/0f87d0d7133f77ac5ddb193afad768ffb5051744) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix no-API-key errors to show provider configuration and keep annotation chips within message bounds.

- [#1151](https://github.com/frontman-ai/frontman/pull/1151) [`4089f7f`](https://github.com/frontman-ai/frontman/commit/4089f7fcd1f31aaf1e7c17bd59072df558031d88) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Remove backend default model selection and let the client choose the first available model option.

- [#1160](https://github.com/frontman-ai/frontman/pull/1160) [`ed80e09`](https://github.com/frontman-ai/frontman/commit/ed80e09ab233e5097c8e70ce7c33be674a08854a) Thanks [@dependabot](https://github.com/apps/dependabot)! - Update ReScript/Sury integration for `sury@11.0.0-alpha.5` and regenerate protocol JSON schemas.

#### @rescript/webapi


### Patch Changes

- [#1160](https://github.com/frontman-ai/frontman/pull/1160) [`ed80e09`](https://github.com/frontman-ai/frontman/commit/ed80e09ab233e5097c8e70ce7c33be674a08854a) Thanks [@dependabot](https://github.com/apps/dependabot)! - Update ReScript/Sury integration for `sury@11.0.0-alpha.5` and regenerate protocol JSON schemas.

#### @frontman-ai/astro


### Patch Changes

- [#1130](https://github.com/frontman-ai/frontman/pull/1130) [`c2d7e23`](https://github.com/frontman-ai/frontman/commit/c2d7e23a7fc79f0941bf1abcfe86181070f5620d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Return MCP-standard tool results for text and image content.

- [#1160](https://github.com/frontman-ai/frontman/pull/1160) [`ed80e09`](https://github.com/frontman-ai/frontman/commit/ed80e09ab233e5097c8e70ce7c33be674a08854a) Thanks [@dependabot](https://github.com/apps/dependabot)! - Update ReScript/Sury integration for `sury@11.0.0-alpha.5` and regenerate protocol JSON schemas.

#### @frontman-ai/frontman-client


### Patch Changes

- [#1154](https://github.com/frontman-ai/frontman/pull/1154) [`2786253`](https://github.com/frontman-ai/frontman/commit/2786253055f47bc2715884acd61b71b256f31727) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Cleanly leave ACP channels and disconnect the Phoenix socket when Frontman unmounts.

- [#1130](https://github.com/frontman-ai/frontman/pull/1130) [`c2d7e23`](https://github.com/frontman-ai/frontman/commit/c2d7e23a7fc79f0941bf1abcfe86181070f5620d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Return MCP-standard tool results for text and image content.

- [#1160](https://github.com/frontman-ai/frontman/pull/1160) [`ed80e09`](https://github.com/frontman-ai/frontman/commit/ed80e09ab233e5097c8e70ce7c33be674a08854a) Thanks [@dependabot](https://github.com/apps/dependabot)! - Update ReScript/Sury integration for `sury@11.0.0-alpha.5` and regenerate protocol JSON schemas.

#### @frontman-ai/frontman-core


### Patch Changes

- [#1130](https://github.com/frontman-ai/frontman/pull/1130) [`c2d7e23`](https://github.com/frontman-ai/frontman/commit/c2d7e23a7fc79f0941bf1abcfe86181070f5620d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Return MCP-standard tool results for text and image content.

- [#1160](https://github.com/frontman-ai/frontman/pull/1160) [`ed80e09`](https://github.com/frontman-ai/frontman/commit/ed80e09ab233e5097c8e70ce7c33be674a08854a) Thanks [@dependabot](https://github.com/apps/dependabot)! - Update ReScript/Sury integration for `sury@11.0.0-alpha.5` and regenerate protocol JSON schemas.

- Updated dependencies [[`c2d7e23`](https://github.com/frontman-ai/frontman/commit/c2d7e23a7fc79f0941bf1abcfe86181070f5620d), [`4089f7f`](https://github.com/frontman-ai/frontman/commit/4089f7fcd1f31aaf1e7c17bd59072df558031d88), [`ed80e09`](https://github.com/frontman-ai/frontman/commit/ed80e09ab233e5097c8e70ce7c33be674a08854a)]:
  - @frontman-ai/frontman-protocol@1.0.1

#### @frontman-ai/nextjs


### Patch Changes

- [#1130](https://github.com/frontman-ai/frontman/pull/1130) [`c2d7e23`](https://github.com/frontman-ai/frontman/commit/c2d7e23a7fc79f0941bf1abcfe86181070f5620d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Return MCP-standard tool results for text and image content.

- [#1160](https://github.com/frontman-ai/frontman/pull/1160) [`ed80e09`](https://github.com/frontman-ai/frontman/commit/ed80e09ab233e5097c8e70ce7c33be674a08854a) Thanks [@dependabot](https://github.com/apps/dependabot)! - Update ReScript/Sury integration for `sury@11.0.0-alpha.5` and regenerate protocol JSON schemas.

#### @frontman-ai/frontman-protocol


### Patch Changes

- [#1130](https://github.com/frontman-ai/frontman/pull/1130) [`c2d7e23`](https://github.com/frontman-ai/frontman/commit/c2d7e23a7fc79f0941bf1abcfe86181070f5620d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Return MCP-standard tool results for text and image content.

- [#1151](https://github.com/frontman-ai/frontman/pull/1151) [`4089f7f`](https://github.com/frontman-ai/frontman/commit/4089f7fcd1f31aaf1e7c17bd59072df558031d88) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Remove backend default model selection and let the client choose the first available model option.

- [#1160](https://github.com/frontman-ai/frontman/pull/1160) [`ed80e09`](https://github.com/frontman-ai/frontman/commit/ed80e09ab233e5097c8e70ce7c33be674a08854a) Thanks [@dependabot](https://github.com/apps/dependabot)! - Update ReScript/Sury integration for `sury@11.0.0-alpha.5` and regenerate protocol JSON schemas.

#### @frontman-ai/vite


### Patch Changes

- [#1130](https://github.com/frontman-ai/frontman/pull/1130) [`c2d7e23`](https://github.com/frontman-ai/frontman/commit/c2d7e23a7fc79f0941bf1abcfe86181070f5620d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Return MCP-standard tool results for text and image content.

- [#1160](https://github.com/frontman-ai/frontman/pull/1160) [`ed80e09`](https://github.com/frontman-ai/frontman/commit/ed80e09ab233e5097c8e70ce7c33be674a08854a) Thanks [@dependabot](https://github.com/apps/dependabot)! - Update ReScript/Sury integration for `sury@11.0.0-alpha.5` and regenerate protocol JSON schemas.

## [1.0.0] - 2026-06-08


#### @frontman-ai/client


### Major Changes

- [#1117](https://github.com/frontman-ai/frontman/pull/1117) [`bd25abe`](https://github.com/frontman-ai/frontman/commit/bd25abeae89df34517dfd2c87cbe9818f58f4c9d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Rename the ChatGPT OAuth surface to OpenAI and simplify provider auth resolution.

  Breaking change: client state, actions, selectors, and OAuth endpoints now use OpenAI names instead of ChatGPT names. Existing selected-model localStorage values with the `openai:` prefix are migrated to `openai_codex:` automatically.

#### @frontman-ai/astro


### Major Changes

- [#1117](https://github.com/frontman-ai/frontman/pull/1117) [`bd25abe`](https://github.com/frontman-ai/frontman/commit/bd25abeae89df34517dfd2c87cbe9818f58f4c9d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Rename the ChatGPT OAuth surface to OpenAI and simplify provider auth resolution.

  Breaking change: client state, actions, selectors, and OAuth endpoints now use OpenAI names instead of ChatGPT names. Existing selected-model localStorage values with the `openai:` prefix are migrated to `openai_codex:` automatically.

#### @frontman-ai/frontman-client


### Major Changes

- [#1117](https://github.com/frontman-ai/frontman/pull/1117) [`bd25abe`](https://github.com/frontman-ai/frontman/commit/bd25abeae89df34517dfd2c87cbe9818f58f4c9d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Rename the ChatGPT OAuth surface to OpenAI and simplify provider auth resolution.

  Breaking change: client state, actions, selectors, and OAuth endpoints now use OpenAI names instead of ChatGPT names. Existing selected-model localStorage values with the `openai:` prefix are migrated to `openai_codex:` automatically.

#### @frontman-ai/frontman-core


### Major Changes

- [#1117](https://github.com/frontman-ai/frontman/pull/1117) [`bd25abe`](https://github.com/frontman-ai/frontman/commit/bd25abeae89df34517dfd2c87cbe9818f58f4c9d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Rename the ChatGPT OAuth surface to OpenAI and simplify provider auth resolution.

  Breaking change: client state, actions, selectors, and OAuth endpoints now use OpenAI names instead of ChatGPT names. Existing selected-model localStorage values with the `openai:` prefix are migrated to `openai_codex:` automatically.

### Patch Changes

- Updated dependencies [[`bd25abe`](https://github.com/frontman-ai/frontman/commit/bd25abeae89df34517dfd2c87cbe9818f58f4c9d)]:
  - @frontman-ai/frontman-protocol@1.0.0

#### @frontman-ai/nextjs


### Major Changes

- [#1117](https://github.com/frontman-ai/frontman/pull/1117) [`bd25abe`](https://github.com/frontman-ai/frontman/commit/bd25abeae89df34517dfd2c87cbe9818f58f4c9d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Rename the ChatGPT OAuth surface to OpenAI and simplify provider auth resolution.

  Breaking change: client state, actions, selectors, and OAuth endpoints now use OpenAI names instead of ChatGPT names. Existing selected-model localStorage values with the `openai:` prefix are migrated to `openai_codex:` automatically.

### Patch Changes

- [#1114](https://github.com/frontman-ai/frontman/pull/1114) [`efac643`](https://github.com/frontman-ai/frontman/commit/efac6433f951cf8e3ee860dd6f93d2bde58dab6f) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix Next.js 16 proxy generation by omitting invalid runtime config, and make E2E failures report broken Frontman routes directly.

#### @frontman-ai/frontman-protocol


### Major Changes

- [#1117](https://github.com/frontman-ai/frontman/pull/1117) [`bd25abe`](https://github.com/frontman-ai/frontman/commit/bd25abeae89df34517dfd2c87cbe9818f58f4c9d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Rename the ChatGPT OAuth surface to OpenAI and simplify provider auth resolution.

  Breaking change: client state, actions, selectors, and OAuth endpoints now use OpenAI names instead of ChatGPT names. Existing selected-model localStorage values with the `openai:` prefix are migrated to `openai_codex:` automatically.

#### @frontman-ai/vite


### Major Changes

- [#1117](https://github.com/frontman-ai/frontman/pull/1117) [`bd25abe`](https://github.com/frontman-ai/frontman/commit/bd25abeae89df34517dfd2c87cbe9818f58f4c9d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Rename the ChatGPT OAuth surface to OpenAI and simplify provider auth resolution.

  Breaking change: client state, actions, selectors, and OAuth endpoints now use OpenAI names instead of ChatGPT names. Existing selected-model localStorage values with the `openai:` prefix are migrated to `openai_codex:` automatically.

#### @frontman-ai/react-statestore


### Major Changes

- [#1117](https://github.com/frontman-ai/frontman/pull/1117) [`bd25abe`](https://github.com/frontman-ai/frontman/commit/bd25abeae89df34517dfd2c87cbe9818f58f4c9d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Rename the ChatGPT OAuth surface to OpenAI and simplify provider auth resolution.

  Breaking change: client state, actions, selectors, and OAuth endpoints now use OpenAI names instead of ChatGPT names. Existing selected-model localStorage values with the `openai:` prefix are migrated to `openai_codex:` automatically.

## [0.18.0] - 2026-06-05


#### @frontman-ai/client


### Patch Changes

- [#1025](https://github.com/frontman-ai/frontman/pull/1025) [`0f92b89`](https://github.com/frontman-ai/frontman/commit/0f92b89da7bee9044a64bbd139c2ed43bfb36181) Thanks [@itayadler](https://github.com/itayadler)! - Add NVIDIA provider key forwarding and settings support.

- [#1058](https://github.com/frontman-ai/frontman/pull/1058) [`e39a7e8`](https://github.com/frontman-ai/frontman/commit/e39a7e817d70c383099a7f229a3bf25eb3ed1d30) Thanks [@dependabot](https://github.com/apps/dependabot)! - Upgrade Tailwind CSS to 4.2.4.

- [#1047](https://github.com/frontman-ai/frontman/pull/1047) [`9ac299c`](https://github.com/frontman-ai/frontman/commit/9ac299c380a64f4c03bd9e3874d3950e7382a41f) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Drive task prompt guidance from explicit project traits emitted by each framework adapter.

- [#1062](https://github.com/frontman-ai/frontman/pull/1062) [`40d489e`](https://github.com/frontman-ai/frontman/commit/40d489eb181867a6e83870ab77c0494fd7cc9a6f) Thanks [@dependabot](https://github.com/apps/dependabot)! - Fix Vitest 4 CI coverage runs by aligning test dependency versions and hook callbacks.

- [#1075](https://github.com/frontman-ai/frontman/pull/1075) [`118c7f8`](https://github.com/frontman-ai/frontman/commit/118c7f865ef510e2356f2ff7d724943e856ea978) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Reduce local console noise from expected connection cleanup and settings modal accessibility warnings.

#### @frontman-ai/astro


### Patch Changes

- [#1047](https://github.com/frontman-ai/frontman/pull/1047) [`9ac299c`](https://github.com/frontman-ai/frontman/commit/9ac299c380a64f4c03bd9e3874d3950e7382a41f) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Drive task prompt guidance from explicit project traits emitted by each framework adapter.

#### @frontman-ai/frontman-client


### Patch Changes

- [#1075](https://github.com/frontman-ai/frontman/pull/1075) [`118c7f8`](https://github.com/frontman-ai/frontman/commit/118c7f865ef510e2356f2ff7d724943e856ea978) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Keep pending question tools answerable across server restarts and retry exact persisted agent errors.

- [#1075](https://github.com/frontman-ai/frontman/pull/1075) [`118c7f8`](https://github.com/frontman-ai/frontman/commit/118c7f865ef510e2356f2ff7d724943e856ea978) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Reduce local console noise from expected connection cleanup and settings modal accessibility warnings.

#### @frontman-ai/frontman-core


### Patch Changes

- [#1025](https://github.com/frontman-ai/frontman/pull/1025) [`0f92b89`](https://github.com/frontman-ai/frontman/commit/0f92b89da7bee9044a64bbd139c2ed43bfb36181) Thanks [@itayadler](https://github.com/itayadler)! - Add NVIDIA provider key forwarding and settings support.

- [#1047](https://github.com/frontman-ai/frontman/pull/1047) [`9ac299c`](https://github.com/frontman-ai/frontman/commit/9ac299c380a64f4c03bd9e3874d3950e7382a41f) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Drive task prompt guidance from explicit project traits emitted by each framework adapter.

- [#1062](https://github.com/frontman-ai/frontman/pull/1062) [`40d489e`](https://github.com/frontman-ai/frontman/commit/40d489eb181867a6e83870ab77c0494fd7cc9a6f) Thanks [@dependabot](https://github.com/apps/dependabot)! - Fix Vitest 4 CI coverage runs by aligning test dependency versions and hook callbacks.

- Updated dependencies [[`118c7f8`](https://github.com/frontman-ai/frontman/commit/118c7f865ef510e2356f2ff7d724943e856ea978), [`118c7f8`](https://github.com/frontman-ai/frontman/commit/118c7f865ef510e2356f2ff7d724943e856ea978)]:
  - @frontman-ai/frontman-protocol@0.7.0

#### @frontman-ai/nextjs


### Patch Changes

- [#1047](https://github.com/frontman-ai/frontman/pull/1047) [`9ac299c`](https://github.com/frontman-ai/frontman/commit/9ac299c380a64f4c03bd9e3874d3950e7382a41f) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Drive task prompt guidance from explicit project traits emitted by each framework adapter.

- [#1062](https://github.com/frontman-ai/frontman/pull/1062) [`40d489e`](https://github.com/frontman-ai/frontman/commit/40d489eb181867a6e83870ab77c0494fd7cc9a6f) Thanks [@dependabot](https://github.com/apps/dependabot)! - Fix Vitest 4 CI coverage runs by aligning test dependency versions and hook callbacks.

#### @frontman-ai/frontman-protocol


### Minor Changes

- [#1075](https://github.com/frontman-ai/frontman/pull/1075) [`118c7f8`](https://github.com/frontman-ai/frontman/commit/118c7f865ef510e2356f2ff7d724943e856ea978) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Restrict JSON-RPC request and response IDs to integers; durable MCP tool IDs now stay in params.callId.

### Patch Changes

- [#1075](https://github.com/frontman-ai/frontman/pull/1075) [`118c7f8`](https://github.com/frontman-ai/frontman/commit/118c7f865ef510e2356f2ff7d724943e856ea978) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Keep pending question tools answerable across server restarts and retry exact persisted agent errors.

#### @frontman-ai/vite


### Patch Changes

- [#1047](https://github.com/frontman-ai/frontman/pull/1047) [`9ac299c`](https://github.com/frontman-ai/frontman/commit/9ac299c380a64f4c03bd9e3874d3950e7382a41f) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Drive task prompt guidance from explicit project traits emitted by each framework adapter.

## [Unreleased]

### Added

- Add a backend `get_tool_result` tool for retrieving stored tool results by tool call ID.

### Changed

- Replace consumed tool result payloads with an omitted-data placeholder that points agents to `get_tool_result`.
- Drive TypeScript/React prompt guidance from explicit project traits, while preserving legacy Next.js guidance for adapters that do not emit traits yet.

### Fixed

- Fix Vitest 4 coverage test runs by aligning Vitest dependency versions and updating hook callbacks for Vitest 4.
- Keep generated task titles stable after the first user prompt instead of regenerating them on every prompt.
- Skip filesystem MCP initialization for WordPress tasks so sessions no longer call unavailable `load_agent_instructions` or `list_tree` tools.

## [0.17.0] - 2026-05-12


#### @frontman-ai/client


### Patch Changes

- [#1012](https://github.com/frontman-ai/frontman/pull/1012) [`9b645f8`](https://github.com/frontman-ai/frontman/commit/9b645f85e286e9a65e7ca0de3a43767ddb7aab51) Thanks [@dependabot](https://github.com/apps/dependabot)! - Align React and ReactDOM dependency ranges for the ReactDOM update.

#### @frontman-ai/frontman-core


### Patch Changes

- [#1013](https://github.com/frontman-ai/frontman/pull/1013) [`70dff99`](https://github.com/frontman-ai/frontman/commit/70dff99ade62f96071e0d20e362a181860d442de) Thanks [@itayadler](https://github.com/itayadler)! - Fix path validation when Vite reports `sourceRoot: "."` so normal project-relative paths like `src/main.tsx` can be read and edited.

#### @frontman-ai/vite


### Patch Changes

- [#1013](https://github.com/frontman-ai/frontman/pull/1013) [`70dff99`](https://github.com/frontman-ai/frontman/commit/70dff99ade62f96071e0d20e362a181860d442de) Thanks [@itayadler](https://github.com/itayadler)! - Fix path validation when Vite reports `sourceRoot: "."` so normal project-relative paths like `src/main.tsx` can be read and edited.

#### @frontman-ai/react-statestore


### Patch Changes

- [#1012](https://github.com/frontman-ai/frontman/pull/1012) [`9b645f8`](https://github.com/frontman-ai/frontman/commit/9b645f85e286e9a65e7ca0de3a43767ddb7aab51) Thanks [@dependabot](https://github.com/apps/dependabot)! - Align React and ReactDOM dependency ranges for the ReactDOM update.

## [0.16.0] - 2026-05-08


#### @frontman-ai/client


### Minor Changes

- [#875](https://github.com/frontman-ai/frontman/pull/875) [`0d53ccc`](https://github.com/frontman-ai/frontman/commit/0d53ccc5a3552f3665db198deb80f817535546b2) Thanks [@itayadler](https://github.com/itayadler)! - Add Fireworks Fire Pass support, including Fireworks API key setup and Kimi K2.5 Turbo in the provider picker.

### Patch Changes

- [`17116b2`](https://github.com/frontman-ai/frontman/commit/17116b203da5608000090031aa301a4c7026245b) Thanks [@itayadler](https://github.com/itayadler)! - Add GPT-5.4 Mini to the OpenAI model picker.

- [#908](https://github.com/frontman-ai/frontman/pull/908) [`c3a6814`](https://github.com/frontman-ai/frontman/commit/c3a6814bd6d237c136defc57e57f390564634f97) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Append the detected framework to auth-required login redirects and thread it through OAuth signup so new-user Discord notifications include the framework used at signup.

- [#930](https://github.com/frontman-ai/frontman/pull/930) [`223e1cc`](https://github.com/frontman-ai/frontman/commit/223e1cce94aefa620076a6d8c5c0f369cac55627) Thanks [@itayadler](https://github.com/itayadler)! - Add Elementor selected-element context and WordPress Elementor tools so agents can inspect and edit Elementor-backed selections directly.

- [#932](https://github.com/frontman-ai/frontman/pull/932) [`e624c70`](https://github.com/frontman-ai/frontman/commit/e624c70f6f848b7424a5dbd4f1677ea44f1414c6) Thanks [@itayadler](https://github.com/itayadler)! - Add a WordPress media upload tool that resolves user-attached images into Media Library attachments for use in posts and Elementor elements.

- [`af82814`](https://github.com/frontman-ai/frontman/commit/af828141eda8291b78f0801413c1285f351abc47) Thanks [@itayadler](https://github.com/itayadler)! - Carry Elementor-selected annotation context through existing nearby text metadata so agents can route edits to Elementor tools without backend-specific prompt changes.

- [#954](https://github.com/frontman-ai/frontman/pull/954) [`6cb67cf`](https://github.com/frontman-ai/frontman/commit/6cb67cf253aa30f9e8a04f2451f6dc2b90c2b447) Thanks [@itayadler](https://github.com/itayadler)! - Remove unused client UI wrappers and redundant frontend dependencies.

- [#890](https://github.com/frontman-ai/frontman/pull/890) [`05942f0`](https://github.com/frontman-ai/frontman/commit/05942f0bdaf3a60710a903542ec68200a58be6aa) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Centralize path normalization and filename pattern matching to shared helpers across core and framework packages. This removes duplicate `toForwardSlashes` logic from client/Next.js/Astro path conversion and moves search/file matching logic into reusable frontman-core utilities, while adding focused regression tests for mixed separators and wildcard/case-insensitive pattern matching.

- [#948](https://github.com/frontman-ai/frontman/pull/948) [`e43a490`](https://github.com/frontman-ai/frontman/commit/e43a49049a36f6eeeea04f1008da0923087c0a48) Thanks [@itayadler](https://github.com/itayadler)! - Fix WordPress page duplication to copy Elementor/page metadata and preserve post-backed navigation item metadata during menu updates.

- [#879](https://github.com/frontman-ai/frontman/pull/879) [`5f4fe05`](https://github.com/frontman-ai/frontman/commit/5f4fe05004dba00f613a44641ce8404007bf7ca8) Thanks [@itayadler](https://github.com/itayadler)! - Escape embedding iframes for hosted auth and logout redirects so Frontman can sign in correctly inside shells like WordPress Playground.

- [`3f374c7`](https://github.com/frontman-ai/frontman/commit/3f374c770e028393b39beac6738babe9e5d4ccb8) Thanks [@itayadler](https://github.com/itayadler)! - Preserve previous Elementor data as private rollback snapshots when updating, removing, or replacing Elementor content.

- [#965](https://github.com/frontman-ai/frontman/pull/965) [`7334070`](https://github.com/frontman-ai/frontman/commit/7334070e166f30659feda38f7b64f52a222aba40) Thanks [@itayadler](https://github.com/itayadler)! - Remove unused client bindings, icons, and legacy connection reducer transitions.

- [#957](https://github.com/frontman-ai/frontman/pull/957) [`67516ac`](https://github.com/frontman-ai/frontman/commit/67516ac5ee501dd9c3553795e92d9b112a16a12c) Thanks [@itayadler](https://github.com/itayadler)! - Remove the client Storybook setup and debug-state snapshot tooling.

- [#944](https://github.com/frontman-ai/frontman/pull/944) [`0efccec`](https://github.com/frontman-ai/frontman/commit/0efccec4dd26e10d307b8eee0535c9b1efc92312) Thanks [@itayadler](https://github.com/itayadler)! - Run WordPress Elementor edits serially and pass Elementor target metadata so the update tool can choose settings versus HTML-fragment edits deterministically.

- [#967](https://github.com/frontman-ai/frontman/pull/967) [`8adb8e4`](https://github.com/frontman-ai/frontman/commit/8adb8e45e2d476a912f71cd60539f642ee37d19f) Thanks [@itayadler](https://github.com/itayadler)! - Trim duplicated CLI package-manager helpers and remove stale client tool summary helpers.

#### @frontman-ai/astro


### Patch Changes

- [#890](https://github.com/frontman-ai/frontman/pull/890) [`05942f0`](https://github.com/frontman-ai/frontman/commit/05942f0bdaf3a60710a903542ec68200a58be6aa) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Centralize path normalization and filename pattern matching to shared helpers across core and framework packages. This removes duplicate `toForwardSlashes` logic from client/Next.js/Astro path conversion and moves search/file matching logic into reusable frontman-core utilities, while adding focused regression tests for mixed separators and wildcard/case-insensitive pattern matching.

- [#966](https://github.com/frontman-ai/frontman/pull/966) [`de43db7`](https://github.com/frontman-ai/frontman/commit/de43db75fcaacd66af39ca000c037e3d90880c76) Thanks [@itayadler](https://github.com/itayadler)! - Consolidate duplicated framework log capture and edit-file log checking through shared core helpers.

- [#953](https://github.com/frontman-ai/frontman/pull/953) [`b2aef53`](https://github.com/frontman-ai/frontman/commit/b2aef533a79fcd0d96291eb40f812b5e926eec9e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Enable React Scan in Frontman UI shells when requested with `?debug=1` and keep the shell in dark mode consistently.

- [#951](https://github.com/frontman-ai/frontman/pull/951) [`dc65580`](https://github.com/frontman-ai/frontman/commit/dc6558045b8eaee5981afbc34e9d75b1b2db4fcc) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Patch vulnerable JavaScript dependencies across framework fixtures.

- [#976](https://github.com/frontman-ai/frontman/pull/976) [`5585afb`](https://github.com/frontman-ai/frontman/commit/5585afb0f0a1e715133ede2fa97f0d32abc3b648) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Update the ReScript compiler and runtime dependencies to 12.2.0 across the workspace.

#### @frontman-ai/frontman-core


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

#### @frontman-ai/nextjs


### Patch Changes

- [#890](https://github.com/frontman-ai/frontman/pull/890) [`05942f0`](https://github.com/frontman-ai/frontman/commit/05942f0bdaf3a60710a903542ec68200a58be6aa) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Centralize path normalization and filename pattern matching to shared helpers across core and framework packages. This removes duplicate `toForwardSlashes` logic from client/Next.js/Astro path conversion and moves search/file matching logic into reusable frontman-core utilities, while adding focused regression tests for mixed separators and wildcard/case-insensitive pattern matching.

- [#966](https://github.com/frontman-ai/frontman/pull/966) [`de43db7`](https://github.com/frontman-ai/frontman/commit/de43db75fcaacd66af39ca000c037e3d90880c76) Thanks [@itayadler](https://github.com/itayadler)! - Consolidate duplicated framework log capture and edit-file log checking through shared core helpers.

- [#953](https://github.com/frontman-ai/frontman/pull/953) [`b2aef53`](https://github.com/frontman-ai/frontman/commit/b2aef533a79fcd0d96291eb40f812b5e926eec9e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Enable React Scan in Frontman UI shells when requested with `?debug=1` and keep the shell in dark mode consistently.

- [#951](https://github.com/frontman-ai/frontman/pull/951) [`dc65580`](https://github.com/frontman-ai/frontman/commit/dc6558045b8eaee5981afbc34e9d75b1b2db4fcc) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Patch vulnerable JavaScript dependencies across framework fixtures.

- [#967](https://github.com/frontman-ai/frontman/pull/967) [`8adb8e4`](https://github.com/frontman-ai/frontman/commit/8adb8e45e2d476a912f71cd60539f642ee37d19f) Thanks [@itayadler](https://github.com/itayadler)! - Trim duplicated CLI package-manager helpers and remove stale client tool summary helpers.

- [#976](https://github.com/frontman-ai/frontman/pull/976) [`5585afb`](https://github.com/frontman-ai/frontman/commit/5585afb0f0a1e715133ede2fa97f0d32abc3b648) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Update the ReScript compiler and runtime dependencies to 12.2.0 across the workspace.

#### @frontman-ai/vite


### Patch Changes

- [#966](https://github.com/frontman-ai/frontman/pull/966) [`de43db7`](https://github.com/frontman-ai/frontman/commit/de43db75fcaacd66af39ca000c037e3d90880c76) Thanks [@itayadler](https://github.com/itayadler)! - Consolidate duplicated framework log capture and edit-file log checking through shared core helpers.

- [#953](https://github.com/frontman-ai/frontman/pull/953) [`b2aef53`](https://github.com/frontman-ai/frontman/commit/b2aef533a79fcd0d96291eb40f812b5e926eec9e) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Enable React Scan in Frontman UI shells when requested with `?debug=1` and keep the shell in dark mode consistently.

- [#967](https://github.com/frontman-ai/frontman/pull/967) [`8adb8e4`](https://github.com/frontman-ai/frontman/commit/8adb8e45e2d476a912f71cd60539f642ee37d19f) Thanks [@itayadler](https://github.com/itayadler)! - Trim duplicated CLI package-manager helpers and remove stale client tool summary helpers.

- [#976](https://github.com/frontman-ai/frontman/pull/976) [`5585afb`](https://github.com/frontman-ai/frontman/commit/5585afb0f0a1e715133ede2fa97f0d32abc3b648) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Update the ReScript compiler and runtime dependencies to 12.2.0 across the workspace.

## [Unreleased]

### Changed

- Add a deployable production notifier worker for GitHub stargazer alerts and idle task summaries, with its own path-scoped production deployment workflow.
- Refactor: move `env_api_keys` into `Scope` struct — eliminates ad-hoc `env_api_key` parameter threading across `Providers`, channels, and the execution pipeline. `Providers.prepare_api_key`, `resolve_api_key`, `available_provider_tiers`, and `model_config_data` all drop their `env_api_key` parameter and read from `scope.env_api_keys` instead.
- Allow `.net` and `.org` origins in the server's allowed origin and external return URL allowlists.
- Align E2E to a first-class `MIX_ENV=e2e` environment, remove `E2E=true` dev-branch config toggles, and standardize strict boolean env parsing across runtime and E2E setup.
- Update `req_llm` through upstream commit `0dd709f` and preserve OpenAI Responses metadata (`response_id`, phased assistant output) across stream conversion, persistence, and interaction replay so follow-up turns keep reasoning continuity.
- Add GPT-5.5 to OpenAI and OpenRouter model catalogs, making it the default direct OpenAI model.
- Remove WordPress plugin filesystem and managed-theme file tools so the plugin no longer exposes direct read, write, create, delete, or modify access to files inside a WordPress installation.

### Fixed

- Address WordPress.org plugin review findings by tightening Frontman route nonce validation, removing flagged inline UI assets, and avoiding direct admin plugin helper includes.
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
