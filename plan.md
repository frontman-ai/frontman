# Implementation Plan: ACP-Compliant Agent Attribution

## Overview

Move agent attribution from ACP mode/config-option state into a versioned Frontman ACP extension. Session responses provide a validated agent catalog, every user and assistant content chunk carries stable message identity and agent metadata, and live and replay paths produce equivalent client state. Standard ACP mode support remains available but no longer controls attribution.

This plan is implementation-ready after human approval. It deliberately leaves the existing model `currentValue` ACP mismatch out of scope.

## Architecture Decisions

- Capability advertisement uses nested metadata: `_meta["frontman.dev"]["agentAttribution"]["version"] = 1`.
- Session metadata uses `_meta["frontman.dev/agents"]`.
- Message metadata uses `_meta["frontman.dev/agentId"]` and `_meta["frontman.dev/timestamp"]`.
- Timestamp is required for Frontman-attributed user and assistant chunks and must be RFC 3339.
- Session catalog is separate from `configOptions`; model configuration remains unchanged.
- Catalog entries contain `id`, `name`, `displayName`, `description`, and explicit `#RRGGBB` color. Client never infers a color.
- New turns persist an agent display snapshot in `TurnStarted`. Loaded-session catalog is stable-order union of active agents and historical snapshots, keyed by ID.
- Legacy turns without snapshots resolve current agent configuration once at replay. Missing legacy definitions fail session load server-side; they are never remapped to default agent.
- Assistant `messageId` is deterministic: persisted `TurnStarted.id` plus zero-based `AgentResponse` ordinal within that turn. Live channel increments ordinal only when persisted `AgentResponse` closes a response segment. This preserves text segments separated by tool calls.
- User `messageId` is persisted user interaction row ID. All blocks from one user message share this ID.
- On user chunks, `agentId` means selected execution target for that message, not message author.
- `session/load` preserves ACP ordering: history notifications precede the success response. The low-level client buffers replay until it validates the response catalog, then delivers buffered updates in wire order.
- Negotiated v1 makes session catalog and chunk attribution mandatory. Without negotiation, generic ACP behavior remains valid and Frontman-specific metadata is ignored.
- Malformed known attributed updates fail visibly. Unknown ACP update variants remain ignorable.
- `CurrentModeUpdate` remains in protocol types; only attribution dependence and agent mode options are removed.

## Non-Goals

- Implementing genuine ACP session modes.
- Fixing model config options missing ACP-required `currentValue`.
- Adding `agent_thought_chunk` support.
- Adding an agent selection UI.
- Changing prompt metadata currently used to select execution agent.

## Dependency Graph

```text
Task 1 extension contract
  ├── Task 2 typed metadata schemas
  │     ├── Task 3 initialize negotiation
  │     ├── Task 5 server session catalog
  │     └── Task 9 client catalog state
  ├── Task 4 historical agent snapshots
  │     └── Task 5 server session catalog
  └── Task 6 stable assistant identity
        ├── Task 7 standard server chunks
  └── Task 11 shared task history projection and ACP encoding

Tasks 3 + 5
  └── Task 8 session load transport ordering

Tasks 2 + 3 + 8 + 9
  └── Task 10 attributed client streaming

Tasks 8 + 11
  └── Task 12 session replay channel wiring

Tasks 7 + 10 + 12
  └── Task 13 reducer assembly

Tasks 4 + 6 + 7 + 8 + 11 + 12 + 13
  └── Task 14 remove attribution misuse

Tasks 1-14
  └── Task 15 compliance matrix and final verification
```

## Task List

### Phase 1: Contract and Protocol Foundation

- [x] Task 1: Publish extension contract
- [x] Task 2: Add typed extension metadata schemas
- [x] Task 3: Negotiate extension version during initialize

## Task 1: Publish Extension Contract

**Description:** Document one normative wire contract before implementation. Include negotiation, catalog ownership, chunk attribution, timestamps, message identity, historical snapshots, failure behavior, generic-client behavior, stable ordering, and versioning. Update existing changeset instead of creating another one.

**Acceptance criteria:**

- [x] Complete examples cover initialize request/response, session new/load, multi-block user chunks, assistant chunks, and generic clients.
- [x] Required versus optional fields and v1 failure semantics are unambiguous.
- [x] Historical snapshot and legacy-row policies match architecture decisions above.

**Verification:**

- [x] Review every metadata key against target contract examples.
- [x] Confirm docs contain no root-level custom ACP fields.
- [x] Confirm `.changeset/show-agent-message-colors.md` describes protocol and replay behavior accurately.

**Dependencies:** None

**Files likely touched:**

- `docs/acp-agent-attribution.md`
- `.changeset/show-agent-message-colors.md`

**Estimated scope:** Small: 2 files

## Task 2: Add Typed Extension Metadata Schemas

**Description:** Define Sury-backed protocol types for capability metadata, catalog entries, session metadata, and message metadata. Keep unrelated `_meta` keys accepted while validating Frontman-owned keys strictly.

**Acceptance criteria:**

- [x] Valid capability, catalog, and message metadata parse and serialize without key relocation.
- [x] Empty identity fields, duplicate IDs, malformed colors, invalid timestamps, and malformed advertised v1 metadata fail.
- [x] Unrelated `_meta` keys remain accepted.

**Verification:**

- [x] Tests pass: `make -C libs/frontman-client test`
- [x] Schemas generate: `make -C libs/frontman-protocol check-schemas`

**Dependencies:** Task 1

**Files likely touched:**

- `libs/frontman-protocol/src/FrontmanProtocol__ACP.res`
- `libs/frontman-client/test/FrontmanClient__ACP__Types.test.res`
- `libs/frontman-protocol/scripts/ExportSchemas.res`
- `libs/frontman-protocol/schemas/acp/*` generated outputs

**Estimated scope:** Medium: 3 authored areas plus generated schemas

## Task 3: Negotiate Extension Version During Initialize

**Description:** Advertise client v1 support, advertise server v1 support, parse both advertisements, and expose negotiated version to session/update handling. Unsupported or absent versions disable Frontman-specific parsing without breaking base ACP.

**Acceptance criteria:**

- [x] Frontman client initialize request advertises v1 only under `_meta`.
- [x] Server initialize response advertises v1 only under `_meta`.
- [x] Client records `None` or negotiated v1 explicitly; malformed advertised v1 fails initialization.

**Verification:**

- [x] Tests pass: `make -C libs/frontman-client test`
- [x] Focused server tests pass: `mix test test/protocols/acp_contract_test.exs` from `apps/frontman_server`.
- [x] Existing initialize fixtures without `_meta` still parse.

**Dependencies:** Task 2

**Files likely touched:**

- `libs/frontman-client/src/FrontmanClient__ACP.res`
- `libs/frontman-client/src/FrontmanClient__ACP__Client.res`
- `libs/frontman-client/test/FrontmanClient__ACP__Client.test.res`
- `apps/frontman_server/lib/agent_client_protocol.ex`
- `apps/frontman_server/test/protocols/acp_contract_test.exs`

**Estimated scope:** Medium: 5 files

## Checkpoint: Protocol Foundation

- [x] Human approves contract and architecture decisions.
- [x] Initialize request and response round-trip with and without extension metadata.
- [x] Local generated schemas are current.
- [x] No agent data uses ACP modes in new contract.

### Phase 2: Catalog and Identity Foundation

- [x] Task 4: Persist historical agent snapshots
- [x] Task 5: Return catalog in session results
- [x] Task 6: Establish stable assistant identity
- [x] Task 7: Emit standard attributed chunks

## Task 4: Persist Historical Agent Snapshots

**Description:** Extend `TurnStarted` with immutable agent display data captured from validated backend agent configuration. New turns always persist snapshot; legacy rows remain readable under explicit replay policy.

**Acceptance criteria:**

- [x] New `TurnStarted` interactions persist ID, name, display name, description, and color snapshot.
- [x] Snapshot validation rejects incomplete fields and non-`#RRGGBB` colors before turn start.
- [x] Existing rows without snapshot still deserialize and are marked for legacy resolution.

**Verification:**

- [x] Focused tests pass: `mix test test/frontman_server/tasks_test.exs test/frontman_server/tasks/interaction_test.exs` from `apps/frontman_server`.
- [x] Automated fixture check confirms renamed active agent does not alter newly persisted historical snapshot.

**Dependencies:** Task 1

**Files likely touched:**

- `apps/frontman_server/lib/frontman_server/tasks/interaction.ex`
- `apps/frontman_server/lib/frontman_server/tasks.ex`
- `apps/frontman_server/lib/frontman_server/agents.ex`
- `apps/frontman_server/test/frontman_server/tasks_test.exs`
- `apps/frontman_server/test/frontman_server/tasks/interaction_test.exs`

**Estimated scope:** Medium: 5 files

## Task 5: Return Catalog in Session Results

**Description:** Build validated session catalog from active agents plus historical snapshots, add it to both session result builders, and wire `session/new`. Task 8 wires `session/load` while changing replay ordering. Remove agent entries from session config options only after client catalog consumption lands in Task 9.

**Acceptance criteria:**

- [x] New and loaded session results use identical catalog schema and stable ordering.
- [x] Duplicate IDs with conflicting snapshots fail server-side; exact duplicate definitions deduplicate.
- [x] Every historical agent ID emitted by planned replay resolves in loaded catalog.

**Verification:**

- [x] Server contract tests pass: `mix test test/protocols/acp_contract_test.exs` from `apps/frontman_server`.
- [x] Builder tests prove both session result shapes include `_meta["frontman.dev/agents"]`; `session/new` channel test proves transport.
- [x] Generic ACP schema validation accepts session results.

**Dependencies:** Tasks 2 and 4

**Files likely touched:**

- `apps/frontman_server/lib/agent_client_protocol.ex`
- `apps/frontman_server/lib/frontman_server_web/channels/tasks_channel.ex`
- `apps/frontman_server/test/protocols/acp_contract_test.exs`
- `apps/frontman_server/test/frontman_server_web/channels/tasks_channel_test.exs`

**Estimated scope:** Medium: 4 files

## Task 6: Establish Stable Assistant Identity

**Description:** Track response-segment identity in `TaskChannel` using persisted `TurnStarted.id` and per-turn `AgentResponse` ordinal. Preserve turn number on live chunk events, start one ID at first content chunk, and close it when matching `AgentResponse` persistence event arrives.

**Acceptance criteria:**

- [x] All content chunks in one persisted response share deterministic message ID.
- [x] Tool-separated responses in one turn receive distinct IDs.
- [x] Wrong turn, chunk without active turn, or response close without active segment fails visibly.

**Verification:**

- [x] Focused `task_channel_test.exs` cases pass for plain response, tool-separated response, stale turn event, and concurrent task channels.
- [x] Derived live IDs match IDs generated from persisted fixture rows.

**Dependencies:** Task 1

**Files likely touched:**

- `apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex`
- `apps/frontman_server/lib/frontman_server/tasks.ex`
- `apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs`

**Estimated scope:** Medium: 3 files

## Task 7: Emit Standard Attributed Chunks

**Description:** Replace custom aggregate `user_message` with standard `user_message_chunk`; align user and agent chunk shapes with ACP `ContentChunk`; place identity, attribution, and timestamp correctly. Emit one user chunk per content block.

**Acceptance criteria:**

- [x] User and agent chunk variants contain standard `content`, optional ACP `messageId` represented as required by Frontman v1, and `_meta`.
- [x] Attribution and timestamp occur only in `_meta`; every user block repeats same message ID and metadata.
- [x] Agent chunks use Task 6 identity and current turn agent; malformed known chunks do not degrade to `Unknown`.

**Verification:**

- [x] Protocol/client tests pass: `make -C libs/frontman-client test`.
- [x] Server builder/channel tests pass for text, image, annotation, embedded context, and assistant text.
- [x] Schemas are current: `make -C libs/frontman-protocol check-schemas`.

**Dependencies:** Tasks 2 and 6

**Files likely touched:**

- `libs/frontman-protocol/src/FrontmanProtocol__ACP.res`
- `libs/frontman-client/test/FrontmanClient__ACP__Types.test.res`
- `apps/frontman_server/lib/agent_client_protocol.ex`
- `apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex`
- Server protocol/channel tests

**Estimated scope:** Medium: 5 files

## Checkpoint: Server Live Path

- [x] Session new returns complete catalog.
- [x] One-block and multi-block user messages emit standard chunks.
- [x] Plain and tool-separated assistant responses have stable IDs and direct attribution.
- [x] No live assistant chunk requires preceding mode update.

### Phase 3: Client Catalog and Streaming

- [x] Task 8: Deliver catalog before replay transport
- [x] Task 9: Store and resolve catalog in application state
- [x] Task 10: Buffer attributed chunks by message identity
- [x] Task 11: Build shared task history projection and ACP encoding
- [x] Task 12: Wire replay through the session channel
- [x] Task 13: Assemble protocol messages in reducer

## Task 8: Deliver Catalog Before Replay Transport

**Description:** Preserve session result metadata in low-level client APIs. Preserve ACP-required history-before-response wire ordering while buffering load-time notifications in the low-level client. After the `session/load` response arrives, validate and install its catalog before delivering buffered replay updates in original wire order. Task 9 installs catalog in application state.

**Acceptance criteria:**

- [x] `createSession` preserves `sessionNewResult._meta`, and session-specific `session/load` returns validated catalog metadata from Task 5.
- [x] Load-result callback receives validated catalog metadata before any buffered replay update callback runs, while wire capture shows history notifications before the load response.
- [x] Fresh load, reconnect without history, and generic no-extension paths have explicit behavior.

**Verification:**

- [x] Frontman client tests assert callback ordering.
- [x] `task_channel_test.exs` asserts history pushes precede the load response; client tests assert buffered update callbacks run only after load-result handling.
- [x] Load without negotiated v1 remains functional.

**Dependencies:** Tasks 3 and 5

**Files likely touched:**

- `libs/frontman-client/src/FrontmanClient__ACP.res`
- `libs/frontman-client/src/FrontmanClient__ACP__Client.res`
- `libs/frontman-client/test/FrontmanClient__ACP__Client.test.res`
- `apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex`
- `apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs`

**Estimated scope:** Medium: 5 files

## Task 9: Store and Resolve Catalog in Application State

**Description:** Add independent catalog state, action, selector, and strict lookup. Dispatch catalog after session new/load before processing attributed updates. Keep model selection sourced only from config options.

**Acceptance criteria:**

- [x] Negotiated v1 state contains validated catalog after new and loaded sessions.
- [x] Agent lookup uses catalog ID and returns complete `Client__Agent.t`, including ID.
- [x] Missing catalog, duplicate IDs, and unknown agent IDs fail with useful messages; no fallback color or agent exists.

**Verification:**

- [x] Tests pass: `make -C libs/client test`.
- [x] Focused state tests prove catalog and model config update independently.

**Dependencies:** Tasks 2, 3, and 8

**Files likely touched:**

- `libs/client/src/Client__Agent.res`
- `libs/client/src/state/Client__State__Types.res`
- `libs/client/src/state/Client__State__StateReducer.res`
- `libs/client/src/state/Client__State.res`
- `libs/client/test/Client__Agent.test.res`

**Estimated scope:** Medium: 5 files

## Task 10: Buffer Attributed Chunks by Message Identity

**Description:** Replace task-level selected-agent buffering with chunk-local `(taskId, messageId, agentId)` buffering. Use collision-safe nested dictionaries or structured encoded keys; do not concatenate unescaped IDs.

**Acceptance criteria:**

- [x] A chunk can buffer without previous mode/config update.
- [x] Same task and message append only when agent matches; different message IDs flush independently.
- [x] Same message crossing tasks or changing agents fails; reset clears all identities.

**Verification:**

- [x] Focused tests pass: `make -C libs/client test`.
- [x] Buffer tests cover interleaved tasks, interleaved message IDs, agent mismatch, explicit flush, and reset.

**Dependencies:** Tasks 7 and 9

**Files likely touched:**

- `libs/client/src/Client__TextDeltaBuffer.res`
- `libs/client/src/Client__FrontmanProvider.res`
- `libs/client/test/Client__TextDeltaBuffer.test.res`
- `libs/client/test/Client__HistoryReplay.test.res`

**Estimated scope:** Medium: 4 files

## Task 11: Build Shared Task History Projection and ACP Encoding

**Description:** Centralize ordered row and turn context in `FrontmanServer.Tasks.History`, then encode that projection through a thin `AgentClientProtocol.History` boundary. Retain canonical interaction row IDs and turn numbers, derive response ordinals once, and generate the same IDs and metadata as the live path. Channel integration remains Task 12.

**Acceptance criteria:**

- [x] Replay emits standard user and agent chunks with valid catalog-resolvable agent IDs.
- [x] Replay assistant IDs exactly match Task 6 derivation, including tool-separated response ordinals.
- [x] Missing turn context, conflicting snapshots, and unavailable legacy agent definitions fail before any partial history is emitted.

**Verification:**

- [x] `acp_history_test.exs` covers plain, multi-block, tool-separated, legacy, removed-agent, and malformed histories.
- [x] One public ACP history function accepts ordered interaction rows and returns complete notifications or one error.
- [x] Replay emits no `current_mode_update` for attribution.

**Dependencies:** Tasks 4, 6, and 7

**Files likely touched:**

- `apps/frontman_server/lib/frontman_server/tasks.ex`
- `apps/frontman_server/lib/frontman_server/tasks/history.ex`
- `apps/frontman_server/lib/agent_client_protocol/history.ex`
- `apps/frontman_server/lib/agent_client_protocol/content.ex`
- `apps/frontman_server/test/protocols/acp_history_test.exs`

**Estimated scope:** Medium: 4 files

## Task 12: Wire Replay Through the Session Channel

**Description:** Replace inline history conversion in `TaskChannel` with Task 11 history projection and ACP encoding. Validate complete history before pushing any notification and preserve Task 8 ACP history-before-response wire ordering. Delete obsolete `TasksChannel session/load`; no repository client uses that second load path.

**Acceptance criteria:**

- [x] The sole session-load entry point calls the shared history encoder.
- [x] Replay failure returns one JSON-RPC error and emits no partial history.
- [x] Session catalog resolves every replayed agent before first history notification is pushed.

**Verification:**

- [x] `task_channel_test.exs` passes focused load/replay cases; `tasks_channel_test.exs` proves the obsolete load handler is absent.
- [x] Replay preserves user, assistant, tool, and terminal event ordering.
- [x] Session-specific channel emits complete validated history before the load response; client delivery remains catalog-first through buffering.

**Dependencies:** Tasks 5, 8, and 11

**Files likely touched:**

- `apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex`
- `apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs`
- `apps/frontman_server/lib/frontman_server_web/channels/tasks_channel.ex`
- `apps/frontman_server/test/frontman_server_web/channels/tasks_channel_test.exs`

**Estimated scope:** Medium: 4 files

## Task 13: Assemble Messages by Protocol Identity

**Description:** Change reducer actions and grouping rules to use protocol `messageId` and immutable `agentId`. Assemble repeated user content blocks once, append assistant deltas by ID, and preserve tool ordering without relying on active mode state.

**Acceptance criteria:**

- [x] Repeated user chunks with one ID create one message; adjacent distinct user IDs never merge.
- [x] Assistant chunks append only to matching message and agent; tool-separated IDs remain separate messages.
- [x] Live and replay fixtures yield equivalent message arrays, including concurrent tasks.

**Verification:**

- [x] Tests pass: `make -C libs/client test`.
- [x] Reducer tests cover ID mismatch, agent mismatch, duplicate/replayed chunks, tool boundaries, load completion, and concurrent tasks.
- [x] UI receives resolved catalog agent for every rendered user and assistant message.

**Dependencies:** Tasks 7, 9, 10, and 12

**Files likely touched:**

- `libs/client/src/state/Client__Message.res`
- `libs/client/src/state/Client__Task__Reducer.res`
- `libs/client/src/Client__FrontmanProvider.res`
- `libs/client/test/Client__Task.test.res`
- `libs/client/test/Client__State__ConcurrentTasks.test.res`

**Estimated scope:** Medium: 5 files

## Checkpoint: Replay Equivalence

- [x] Catalog is installed before first replay chunk.
- [x] Live and replay fixtures produce identical message IDs, attribution, timestamps, content, and ordering.
- [x] Removed agent with persisted snapshot renders stable display name and color.
- [x] Concurrent task streams cannot cross-contaminate message identity.

### Phase 4: Cleanup and Compliance

- [x] Task 14: Remove mode/config attribution paths
- [x] Task 15: Add upstream compliance matrix and complete non-browser verification

## Task 14: Remove Mode and Config Attribution Paths

**Description:** Remove agent mode options, mode-update emission for attribution, selected-agent buffer state, and UI lookup through config options. Preserve standard `CurrentModeUpdate` parsing for future genuine ACP mode support.

**Acceptance criteria:**

- [x] No agent catalog or lookup reads `configOptions`.
- [x] No attribution path emits or consumes `current_mode_update`.
- [x] Model config selection and prompt execution-agent selection remain unchanged.

**Verification:**

- [x] Repository search finds no calls to `build_current_mode_update_notification` outside genuine mode tests/helpers.
- [x] Repository search finds no `selectAgent` buffer API and no agent option with `category: "mode"`.
- [x] Model refresh and prompt tests pass.

**Dependencies:** Tasks 5, 9, 10, 11, 12, and 13

**Files likely touched:**

- `apps/frontman_server/lib/agent_client_protocol.ex`
- `apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex`
- `libs/client/src/Client__Agent.res`
- `libs/client/src/Client__Chatbox.res`
- Existing model/config tests

**Estimated scope:** Medium: 5 files

## Task 15: Add Upstream Compliance Matrix and Complete Verification

**Description:** Pin official ACP v1 schema source to an upstream commit, validate standard envelopes without network access, add Frontman extension behavior matrix, regenerate local schemas, and perform full automated and browser verification.

**Acceptance criteria:**

- [x] Initialize, session new/load, user chunk, agent chunk, unknown metadata, and generic-client fixtures validate against pinned upstream ACP v1 contract.
- [x] Frontman validation rejects malformed v1 metadata while generic ACP validation accepts ignorable extension metadata.
- [x] Behavior matrix covers negotiation absence/version mismatch, missing catalog, invalid color, missing/unknown agent ID, agent mutation, archived agent, and unrelated metadata.

**Verification:**

- [x] `make -C libs/frontman-protocol check-schemas`
- [x] `make -C libs/frontman-client check`
- [x] `make -C libs/client test`
- [x] `make -C apps/frontman_server precommit`
- [x] `make reanalyze`
- [x] `git diff --check`
- [ ] Browser check intentionally skipped at user request: live plain response, multi-block user message, tool-separated response, loaded history, and removed-agent snapshot all render correct chips.

**Dependencies:** Tasks 1-14

**Files likely touched:**

- `apps/frontman_server/test/protocols/acp_contract_test.exs`
- `libs/frontman-protocol/schemas/acp/upstream/*`
- Schema provenance/refresh documentation
- Generated `libs/frontman-protocol/schemas/acp/*`

**Estimated scope:** Medium: 4 authored areas plus generated schemas

## Checkpoint: Complete

- [x] Every task acceptance criterion passes.
- [x] All non-browser automated verification commands pass.
- [ ] Browser verifies live and replay behavior; intentionally skipped at user request.
- [x] Generic ACP fixture ignores all Frontman metadata.
- [x] Generated schemas and changeset are included in the feature commit.
- [x] Ready for code review.

## Parallelization Opportunities

| Work | Parallelization |
| --- | --- |
| Task 1 | Can run alone immediately; contract gates all code. |
| Tasks 3 and 4 | Safe in parallel after Task 2 because they touch separate client/protocol and persistence concerns. |
| Tasks 6 and 9 | Safe in parallel after their dependencies; coordinate only on agent/message type names. |
| Tasks 8 and 11 | Safe in parallel after dependencies; coordinate replay API and load ordering before Task 12. |
| Tasks 10 and 11 | Safe in parallel after Task 7 because one is client buffer and one is server replay. |
| Task 12 | Sequential after load transport and replay engine stabilize. |
| Task 13 | Sequential after client buffer and shared channel replay stabilize. |
| Tasks 14 and 15 | Sequential; compliance tests should inspect final cleanup state. |

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Load history races catalog installation | High | Preserve ACP history-before-response wire order, buffer replay client-side, install response catalog, then deliver buffered callbacks; assert both wire and callback order. |
| Tool calls split one turn into multiple assistant messages | High | Derive ID from persisted turn ID plus persisted response ordinal; test tool-separated flows first. |
| Legacy agent no longer exists | High | Resolve legacy snapshot before streaming and fail entire load if unavailable; never map to default agent. |
| Active and historical definitions conflict for same ID | High | Reject conflicting union entries server-side; require stable IDs or versioned new IDs. |
| Sury fallback hides malformed known chunks as `Unknown` | High | Parse discriminator first and make known attributed variants strict. |
| Broad reducer fixture churn masks regressions | Medium | Land buffer and reducer changes separately; retain live/replay equivalence fixtures throughout. |
| Generated local schema mistaken for upstream compliance | Medium | Pin separate official ACP fixture/schema with provenance and offline validation. |
| Both channels diverge during migration | Medium | Centralize replay before deleting duplicated behavior; test both session load entry points. |

## Open Questions for Human Approval

- [x] Approve persisted `TurnStarted` agent snapshots instead of immutable global registry or archived configuration records.
- [x] Approve deterministic assistant IDs based on `TurnStarted.id` plus `AgentResponse` ordinal.
- [x] Approve failing legacy session load when removed agent lacks persisted snapshot and current definition.
- [x] Remove legacy `session/load` handling on `TasksChannel`; repository clients use `TaskChannel`.

## Definition of Done

- [x] Every task has passed listed acceptance and non-browser verification checks.
- [x] Cross-layer protocol migration received independent correctness and architecture review.
- [x] Extension contract and generated schemas match emitted wire payloads.
- [x] No color or agent fallback exists.
- [x] No attribution path depends on mode-update ordering or agent config options.
- [x] Human approved plan before implementation begins.

## Separate Follow-Up

Existing model config options omit ACP-required `currentValue`. Fix separately because it changes model-selection ownership and `session/set_config_option` behavior.

Upstream prose currently shows `modeId` in one session-mode notification example while stable v1 schema defines `CurrentModeUpdate.currentModeId`. Follow stable generated schema. Attribution implementation does not depend on either field.
