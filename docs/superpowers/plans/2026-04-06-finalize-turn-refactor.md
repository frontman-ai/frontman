# Finalize Turn Refactor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify `handle_turn_ended/2` and `handle_turn_error/3` into a single `finalize_turn/2` that always clears retry state, fixing two bugs where stale retry state causes unwanted behavior.

**Architecture:** Replace two separate turn-ending functions with one `finalize_turn/2` dispatching on `{:completed, stop_reason} | {:error, message, category}`. Extract `resolve_pending_prompt/2` for the shared RPC resolution logic. Add a nil guard on `:fire_retry` to handle Erlang mailbox race conditions.

**Tech Stack:** Elixir, Phoenix Channels, ExUnit

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex` | Modify | Replace `handle_turn_ended/2` + `handle_turn_error/3` with `finalize_turn/2` + `resolve_pending_prompt/2`; guard `:fire_retry`; update all call sites |
| `apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs` | Modify | Add two new test cases for the bugs |

---

### Task 1: Write failing test for stale `:fire_retry` after cancel

**Files:**
- Modify: `apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs`

- [ ] **Step 1: Add test case for stale `:fire_retry` after cancel**

Add this test inside the existing `describe "bug: session/cancel during retry countdown is silently ignored"` block (after line 1646):

```elixir
    test "stale :fire_retry in mailbox after cancel does not start execution", %{
      socket: socket,
      task_id: task_id
    } do
      error = %FrontmanServer.Tasks.Execution.LLMError{
        message: "Rate limited",
        category: "rate_limit",
        retryable: true
      }

      # Trigger transient error — retry state created, timer scheduled
      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), swarm_failed(error))
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "error", "attempt" => 1, "retryAt" => _}}
      })

      # Cancel during countdown — clears retry state
      push(
        socket,
        "acp:message",
        build_acp_request("session/cancel", nil, %{"sessionId" => task_id})
      )

      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{
          "update" => %{"sessionUpdate" => "agent_turn_complete", "stopReason" => "cancelled"}
        }
      })

      flush_mailbox()

      # Simulate the race: :fire_retry arrives AFTER cancel cleared retry_state
      # (timer fired right before cancel, message was already in mailbox)
      send(socket.channel_pid, :fire_retry)
      :sys.get_state(socket.channel_pid)

      # No execution should start — no error notification, no swarm activity
      refute_push("acp:message", _)

      # Channel still alive and retry_state still nil
      assert Process.alive?(socket.channel_pid)
      %{assigns: assigns} = :sys.get_state(socket.channel_pid)
      assert is_nil(assigns[:retry_state])
    end
```

- [ ] **Step 2: Run the test to confirm it fails**

Run: `cd apps/frontman_server && mix test test/frontman_server_web/channels/task_channel_test.exs --only line:1648 2>&1 | tail -30`

Expected: FAIL — the current `:fire_retry` handler unconditionally calls `Tasks.maybe_start_execution`, which will either start an execution or broadcast an error. The channel may crash from the unhandled message in the raise catch-all, or the test will see unexpected pushes.

- [ ] **Step 3: Commit the failing test**

```bash
cd apps/frontman_server
git add test/frontman_server_web/channels/task_channel_test.exs
git commit -m "test: add failing test for stale :fire_retry after cancel

Reproduces the race condition where Process.cancel_timer can't dequeue
a :fire_retry message already in the mailbox."
```

---

### Task 2: Write failing test for non-retryable error not clearing retry state

**Files:**
- Modify: `apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs`

- [ ] **Step 1: Add test case**

Add a new describe block after the `"bug: execution_start_error during retry leaves zombie coordinator"` block (after line 1742):

```elixir
  describe "bug: handle_turn_error does not clear retry_state" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "non-retryable error after retry clears state for next turn", %{
      socket: socket,
      task_id: task_id
    } do
      retryable_error = %FrontmanServer.Tasks.Execution.LLMError{
        message: "Rate limited",
        category: "rate_limit",
        retryable: true
      }

      non_retryable_error = %FrontmanServer.Tasks.Execution.LLMError{
        message: "Invalid API key",
        category: "auth",
        retryable: false
      }

      # First: transient error creates retry state at attempt 1
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        swarm_failed(retryable_error)
      )

      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "error", "attempt" => 1, "retryAt" => _}}
      })

      # Retry fires, but execution hits a non-retryable error
      send(socket.channel_pid, :fire_retry)
      :sys.get_state(socket.channel_pid)

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        swarm_failed(non_retryable_error)
      )

      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{
          "update" => %{"sessionUpdate" => "error", "message" => "Invalid API key"}
        }
      })

      # retry_state MUST be cleared after the non-retryable error
      %{assigns: assigns} = :sys.get_state(socket.channel_pid)
      assert is_nil(assigns[:retry_state])

      flush_mailbox()

      # New turn: another transient error should start fresh at attempt 1
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        swarm_failed(retryable_error)
      )

      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "error", "attempt" => 1, "retryAt" => _}}
      })
    end
  end
```

- [ ] **Step 2: Run the test to confirm it fails**

Run: `cd apps/frontman_server && mix test test/frontman_server_web/channels/task_channel_test.exs --only line:1744 2>&1 | tail -30`

Expected: FAIL — `handle_turn_error` doesn't clear `retry_state`, so the assert `is_nil(assigns[:retry_state])` fails, and/or the final transient error reports `attempt: 2` instead of `attempt: 1`.

- [ ] **Step 3: Commit the failing test**

```bash
cd apps/frontman_server
git add test/frontman_server_web/channels/task_channel_test.exs
git commit -m "test: add failing test for stale retry_state after non-retryable error

handle_turn_error doesn't clear retry_state, so subsequent transient
errors inherit the stale attempt counter."
```

---

### Task 3: Implement `finalize_turn/2` and `resolve_pending_prompt/2`

**Files:**
- Modify: `apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex:830-883`

- [ ] **Step 1: Replace `handle_turn_ended/2` and `handle_turn_error/3` with `finalize_turn/2` and `resolve_pending_prompt/2`**

Replace lines 819-883 (the comment block + `handle_turn_ended/2` + `handle_turn_error/3`) with:

```elixir
  # Unified turn finalization — every code path that ends a turn goes through here.
  # This guarantees the domain invariant: retry_state is always nil when a turn ends.
  defp finalize_turn(socket, outcome) do
    task_id = socket.assigns.task_id
    socket = assign(socket, :retry_state, RetryCoordinator.clear(socket.assigns[:retry_state]))

    case outcome do
      {:completed, stop_reason} ->
        notification = ACP.build_agent_turn_complete_notification(task_id, stop_reason)
        push(socket, @acp_message, notification)
        resolve_pending_prompt(socket, {:ok, stop_reason})

      {:error, message, category} ->
        notification =
          ACP.build_error_notification(task_id, message, DateTime.utc_now(), category: category)

        push(socket, @acp_message, notification)
        resolve_pending_prompt(socket, {:error, message})
    end
  end

  defp resolve_pending_prompt(socket, result) do
    task_id = socket.assigns.task_id

    socket =
      case socket.assigns[:pending_prompt_id] do
        nil ->
          Logger.info("Turn finalized with no pending_prompt_id for task #{task_id}")
          socket

        prompt_id ->
          response =
            case result do
              {:ok, stop_reason} ->
                Logger.info(
                  "Resolving pending prompt #{prompt_id} with stop_reason=#{stop_reason}"
                )

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

- [ ] **Step 2: Update all call sites**

**In `handle_info({:swarm_event, _}, socket)` (around line 631):**

Replace:
```elixir
      :agent_completed ->
        handle_turn_ended(socket, ACP.stop_reason_end_turn())

      :agent_cancelled ->
        handle_turn_ended(socket, ACP.stop_reason_cancelled())

      :agent_paused ->
        handle_turn_ended(socket, ACP.stop_reason_end_turn())

      {:agent_error, %{retryable: true} = error_info} ->
        handle_transient_error(socket, error_info)

      {:agent_error, %{retryable: false} = error_info} ->
        handle_turn_error(socket, error_info.message, error_info.category)
```

With:
```elixir
      :agent_completed ->
        finalize_turn(socket, {:completed, ACP.stop_reason_end_turn()})

      :agent_cancelled ->
        finalize_turn(socket, {:completed, ACP.stop_reason_cancelled()})

      :agent_paused ->
        finalize_turn(socket, {:completed, ACP.stop_reason_end_turn()})

      {:agent_error, %{retryable: true} = error_info} ->
        handle_transient_error(socket, error_info)

      {:agent_error, %{retryable: false} = error_info} ->
        finalize_turn(socket, {:error, error_info.message, error_info.category})
```

**In `handle_cancel` (around line 401):**

Replace:
```elixir
          handle_turn_ended(socket, ACP.stop_reason_cancelled())
```

With:
```elixir
          finalize_turn(socket, {:completed, ACP.stop_reason_cancelled()})
```

**In `handle_info({:execution_start_error, _}, socket)` (around line 736):**

Replace:
```elixir
  def handle_info({:execution_start_error, msg}, socket) do
    socket = assign(socket, :retry_state, RetryCoordinator.clear(socket.assigns[:retry_state]))
    handle_turn_error(socket, msg, "unknown")
  end
```

With:
```elixir
  def handle_info({:execution_start_error, msg}, socket) do
    finalize_turn(socket, {:error, msg, "unknown"})
  end
```

**In `handle_transient_error` exhausted path (around line 799):**

Replace:
```elixir
      {:exhausted, error_info} ->
        socket = assign(socket, :retry_state, nil)
        handle_turn_error(socket, error_info.message, error_info.category)
```

With:
```elixir
      {:exhausted, error_info} ->
        finalize_turn(socket, {:error, error_info.message, error_info.category})
```

- [ ] **Step 3: Run all existing retry tests to confirm they still pass**

Run: `cd apps/frontman_server && mix test test/frontman_server_web/channels/task_channel_test.exs 2>&1 | tail -20`

Expected: All existing tests PASS (behavior unchanged, only internal structure changed).

- [ ] **Step 4: Commit**

```bash
cd apps/frontman_server
git add lib/frontman_server_web/channels/task_channel.ex
git commit -m "refactor: unify turn-ending into finalize_turn/2

Replace handle_turn_ended/2 and handle_turn_error/3 with a single
finalize_turn/2 that always clears retry_state. Extract
resolve_pending_prompt/2 for shared RPC resolution logic.

Fixes bug where handle_turn_error didn't clear retry_state, leaving
stale attempt counters for subsequent transient errors."
```

---

### Task 4: Guard `:fire_retry` against stale mailbox messages

**Files:**
- Modify: `apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex`

- [ ] **Step 1: Add nil guard to `:fire_retry` handler**

Replace (around line 741):
```elixir
  def handle_info(:fire_retry, socket) do
    scope = socket.assigns.scope
    task_id = socket.assigns.task_id
    opts = socket.assigns[:last_execution_opts] || []
    mcp_tools = socket.assigns[:mcp_tools] || []
    all_tools = mcp_tools |> Tools.prepare_for_task(task_id)
    Tasks.maybe_start_execution(scope, task_id, all_tools, opts)
    {:noreply, socket}
  end
```

With:
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

- [ ] **Step 2: Run both new tests to confirm they pass**

Run: `cd apps/frontman_server && mix test test/frontman_server_web/channels/task_channel_test.exs 2>&1 | tail -20`

Expected: ALL tests pass, including the two new ones from Tasks 1 and 2.

- [ ] **Step 3: Commit**

```bash
cd apps/frontman_server
git add lib/frontman_server_web/channels/task_channel.ex
git commit -m "fix: guard :fire_retry against stale mailbox messages

Process.cancel_timer/1 cannot dequeue a message already in the mailbox.
Check retry_state before starting execution to handle the race where
cancel clears state but :fire_retry was already enqueued."
```

---

### Task 5: Run full test suite and format check

**Files:** None (verification only)

- [ ] **Step 1: Run mix format**

Run: `cd apps/frontman_server && mix format`

- [ ] **Step 2: Run the full task_channel test file**

Run: `cd apps/frontman_server && mix test test/frontman_server_web/channels/task_channel_test.exs 2>&1 | tail -20`

Expected: All tests pass, zero failures.

- [ ] **Step 3: Run the retry coordinator unit tests**

Run: `cd apps/frontman_server && mix test test/frontman_server/tasks/retry_coordinator_test.exs 2>&1 | tail -20`

Expected: All tests pass (this module was not modified, just confirming nothing is broken).
