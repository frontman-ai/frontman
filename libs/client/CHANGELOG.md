# @frontman-ai/client

## 1.2.0

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

## 1.1.0

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

## 1.0.5

### Patch Changes

- [#1415](https://github.com/frontman-ai/frontman/pull/1415) [`3ab55f5`](https://github.com/frontman-ai/frontman/commit/3ab55f5efc38b66f3ee380a9dae6e1580c63efa7) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Give annotated elements the same bounded DOM context as `get_dom`, including their parent and direct children, so agents can follow selectors instead of broadly searching source files. Keep `get_dom` shadow traversal compatible with navigable indexed `>>>` paths. Resolve Next.js React Server Component annotations through server-side source maps without issuing invalid browser requests for React's virtual source URLs, while preserving client-component source locations beneath server components.

- [#1416](https://github.com/frontman-ai/frontman/pull/1416) [`f8c6c52`](https://github.com/frontman-ai/frontman/commit/f8c6c52a79a148168e061db6f3aec36839519d80) Thanks [@uinstinct](https://github.com/uinstinct)! - Allow a second paste within five seconds to expand a pasted-text chip in place.

- [#1415](https://github.com/frontman-ai/frontman/pull/1415) [`3ab55f5`](https://github.com/frontman-ai/frontman/commit/3ab55f5efc38b66f3ee380a9dae6e1580c63efa7) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Prevent task failures from rendering duplicate error banners and reconnect cleanly after React Strict Mode lifecycle cleanup.

- [#1415](https://github.com/frontman-ai/frontman/pull/1415) [`3ab55f5`](https://github.com/frontman-ai/frontman/commit/3ab55f5efc38b66f3ee380a9dae6e1580c63efa7) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Stop reporting Astro DOM ancestors as component invocation callsites, attach React component props instead of selected host-element props when ownership matches, and preserve current-page context in task diagnostics.

- [#1402](https://github.com/frontman-ai/frontman/pull/1402) [`c30f33e`](https://github.com/frontman-ai/frontman/commit/c30f33ea32ecb3d50c4e8aef41c42c54a8274277) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Make Frontman work immediately on WordPress sites using Plain permalinks.

- [#1410](https://github.com/frontman-ai/frontman/pull/1410) [`f0868c4`](https://github.com/frontman-ai/frontman/commit/f0868c487e4f1d8cbf42d3b75c583921d657bbe4) Thanks [@uinstinct](https://github.com/uinstinct)! - Keep the thinking indicator visible for the whole AI turn, including while text is streaming.

- [#1436](https://github.com/frontman-ai/frontman/pull/1436) [`0224d40`](https://github.com/frontman-ai/frontman/commit/0224d40b3b6b61800553e6833ca90ea8f68b0096) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Align Tiptap packages on version 3.30.1 and upgrade the repository to Yarn 4.18.

- [#1409](https://github.com/frontman-ai/frontman/pull/1409) [`6732667`](https://github.com/frontman-ai/frontman/commit/673266773033f17eb9b6a7ad6929a753b18fdd75) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Use explicit new-tab sign-in and sign-out flows in top-level and embedded Frontman clients. Ensure WordPress installations receive the updated hosted client instead of a browser-cached bundle.

## 1.0.4

### Patch Changes

- [#1336](https://github.com/frontman-ai/frontman/pull/1336) [`01667f2`](https://github.com/frontman-ai/frontman/commit/01667f23231e9d63a6ff201a82ed1581bea8f85a) Thanks [@dependabot](https://github.com/apps/dependabot)! - Align the Sury runtime and PPX on `sury@11.0.0-alpha.10`.

- [#1318](https://github.com/frontman-ai/frontman/pull/1318) [`45139a1`](https://github.com/frontman-ai/frontman/commit/45139a10873190798ada2af674f49ba4f837836f) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Advertise output schemas only for browser tools that return structured content.

- [#1393](https://github.com/frontman-ai/frontman/pull/1393) [`fe076d1`](https://github.com/frontman-ai/frontman/commit/fe076d146d405ac287fc226d11a9668bff3b1f0d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Instrument typed OAuth activation events without sending prompt or relay error details to analytics.

- [#1311](https://github.com/frontman-ai/frontman/pull/1311) [`3589e66`](https://github.com/frontman-ai/frontman/commit/3589e666cd9726fd559f6a6113d1d036436861e4) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Remove unsupported provider-key injection from framework runtime HTML, client settings, ACP metadata, and MCP tool-result metadata. Tool-result persistence now strips result metadata, while account-saved BYOK and provider OAuth remain unchanged.

  Make MCP tool-result `_meta` optional and generic, align WordPress results with that contract, and stop exposing the unused absolute source root to browser runtime configuration.

- [#1314](https://github.com/frontman-ai/frontman/pull/1314) [`59604b7`](https://github.com/frontman-ai/frontman/commit/59604b75efebd4a11d93c9496b152ab26ab4ba83) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Share typed text, image, audio, link, and resource content across MCP and ACP.

- [#1317](https://github.com/frontman-ai/frontman/pull/1317) [`5c25668`](https://github.com/frontman-ai/frontman/commit/5c25668ddf5f708b81ea19ab2dd7eb811c1f4b5a) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Preserve and generically render typed multipart MCP tool content through ACP.

- [#1315](https://github.com/frontman-ai/frontman/pull/1315) [`41f323a`](https://github.com/frontman-ai/frontman/commit/41f323ae561dc0d6192aeb4bb56356efd24896d2) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Preserve structured tool arguments through ACP `rawInput`.

- [#1316](https://github.com/frontman-ai/frontman/pull/1316) [`9402b2e`](https://github.com/frontman-ai/frontman/commit/9402b2e91b4133b56db5448ad818bd1e82ba4c85) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Preserve structured MCP tool results through ACP `rawOutput`.

## 1.0.3

### Patch Changes

- [#1292](https://github.com/frontman-ai/frontman/pull/1292) [`6097f0b`](https://github.com/frontman-ai/frontman/commit/6097f0be83ab3ff3a79f06306fd63fae21534481) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Add Astro 7 support while preserving Astro 5 and 6 compatibility. Raise the minimum Node.js version to 22.19, support Sätteri and unified Markdown processors, restore source annotations under Astro's Rust compiler, harden component prop capture, honor Astro's trailing-slash policy, and keep preview URLs synchronized during client-side navigation.

## 1.0.2

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

## 1.0.1

### Patch Changes

- [#1112](https://github.com/frontman-ai/frontman/pull/1112) [`9b8fea7`](https://github.com/frontman-ai/frontman/commit/9b8fea73ab3ba4354ede9157deade5cb920b6f16) Thanks [@itayadler](https://github.com/itayadler)! - Serialize annotated element CSS selectors and clarify that `execute_js` is for inspection/navigation, not source-of-truth edits.

- [#1154](https://github.com/frontman-ai/frontman/pull/1154) [`2786253`](https://github.com/frontman-ai/frontman/commit/2786253055f47bc2715884acd61b71b256f31727) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Cleanly leave ACP channels and disconnect the Phoenix socket when Frontman unmounts.

- [#1130](https://github.com/frontman-ai/frontman/pull/1130) [`c2d7e23`](https://github.com/frontman-ai/frontman/commit/c2d7e23a7fc79f0941bf1abcfe86181070f5620d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Return MCP-standard tool results for text and image content.

- [#1172](https://github.com/frontman-ai/frontman/pull/1172) [`0f87d0d`](https://github.com/frontman-ai/frontman/commit/0f87d0d7133f77ac5ddb193afad768ffb5051744) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Fix no-API-key errors to show provider configuration and keep annotation chips within message bounds.

- [#1151](https://github.com/frontman-ai/frontman/pull/1151) [`4089f7f`](https://github.com/frontman-ai/frontman/commit/4089f7fcd1f31aaf1e7c17bd59072df558031d88) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Remove backend default model selection and let the client choose the first available model option.

- [#1160](https://github.com/frontman-ai/frontman/pull/1160) [`ed80e09`](https://github.com/frontman-ai/frontman/commit/ed80e09ab233e5097c8e70ce7c33be674a08854a) Thanks [@dependabot](https://github.com/apps/dependabot)! - Update ReScript/Sury integration for `sury@11.0.0-alpha.5` and regenerate protocol JSON schemas.

## 1.0.0

### Major Changes

- [#1117](https://github.com/frontman-ai/frontman/pull/1117) [`bd25abe`](https://github.com/frontman-ai/frontman/commit/bd25abeae89df34517dfd2c87cbe9818f58f4c9d) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Rename the ChatGPT OAuth surface to OpenAI and simplify provider auth resolution.

  Breaking change: client state, actions, selectors, and OAuth endpoints now use OpenAI names instead of ChatGPT names. Existing selected-model localStorage values with the `openai:` prefix are migrated to `openai_codex:` automatically.

## 0.10.2

### Patch Changes

- [#1025](https://github.com/frontman-ai/frontman/pull/1025) [`0f92b89`](https://github.com/frontman-ai/frontman/commit/0f92b89da7bee9044a64bbd139c2ed43bfb36181) Thanks [@itayadler](https://github.com/itayadler)! - Add NVIDIA provider key forwarding and settings support.

- [#1058](https://github.com/frontman-ai/frontman/pull/1058) [`e39a7e8`](https://github.com/frontman-ai/frontman/commit/e39a7e817d70c383099a7f229a3bf25eb3ed1d30) Thanks [@dependabot](https://github.com/apps/dependabot)! - Upgrade Tailwind CSS to 4.2.4.

- [#1047](https://github.com/frontman-ai/frontman/pull/1047) [`9ac299c`](https://github.com/frontman-ai/frontman/commit/9ac299c380a64f4c03bd9e3874d3950e7382a41f) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Drive task prompt guidance from explicit project traits emitted by each framework adapter.

- [#1062](https://github.com/frontman-ai/frontman/pull/1062) [`40d489e`](https://github.com/frontman-ai/frontman/commit/40d489eb181867a6e83870ab77c0494fd7cc9a6f) Thanks [@dependabot](https://github.com/apps/dependabot)! - Fix Vitest 4 CI coverage runs by aligning test dependency versions and hook callbacks.

- [#1075](https://github.com/frontman-ai/frontman/pull/1075) [`118c7f8`](https://github.com/frontman-ai/frontman/commit/118c7f865ef510e2356f2ff7d724943e856ea978) Thanks [@BlueHotDog](https://github.com/BlueHotDog)! - Reduce local console noise from expected connection cleanup and settings modal accessibility warnings.

## 0.10.1

### Patch Changes

- [#1012](https://github.com/frontman-ai/frontman/pull/1012) [`9b645f8`](https://github.com/frontman-ai/frontman/commit/9b645f85e286e9a65e7ca0de3a43767ddb7aab51) Thanks [@dependabot](https://github.com/apps/dependabot)! - Align React and ReactDOM dependency ranges for the ReactDOM update.

## 0.10.0

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

## 0.9.0

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

## 0.8.0

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

## 0.7.0

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
