# Queue Refactor Plan

## Goal

Make chat message submission instant and robust while reducing lifecycle complexity.

Users should be able to submit messages at any time. Submitted messages should always appear in the chat as accepted session history. Agent execution should drain accepted messages serially without tying user submit to long-running agent work.

This refactor should remove concepts where possible. Do not add a queue table or queue object. A turn-start interaction is required because interactions are append-only events; claiming execution must not mutate an accepted `UserMessage`.

Core move: `UserMessage` remains the accepted-message event. It is never mutated into execution state. Claiming execution appends a `TurnStarted`/`ExecutionStarted` event that references all unclaimed accepted `UserMessage` rows visible at claim time, in persisted order. Queueing falls out of persisted facts, not channel-held state.

## ACP v2 Alignment

The ACP v2 prompt lifecycle RFD changes `session/prompt` semantics:

- `session/prompt` response means the prompt was accepted, not that the agent turn completed.
- The agent owns session history and message IDs.
- The agent emits accepted user messages through `session/update`.
- Turn state should be communicated through session updates such as `state_update: running`, `idle`, or `requires_action`.

Frontman should move in this direction:

- `session/prompt` should return quickly after accepting and persisting the user message.
- Turn completion should not be encoded as a prompt response.
- Accepted user messages should be server-owned messages emitted back to the client.
- Running/idle/requires-action state should come from session updates.

ACP alignment is a consequence of the domain fix, not the first abstraction to build.

## Current Problem

Current prompt flow couples three separate concerns:

- Accepting a user message.
- Starting an agent run.
- Waiting for the agent run to finish.

That coupling creates complexity:

- `TaskChannel` keeps `pending_prompt` so it can answer the original JSON-RPC request when the run ends.
- `TaskChannel` keeps `queued_prompt` while MCP initializes.
- The client tracks `isSendingPrompt` and rejects concurrent sends.
- The server rejects messages when an agent is running.
- Turn completion is signaled twice: JSON-RPC prompt response and `agent_turn_complete` notification.
- Client code has special logic to resolve pending prompt requests from completion notifications.

This is why queued messages are hard to model today.

## Current Code Facts

This plan is grounded in implementation facts, not only ACP v2 direction. Some original facts have already been made false by the refactor.

Facts now false in current worktree:

- `Tasks.submit_user_message/2` no longer allocates `turn_number`, requires `mcp_tools` / `project_traits`, or calls `Execution.run/4`.
- `InteractionSchema.validate_turn_number/1` no longer requires accepted `UserMessage` rows to have `turn_number`; it rejects `UserMessage(turn_number)`.
- `@agent_run_starter_interaction_types` no longer includes `:user_message`; normal active-run detection starts from `:turn_started`.
- Shared task fixtures no longer insert `UserMessage(turn_number)` for normal started-turn setup; they insert accepted `UserMessage` plus `TurnStarted`.
- `TaskChannel.process_prompt/3` no longer assigns `pending_prompt` for normal prompt submission.
- Normal `session/prompt` response no longer waits for turn completion; it returns `{}` after accepted-message persistence.
- `promptResult.stopReason` is no longer required by the local protocol schema; `promptResult` now parses `{}` as acceptance.
- Prompt `onComplete` no longer dispatches `TurnCompleted` in `Client__State__StateReducer`.
- `TaskChannel.process_prompt/3` no longer passes ignored `mcp_tools` / `project_traits` into `Tasks.submit_user_message/2`.
- `TaskChannel.pending_prompt`, `resolve_pending_prompt/3`, `queued_prompt`, `process_queued_prompt_if_ready/1`, and `ensure_noreply/1` are deleted.
- Server `build_agent_turn_complete_notification/2`, ReScript `AgentTurnComplete`, and first-class client handling for `agent_turn_complete` are deleted. Legacy wire values parse as `Unknown`.
- Legacy `UserMessage(turn_number=N)` rows are handled by data migration, not runtime compatibility. The migration appends `TurnStarted` and clears `turn_number` on `UserMessage`.
- `InteractionSchema.ordered/1` no longer uses nil-sequence fallback; persisted `sequence` is required after sequence backfills.

Facts still true and still need removal:

- `record_interaction/3` persists and broadcasts together. Claim logic must not rely on broadcasts from work that can later roll back.
- `Client__FrontmanProvider` renders strict ACP `UserMessage(_)` updates. Live sends use server-only rendering, so no optimistic reconciliation or `clientRequestId` is needed.

Any implementation phase should first make these facts false one at a time, with tests.

## Current Progress

- Domain foundation is implemented: accepted `UserMessage` rows are task-scoped history facts with nil `turn_number`.
- `TurnStarted` exists and references ordered accepted user-message interaction row ids.
- `Tasks.start_next_turn/3` exists as the DB-backed claim boundary.
- Active-run detection uses `TurnStarted` plus `AgentRetry` as run starters.
- Execution prompt building uses `TurnStarted.user_message_ids`.
- `Tasks.submit_user_message/2` persists accepted `UserMessage` without execution.
- `TaskChannel.process_prompt/3` emits `user_message` update and returns `{}` immediately.
- Server + ReScript protocol: `user_message`, `state_update`, `{}` prompt result, no `AgentTurnComplete`.
- Client: `isSendingPrompt`, `PromptSent`, already-sending rejection removed. Running state from `state_update`. Input enabled while running. Prompt `onComplete` does not dispatch `TurnCompleted`.
- `TaskChannel` `pending_prompt`, `queued_prompt`, `resolve_pending_prompt/3`, `ensure_noreply/1` all deleted.
- `insert_user_turn_for_locked_task/3` and `insert_user_turn_if_idle/2` deleted.
- `ACPHistory` projects `TurnStarted` to `[]`.
- `Tasks.run_next_turn/3` exists as the thin delivery wrapper (claims, starts Swarm, returns). No `TurnRunner` module.
- Channel coverage: MCP-pending drain, session/load drain, terminal wake.
- **All tests pass: 746 server, 311 client, 87 frontman-client.** Root `make rescript-build` passes in this worktree.
- All execution test files adapted: `execution_test.exs`, `execution_image_history_test.exs`, `mcp_tool_routing_test.exs`, `mcp_tool_broadcast_test.exs`, `error_propagation_test.exs` — all pass with accept-then-wake pattern.
- Legacy migration coverage is implemented: old `UserMessage(turn_number=N)` rows become accepted `UserMessage(turn_number=nil)` plus one `TurnStarted` per task/turn.
- Sequence-order fallback is removed. `InteractionSchema.ordered/1` now orders by persisted `sequence`, then `inserted_at`, then `id`.

## What We Learned

- `TurnStarted.user_message_ids` currently means interaction row ids, not embedded domain `UserMessage.id` values. Prompt lookup, tests, and future migrations must keep this straight.
- One logical started turn now commonly produces two persisted rows before any agent work: accepted `UserMessage` and `TurnStarted`. Tests that count rows or assert history order must include both.
- Typed polymorphic embeds make raw `%InteractionSchema{data: map}` inserts invalid for normal tests. Normal tests should build domain structs through `InteractionSchema.create_changeset/3`.
- Raw SQL inserts remain useful for legacy migration tests, but those rows need `data.__type__` so Ecto can load them after migration code runs.
- `TaskChannel` no longer stores prompt lifecycle state. It now wakes drain logic without storing prompt payloads: accepted prompts before MCP readiness persist immediately, then MCP ready/failed wakes `run_next_turn/3` with live tools/context.
- Removing code safely required first migrating fixtures away from old semantics; otherwise failures were mostly test scaffolding preserving `UserMessage(turn_number)`, not product behavior.
- Official ACP docs via Context7 confirm `session/update user_message` exists in ACP v2, but the strict documented shape is only `sessionUpdate`, `messageId`, and `content`. Do not add `timestamp` or `_meta.frontman.dev/clientRequestId` to the `user_message` update unless ACP docs change.
- `session/prompt` acceptance response as `{}` is v2/RFD behavior. Current v1 docs still describe completion response with `stopReason`, so this repo is intentionally migrating toward v2 semantics and must keep schema/tests consistent.
- Accepted `user_message` updates render through `userMessageReceived`; live send no longer inserts an optimistic message, avoiding duplicate reconciliation.
- `TurnStarted` showing up in session history is a bug. It should project to no ACP history items; it only marks execution claim state.
- Full channel tests exposed a resumed execution prompt-context bug: reconnect/resume can construct a Swarm text content part from nil for valid tool-call-only assistant responses. This is now fixed; nil content without tool calls still crashes.
- Do not introduce `TurnRunner` as a broad new concept casually. Current implementation keeps the tiny delivery wrapper as `Tasks.run_next_turn/3`; only add a module/supervisor if ownership/durability needs require it.
- Tests that still expect submit-time execution must either use explicit started-turn fixtures or wait for runner wake behavior. Do not make `submit_user_message/2` start execution again to appease those tests.
- `state_update running` must be emitted after `TurnStarted` commits. It should not be inferred from accepted `UserMessage` or local optimistic submit.
- Tests in `execution/` subdirectory files (`mcp_tool_routing_test.exs`, `mcp_tool_broadcast_test.exs`, `error_propagation_test.exs`) also needed a `submit_user_message_and_run` helper because they called `Tasks.submit_user_message/2` directly and expected submit to also start execution. The pattern is: call `submit_user_message`, then call `run_next_turn`, then assert execution behavior.
- `execution_image_history_test.exs` had its own `submit_anthropic_message` helper that needed the same accept-then-wake treatment.
- `mcp_tool_broadcast_test.exs` "MCP tool registration timing" test uses its own `describe` block with a separate `setup` that returns `scope` and `task_id` — the helper pattern works across all test `describe` scopes.
- `error_propagation_test.exs` had a subtle `\ ` instead of `\\` syntax error after the first automated patch pass; verify helper syntax before running.
- **Full server suite (746 tests) now passes** across all modified test files and broader server coverage.
- **Client suites also pass**: 311 Vitest tests in `libs/client`, 87 Vitest tests in `libs/frontman-client`.
- `record_interaction/3` still persists and broadcasts together — this fact remains unchanged and will need attention if claim/runner work ever needs broadcast- before-commit-safe behavior.
- The legacy turn-start backfill must insert `TurnStarted.sequence` at the first referenced user-message sequence. If inserted after terminal events, a migrated completed turn can look active because active-run detection sees the starter after the terminal event.
- Do not add runtime legacy readers for `UserMessage(turn_number=N)`. Data migration is sufficient and keeps normal code crashy/strict.
- Raw SQL migration tests for `UserMessage` must include `data.__type__` and required embedded fields such as `images: []`, or polymorphic embed loading/history projection will fail for test setup reasons.
- Nil `sequence` is no longer supported by `InteractionSchema.ordered/1`. Tests that manufacture nil sequence rows preserve obsolete pre-backfill behavior and should be deleted or migrated.

## Domain Semantics

### UserMessage

`UserMessage` should mean: user-authored message accepted into session history.

`UserMessage` should not carry execution state. It should not be updated when execution starts.

States are derived from append-only events:

- `UserMessage` with no referencing `TurnStarted` is accepted and queued.
- `TurnStarted(turn_number=N, user_message_ids=[...])` claims one or more accepted user messages for turn N.
- If turn N has no terminal interaction, that turn is running.
- If turn N has `AgentCompleted`, `AgentError`, or `AgentPaused`, that turn is done or waiting.

Consequences:

- `UserMessage` should be visible immediately after acceptance.
- `UserMessage` should be replayed on session load whether or not the agent has processed it yet.
- `UserMessage` should have a server-owned message ID.
- Client renders server-owned messages only; no temporary `clientRequestId` is used.
- Accepted-but-unclaimed messages are `UserMessage` rows with no claim reference; no `QueuedUserMessage`, no `UserMessage.status`, and no mutation of `UserMessage.turn_number`.

### TurnStarted

`TurnStarted` or `ExecutionStarted` should mean: execution started for turn N using a snapshot of all queued accepted user messages available at claim time.

It should include:

- `turn_number`
- ordered `user_message_ids`
- execution metadata needed to reconstruct model/provider context, if that metadata is not recoverable from accepted messages

Invariants:

- one `UserMessage` can be referenced by at most one `TurnStarted`
- one `TurnStarted` can reference one or more `UserMessage` rows
- messages accepted after the `TurnStarted` commit remain queued for the next turn
- active-run detection starts from `TurnStarted`, not from `UserMessage`

### Turn

`turn_number` means an agent execution group:

- one `TurnStarted` opens normal agent work for a turn
- one turn may include multiple accepted `UserMessage` rows
- agent responses, tool calls, and tool results belong to that turn
- terminal events close the active run for that turn
- retry re-runs work for an existing failed turn

That meaning stays. The change is that accepted user messages are claimed by appending `TurnStarted`; `UserMessage` rows remain immutable.

### Retry

Keep retry out of the first refactor unless it blocks normal queued submits.

For the first implementation, `AgentRetry(turn_number=N)` can remain the retry starter for failed turn N. Later, retry can be made acceptance-based too, but that should be a separate simplification after user-message queueing is stable.

## Required: `TurnStarted` / `ExecutionStarted`

A turn-start interaction is required because accepted interactions are append-only event-source facts. Claiming work must append a meaningful event, not mutate `UserMessage`.

Target shape:

```elixir
%UserMessage{id: u1} # accepted
%UserMessage{id: u2} # accepted
%TurnStarted{turn_number: 3, user_message_ids: [u1, u2]} # claimed batch starts turn 3
```

This adds a domain event, enum value, prompt-building resolution path, and indexes. That complexity is justified because it preserves the event log: accepted user messages remain meaningful immutable facts, and execution start becomes its own meaningful fact.

## Public API

Keep product-oriented APIs. Queueing is internal.

Keep:

```elixir
Tasks.submit_user_message(scope, attrs)
Tasks.cancel_execution(scope, task_id)
```

Retry API can keep its current name during normal queue migration:

```elixir
Tasks.retry_execution(scope, task_id, retried_error_id, execution_context)
```

Do not redesign retry and normal user-message submission in the same first slice.

## Claim Boundary

Before introducing any OTP runner, introduce one database-backed claim boundary. This is the only place that may decide whether accepted work becomes execution work.

Target shape:

```elixir
Tasks.claim_next_execution(scope, task_id, execution_context)
```

It should return one of:

```elixir
{:ok, task, turn_started}
| :no_work
| :already_running
| :missing_execution_context
| {:error, reason}
```

Responsibilities:

- authorize task access
- verify live execution context exists
- ensure no active execution exists
- choose all unclaimed accepted `UserMessage` rows visible at claim time, ordered by persisted sequence/id
- allocate next `turn_number`
- append `TurnStarted(turn_number, user_message_ids)`

Non-responsibilities:

- it should not wait for `Execution.run/4` to finish
- it should not answer any JSON-RPC request
- it should not know about prompt lifecycle state in `TaskChannel`
- it should not introduce a separate queue model

During migration, the old submit path may call this function synchronously. The lazy runner should be added only after the claim function is tested and boring.

## Prompt Flow

Target `session/prompt` flow:

1. Client sends `session/prompt` with content blocks and `_meta`.
2. `TaskChannel.process_prompt` validates params/model/content.
3. `Tasks.submit_user_message` persists an immutable `UserMessage` as accepted session history.
4. Server emits ACP v2-style `session/update user_message` with server-owned `messageId`.
5. Server responds to `session/prompt` immediately with success (`{}`).
6. Server wakes the queue runner.
7. Runner claims all queued messages visible at claim time by appending `TurnStarted`.
8. Runner starts execution when possible.

No prompt request remains pending while the agent runs.

## Queue Runner Lifecycle

Use a lazy, short-lived OTP runner. Do not keep one process alive per task forever.

The runner should be a thin delivery wrapper around `Tasks.claim_next_execution/3`. It should not own queue semantics; persisted interactions and the claim function own them.

### Start Triggers

Wake the runner when:

- `Tasks.submit_user_message` accepts a message.
- MCP initialization completes.
- session load/reconnect completes MCP setup.
- terminal interaction is persisted.

Retry wakeups can be added later if retry becomes acceptance-based.

### Stop Conditions

Runner exits when:

- no queued user messages exist.
- an agent run is already active.
- no live execution context is available.
- task was deleted.
- it successfully starts one `Execution.run`.

The runner should not wait for the whole agent run. `SwarmAi` owns long-running execution. The terminal event wakes the runner again for the next queued message.

### Runner Algorithm

1. Build or receive live execution context.
2. Call `Tasks.claim_next_execution/3`.
3. If claim returns `:already_running`, `:no_work`, `:missing_execution_context`, or `:not_found`, stop.
4. If claim returns `{:ok, task, turn_started}`, emit `state_update: running`.
5. Start `Execution.run` for the claimed turn.
6. Stop.

## Locking And Concurrency

Submitting a message should not take a task row lock for turn assignment.

Submit only persists an accepted `UserMessage` and returns.

Atomicity is needed only when claiming work:

- ensure no active run exists
- choose all unclaimed `UserMessage` rows visible at claim time
- allocate turn number
- append `TurnStarted` with ordered `user_message_ids`

Keep any locking inside the runner claim path. Start with the simplest reliable option:

- lock the task row during claim
- load rows in persisted order
- compute active run and next turn inside the lock
- insert one `TurnStarted` row/event that references all queued user messages

Do not add advisory locks or queue tables unless concurrent-claim tests prove row locking plus start-event constraints are insufficient.

## MCP And Live Browser Context

Execution still depends on live browser-side MCP tools.

Implications:

- User messages can be accepted even while MCP is not ready.
- Runner should only claim and start execution when live execution context is available.
- MCP initialization completion should wake the runner.
- Reconnect/session load should wake the runner after MCP setup.

Execution context includes:

- `mcp_tools`
- project traits/framework metadata
- selected model/provider info, when not already recoverable from persisted user message

If no live context exists, accepted messages remain queued and visible.

## Persistence And Notifications

Persisted interactions are the source of truth. ACP notifications are projections from persisted facts or live streaming events.

Implications:

- accepted `UserMessage` must be persisted before any accepted-message notification is emitted
- `TurnStarted` must commit before `state_update: running` is emitted
- terminal interactions must be persisted before `state_update: idle` or `requires_action` is emitted
- channel assigns must not be the only place where accepted user work exists
- reconnect/session load should reconstruct accepted messages and execution state from persisted interactions

The existing `record_interaction/3` helper persists and broadcasts together. Claim logic should use a deliberate transaction and project/broadcast only after `TurnStarted` commits. Do not introduce a separate in-memory queue as source of truth.

## Session Updates

Add or emulate ACP v2-style updates.

### Accepted User Message

Emit when `UserMessage` is persisted:

```json
{
  "sessionUpdate": "user_message",
  "messageId": "server-owned-id",
  "content": [...]
}
```

Strict ACP does not include `timestamp` or `_meta` on this update. Frontman renders this server update directly instead of adding optimistic reconciliation metadata.

### Running

Emit after `TurnStarted` commits:

```json
{
  "sessionUpdate": "state_update",
  "state": "running"
}
```

### Idle

Emit when terminal interaction is persisted and no immediate requires-action state applies:

```json
{
  "sessionUpdate": "state_update",
  "state": "idle",
  "stopReason": "end_turn"
}
```

### Requires Action

Emit when waiting for user/tool input:

```json
{
  "sessionUpdate": "state_update",
  "state": "requires_action"
}
```

Legacy `agent_turn_complete` is no longer first-class protocol data. If received from an old sender, it parses as `Unknown` and must not resolve prompt requests.

## Execution Prompt Building

Current execution prompt building converts `UserMessage(turn_number=N)` directly into a Swarm user message.

Replace that path. After the refactor, `TurnStarted(turn_number=N, user_message_ids=[...])` identifies which accepted user messages enter Swarm for turn N.

Required adjustments:

- exclude unclaimed `UserMessage` rows from `Execution.prompt_messages/2`
- load `TurnStarted` for the current turn and include all referenced `UserMessage` content in accepted order
- decide whether referenced messages become one combined Swarm user message or multiple sequential user messages; preserve accepted order either way
- ensure history replay still includes unclaimed `UserMessage` rows for the client
- keep retry execution from adding a new user message

This preserves turn semantics while moving execution start from submit-time mutation to claim-time append.

## Client Changes

### Input

- Remove `isAgentRunning` from input disabled logic.
- User can submit while agent is running.
- If text/content exists, submit button should submit a new queued message.
- Cancel/stop should be a separate affordance or only take over when input is empty.

### Prompt Promise

- `sendPrompt` resolves when server accepts the prompt.
- It no longer stays pending until turn completion.
- Remove `isSendingPrompt` and “already sending” rejection.

### Message Rendering

- Server emits accepted `user_message` with canonical `messageId`.
- Client renders on server update only.

### Running State

- `isAgentRunning` should come from `state_update: running/idle/requires_action`.
- Turn completion should not depend on prompt response.
- Remove client fallback that resolves pending `session/prompt` from `agent_turn_complete`.

## Code To Remove Or Shrink

Server:

- `get_task_by_id_for_update` from message submit path; keep or rename only for claim path (done: now claim-only)
- `insert_user_turn_for_locked_task` (done)
- `insert_user_turn_if_idle` (done)
- submit-time `:already_running` (done for normal `submit_user_message/2`)
- `Tasks.submit_user_message` knowledge of `mcp_tools`, `project_traits`, and `Execution.run` (done)
- `TaskChannel` `pending_prompt` (done)
- `TaskChannel.resolve_pending_prompt` (done)
- `TaskChannel.queued_prompt` (done)
- `TaskChannel.ensure_noreply` (done)
- MCP-pending prompt queueing in channel assigns (done)
- cancel path coupling to `pending_prompt.turn_number` (done)
- prompt response tied to turn finalization (done)
- legacy `agent_turn_complete` builders/pushes after `state_update` is authoritative (done)
- `UserMessage` history replay as multiple `user_message_chunk` notifications once accepted `user_message` exists (done)
- stale comments/docs saying submit starts execution (mostly done; keep removing if found)

Keep for now:

- `AgentRetry` as a retry starter until retry is refactored separately
- `Tasks.model_for_turn/2`, but resolve normal turns through `TurnStarted` and its referenced user messages or metadata
- prompt-builder assumption that retry turns can still start from existing retry semantics

Client:

- `ConnectionReducer.isSendingPrompt` (done)
- `PromptSent` (done)
- `Cannot send prompt: already sending` (done)
- `CancelPrompt` behavior tied to `isSendingPrompt` (done)
- special `agent_turn_complete` request-resolution path (done)
- input disabled while `isAgentRunning` (done)
- submit button switching to stop mode whenever `isAgentRunning` (done; Stop only appears when running with empty input)
- toolbar disable/hide behavior while running (done)
- prompt `onComplete` dispatching `TurnCompleted` (done)
- duplicate-completion/idempotency logic for RPC response plus `agent_turn_complete` (done)
- `_userMsgBuffer` once accepted `user_message` is replayed as a single update (done; buffer absent)
- stale streaming guards that treat `isAgentRunning=false` as proof streaming events are invalid (done)

Domain:

- `UserMessage.turn_number` as required invariant for accepted messages (done)
- submit-time turn allocation (done)
- unique `user_message` per turn assumption; one turn can claim multiple accepted user messages (done)
- any mutation of accepted `UserMessage` rows to represent queue or execution state (still forbidden; no current mutation path)

Protocol:

- `promptResult.stopReason` as required response to `session/prompt` (done locally: prompt result is `{}` / `unit`)
- `AgentTurnComplete` as completion signal once `StateUpdate` exists (server builder and ReScript handler removed)
- `user_message_chunk` as accepted-user-message transport (done for accepted messages)

Database:

- indexes or constraints that require accepted `UserMessage` rows to carry execution turns
- missing constraints for one claim reference per `UserMessage` and one `TurnStarted` per task turn
- sequence-order fallback in `InteractionSchema.ordered/1` after all rows have sequence (done)
- runtime legacy bridge for old `UserMessage(turn_number=N)` rows (not added; data migration used instead)
- legacy `UserMessage(turn_number=N)` rows without `TurnStarted` (done via `20260630000000_backfill_turn_started_for_user_messages.exs`)

## Implementation Phases

### Phase 1: Make Accepted UserMessage Task-Scoped

- Update `InteractionSchema.validate_turn_number/1` so accepted `UserMessage` does not require a turn.
- Keep positive `turn_number` required for agent responses, tool calls, tool results, and terminal interactions.
- Keep task-scoped validation for discovered project interactions unchanged.
- Add schema tests for accepted `UserMessage` without execution turn.

Status: done. Current validation rejects `UserMessage(turn_number)` and allows accepted `UserMessage` with nil turn.

### Phase 1b: Add TurnStarted Interaction

- Add `TurnStarted` or `ExecutionStarted` as append-only turn-start event.
- Store ordered accepted `user_message_ids` claimed into the turn.
- Add validation that `TurnStarted` requires a positive `turn_number` and at least one user message id.
- Add constraints so one accepted `UserMessage` can be claimed by at most one turn and one turn has at most one `TurnStarted`.

Status: domain event done. DB constraints for one claim reference per user message and one `TurnStarted` per task turn are still deferred; row-lock transaction, focused concurrent test, and migration idempotency checks currently provide coverage.

### Phase 2: Add Claim Function

- Add `Tasks.claim_next_execution/3` or equivalent internal function.
- Claim all unclaimed accepted `UserMessage` rows visible at claim time by appending `TurnStarted`.
- Keep all locking inside this function.
- Prove claim is atomic under concurrent calls.
- Initially call claim from the existing submit/start path, so behavior remains mostly unchanged while invariant changes land.

Status: implemented as `Tasks.start_next_turn/3`. It returns `:no_accepted_messages`, `:already_running`, `:missing_execution_context`, or `{:ok, task, turn_started}`. It does not run execution.

### Phase 3: Split Accept From Start

- Make `Tasks.submit_user_message` persist immutable `UserMessage` as accepted session history without starting execution.
- Remove `mcp_tools`, `project_traits`, and `Execution.run/4` from submit path.
- Return accepted user message quickly.
- Preserve title generation for first accepted user message, not first execution turn.
- Emit server-owned accepted user message update.
- Wake the claim path after acceptance instead of claiming inline.

Status: mostly done for acceptance. `Tasks.submit_user_message/2` now persists accepted history and returns quickly without execution. Normal `TaskChannel.process_prompt/3` emits strict accepted-message protocol update, replies `{}`, and wakes `Tasks.run_next_turn/3` when live context is available.

### Phase 4: Remove Long Prompt Lifecycle

- Return `session/prompt` success on acceptance.
- Delete `pending_prompt` and prompt completion response logic.
- Stop resolving prompt request on turn completion.
- Emit state updates for running/idle/requires-action.

Status: mostly done. Normal `session/prompt` now returns `{}` immediately after acceptance and emits strict `user_message`. `pending_prompt`, `resolve_pending_prompt/3`, `queued_prompt`, and `ensure_noreply` are gone. First-class `agent_turn_complete` transport is removed from server builder and ReScript protocol/client handling.

### Phase 5: Remove Channel-Held MCP Prompt Queue

- Delete `queued_prompt` and `ensure_noreply`.
- Persist accepted messages before MCP is ready.
- Wake claim path when MCP initialization completes or fails, and when session load/reconnect makes live context available.

Status: prompt persistence before MCP readiness is done. `queued_prompt` and `ensure_noreply` are deleted. MCP ready/failed wakes `Tasks.run_next_turn/3` without retaining prompt payloads in channel assigns.

### Phase 6: Add Lazy Runner

- Add short-lived runner wake/drain path as a wrapper around the claim function.
- Runner starts `Execution.run` for a claimed turn and exits.
- Terminal events wake runner for next queued message.

Status: done as `Tasks.run_next_turn/3`. All execution test suites pass with it. No `TurnRunner` module — the wrapper stays in `Tasks` and channel self-wake. Prompt acceptance, MCP ready/failed, session/load, and terminal success/error paths wake it. Verified through full `mix test` (746 server tests current baseline).

### Phase 7: Allow Queued Submits In UI

- Remove running-state input disable (done).
- Remove `isSendingPrompt` (done).
- Reconcile accepted user message updates to temp messages (not needed — Task 20 chose server-only render).
- Show queued/running state from derived message/execution state (running/idle driven by `state_update`).

### Phase 8: Retry Follow-Up

- Keep retry behavior unchanged until normal queued submits are stable.
- Then decide whether retry should remain immediate or become accepted/claimed like user messages.
- Preserve stale retry rejection.
- If retry becomes queued, design it as a small follow-up using existing `AgentRetry` before adding new event types.

### Phase 9: Cleanup And Migration

- Remove compatibility paths.
- Update history replay around accepted-but-unclaimed user messages.
- Update tests to assert queue semantics.
- Add migration/backfill plan for any old `UserMessage(turn_number=N)` rows, either converting them to accepted messages plus `TurnStarted` events or supporting them only through a temporary legacy reader.
- Remove sequence-order fallback after migrations guarantee `sequence`.

Specific cleanup after compatibility bridge is no longer needed:

- Delete submit-time turn allocation and execution start helpers from `Tasks`.
- Delete channel prompt lifecycle assigns and helpers: `pending_prompt`, `queued_prompt`, `resolve_pending_prompt`, `ensure_noreply`.
- Delete MCP-pending prompt queueing; MCP ready should wake the runner instead.
- Delete client fallback that resolves `session/prompt` from `agent_turn_complete`.
- Delete prompt `onComplete -> TurnCompleted` dispatch.
- Replace `UserMessage` history chunk buffering with canonical accepted `user_message` replay.
- Replace client `isAgentRunning` boolean with a derived execution state if UI needs `idle`, `running`, and `requires_action`.
- Keep `SwarmAi` `:already_running` guard; runner should make it rare, but runtime protection remains useful.
- Legacy runtime bridge was not added; migration handles old turn-numbered user messages.
- Nil-sequence compatibility was removed; `sequence` is required persisted ordering data.

## File-Level Cleanup Notes

### Server

`apps/frontman_server/lib/frontman_server/tasks.ex`:

- Split accept-message from claim-and-run. `submit_user_message/2` should not require `mcp_tools`, `project_traits`, or call `Execution.run/4`.
- Move task row lock and turn allocation into claim logic only.
- Update `active_agent_run_turn_number/1` to use `TurnStarted(turn_number=N)` and `AgentRetry(turn_number=N)` initially.
- Ensure active-run detection ignores accepted `UserMessage` rows.
- Update `model_for_turn/2` to resolve normal turns through `TurnStarted` and referenced user messages or stored turn-start metadata.
- Rename or remove `latest_turn_number/1` if it continues to imply latest user message rather than latest claimed turn.
- Keep `run_execution/4` `:already_running` mapping until runner claim proves it unnecessary.

`apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex`:

- Remove `pending_prompt`, `queued_prompt`, `resolve_pending_prompt/3`, and `ensure_noreply/1`.
- Remove channel-held MCP prompt queue. Accepted messages should persist before MCP is ready; runner wakes when MCP becomes ready.
- Remove cancel handling that depends on `pending_prompt.turn_number`.
- Add explicit runner wake calls after prompt acceptance, MCP ready/failed, session load, reconnect setup, and terminal interaction persistence.
- Replace `agent_turn_complete` pushes in `finalize_turn/3` with `state_update idle` or `state_update requires_action`.

Current status: normal prompt acceptance no longer assigns `pending_prompt`; `queued_prompt`, `ensure_noreply`, and `pending_prompt` are deleted.

`apps/frontman_server/lib/frontman_server/tasks/interaction.ex`:

- Add `TurnStarted`/`ExecutionStarted` for normal queued submits at claim time, not submit time.
- Keep `UserMessage` as accepted-message fact only; it is not a turn starter.
- Keep `AgentRetry` starter semantics until retry is simplified separately.
- Remove comments that say submitting a `UserMessage` starts execution.

`apps/frontman_server/lib/frontman_server/tasks/execution.ex`:

- Update `prompt_messages/2` to load `TurnStarted(turn_number=N)` and include all referenced user messages in order.
- Ensure unclaimed `UserMessage` rows are not loaded into Swarm prompt context.
- Keep retry starts from adding a new user message.
- Clean existing mismatch where `system_prompt/2` reads `task.interactions` while `run/4` separately loads interaction rows.

`apps/frontman_server/lib/frontman_server_web/protocols/acp_history_impl.ex`:

- Replay all accepted `UserMessage` rows as accepted user messages, whether or not a `TurnStarted` references them.
- Replace `UserMessage` replay as many `user_message_chunk` updates with one accepted `user_message` update when protocol support exists.
- Remove hydration buffer dependency caused by chunk replay.
- Keep `TurnStarted` projecting to `[]`; it is not ACP chat history.

`apps/frontman_server/lib/frontman_server/tasks/interaction_schema.ex`:

- Update `validate_turn_number/1` for accepted `UserMessage` without execution turn.
- Add schema validation for `TurnStarted` references.
- Add query helpers for unclaimed accepted messages if they make claim code clearer.
- Keep task-scoped validation for discovered project interactions unchanged.
- Remove sequence-order migration comment after all rows have sequence (done).

Current status: `InteractionSchema.ordered/1` now orders directly by `sequence`, `inserted_at`, and `id`. The obsolete nil-sequence compatibility test was deleted.

`apps/frontman_server/priv/repo/migrations/*`:

- Ensure DB constraints allow multiple accepted `UserMessage` rows per task without execution turns.
- Add storage/indexing for `TurnStarted.user_message_ids` or equivalent claim references.
- Add uniqueness for one `TurnStarted` per task turn and one claim reference per accepted user message.
- Backfill old `UserMessage(turn_number=N)` rows into accepted messages plus `TurnStarted`, or document temporary legacy read support (done via data migration; no temporary reader).

Current status: `20260630000000_backfill_turn_started_for_user_messages.exs` appends one `TurnStarted` per task/legacy turn, references user-message row ids, then clears `turn_number` on those `UserMessage` rows. It skips already-existing `TurnStarted` rows so rerun/partial-repair does not duplicate start events. Legacy migration tests live in `tasks_test.exs`; legacy session/load replay coverage lives in `tasks_channel_test.exs`.

### Protocol

`apps/frontman_server/lib/agent_client_protocol.ex`:

- Add builders for accepted `user_message` and `state_update`.
- Deprecate `build_user_message_chunk_notification/3` for accepted messages.
- Delete `build_agent_turn_complete_notification/2` after clients consume state updates.
- Shrink `build_prompt_result/1` or replace it with empty acceptance response.

Current status: accepted `user_message` builder is done with strict ACP shape; `build_prompt_result/1` returns `%{}`; state update builder is done; `build_agent_turn_complete_notification/2` is deleted.

`libs/frontman-protocol/src/FrontmanProtocol__ACP.res`:

- Add `UserMessage` session update with strict ACP `messageId` and `content` only.
- Add `StateUpdate` session update for `running`, `idle`, and `requires_action`.
- Remove `AgentTurnComplete` after migration to state updates.
- Update `promptResultSchema` if `session/prompt` response becomes `{}`.

Current status: `UserMessage`, `{}` prompt result, and `StateUpdate` are done; `AgentTurnComplete` is removed from ReScript protocol.

`libs/frontman-client/src/FrontmanClient__ACP__Protocol.res`:

- Remove `AgentTurnComplete` resolving pending `session/prompt`.
- Make `sendPrompt` resolve from JSON-RPC response only.
- Update cancel comments; cancel no longer depends on prompt response finalization.
- Change prompt parse target if prompt result becomes unit/empty object.

Current status: prompt parse target is unit/empty object and normal prompts resolve from JSON-RPC response. `AgentTurnComplete` is removed from the protocol; legacy wire values parse as `Unknown`.

`libs/frontman-client/src/FrontmanClient__ACP.res`:

- Change `sendPrompt` result type to acceptance response, likely `result<unit, string>`.
- Remove comments saying prompt resolves when cancelled/completed.

### Client

`libs/client/src/Client__ConnectionReducer.res`:

- Delete `isSendingPrompt`, `PromptSent`, already-sending rejection, and cancel behavior tied to prompt-send state.
- Let `SendPromptEffect` call `onComplete` on acceptance only.
- Make `CancelPrompt` depend only on active session; running state belongs in task/execution state.

`libs/client/src/Client__FrontmanProvider.res`:

- Replace `AgentTurnComplete` handling with `StateUpdate` handling.
- Remove `_userMsgBuffer` after accepted `user_message` is replayed as one update.
- Flush text deltas on `state_update idle` or terminal/error updates, not prompt `onComplete`.
- Render accepted `UserMessage(_)` updates directly; do not add `clientRequestId` reconciliation.

Current status: `UserMessage(_)` renders in loaded and loading tasks; `StateUpdate` drives completion state.

`libs/client/src/state/Client__State__StateReducer.res`:

- Remove prompt `onComplete` dispatch of `TurnCompleted`.
- `AddUserMessage` sends and clears local state; server-accepted `UserMessage` update inserts the visible message.
- Remove comments about duplicate completion from notification plus RPC response.

Current status: prompt `onComplete -> TurnCompleted` dispatch is removed.

`libs/client/src/state/Client__Task__Reducer.res`:

- Stop `AddUserMessage` from setting `isAgentRunning: true`.
- Add state-update action to set `running`, `idle`, or `requires_action`.
- Remove duplicate-completion/idempotency logic tied to long prompt lifecycle.
- Make `RetryTurn` acceptance not imply running until server emits running state.
- Treat scheduled retry as retry status, not active run.
- Revisit streaming guards that drop events when `isAgentRunning=false`; accepted queued messages make that predicate too broad.

`libs/client/src/state/Client__Task__Types.res`:

- Replace `isAgentRunning: bool` with an execution-state enum if UI needs more than running/not-running.
- Add per-message queue/run/done status only if product UI needs it; otherwise derive from execution state.
- Keep `pendingQuestion`, but tie it to `requires_action` state instead of prompt lifecycle.

`libs/client/src/components/frontman/Client__PromptInput.res`:

- Remove `isAgentRunning` from `isInputDisabled`.
- Change running placeholder from `Waiting for response...` to normal submit placeholder.
- Stop disabling toolbar while running.
- Split submit and stop affordances. If input has content, submit should queue; stop can be separate or only appear for empty input.

`libs/client/src/Client__Chatbox.res`, `Client__TopBar.res`, `Client__ToolGroupBlock.res`, `Client__RetryBanner.res`:

- Rename `isAgentRunning` selector/prop to execution-state semantics.
- Keep thinking/tool-open visuals driven by `state_update running`.
- Ensure retry UI does not depend on prompt input owning stop behavior.

## Tests To Add Or Rewrite

Server:

- `submit_user_message` returns immediately and persists immutable accepted `UserMessage`.
- accepted `UserMessage` has no new turn assignment.
- `session/prompt` responds with success before execution completes.
- submitting while active run exists creates another accepted `UserMessage`.
- queued user message is visible in session load.
- claim appends `TurnStarted` for all queued user messages visible at claim time.
- claim is atomic under concurrent wakes.
- claim does not start second execution while active run exists.
- terminal event wakes runner and starts next queued message.
- execution prompt builder ignores unclaimed user messages.
- execution prompt builder includes every `UserMessage` referenced by current turn's `TurnStarted`, in order.
- stale retry remains rejected.
- `state_update running` is emitted when execution is claimed.
- `state_update idle` is emitted when terminal event persists and no requires-action applies.
- history replay emits accepted user messages with canonical IDs, including unclaimed rows.
- `TurnStarted` in history projects to no ACP items.
- migration test covers old turn-numbered `UserMessage` rows converting to `TurnStarted` plus accepted messages.
- session/load test covers migrated legacy user message history.
- server ordering tests assume every persisted row has `sequence`; nil-sequence compatibility is gone.

Client:

- prompt input remains enabled while running.
- multiple submits create multiple visible messages.
- prompt promise resolves on acceptance.
- server accepted user message reconciles temp message.
- state updates drive running/idle UI.
- prompt `onComplete` does not dispatch `TurnCompleted`.
- `agent_turn_complete` no longer resolves pending `session/prompt`.
- `AddUserMessage` does not set running state by itself.
- submit button queues when content exists while running.
- stop/cancel remains available without replacing content submit.

Channel/e2e:

- prompt before MCP ready is accepted and visible.
- MCP ready starts queued work.
- reconnect/session load shows queued messages and wakes runner.
- no `Agent already running` prompt response for normal message submits.
- no channel assign stores a deferred JSON-RPC prompt while MCP initializes.
- terminal event wakes runner for next queued message.
- session load returns accepted history and does not rely on `user_message_chunk` buffering once new update exists.

Tests to remove or rewrite:

- `agent_turn_complete notification resolves pending prompt request`.
- `isSendingPrompt` state transitions.
- `Cannot send prompt: already sending` rejection.
- `AddUserMessage` sets `isAgentRunning=true`.
- submit while running returns `Agent already running`.
- channel `pending_prompt` and `queued_prompt` assign tests.
- prompt request completion from turn finalization.
- nil-sequence ordering compatibility test.

## Open Questions

- Should retry remain immediate until later, or should it become accepted/claimed after normal queued submits are stable?
- How should queued/running/done state be represented on the wire before ACP v2 schemas stabilize?
- Server-only accepted-message rendering is chosen; optimistic user messages and `clientRequestId` reconciliation are intentionally not used.
- If queued messages exist but no live MCP context is available, should they wait indefinitely, fail after timeout, or run with backend tools only?
- Do we need multi-node-safe claim semantics now, or is single-node OTP plus localized DB lock enough for current deployment?
- Should `TurnStarted.user_message_ids` live inside interaction metadata, a join table, or another normalized claim reference?
