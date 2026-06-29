# Queue Refactor Plan

## Goal

Make chat message submission instant and robust while reducing lifecycle complexity.

Users should be able to submit messages at any time. Submitted messages should always appear in the chat as accepted/queued session history. Agent execution should drain those messages serially without tying user submit to long-running agent work.

This refactor should remove concepts where possible, not add another abstraction layer beside the current one.

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

## Domain Semantics

### UserMessage

`UserMessage` should mean: user-authored message accepted into session history.

It should not mean: an agent turn has started.

Consequences:

- `UserMessage` should be visible immediately after acceptance.
- `UserMessage` should be replayed on session load whether or not the agent has processed it yet.
- `UserMessage` should have a server-owned message ID.
- Client may include a temporary `clientRequestId` for optimistic reconciliation, but that is not the protocol message ID.
- `turn_number` should not conceptually belong to `UserMessage`.

### Turn

`turn_number` currently means an agent execution group:

- one starter event opens agent work for a turn
- agent responses, tool calls, and tool results belong to that turn
- terminal events close the active run for that turn
- retry re-runs work for an existing failed turn

That meaning should remain, but `UserMessage` should stop being the starter.

### AgentLoopStarted

Introduce an execution-level interaction:

```elixir
%Interaction.AgentLoopStarted{
  id: "...",
  trigger_type: :user_message | :retry,
  trigger_id: "...",
  timestamp: ...
}
```

Persist it with `turn_number`.

For a normal user message:

- `trigger_type = :user_message`
- `trigger_id = user_message.id`
- `turn_number = next turn`

For retry:

- `trigger_type = :retry`
- `trigger_id = agent_error.id`
- `turn_number = failed turn number`

`AgentLoopStarted` becomes the only agent-run starter.

Active run detection becomes:

- `AgentLoopStarted(turn=N)` opens active run.
- `AgentCompleted`, `AgentError`, or `AgentPaused` for `turn=N` closes it.
- `UserMessage` no longer affects active-run detection.

Queued state becomes derived:

- A `UserMessage` with no `AgentLoopStarted(trigger_type=:user_message, trigger_id=user_message.id)` is queued.
- A `UserMessage` referenced by the active `AgentLoopStarted` is running.
- A `UserMessage` referenced by a closed turn is done.

No `QueuedUserMessage`, no `UserMessage.status`, no `turn_number=nil` exception.

## Public API

Keep product-oriented APIs. Queueing is internal.

Keep:

```elixir
Tasks.submit_user_message(scope, attrs)
Tasks.cancel_execution(scope, task_id)
```

Retry API can keep its current name during migration:

```elixir
Tasks.retry_execution(scope, task_id, retried_error_id, execution_context)
```

But internally retry should enqueue/accept retry intent and wake the runner. It should not synchronously start execution.

## Prompt Flow

Target `session/prompt` flow:

1. Client sends `session/prompt` with content blocks and `_meta`.
2. `TaskChannel.process_prompt` validates params/model/content.
3. `Tasks.submit_user_message` persists `UserMessage` as accepted session history.
4. Server emits ACP v2-style `session/update user_message` with server-owned `messageId`.
5. Server responds to `session/prompt` immediately with success (`{}`).
6. Server wakes the queue runner.
7. Runner starts execution when possible.

No prompt request remains pending while the agent runs.

## Queue Runner Lifecycle

Use a lazy, short-lived OTP runner. Do not keep one process alive per task forever.

### Start Triggers

Wake the runner when:

- `Tasks.submit_user_message` accepts a message.
- retry is accepted.
- MCP initialization completes.
- session load/reconnect completes MCP setup.
- terminal interaction is persisted.

### Stop Conditions

Runner exits when:

- no queued user messages exist.
- an agent run is already active.
- no live execution context is available.
- task was deleted.
- it successfully starts one `Execution.run`.

The runner should not wait for the whole agent run. `SwarmAi` owns long-running execution. The terminal event wakes the runner again for the next queued message.

### Runner Algorithm

1. Load task/interactions.
2. If active run exists, stop.
3. Find oldest accepted `UserMessage` not referenced by `AgentLoopStarted`.
4. If none, stop.
5. Insert `AgentLoopStarted(trigger_type=:user_message, trigger_id=user_message.id)` with next `turn_number`.
6. Emit `state_update: running`.
7. Start `Execution.run` for that turn.
8. Stop.

Retry claim is similar, but uses the failed turn number instead of allocating a new turn.

## Locking And Concurrency

Submitting a message should not take a task row lock for turn assignment.

Submit only persists an accepted `UserMessage` and returns.

Atomicity is needed only when claiming work:

- ensure no active run exists
- choose oldest unprocessed `UserMessage`
- allocate turn number
- insert `AgentLoopStarted`

Keep any locking inside the runner claim path. Options:

- task row lock during claim, renamed around queue semantics (for example `lock_task_for_loop_claim`)
- atomic insert/update constraints around `AgentLoopStarted`
- advisory lock per task if needed later

The first implementation should prefer the simplest reliable option and keep it localized to claim logic.

## MCP And Live Browser Context

Execution still depends on live browser-side MCP tools.

Implications:

- User messages can be accepted even while MCP is not ready.
- Runner should only start execution when live execution context is available.
- MCP initialization completion should wake the runner.
- Reconnect/session load should wake the runner after MCP setup.

Execution context includes:

- `mcp_tools`
- project traits/framework metadata
- selected model/provider info, when not already recoverable from persisted user message

If no live context exists, accepted messages remain queued and visible.

## Session Updates

Add or emulate ACP v2-style updates.

### Accepted User Message

Emit when `UserMessage` is persisted:

```json
{
  "sessionUpdate": "user_message",
  "messageId": "server-owned-id",
  "content": [...],
  "_meta": {
    "frontman.dev/clientRequestId": "optional-client-temp-id"
  }
}
```

If protocol schemas are not ready for `user_message`, use a Frontman extension or adapt existing history replay path during migration.

### Running

Emit when `AgentLoopStarted` is persisted:

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

Legacy `agent_turn_complete` can be kept temporarily during migration, but should not be required to resolve prompt requests.

## Execution Prompt Building

Current execution prompt building converts `UserMessage(turn_number=N)` directly into a Swarm user message.

After refactor:

- `AgentLoopStarted(trigger_type=:user_message, trigger_id=msg_id, turn_number=N)` marks where the user message enters execution.
- Prompt builder resolves `msg_id` to the accepted `UserMessage`.
- It emits that user message into Swarm context at the loop start position.
- `AgentLoopStarted(trigger_type=:retry)` emits no new user message; it reruns the existing turn context.

This preserves turn semantics while removing execution state from `UserMessage`.

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

### Message Reconciliation

- Client may create a temp optimistic message with `clientRequestId`.
- Server emits accepted `user_message` with canonical `messageId`.
- Client replaces/reconciles temp message using `clientRequestId`.
- If no optimistic rendering is used, render on server update only.

### Running State

- `isAgentRunning` should come from `state_update: running/idle/requires_action`.
- Turn completion should not depend on prompt response.
- Remove client fallback that resolves pending `session/prompt` from `agent_turn_complete`.

## Code To Remove Or Shrink

Server:

- `get_task_by_id_for_update` from message submit path
- `insert_user_turn_for_locked_task`
- `insert_user_turn_if_idle`
- submit-time `:already_running`
- `TaskChannel` `pending_prompt`
- `TaskChannel.resolve_pending_prompt`
- `TaskChannel.queued_prompt`
- `TaskChannel.ensure_noreply`
- prompt response tied to turn finalization

Client:

- `ConnectionReducer.isSendingPrompt`
- `PromptSent`
- `Cannot send prompt: already sending`
- special `agent_turn_complete` request-resolution path
- input disabled while `isAgentRunning`

Domain:

- `UserMessage` as agent-run starter
- `AgentRetry` as independent starter if replaced by `AgentLoopStarted(trigger_type=:retry)`

## Implementation Phases

### Phase 1: Add AgentLoopStarted

- Add `Interaction.AgentLoopStarted`.
- Add schema/serialization tests.
- Update active-run detection to use `AgentLoopStarted` as starter.
- Keep old `UserMessage(turn_number)` compatibility only as migration bridge if needed.

### Phase 2: Emit Accepted User Messages

- Make `Tasks.submit_user_message` persist `UserMessage` as session history without starting execution.
- Emit server-owned accepted user message update.
- Return `session/prompt` success on acceptance.
- Keep execution start path temporarily behind explicit runner call.

### Phase 3: Add Lazy Runner

- Add short-lived runner wake/drain path.
- Runner claims oldest unprocessed `UserMessage` by inserting `AgentLoopStarted`.
- Runner starts `Execution.run` and exits.
- Terminal events wake runner.

### Phase 4: Remove Long Prompt Lifecycle

- Delete `pending_prompt` and prompt completion response logic.
- Stop resolving prompt request on turn completion.
- Emit state updates for running/idle/requires-action.

### Phase 5: Allow Queued Submits In UI

- Remove running-state input disable.
- Remove `isSendingPrompt`.
- Reconcile accepted user message updates to temp messages.
- Show queued/running state from derived message/loop state.

### Phase 6: Convert Retry

- Make retry acceptance immediate.
- Represent retry execution with `AgentLoopStarted(trigger_type=:retry)`.
- Preserve stale retry rejection.
- Remove or reduce `AgentRetry` if it becomes redundant.

### Phase 7: Cleanup And Migration

- Remove compatibility paths.
- Update history replay around accepted user messages and loop starts.
- Update tests to assert queue semantics.
- Consider data migration for old `UserMessage.turn_number` rows if necessary.

## Tests To Add Or Rewrite

Server:

- `submit_user_message` returns immediately and persists accepted `UserMessage`.
- `session/prompt` responds with success before execution completes.
- submitting while active run exists creates another accepted user message.
- queued user message is visible in session load.
- runner inserts `AgentLoopStarted` for oldest unprocessed user message.
- runner does not start second loop while active run exists.
- terminal event wakes runner and starts next queued message.
- retry creates `AgentLoopStarted(trigger_type=:retry)` for failed turn.
- stale retry remains rejected.

Client:

- prompt input remains enabled while running.
- multiple submits create multiple visible messages.
- prompt promise resolves on acceptance.
- server accepted user message reconciles temp message.
- state updates drive running/idle UI.

Channel/e2e:

- prompt before MCP ready is accepted and visible.
- MCP ready starts queued work.
- reconnect/session load shows queued messages and wakes runner.
- no `Agent already running` prompt response for normal message submits.

## Open Questions

- Should `AgentLoopStarted(trigger_type=:retry)` replace `AgentRetry`, or should `AgentRetry` remain as observability-only event?
- How should queued/running/done state be represented on the wire before ACP v2 schemas stabilize?
- Should optimistic user messages render before server acceptance, or should server acceptance be fast enough to be the first render?
- If queued messages exist but no live MCP context is available, should they wait indefinitely, fail after timeout, or run with backend tools only?
- Do we need multi-node-safe claim semantics now, or is single-node OTP plus localized DB lock enough for current deployment?
