# Finalize Turn Refactor — Design Spec

## Problem

Two bugs found during PR #762 review share a root cause: turn-ending logic is split across `handle_turn_ended/2` and `handle_turn_error/3` with inconsistent cleanup of `retry_state`.

**Bug 1 — Stale `:fire_retry` after cancel:** `Process.cancel_timer/1` can't dequeue a message already in the mailbox. If the timer fires right before `handle_cancel` runs, `:fire_retry` is processed after cancel and starts an unwanted execution. The handler doesn't check whether `retry_state` is nil.

**Bug 2 — `handle_turn_error` doesn't clear `retry_state`:** When a retried execution fails with a non-retryable error, the channel routes to `handle_turn_error`, which doesn't clear the stale `RetryCoordinator` struct. A subsequent transient error finds the old attempt count and gets fewer retries than expected.

## Root Cause

The domain invariant — "retry_state must be nil when a turn ends" — is enforced by the transport layer across 5 separate code paths. Each path must independently remember to clear retry state. `handle_turn_error` forgot.

## Design

### 1. Unified `finalize_turn/2`

Replace `handle_turn_ended/2` and `handle_turn_error/3` with a single `finalize_turn/2` that always clears retry state, then dispatches on outcome type.

```elixir
@type turn_outcome ::
  {:completed, stop_reason :: String.t()}
  | {:error, message :: String.t(), category :: String.t()}

@spec finalize_turn(Phoenix.Socket.t(), turn_outcome()) :: {:noreply, Phoenix.Socket.t()}
defp finalize_turn(socket, outcome) do
  task_id = socket.assigns.task_id
  socket = assign(socket, :retry_state, RetryCoordinator.clear(socket.assigns[:retry_state]))

  case outcome do
    {:completed, stop_reason} ->
      notification = ACP.build_agent_turn_complete_notification(task_id, stop_reason)
      push(socket, @acp_message, notification)
      resolve_pending_prompt(socket, {:ok, stop_reason})

    {:error, message, category} ->
      notification = ACP.build_error_notification(task_id, message, DateTime.utc_now(), category: category)
      push(socket, @acp_message, notification)
      resolve_pending_prompt(socket, {:error, message})
  end
end
```

### 2. Extract `resolve_pending_prompt/2`

Pending RPC resolution is duplicated between the two current handlers. Extract it:

```elixir
@spec resolve_pending_prompt(Phoenix.Socket.t(), {:ok, String.t()} | {:error, String.t()}) ::
  {:noreply, Phoenix.Socket.t()}
defp resolve_pending_prompt(socket, result) do
  task_id = socket.assigns.task_id

  socket =
    case socket.assigns[:pending_prompt_id] do
      nil ->
        Logger.info("Turn finalized with no pending_prompt_id for task #{task_id}")
        socket

      prompt_id ->
        response = case result do
          {:ok, stop_reason} ->
            Logger.info("Resolving pending prompt #{prompt_id} with stop_reason=#{stop_reason}")
            JsonRpc.success_response(prompt_id, ACP.build_prompt_result(stop_reason))

          {:error, message} ->
            Logger.info("Resolving pending prompt #{prompt_id} with error: #{message}")
            JsonRpc.error_response(prompt_id, -32_000, message)
        end

        push(socket, @acp_message, response)
        assign(socket, :pending_prompt_id, nil)
    end

  {:noreply, socket}
end
```

### 3. Guard `:fire_retry` against stale messages

Standard Erlang defensive pattern — check that the state the timer was meant for still exists:

```elixir
def handle_info(:fire_retry, socket) do
  if socket.assigns[:retry_state] do
    scope = socket.assigns.scope
    task_id = socket.assigns.task_id
    opts = socket.assigns[:last_execution_opts] || []
    mcp_tools = socket.assigns[:mcp_tools] || []
    all_tools = mcp_tools |> Tools.prepare_for_task(task_id)
    Tasks.maybe_start_execution(scope, task_id, all_tools, opts)
  end

  {:noreply, socket}
end
```

### 4. Caller updates

All turn-ending call sites change from two function names to one with tagged tuples:

| Before | After |
|--------|-------|
| `handle_turn_ended(socket, ACP.stop_reason_end_turn())` | `finalize_turn(socket, {:completed, ACP.stop_reason_end_turn()})` |
| `handle_turn_ended(socket, ACP.stop_reason_cancelled())` | `finalize_turn(socket, {:completed, ACP.stop_reason_cancelled()})` |
| `handle_turn_error(socket, msg, category)` | `finalize_turn(socket, {:error, msg, category})` |

Call sites:
- `handle_info({:swarm_event, _})` — lines 632-645: 4 calls
- `handle_cancel` — line 401: 1 call
- `handle_transient_error` exhausted path — line 801: 1 call
- `handle_info({:execution_start_error, _})` — line 738: 1 call (also remove the manual `RetryCoordinator.clear` since `finalize_turn` handles it)

### 5. Simplifications

- `handle_info({:execution_start_error, _})` no longer needs its own `RetryCoordinator.clear` call
- `handle_transient_error` exhausted path no longer needs `assign(socket, :retry_state, nil)`

## What doesn't change

- `RetryCoordinator` module — already clean domain logic
- `handle_cancel` — already correct, clears retry state before delegating
- `handle_transient_error` retry-scheduled path — only the exhausted branch routes through `finalize_turn`
- ACP notification formats and content
- `handle_info({:swarm_event, _})` routing logic

## Tests

### New tests

1. **Stale `:fire_retry` after cancel doesn't start execution:**
   - Trigger a transient error (starts retry countdown)
   - Send `session/cancel` (clears retry state)
   - Manually send `:fire_retry` to the channel process
   - Assert no execution starts (no swarm events, no error notifications)

2. **Non-retryable error after retry clears state for next turn:**
   - Trigger a transient error (attempt 1)
   - Fire retry, execution fails with non-retryable error
   - Send a new message, trigger another transient error
   - Assert attempt = 1 (not 2)

### Existing tests

All existing retry/cancel tests should continue to pass — the refactor changes internal structure, not external behavior.
