# Implementation Plan: Append-Only Turn Start Refactor

## Overview

Refactor prompt submission so accepted user messages persist immediately as immutable session-history events. Agent execution starts turns serially by appending a `TurnStarted` event that includes all accepted user messages not already part of a turn. `UserMessage` rows are never mutated to represent execution state.

## Architecture Decisions

- `UserMessage` means accepted user-authored session event only.
- `TurnStarted` means execution started for one turn and references one or more accepted `UserMessage` ids.
- Starting a turn is append-only: no `UserMessage.turn_number` mutation, no `UserMessage.status`, no queue table.
- Turn-start boundary includes all accepted messages visible in one DB transaction.
- Messages accepted after `TurnStarted` commits remain accepted history for the next turn.
- `session/prompt` response means accepted, not completed.
- Running/idle/requires-action state comes from session updates, not prompt promise lifecycle.
- Retry stays mostly unchanged until normal accepted-message submit semantics are stable.

## Current Progress Snapshot

- Domain foundation is in place: accepted `UserMessage` rows have nil `turn_number`; normal execution starts from `TurnStarted`.
- `start_next_turn/3` exists as the DB-backed claim boundary. It locks the task row, ignores accepted-only messages for active-run detection, claims all unclaimed accepted messages visible at claim time, and appends one `TurnStarted`.
- Execution prompt building now reads current-turn user input from `TurnStarted.user_message_ids`, not `UserMessage(turn_number=N)`.
- `Tasks.submit_user_message/2` now accepts and persists a `UserMessage` without starting execution or requiring `mcp_tools` / `project_traits`.
- Shared task test fixtures now model a started turn as accepted `UserMessage` plus `TurnStarted`; no normal test fixture should insert `UserMessage(turn_number)`.
- `mix test test/frontman_server/tasks_test.exs` passes.
- ACP `user_message` protocol support is implemented with the strict documented shape: `sessionUpdate`, `messageId`, and `content` only.
- ACP `state_update` protocol support is implemented on server and ReScript clients for `running`, `idle`, and `requires_action`.
- `TaskChannel.process_prompt/3` now emits accepted `user_message` and returns `{}` immediately for normal prompt acceptance.
- `TaskChannel.pending_prompt` and `resolve_pending_prompt/3` have been deleted. Turn completion no longer resolves JSON-RPC `session/prompt` requests.
- `TaskChannel.finalize_turn/3` emits `state_update idle` for completed/cancelled turns. `AgentPaused` emits `state_update requires_action`.
- `queued_prompt` has been deleted. Prompts are accepted and persisted even while MCP initializes.
- `TaskChannel.ensure_noreply/1` and `process_queued_prompt_if_ready/1` are deleted; no deferred JSON-RPC prompt lives in channel assigns.
- Client `promptResult` is now an acceptance response (`unit` / `{}`), and prompt acceptance no longer dispatches `TurnCompleted`.
- Client-side `agent_turn_complete` no longer resolves pending prompt requests. It parses as `Unknown` instead of first-class protocol data.
- Client `isSendingPrompt`, `PromptSent`, and the already-sending rejection are deleted. Sending while another prompt is in flight now emits another send effect.
- Client running state now comes from `state_update`: `AddUserMessage` no longer sets `isAgentRunning`; `state_update running` sets it; `state_update idle` clears it; `state_update requires_action` clears it but does not yet create `pendingQuestion`.
- Prompt input remains editable while the agent runs. Text/attachments/annotations submit while running; Stop appears only when running with empty input.
- The task reducer no longer silently drops streaming/tool updates solely because `isAgentRunning=false`; valid streamed updates process, invalid follow-ups fail through existing invariants.
- `mix test test/frontman_server_web/channels/task_channel_test.exs` passes. The reconnect/resume nil-text crash is fixed by converting valid tool-call-only assistant responses to textless Swarm assistant messages.
- `make test` in `libs/client` passes (311 tests) after prompt-send/running-state/UI changes and legacy `TurnCompleted` deletion.
- `make test` in `libs/frontman-client` passes (87 tests) after `state_update` parsing and prompt-resolution cleanup.
- Root `make rescript-build` passes in this worktree.
- Minimal wake/drain is implemented without a separate `TurnRunner` module: `Tasks.run_next_turn/3` claims with `start_next_turn/3`, broadcasts committed `TurnStarted`, starts `Execution.run/4`, and returns without waiting for Swarm completion.
- **All execution test files now pass with accept-then-wake pattern** (104 execution tests across `execution_test.exs`, `execution_image_history_test.exs`, `mcp_tool_routing_test.exs`, `mcp_tool_broadcast_test.exs`, `error_propagation_test.exs`).
- **Full server suite: `mix test` in `apps/frontman_server` passes with 746 tests** after legacy migration, sequence-order cleanup, and stale MCP string-id answer removal.
- Execution test files adapted using per-file `submit_user_message_and_run` helpers that call `Tasks.submit_user_message/2` then `Tasks.run_next_turn/3`.
- Legacy `UserMessage(turn_number=N)` rows are migrated by appending `TurnStarted` rows that reference old user-message row ids, then clearing `turn_number` on those `UserMessage` rows. No runtime legacy bridge was added.
- `InteractionSchema.ordered/1` now orders by persisted `sequence` directly. The old `coalesce(sequence, 0)` fallback and nil-sequence compatibility test were deleted after sequence backfill coverage.

## Lessons Learned

- `TurnStarted.user_message_ids` currently stores interaction row ids, not embedded `UserMessage.id` values. Keep that convention unless a migration deliberately changes storage shape.
- Old raw-map inserts are incompatible with typed polymorphic embeds. Normal tests should create domain structs through `InteractionSchema.create_changeset/3`; raw SQL belongs only in legacy migration tests.
- Legacy raw SQL rows need the polymorphic `__type__` discriminator in `data` so Ecto can load them after migration tests run.
- Existing tests that count interaction rows must include `TurnStarted`; one logical turn setup now persists at least two rows: accepted `UserMessage` and `TurnStarted`.
- `record_interaction/3` still persists and broadcasts together. Claim/runner work should remain careful not to broadcast `TurnStarted` until commit is complete.
- Context7/official ACP docs confirm `session/update user_message` exists, but the documented v2 shape is only `messageId` plus `content`; `timestamp` and `_meta.frontman.dev/clientRequestId` on `user_message` were removed because they were invented locally.
- ACP `session/prompt` acceptance response is now `{}` in this worktree. Current stable v1 docs still describe completion response with `stopReason`, so treat this as an intentional ACP v2/RFD migration and keep schema/tests aligned.
- Accepted `user_message` now renders through the client message path without ACP timestamps. Live sends use server-only rendering: `AddUserMessage` sends/clears local state, and the canonical server `UserMessage(_)` inserts the visible chat message. No `clientRequestId` reconciliation path was added.
- `TurnStarted` is not an ACP history item. `ACPHistory` now projects it to `[]` so `session/load` can stream history without crashing on domain-only claim events.
- Full channel tests exposed and now cover a resumed execution prompt-context bug: reconnect/resume paths can build tool-call-only assistant responses with nil text. Valid tool-call-only responses now convert to textless Swarm assistant messages; nil content without tool calls still crashes.
- Phoenix 1.7.2+ socket draining matters here: channel assigns are not durable during deploy/shutdown/reconnect. That reinforces deleting `queued_prompt`; accepted prompts must persist before MCP readiness instead of living only in a channel process.
- `session/update state_update` is the correct replacement for turn completion coupling. Completion state can move independently from prompt acceptance once clients consume `running`/`idle`/`requires_action`.
- `pending_prompt` was pure lifecycle coupling after prompt acceptance moved to `{}`. Removing it simplified cancel/finalize paths and made turn completion session-update-only.
- `agent_turn_complete` no longer exists as first-class protocol data. Client prompt promises resolve only from JSON-RPC responses.
- `state_update requires_action` is not enough to construct `pendingQuestion`; it carries state only, not question content or resolver callbacks. Existing question-tool payloads still own `pendingQuestion` until a richer requires-action protocol is designed.
- `AddUserMessage` implying execution start was wrong. Accepted messages and execution state are separate facts; running starts on `state_update running`.
- `isSendingPrompt` was redundant once `session/prompt` means acceptance. Removing it made concurrent sends possible and removed the local already-sending rejection.
- Running-state UI gating was too broad. Prompt input and toolbar can stay usable while execution runs; only Stop is conditional on running with empty input.
- Dropping stream/tool updates because local `isAgentRunning=false` hid real ordering bugs. With queued acceptance and state updates, local running can be stale; valid streamed updates should process, invalid follow-ups should crash loudly through existing invariants.
- Server protocol schema JSON must be regenerated whenever Sury protocol types change; otherwise Elixir contract tests validate against stale generated schemas.
- Root ReScript verification passes in this worktree.
- Server `build_agent_turn_complete_notification/2` is deleted; no production server code builds legacy completion notifications.
- ReScript protocol and client provider no longer expose or handle `AgentTurnComplete`; legacy `agent_turn_complete` parses through `Unknown` and does not resolve prompts.
- Do not introduce `TurnRunner` as a broad new concept casually. Current slice uses `Tasks.run_next_turn/3` as the tiny delivery wrapper around `start_next_turn/3` plus `Execution.run/4`; only add a module/supervisor if durability or ownership needs require it.
- Tests that still expect submit-time execution must either be rewritten to use explicit started-turn fixtures or wait for runner wake behavior. Do not make `submit_user_message/2` start execution again to appease those tests.
- `state_update running` must be emitted after `TurnStarted` commits. It should not be inferred from accepted `UserMessage` or local optimistic submit.
- Tests in `execution/` subdirectory files (`mcp_tool_routing_test.exs`, `mcp_tool_broadcast_test.exs`, `error_propagation_test.exs`) all needed a per-file `submit_user_message_and_run` helper because they called `Tasks.submit_user_message/2` directly and expected it to start execution. The pattern is: submit, then `run_next_turn`, then assert execution behavior.
- `mcp_tool_broadcast_test.exs` has a "MCP tool registration timing" test in its own `describe` block with a separate `setup` — the helper pattern works across all test `describe` scopes.
- `error_propagation_test.exs` had a `\ ` vs `\\` syntax error after first automated patch pass; verify helper syntax when refactoring across multiple files.
- Full server suite now passes, including all 104 execution tests. Client suites: 311 (libs/client) + 87 (libs/frontman-client). This was the first time all three suites passed together with the accept-then-wake pattern.
- Later full server verification passes with 746 tests after broader suite inclusion, deletion of obsolete nil-sequence compatibility, and stale MCP string-id answer tests. Treat 746 as the current server baseline.
- `20260630000000_backfill_turn_started_for_user_messages.exs` is the legacy-data cutoff: old turn-numbered user messages become accepted messages plus `TurnStarted`. Prefer data migration over runtime readers/bridges.
- In the legacy migration, `TurnStarted.sequence` must use the first referenced user-message sequence. If it is inserted after terminal events, migrated completed turns can look active.
- `InteractionSchema.ordered/1` no longer protects nil `sequence`; nil sequence is now invalid persisted state. If a test creates nil sequence rows, it is preserving obsolete pre-backfill behavior.
- Migration tests that use raw SQL must provide `images: []` for `UserMessage` data when they expect canonical history replay, because typed embeds load those rows before `ACPHistory` projects them.

## Dependency Graph

```text
Immutable accepted UserMessage validation
  -> TurnStarted interaction
    -> start_next_turn function
      -> Prompt builder uses TurnStarted references
        -> Submit accepts without execution
          -> Protocol accepted-message/state updates
            -> Channel prompt lifecycle removal
              -> Lazy runner wake/drain
                -> Client prompt/running-state changes
                  -> History cleanup + legacy removal
```

## Phase 1: Append-Only Domain Foundation

### Task 1: Make UserMessage Accepted-Only

**Status:** Done in current worktree.

**Description:** Update interaction validation so `UserMessage` can be persisted as a task/session-scoped accepted event without an execution turn. Keep turn requirements for execution-bound interactions.

**Acceptance criteria:**
- [x] Accepted `UserMessage` without `turn_number` is valid.
- [x] `UserMessage` with `turn_number` is rejected.
- [x] Agent responses, tool calls, tool results, terminal events still require positive `turn_number`.
- [x] No validation path treats accepted `UserMessage` as active-run starter.

**Verification:**
- [x] Server tests cover accepted `UserMessage` without turn.
- [x] Server tests cover rejection of `UserMessage` with turn.
- [x] Server tests cover rejection of nil turns for execution-bound interactions.
- [x] Full `mix test` in `apps/frontman_server` passes.

**Dependencies:** None

**Files likely touched:**
- `apps/frontman_server/lib/frontman_server/tasks/interaction_schema.ex`
- `apps/frontman_server/test/frontman_server/tasks/interaction_schema_test.exs`

**Estimated scope:** S

### Task 2: Add TurnStarted Interaction

**Status:** Done in current worktree.

**Description:** Add append-only `TurnStarted`/`ExecutionStarted` interaction type that starts normal execution for a turn and references one or more accepted user messages in order.

**Acceptance criteria:**
- [x] `TurnStarted` requires positive `turn_number`.
- [x] `TurnStarted` requires non-empty ordered `user_message_ids`.
- [x] `TurnStarted` serializes/deserializes through typed polymorphic interaction storage.
- [x] `UserMessage` remains immutable accepted-message event.

**Implementation notes:**
- `Interaction.TurnStarted` owns embedded-data validation through its embedded changeset.
- `InteractionSchema` owns row-level validation such as `turn_number`.
- Interaction storage now uses typed polymorphic embeds, so old raw-map test inserts need updates.

**Verification:**
- [x] Interaction schema tests cover valid and invalid `TurnStarted`.
- [x] Serialization tests cover `user_message_ids` round trip.
- [x] Full `mix test` in `apps/frontman_server` passes.

**Dependencies:** Task 1

**Files likely touched:**
- `apps/frontman_server/lib/frontman_server/tasks/interaction.ex`
- `apps/frontman_server/lib/frontman_server/tasks/interaction_schema.ex`
- `apps/frontman_server/test/frontman_server/tasks/interaction_schema_test.exs`

**Estimated scope:** M

### Task 3: Do Not Add Separate Turn-Message Storage

**Status:** Done by architecture choice; no separate storage added.

**Description:** Do not add a join table, queue table, JSON uniqueness trigger, or separate turn-message reference. The architecture uses one turn-start path plus OTP runner ownership as the primary serialization mechanism. The database transaction and task row lock remain a correctness backstop.

**Acceptance criteria:**
- [x] No queue table added.
- [x] No separate turn-message table added.
- [x] Multiple accepted `UserMessage` rows can exist without execution turns.
- [x] Duplicate turn-start protection is covered by `start_next_turn/3` transaction tests and task-row locking; DB constraints remain deferred.

**Verification:**
- [x] No migration needed for separate turn-message storage.
- [x] Focused tests prove `start_next_turn/3` does not start duplicate active turns.

**Dependencies:** Task 2

**Files likely touched:**
- `apps/frontman_server/test/frontman_server/tasks_test.exs`

**Estimated scope:** M

## Checkpoint: Domain Foundation

- [x] `UserMessage` accepted-event tests pass.
- [x] `TurnStarted` schema/serialization tests pass.
- [x] No separate queue/turn-message storage exists.
- [x] No implementation mutates `UserMessage` to start turn work.

## Phase 2: Turn Start Boundary

### Task 4: Add `start_next_turn/3`

**Status:** Done in current worktree.

**Description:** Add DB-backed turn-start function that locks task, checks active run, selects all accepted user messages not already included in a turn, allocates next turn, and appends one `TurnStarted` event.

**Acceptance criteria:**
- [x] Returns `{:ok, task, turn_started}` after starting turn with all accepted messages not already in a turn.
- [x] Returns `:no_accepted_messages` when no accepted user messages are available.
- [x] Returns `:already_running` when a started turn lacks terminal event.
- [x] Returns `:missing_execution_context` when live context is absent.
- [x] Does not update any `UserMessage` row.

**Verification:**
- [x] Unit tests cover turn-start success, no accepted messages, already running, missing context.
- [x] Test proves two accepted messages are included in one `TurnStarted`.
- [x] `mix test test/frontman_server/tasks_test.exs` passes.
- [x] Full `mix test` in `apps/frontman_server` passes.

**Implementation notes:**
- Claim return name is `:no_accepted_messages` in current code, not `:no_work`.
- Claim appends `TurnStarted`; it does not start `Execution.run/4`.
- Existing task-row lock/transaction serialized concurrent starts in focused tests.

**Dependencies:** Tasks 1-3

**Files likely touched:**
- `apps/frontman_server/lib/frontman_server/tasks.ex`
- `apps/frontman_server/test/frontman_server/tasks_test.exs`
- `apps/frontman_server/test/support/fixtures/tasks.ex`

**Estimated scope:** M

### Task 5: Prove Turn Start Serialization

**Status:** Done in current worktree.

**Description:** Add concurrent start-next-turn test proving two wakeups cannot include same accepted messages in two active turns or start two active turns.

**Acceptance criteria:**
- [x] Concurrent turn starts produce at most one `TurnStarted` for accepted batch.
- [x] Second starter gets `:already_running` or `:no_accepted_messages`.
- [x] No accepted `UserMessage` id appears in two started turns.

**Verification:**
- [x] Focused concurrent test passes.
- [x] `mix test test/frontman_server/tasks_test.exs:156` passes with temp `MIX_HOME`/`HEX_HOME`.
- [x] `mix test test/frontman_server/tasks_test.exs:111` passes with temp `MIX_HOME`/`HEX_HOME`.
- [x] `mix test test/frontman_server/tasks_test.exs` passes after fixture migration.
- [x] Full `mix test` in `apps/frontman_server` passes.

**Implementation notes:**
- No production changes were needed for serialization; existing task-row lock/transaction serialized concurrent starts.
- `TurnStarted.user_message_ids` store interaction row ids, not embedded `UserMessage.id` values.

**Dependencies:** Task 4

**Files likely touched:**
- `apps/frontman_server/test/frontman_server/tasks_test.exs`

**Estimated scope:** S

### Task 6: Update Active-Run And Model Lookup

**Status:** Done in current worktree.

**Description:** Move active-run detection and normal-turn model lookup from `UserMessage(turn_number=N)` semantics to `TurnStarted` semantics. Keep `AgentRetry` path intact for now.

**Acceptance criteria:**
- [x] Active normal run is derived from `TurnStarted(turn=N)` without terminal event.
- [x] Accepted-only `UserMessage` rows never make a task active.
- [x] `model_for_turn/2` resolves normal turn metadata through `TurnStarted` and referenced messages or stored metadata.
- [x] Retry active-run behavior remains unchanged.

**Verification:**
- [x] Tests cover accepted message while idle does not report active run.
- [x] Tests cover `TurnStarted` without terminal reports active run.
- [x] Tests cover model lookup for normal started turn.
- [x] `mix test test/frontman_server/tasks_test.exs:73 test/frontman_server/tasks_test.exs:156 test/frontman_server/tasks_test.exs:335 test/frontman_server/tasks_test.exs:359` passes with temp `MIX_HOME`/`HEX_HOME`.
- [x] `mix test test/frontman_server/tasks_test.exs` passes after fixture migration.
- [x] Full `mix test` in `apps/frontman_server` passes.

**Implementation notes:**
- `active_agent_run_turn_number/1` now treats `:turn_started` and `:agent_retry` as run starters.
- `:user_message` rows with nil `turn_number` are accepted history and ignored by active-run detection.
- `model_for_turn/2` resolves from `TurnStarted.user_message_ids`; ids refer to interaction row ids, not embedded message ids.

**Dependencies:** Task 4

**Files likely touched:**
- `apps/frontman_server/lib/frontman_server/tasks.ex`
- `apps/frontman_server/test/frontman_server/tasks_test.exs`

**Estimated scope:** M

## Checkpoint: Turn Start Safe

- [x] `start_next_turn/3` tested.
- [x] Concurrent turn-start test passing.
- [x] Active-run detection ignores accepted-only messages.
- [x] No duplicate active turn possible by DB transaction/task-row lock in focused tests.
- [x] Lazy runner/wake ownership is implemented as `Tasks.run_next_turn/3` plus channel self-wake, without a dedicated `TurnRunner` module.

## Phase 3: Execution Prompt And Acceptance Split

### Task 7: Build Execution Prompt From TurnStarted

**Status:** Done in current worktree.

**Description:** Update prompt building so current turn input comes from `TurnStarted.user_message_ids`, not from `UserMessage(turn_number=N)`. Preserve accepted order and keep retry from adding new user messages.

**Acceptance criteria:**
- [x] Accepted user messages not included in the current turn are excluded from Swarm prompt.
- [x] All user messages referenced by current `TurnStarted` are included in accepted order.
- [x] Multiple accepted messages included in a turn are represented deterministically as one combined user block or ordered user blocks.
- [x] Retry path does not synthesize a new user message.

**Verification:**
- [x] Execution prompt tests cover exclusion of accepted messages not in the current turn.
- [x] Execution prompt tests cover multi-message started turn.
- [x] `mix test test/frontman_server/tasks/execution_test.exs:374 test/frontman_server/tasks/execution_test.exs:403` passes with temp `MIX_HOME`/`HEX_HOME`.
- [x] Retry prompt tests still pass through full server suite.
- [x] Full `mix test` in `apps/frontman_server` passes.

**Implementation notes:**
- `Execution` uses `InteractionSchema.prompt_context_for_turn/2`; query logic stays in schema, not execution orchestration.
- Prompt building expands only `TurnStarted.user_message_ids` into Swarm user messages.
- Accepted-but-unclaimed `UserMessage` rows are loaded for lookup context but convert to no prompt messages.
- Historical images still decay through the existing historical-message rule.
- Simplification pass removed `maybe_` naming and collapsed duplicate `TurnStarted` branches.

**Dependencies:** Tasks 4, 6

**Files likely touched:**
- `apps/frontman_server/lib/frontman_server/tasks/execution.ex`
- `apps/frontman_server/test/frontman_server/tasks/execution_test.exs`

**Estimated scope:** M

### Task 8: Change `submit_user_message/2` To Accept Only

**Status:** Done in current worktree.

**Description:** Make submit persist immutable accepted `UserMessage` and return quickly without turn allocation, `mcp_tools`, `project_traits`, or `Execution.run/4`.

**Acceptance criteria:**
- [x] Submit persists accepted `UserMessage` without execution turn.
- [x] Submit succeeds while active run exists.
- [x] Submit no longer returns `:already_running` for normal user messages.
- [x] First accepted message still triggers title generation.

**Verification:**
- [x] Server tests cover submit while running.
- [x] Server tests prove no `TurnStarted` is appended by submit itself.
- [x] `mix test test/frontman_server/tasks_test.exs` passes.
- [x] `mix test` in `apps/frontman_server`.

**Implementation notes:**
- `Tasks.submit_user_message/2` now accepts `task_id`, `message`, and `model`; extra execution-context keys from existing channel callers are ignored during migration.
- Submit records an accepted `UserMessage` with nil `turn_number` and returns `{:ok, accepted_message, nil}`.
- Submit-time task row locking, turn allocation, active-run rejection, and `Execution.run/4` call were removed from the submit path.
- `insert_user_turn_for_locked_task/3` and `insert_user_turn_if_idle/2` were deleted.
- Focused tests pass: `mix test test/frontman_server/tasks_test.exs:91` and `mix test test/frontman_server/tasks_test.exs:110`.
- Shared task fixtures now create accepted `UserMessage` plus `TurnStarted` instead of legacy `UserMessage(turn_number)`.
- `tasks_test.exs` raw legacy migration helpers bypass typed changesets deliberately; normal helpers use typed interaction structs.

**Remaining caveat:** none for normal prompt acceptance. `TaskChannel.process_prompt/3` now accepts, emits canonical `user_message`, replies `{}`, and wakes the runner.

**Dependencies:** Task 7

**Files likely touched:**
- `apps/frontman_server/lib/frontman_server/tasks.ex`
- `apps/frontman_server/test/frontman_server/tasks_test.exs`
- `apps/frontman_server/test/support/fixtures/tasks.ex`

**Estimated scope:** M

### Task 9: Add Accepted User Message Protocol Builder

**Status:** Done in current worktree.

**Description:** Add server and ReScript protocol support for canonical accepted user message updates with server-owned `messageId`.

**Acceptance criteria:**
- [x] Server builds `session/update` with `sessionUpdate: "user_message"`.
- [x] ReScript protocol parses accepted `UserMessage` updates.
- [x] Legacy `user_message_chunk` is no longer used as accepted-message transport.

**Verification:**
- [x] Server protocol tests pass: `mix test test/protocols/acp_contract_test.exs`.
- [x] ReScript protocol/client tests pass: `make test` in `libs/frontman-client`.
- [x] Package-level protocol/client tests pass; root `make rescript-build` passes.

**Implementation notes:**
- Strict ACP shape is `sessionUpdate`, `messageId`, and `content` only. Do not add `timestamp` or `_meta` to `user_message` unless ACP docs change.
- `promptResultSchema` was also changed to parse `{}` as acceptance response because normal `session/prompt` now returns immediately.
- `AgentTurnComplete` has been removed from the protocol; legacy wire values parse as `Unknown`.

**Dependencies:** Task 8

**Files likely touched:**
- `apps/frontman_server/lib/agent_client_protocol.ex`
- `libs/frontman-protocol/src/FrontmanProtocol__ACP.res`
- `libs/frontman-client/test/FrontmanClient__ACP__Client.test.res`

**Estimated scope:** M

## Checkpoint: Acceptance Path

- [x] Submit accepts while running.
- [x] Accepted messages persist without execution mutation.
- [x] Accepted message protocol update round-trips.
- [x] Prompt builder uses `TurnStarted` references.

## Phase 4: Channel Prompt Lifecycle And Runner

### Task 10: Emit Accepted Message On Prompt Acceptance

**Status:** Done for normal prompt acceptance.

**Description:** After `Tasks.submit_user_message/2` persists accepted message, channel emits accepted user message update and returns prompt success immediately.

**Acceptance criteria:**
- [x] `session/prompt` response is success on acceptance for normal prompt submission.
- [x] Accepted user message update is emitted after persistence.
- [x] Normal prompt response no longer waits for turn completion.

**Verification:**
- [x] Focused channel test asserts immediate `{}` response and accepted `user_message` notification.
- [x] Queued-prompt-after-MCP test was updated to assert accepted update plus `{}` response.
- [x] Full `mix test` in `apps/frontman_server`.

**Implementation notes:**
- `TaskChannel.process_prompt/3` no longer passes ignored execution-context fields to `Tasks.submit_user_message/2`.
- Normal submit no longer assigns `pending_prompt` and no longer handles submit-time `:already_running`.
- `queued_prompt` no longer stores unpersisted prompts while MCP initializes; prompts persist and reply before MCP readiness.
- `pending_prompt`, `resolve_pending_prompt/3`, `queued_prompt`, and `ensure_noreply/1` are deleted.
- `ACPHistory` projects `TurnStarted` to `[]` because it is a domain claim event, not chat history.

**Dependencies:** Task 9

**Files likely touched:**
- `apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex`
- `apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs`

**Estimated scope:** M

### Task 11: Add State Update Protocol

**Status:** Done in current worktree.

**Description:** Add server and ReScript protocol builders/parsers for `state_update` with `running`, `idle`, and `requires_action`.

**Acceptance criteria:**
- [x] Server can build `state_update running`.
- [x] Server can build `state_update idle` with stop reason.
- [x] Server can build `state_update requires_action`.
- [x] ReScript client parses state updates.

**Verification:**
- [x] Protocol tests pass: `mix test test/protocols/acp_contract_test.exs`.
- [x] `make test` in `libs/frontman-client`.
- [x] `make rescript-build` at repo root passes.

**Implementation notes:**
- Server builder emits strict `session/update` with `sessionUpdate: "state_update"`, `state`, and optional `stopReason`.
- ReScript protocol has `StateUpdate({state, stopReason})` with `running`, `idle`, and `requires_action` states.
- ACP JSON schemas were regenerated from Sury schemas.

**Dependencies:** Task 9

**Files likely touched:**
- `apps/frontman_server/lib/agent_client_protocol.ex`
- `libs/frontman-protocol/src/FrontmanProtocol__ACP.res`

**Estimated scope:** S

### Task 12: Add Lazy Runner Wake/Drain

**Description:** Add short-lived runner that calls `start_next_turn/3`, emits `state_update running` after `TurnStarted` commits, starts `Execution.run/4`, then exits.

**Status:** Done in current worktree.

**Current note:** Implemented as `Tasks.run_next_turn/3`, not a new `TurnRunner` module. A previous module/supervisor WIP was removed because it added a concept before the cleanup slice was small and green. Current wrapper claims one turn, broadcasts committed `TurnStarted`, starts existing Swarm execution, and exits.

**Acceptance criteria:**
- [x] Runner wrapper starts one execution turn and returns.
- [x] Runner wrapper exits on no work, already running, or missing context.
- [x] Runner wrapper does not wait for Swarm execution completion.
- [x] Runner wrapper starts execution with messages included by `TurnStarted`.
- [x] Dedicated module/supervisor ownership not added (intentionally kept as thin `Tasks` wrapper).

**Verification:**
- [x] Focused execution test covers accepted message draining through `run_next_turn/3`.
- [x] All execution test suites pass with accept-then-wake pattern (104 execution tests).
- [x] Full `mix test` in `apps/frontman_server` passes.

**Dependencies:** Tasks 4-7, 11

**Files likely touched:**
- `apps/frontman_server/lib/frontman_server/tasks.ex`
- `apps/frontman_server/lib/frontman_server/tasks/turn_runner.ex`
- `apps/frontman_server/test/frontman_server/tasks/turn_runner_test.exs`

**Estimated scope:** M

### Task 13: Wake Runner From Channel Lifecycle

**Status:** Done in current worktree.

**Description:** Call runner wake after prompt acceptance, MCP ready/failed, session load/reconnect, and terminal turn persistence.

**Acceptance criteria:**
- [x] Prompt before MCP ready is accepted and visible.
- [x] MCP ready wakes turn start.
- [x] Terminal success/error wakes next turn start.
- [x] Reconnect/session load wakes turn start after live context exists.

**Verification:**
- [x] Channel test covers MCP-pending prompt accepted before init and drained after init.
- [x] Channel test covers `session/load` draining accepted work created outside channel prompt flow.
- [x] Channel test covers terminal wake with a queued follow-up message.
- [x] Full `mix test` in `apps/frontman_server` passes.

**Dependencies:** Task 12

**Files likely touched:**
- `apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex`
- `apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs`

**Estimated scope:** M

### Task 14: Emit Idle/Requires Action On Finalize

**Status:** Done in current worktree.

**Description:** Replace completion lifecycle signal with state updates after terminal interactions persist.

**Acceptance criteria:**
- [x] Completed turn emits `state_update idle`.
- [x] Paused/question turn emits `state_update requires_action` through `AgentPaused` finalization.
- [x] Legacy `agent_turn_complete` no longer exists as a first-class protocol update; old wire values parse as `Unknown` and do not resolve prompt requests.

**Verification:**
- [x] Focused channel finalize tests assert state updates.
- [x] Existing completion tests mostly rewritten. `execution_test.exs` now passes with acceptance plus explicit `run_next_turn/3` wake semantics.
- [x] Full `mix test` in `apps/frontman_server`.

**Implementation notes:**
- `TaskChannel.finalize_turn/3` now pushes `state_update idle` for completed/cancelled turns.
- `AgentPaused` now pushes `state_update requires_action` instead of `agent_turn_complete`.
- Server `build_agent_turn_complete_notification/2` is deleted.
- ReScript `AgentTurnComplete` variant is deleted; legacy wire updates parse as `Unknown`.
- Focused tests pass: `mix test test/frontman_server_web/channels/task_channel_test.exs:467 test/frontman_server_web/channels/task_channel_test.exs:829 test/frontman_server_web/channels/task_channel_test.exs:1450`.
- Full channel suite now passes after the reconnect/resume nil-text fix.

**Dependencies:** Task 11

**Files likely touched:**
- `apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex`
- `apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs`

**Estimated scope:** M

## Checkpoint: Server Turn Start E2E

- [x] Multiple prompt submissions accepted (channel tests plus execution tests).
- [x] Runner starts one turn with all accepted messages visible at turn-start time (`start_next_turn/3` tests).
- [x] Execution drains serially by appending `TurnStarted` per batch (execution tests + full test suite passes).
- [x] No normal submit returns `Agent already running` (accept returns `{:ok, message, nil}`).
- [x] State updates reflect running/idle/requires-action (finalize tests + `execution_test.exs`).

## Phase 5: Remove Long Prompt And Channel-Held Deferred Prompts

### Task 15: Delete `pending_prompt`

**Status:** Done in current worktree.

**Description:** Remove channel assign and helper that resolve prompt JSON-RPC responses on turn completion.

**Acceptance criteria:**
- [x] No `pending_prompt` assign remains.
- [x] `resolve_pending_prompt/3` is deleted.
- [x] Cancel path does not depend on pending prompt turn.

**Verification:**
- [x] Focused channel tests pass: `mix test test/frontman_server_web/channels/task_channel_test.exs:394 test/frontman_server_web/channels/task_channel_test.exs:451 test/frontman_server_web/channels/task_channel_test.exs:829 test/frontman_server_web/channels/task_channel_test.exs:1450`.
- [x] Grep finds no `pending_prompt` or `resolve_pending_prompt` in `apps/frontman_server`.

**Implementation notes:**
- `TaskChannel.finalize_turn/3` no longer resolves JSON-RPC prompt requests.
- Turn errors and completions now publish session updates only.
- Cancel retry cleanup emits cancelled idle state without consulting prompt lifecycle assigns.

**Dependencies:** Tasks 10, 14

**Files likely touched:**
- `apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex`
- `apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs`

**Estimated scope:** S

### Task 16: Delete Channel-Held Deferred Prompt

**Status:** Done in current worktree.

**Description:** Remove `queued_prompt` and `ensure_noreply`; prompts persist before MCP readiness and runner starts a turn when context arrives.

**Acceptance criteria:**
- [x] No `queued_prompt` assign remains.
- [x] No deferred JSON-RPC prompt stored in channel.
- [x] MCP pending prompt test now asserts persisted accepted message.

**Verification:**
- [x] Channel tests pass.
- [x] Grep finds no `queued_prompt` or `ensure_noreply`.

**Implementation notes:**
- `handle_prompt/3` no longer waits for MCP readiness before accepting a prompt.
- `process_queued_prompt_if_ready/1`, `ensure_noreply/1`, and the `queued_prompt` assign were deleted.
- Focused test proves prompt before MCP ready persists and replies before initialization completes.

**Dependencies:** Task 13

**Files likely touched:**
- `apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex`
- `apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs`

**Estimated scope:** S

## Phase 6: Client Protocol And State

### Task 17: Make `sendPrompt` Resolve On Acceptance

**Status:** Done in current worktree.

**Description:** Remove client-side dependency on `agent_turn_complete` for resolving `session/prompt`.

**Acceptance criteria:**
- [x] Normal `sendPrompt` resolves from the JSON-RPC `{}` acceptance response.
- [x] `AgentTurnComplete` no longer resolves pending prompt requests.
- [x] Prompt result type becomes unit/acceptance-compatible if server returns `{}`.

**Verification:**
- [x] `frontman-client` tests pass.
- [x] `libs/client` tests pass.
- [x] `make rescript-build`.
- [x] `make test` in `libs/frontman-client` passes after removing `AgentTurnComplete` prompt-resolution fallback.

**Implementation notes:**
- `Client__State__StateReducer` no longer dispatches `TurnCompleted` from prompt `onComplete`; prompt `onComplete` now means accepted only.
- `AgentTurnComplete` no longer exists as a protocol variant; legacy wire values parse as `Unknown` and do not resolve `session/prompt` requests.

**Dependencies:** Tasks 10, 15

**Files likely touched:**
- `libs/frontman-client/src/FrontmanClient__ACP__Protocol.res`
- `libs/frontman-client/src/FrontmanClient__ACP.res`
- `libs/frontman-client/test/FrontmanClient__ACP__Client.test.res`

**Estimated scope:** M

### Task 18: Remove `isSendingPrompt`

**Status:** Done in current worktree.

**Description:** Let multiple prompts send while a session is active. Remove prompt-send blocking state and already-sending rejection.

**Acceptance criteria:**
- [x] No `isSendingPrompt` field remains.
- [x] No `PromptSent` action remains.
- [x] Sending while prior prompt is in flight creates another send effect.
- [x] Cancel depends on active session, not sending state.

**Verification:**
- [x] `Client__ConnectionReducer` tests pass.
- [x] `make test` in `libs/client`.
- [x] `make rescript-build` at repo root passes.

**Implementation notes:**
- Removed prompt-send state from `Client__ConnectionReducer` and `Client__FrontmanProvider` context.
- `SendPromptEffect` no longer dispatches a completion action for local send state.
- `CancelPrompt` now only requires an active session.

**Dependencies:** Task 17

**Files likely touched:**
- `libs/client/src/Client__ConnectionReducer.res`
- `libs/client/test/Client__ConnectionReducer.test.res`
- `libs/client/src/Client__FrontmanProvider.res`

**Estimated scope:** M

### Task 19: Drive Running State From `state_update`

**Status:** Mostly done in current worktree.

**Description:** Add client handling for `StateUpdate` and stop treating local user message insertion as execution start.

**Acceptance criteria:**
- [x] `AddUserMessage` does not set running state.
- [x] `state_update running` sets task execution running.
- [x] `state_update idle` clears running.
- [ ] `state_update requires_action` drives pending action state.

**Verification:**
- [x] Client task reducer tests pass.
- [x] State reducer tests pass.
- [x] `make test` in `libs/client`.
- [x] `make rescript-build` at repo root passes.

**Implementation notes:**
- `Client__FrontmanProvider` now handles `StateUpdate` and dispatches task execution-state actions.
- `ExecutionStateRunning`, `ExecutionStateIdle`, and `ExecutionStateRequiresAction` were added to the task reducer.
- `requires_action` currently clears running state but does not create `pendingQuestion`; question payloads still drive `pendingQuestion` through existing question-tool actions.

**Dependencies:** Tasks 11, 18

**Files likely touched:**
- `libs/client/src/Client__FrontmanProvider.res`
- `libs/client/src/state/Client__Task__Reducer.res`
- `libs/client/src/state/Client__Task__Types.res`
- `libs/client/test/Client__Task.test.res`

**Estimated scope:** M

### Task 20: Reconcile Accepted User Messages

**Status:** Done via server-only render.

**Description:** Handle server-owned `UserMessage` updates by rendering only on server acceptance.

**Acceptance criteria:**
- [x] Accepted `user_message` update creates visible message.
- [x] Duplicate optimistic/server message is avoided by not inserting optimistic messages.
- [x] Session load replays accepted user messages whether or not they are included in a prior turn.

**Verification:**
- [x] Client tests cover accepted update and session load.
- [x] `make rescript-build`.

**Implementation notes:**
- Chosen policy: server-only render. Strict ACP `user_message` has no timestamp, so the client preserves server push order during load and uses local receipt time only as message metadata. No `clientRequestId` is needed.

**Dependencies:** Tasks 9, 19

**Files likely touched:**
- `libs/client/src/Client__FrontmanProvider.res`
- `libs/client/src/state/Client__State__StateReducer.res`
- `libs/client/src/state/Client__Task__Reducer.res`
- `libs/client/test/Client__State__StateReducer.test.res`

**Estimated scope:** M

## Phase 7: UI While Running Behavior

### Task 21: Keep Prompt Input Enabled While Running

**Status:** Mostly done in current worktree.

**Description:** Update prompt input so text submission accepts a new message while execution is running; stop/cancel remains separate or empty-input behavior.

**Acceptance criteria:**
- [x] Input remains editable while running.
- [x] Submit button sends content while running.
- [x] Toolbar does not disable solely because agent is running.
- [x] Stop remains available without replacing content submit.

**Verification:**
- [x] Prompt input tests pass via `make test` in `libs/client`.
- [ ] Manual check: send second message during active run.
- [x] `make test` in `libs/client`.
- [x] `make rescript-build` at repo root passes.

**Implementation notes:**
- Running state no longer disables the contenteditable input.
- Toolbar remains interactive while the agent runs.
- The main button submits when text, attachments, or annotations exist. It shows Stop only while running with empty input.
- Removed the running-only `Waiting for response...` placeholder; normal placeholder stays available.

**Dependencies:** Tasks 18-19

**Files likely touched:**
- `libs/client/src/components/frontman/Client__PromptInput.res`
- `libs/client/src/Client__Chatbox.res`
- `libs/client/src/Client__TopBar.res`

**Estimated scope:** M

### Task 22: Update Running Props And Visuals

**Status:** Mostly done in current worktree.

**Description:** Rename or reshape `isAgentRunning` usage around execution-state semantics without broad UI redesign.

**Acceptance criteria:**
- [x] Thinking/tool visuals still appear during running.
- [ ] Retry UI does not depend on prompt input owning stop behavior.
- [x] Stale streaming guards do not drop valid updates solely because local running state is false.

**Verification:**
- [x] Client tests pass: `make test` in `libs/client`.
- [ ] Manual check: running, idle, requires-action visual states.
- [x] `make rescript-build` at repo root passes.

**Implementation notes:**
- Removed the task reducer guard that silently dropped streaming/tool updates when `isAgentRunning=false`.
- Valid streamed updates now process regardless of local running flag; invalid tool follow-ups hit existing invariant failures instead of disappearing.

**Dependencies:** Task 21

**Files likely touched:**
- `libs/client/src/Client__Chatbox.res`
- `libs/client/src/Client__TopBar.res`
- `libs/client/src/components/frontman/Client__ToolGroupBlock.res`
- `libs/client/src/components/frontman/Client__RetryBanner.res`

**Estimated scope:** M

## Checkpoint: Client E2E

- [ ] User can submit while agent is running (client code supports it; manual browser flow not verified).
- [x] Multiple submitted messages are visible through server-owned accepted `user_message` updates.
- [x] Prompt promise resolves on acceptance (server returns `{}`).
- [x] Running/idle UI follows `state_update` (client parses and dispatches `StateUpdate`; input enabled while running).

## Phase 8: History And Cleanup

### Task 23: Replay Accepted User Messages Canonically

**Status:** Done in current worktree.

**Description:** Update history replay so all accepted user messages replay as accepted `user_message` updates, whether or not a `TurnStarted` references them.

**Acceptance criteria:**
- [x] Session load shows accepted messages not yet included in a turn.
- [x] Session load shows messages included by prior `TurnStarted`.
- [x] `_userMsgBuffer` no longer needed after migration.

**Verification:**
- [x] Server history tests pass.
- [x] Client load-session/history tests pass.

**Implementation notes:**
- `ACPHistory` projects `UserMessage` as strict canonical `user_message` updates and `TurnStarted` as `[]`.
- Grep finds no live `_userMsgBuffer` or `user_message_chunk` accepted-message transport.
- Verified in this slice with focused server/channel tests and `make test` in `libs/client`.

**Dependencies:** Tasks 9, 20

**Files likely touched:**
- `apps/frontman_server/lib/frontman_server_web/protocols/acp_history_impl.ex`
- `libs/client/src/Client__FrontmanProvider.res`
- `libs/client/test/Client__LoadSessionFlow.test.res`

**Estimated scope:** M

### Task 24: Remove Legacy Completion Transport

**Status:** Done in current worktree.

**Description:** Remove `AgentTurnComplete` and prompt-result completion semantics after state updates and accepted responses are authoritative.

**Acceptance criteria:**
- [x] No client code handles `AgentTurnComplete`.
- [x] No server code builds completion notification for normal turns.
- [x] `promptResult.stopReason` no longer required for prompt acceptance.

**Verification:**
- [x] Grep finds no active `AgentTurnComplete` handling outside legacy tests/docs.
- [x] `make rescript-build` at repo root passes.
- [x] Focused server tests pass, including `mix test test/frontman_server/tasks/execution_test.exs` after migrating stale submit-time execution assumptions.

**Implementation notes:**
- `AgentTurnComplete` variant and schema branch were removed from `FrontmanProtocol__ACP.res`.
- `Client__FrontmanProvider` no longer dispatches `TurnCompleted` from completion notifications.
- Existing legacy `agent_turn_complete` wire values now parse as `Unknown`, preserving parse visibility without first-class behavior.
- Client `TurnCompleted` reducer action and public action creator were deleted; `ExecutionStateIdle` owns streaming completion.

**Dependencies:** Tasks 14, 17, 23

**Files likely touched:**
- `apps/frontman_server/lib/agent_client_protocol.ex`
- `libs/frontman-protocol/src/FrontmanProtocol__ACP.res`
- `libs/frontman-client/src/FrontmanClient__ACP__Protocol.res`

**Estimated scope:** M

### Task 25: Remove Submit-Time Execution Helpers

**Status:** Done in current worktree.

**Description:** Delete old helpers and comments that encode submit as execution start or `UserMessage` as turn starter.

**Acceptance criteria:**
- [x] `insert_user_turn_for_locked_task` removed or replaced by turn-start append path.
- [x] `insert_user_turn_if_idle` removed.
- [x] `Tasks.submit_user_message` has no execution context args.
- [x] Comments/docs reflect accept/start-turn lifecycle.

**Verification:**
- [x] Grep confirms removed helper names.
- [x] Server tests pass.

**Implementation notes:**
- This slice removed a stale retry/stop comment and collapsed redundant prompt/runner branches without adding behavior.
- Grep finds no live old helper names, prompt lifecycle assigns, legacy chunk/buffer symbols, or client prompt-send blocker symbols.

**Dependencies:** Tasks 8, 12, 15

**Files likely touched:**
- `apps/frontman_server/lib/frontman_server/tasks.ex`
- `apps/frontman_server/lib/frontman_server/tasks/interaction.ex`

**Estimated scope:** S

### Task 26: Backfill Or Bridge Legacy Turn-Numbered UserMessages

**Status:** Done in current worktree via backfill migration, no runtime bridge.

**Description:** Handle any existing `UserMessage(turn_number=N)` rows by backfilling accepted messages plus `TurnStarted` events or by adding temporary legacy read support.

**Acceptance criteria:**
- [x] Existing history remains readable after refactor.
- [x] Existing `UserMessage(turn_number=N)` rows map to started turns.
- [x] Temporary legacy bridge not used.

**Verification:**
- [x] Migration/backfill test covers old turn-numbered user message rows.
- [x] Session load test covers legacy data.
- [x] Server tests pass.

**Implementation notes:**
- Added `20260630000000_backfill_turn_started_for_user_messages.exs`.
- Migration appends one `TurnStarted` per task/legacy turn, referencing old user-message row ids in persisted order, then clears `turn_number` from legacy `UserMessage` rows.
- `TurnStarted.sequence` uses the first referenced user message sequence so migrated completed turns do not appear active after terminal rows.
- Focused tests pass: `mix test test/frontman_server/tasks_test.exs test/frontman_server_web/channels/tasks_channel_test.exs`.
- Session/load legacy coverage lives in `tasks_channel_test.exs`; active-run legacy coverage lives in `tasks_test.exs`.

### Task 27: Remove Sequence-Order Fallback

**Status:** Done in current worktree.

**Description:** Remove obsolete nil-sequence ordering compatibility after sequence backfill coverage.

**Acceptance criteria:**
- [x] `InteractionSchema.ordered/1` orders by persisted `sequence` directly.
- [x] Stale nil-sequence compatibility test is deleted.
- [x] Queue docs reflect nil `sequence` as invalid persisted state.

**Verification:**
- [x] `mix format --check-formatted lib/frontman_server/tasks/interaction_schema.ex test/frontman_server/tasks_test.exs`.
- [x] `mix test test/frontman_server/tasks_test.exs` passes.
- [x] Full `mix test` in `apps/frontman_server` passes with 746 tests.

**Implementation notes:**
- Existing sequence migrations backfill old rows and all normal writes generate `sequence`.
- Removing `coalesce(sequence, 0)` makes ordering assumptions explicit instead of hiding corrupted or pre-migration data.

**Dependencies:** Tasks 2-3, 23

**Files likely touched:**
- `apps/frontman_server/priv/repo/migrations/*`
- `apps/frontman_server/lib/frontman_server/tasks/execution.ex`
- `apps/frontman_server/lib/frontman_server_web/protocols/acp_history_impl.ex`

**Estimated scope:** M

## Final Checkpoint

- [x] `mix test` in `apps/frontman_server`.
- [x] `make rescript-build` at repo root.
- [x] `make test` in `libs/client`.
- [x] `make test` in `libs/frontman-client`.
- [ ] Manual browser flow: submit message, submit second while first runs, observe accepted message.
- [ ] Manual browser flow: submit multiple messages before runner starts a turn, observe one turn containing all accepted messages.
- [x] Changesets exist in `.changeset/` for this refactor work.

## Parallelization

- Safe after Task 9: client parsing and state-update handling can proceed with mocked updates.
- Safe after Task 11: client running-state work can proceed while runner implementation continues.
- Safe after Task 20: UI while-running behavior can proceed while history cleanup continues.
- Must be sequential: Tasks 1-7, because append-only domain and turn-start semantics are foundation.
- Must be sequential: Tasks 15-16 after prompt acceptance and runner wake exist.
- Needs coordination: exact `TurnStarted.user_message_ids` storage shape before server/client/history split.

## Risks And Mitigations

| Risk | Impact | Mitigation |
|---|---:|---|
| Two runners start duplicate active turns | High | OTP runner ownership plus Task 5 concurrent turn-start test and DB row lock |
| User message included in two turns | High | Single turn-start path plus row-lock transaction; add storage constraint only if tests prove needed |
| Prompt accepted but never runs after MCP ready | High | Task 13 wake tests for MCP/session/terminal |
| Prompt builder orders batched messages incorrectly | Medium | Task 7 multi-message order test |
| Client duplicates sent and accepted messages | Medium | Task 20 removed optimistic insertion; accepted server update is the only visible user message |
| Legacy `UserMessage(turn_number=N)` history breaks | Low | Task 26 data migration backfills accepted messages plus `TurnStarted`; no runtime bridge |
| State updates and legacy completion double-update UI | Low | Legacy completion transport removed from first-class server/client protocol; legacy wire parses as `Unknown` |
| Retry semantics regress | Medium | Keep retry immediate until accepted-message semantics stable |
| Strict ACP `user_message` lacks timestamp but client message state requires one | Medium | Task 20 must add timestamp-free accepted-message reconciliation or an explicit local timestamp policy |
| Reconnect/resume execution prompt builder still emits nil text | Low | Fixed for valid tool-call-only assistant responses; nil content without tool calls still crashes loudly |
| Nil sequence rows order incorrectly | Low | Sequence migrations repair legacy rows; `ordered/1` no longer hides nil sequence |

## Open Questions

- Should `TurnStarted.user_message_ids` stay as embedded event data permanently, or later need normalized storage for reporting/performance?
- Should batched user messages become one combined Swarm user message or multiple ordered user messages?
- Server acceptance is the first user-message render; no optimistic user-message rendering.
- Should accepted messages wait forever when MCP context never returns, or fail after timeout?
- Is OTP runner ownership plus DB row lock enough for deployment, or is cluster-wide runner ownership required now?
- Should retry stay immediate permanently, or move to accepted/start-turn flow after normal accepted-message flow is stable?
- Should accepted `user_message` rendering use a client-local received timestamp, persisted interaction timestamp via Frontman extension elsewhere, or a timestamp-free message state?
