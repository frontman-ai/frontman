# Fix Noisy Test Logs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Silence 121 expected error/warning log lines that pollute CI test output by wrapping them with `ExUnit.CaptureLog`.

**Architecture:** Each noisy test either (a) already uses `capture_log` but has gaps, or (b) needs `capture_log` / `@tag :capture_log` added to specific tests. No production code changes — all fixes are in test files.

**Tech Stack:** Elixir, ExUnit, ExUnit.CaptureLog

---

## File Map

All files are under `apps/frontman_server/test/`:

| File | Action | Log patterns to capture |
|------|--------|------------------------|
| `frontman_server_web/channels/task_channel_test.exs` | Modify | 401 auth errors (Stream error, Metadata collection failed, Execution failed, event dispatch failed), "Client tried to join non-existent task", "Unknown ACP method" |
| `frontman_server_web/channels/task_channel_sentry_test.exs` | Modify | "MCP tool failed: permission denied", "Unknown MCP error" |
| `frontman_server/tasks/execution/tool_error_sentry_test.exs` | Modify | "ToolExecutor: Failed to parse arguments", "ToolExecutor: MCP tool timed out", "ToolExecutor: Backend tool failed" |
| `frontman_server_web/channels/task_channel/mcp_initializer_test.exs` | Modify | "Unexpected project rules format" |

Files already clean (no changes needed):
- `error_propagation_test.exs` — already uses `capture_log` everywhere
- `execution_sentry_test.exs` — already uses `capture_log` everywhere
- `stream_stall_timeout_test.exs` — already uses `capture_log` on stall tests
- `stream_cleanup_test.exs` — already uses `capture_log` on the cancel-explodes test

---

### Task 1: Capture logs in `task_channel_test.exs`

This is the noisiest file (95+ lines). The 401 auth errors come from tests that push `session/prompt` which triggers `Tasks.submit_user_message` → LLM execution with no real API key. The "non-existent task" and "Unknown ACP method" warnings come from tests that deliberately exercise those paths.

**Files:**
- Modify: `apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs`

**Strategy:** Use `@tag :capture_log` on specific tests, not module-wide, because many tests in this file don't produce log noise and we don't want to mask unexpected errors.

- [ ] **Step 1: Add `@tag :capture_log` to the "fails when task does not exist" test**

This test deliberately joins a non-existent task, producing `[warning] Client tried to join non-existent task`.

```elixir
    @tag :capture_log
    test "fails when task does not exist", %{scope: scope} do
```

- [ ] **Step 2: Add `@tag :capture_log` to the "returns error for unknown method" test**

This test sends an unknown ACP method, producing `[warning] Unknown ACP method in task channel: unknown/method`.

```elixir
    @tag :capture_log
    test "returns error for unknown method", %{socket: socket} do
```

- [ ] **Step 3: Add `@tag :capture_log` to the "forwards prompt model and env API key" test**

This test pushes a prompt that triggers LLM execution with no credentials, producing 401 auth errors.

```elixir
    @tag :capture_log
    test "forwards prompt model and env API key to title generation job", %{
```

- [ ] **Step 4: Add `@tag :capture_log` to the "MCP tools race condition" describe setup**

The test in this describe block pushes a prompt before MCP init, which triggers LLM execution.

```elixir
  describe "MCP tools race condition" do
    @tag :capture_log
    test "queued prompt is processed with MCP tools after initialization completes", %{
```

- [ ] **Step 5: Add `@tag :capture_log` to tests that push `session/prompt` (triggering LLM execution)**

Any test that calls `push(socket, "acp:message", build_prompt_request(...))` triggers `Tasks.submit_user_message` which spawns the LLM agent. Without real API keys, this produces 401 auth errors.

Add `@tag :capture_log` before each of these tests:

In "failed event handling" describe:
```elixir
    @tag :capture_log
    test "sends JSON-RPC error response when prompt is pending", %{
```

In "completed event without pending prompt" describe:
```elixir
    @tag :capture_log
    test "does not interfere with subsequent prompts after nil completion", %{
```

In "session/cancel" describe:
```elixir
    @tag :capture_log
    test "cancel resolves pending prompt with stopReason 'cancelled'", %{

    # "cancel with no pending prompt is a no-op" does NOT push a prompt — skip it

    @tag :capture_log
    test "cancel does not interfere with subsequent prompts", %{
```

- [ ] **Step 6: Skip "tool_call_start chunk streaming" — no changes needed**

These tests (lines 896-1037) only send interactions directly via `send(socket.channel_pid, ...)` — they don't push `session/prompt`, so they don't trigger LLM execution and don't produce log noise.

- [ ] **Step 7: Add `@tag :capture_log` to the "reconnect re-executes unresolved tool calls" tests**

All tests in this describe block join channels for tasks that have interactions, and some trigger LLM execution.

```elixir
    @tag :capture_log
    test "e2e: reconnect → session/load → tools/call → answer → tool result persisted", %{

    @tag :capture_log
    test "e2e: session/load before MCP handshake → answer after handshake → persisted", %{

    @tag :capture_log
    test "tools/call is pushed AFTER session/load success response (ordering guarantee)", %{

    @tag :capture_log
    test "resolved tool calls are NOT re-dispatched", %{
```

- [ ] **Step 8: Run the test file and verify zero log noise**

Run: `mix test test/frontman_server_web/channels/task_channel_test.exs 2>&1 | grep -E '\[(error|warning)\]'`
Expected: No output (zero log lines)

- [ ] **Step 9: Run the test file normally and verify all tests still pass**

Run: `mix test test/frontman_server_web/channels/task_channel_test.exs`
Expected: All tests pass, 0 failures

- [ ] **Step 10: Commit**

```bash
git add apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs
git commit -m "fix: capture expected log noise in task_channel_test"
```

---

### Task 2: Capture logs in `task_channel_sentry_test.exs`

Two tests produce MCP tool error logs — these are testing Sentry error reporting for MCP tool failures.

**Files:**
- Modify: `apps/frontman_server/test/frontman_server_web/channels/task_channel_sentry_test.exs`

- [ ] **Step 1: Add `import ExUnit.CaptureLog` and wrap both MCP error tests**

Add the import at the top of the module, then wrap the test bodies that produce error logs with `capture_log`. These tests should also assert the log content since they're testing error reporting:

```elixir
  import ExUnit.CaptureLog

  # ... (existing setup stays the same)

  describe "MCP tool error Sentry reporting (Gap 4)" do
    test "reports MCP tool error to Sentry with context", %{
      socket: socket,
      task_id: task_id
    } do
      tool_call =
        tool_call("call_mcp_err_#{:rand.uniform(1_000_000)}", "testMcpTool", %{"key" => "value"})

      send(socket.channel_pid, {:interaction, tool_call})

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "id" => mcp_request_id,
        "params" => %{"name" => "testMcpTool"}
      })

      mcp_error = %{
        "code" => -32_000,
        "message" => "Tool execution failed: permission denied"
      }

      log =
        capture_log(fn ->
          push(
            socket,
            "mcp:message",
            JsonRpc.error_response(mcp_request_id, mcp_error["code"], mcp_error["message"])
          )

          :sys.get_state(socket.channel_pid)
        end)

      assert log =~ "MCP tool testMcpTool failed"

      # ... rest of assertions unchanged
```

Do the same wrapping for the "MCP tool error with missing message field" test:

```elixir
    test "MCP tool error with missing message field defaults to 'Unknown MCP error'", %{
      socket: socket
    } do
      tool_call =
        tool_call("call_mcp_no_msg_#{:rand.uniform(1_000_000)}", "anotherMcpTool")

      send(socket.channel_pid, {:interaction, tool_call})

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "id" => mcp_request_id
      })

      log =
        capture_log(fn ->
          push(
            socket,
            "mcp:message",
            JsonRpc.error_response(mcp_request_id, -32_000, "Unknown MCP error")
          )

          :sys.get_state(socket.channel_pid)
        end)

      assert log =~ "MCP tool anotherMcpTool failed"

      # ... rest of assertions unchanged
```

- [ ] **Step 2: Run the test file and verify zero log noise**

Run: `mix test test/frontman_server_web/channels/task_channel_sentry_test.exs 2>&1 | grep -E '\[(error|warning)\]'`
Expected: No output

- [ ] **Step 3: Run the test file and verify all tests pass**

Run: `mix test test/frontman_server_web/channels/task_channel_sentry_test.exs`
Expected: All tests pass, 0 failures

- [ ] **Step 4: Commit**

```bash
git add apps/frontman_server/test/frontman_server_web/channels/task_channel_sentry_test.exs
git commit -m "fix: capture expected MCP error logs in task_channel_sentry_test"
```

---

### Task 3: Capture logs in `tool_error_sentry_test.exs`

Six tests produce ToolExecutor error logs — JSON parse failures, MCP timeout, and backend tool errors.

**Files:**
- Modify: `apps/frontman_server/test/frontman_server/tasks/execution/tool_error_sentry_test.exs`

- [ ] **Step 1: Add `import ExUnit.CaptureLog` and wrap the three describe blocks**

Add the import at the top. Then wrap the `ToolExecutor.execute` calls in `capture_log` for tests that produce log output. Assert on log content where meaningful.

For the "backend tool soft error" test (line 42-82):
```elixir
      log =
        capture_log(fn ->
          result =
            ToolExecutor.execute(scope, tool_call, task_id,
              mcp_tools: [],
              llm_opts: [api_key: "test", model: "mock"]
            )

          assert {:error, _reason} = result
        end)

      assert log =~ "ToolExecutor: Backend tool todo_write failed"
```

For the "malformed JSON arguments" test (line 86-123):
```elixir
      log =
        capture_log(fn ->
          result =
            ToolExecutor.execute(scope, tool_call, task_id,
              mcp_tools: [],
              llm_opts: [api_key: "test", model: "mock"]
            )

          assert {:error, _reason} = result
        end)

      assert log =~ "ToolExecutor: Failed to parse arguments"
```

For the "truncates long raw arguments" test (line 148-174):
```elixir
      capture_log(fn ->
        assert {:error, _} =
                 ToolExecutor.execute(scope, tool_call, task_id,
                   mcp_tools: [],
                   llm_opts: [api_key: "test", model: "mock"]
                 )
      end)
```

For the "MCP tool timeout" test (line 180-225):
```elixir
      task =
        Task.async(fn ->
          capture_log(fn ->
            result =
              ToolExecutor.execute(scope, tool_call, task_id,
                mcp_tools: [],
                llm_opts: [api_key: "test", model: "mock"]
              )

            send(test_pid, {:tool_result, result})
          end)
        end)
```

- [ ] **Step 2: Run the test file and verify zero log noise**

Run: `mix test test/frontman_server/tasks/execution/tool_error_sentry_test.exs 2>&1 | grep -E '\[(error|warning)\]'`
Expected: No output

- [ ] **Step 3: Run the test file and verify all tests pass**

Run: `mix test test/frontman_server/tasks/execution/tool_error_sentry_test.exs`
Expected: All tests pass, 0 failures

- [ ] **Step 4: Commit**

```bash
git add apps/frontman_server/test/frontman_server/tasks/execution/tool_error_sentry_test.exs
git commit -m "fix: capture expected ToolExecutor error logs in tool_error_sentry_test"
```

---

### Task 4: Capture logs in `mcp_initializer_test.exs`

One test produces `[warning] MCPInitializer: Unexpected project rules format` — the "handles JSON that decodes to a map" test on line 110.

**Files:**
- Modify: `apps/frontman_server/test/frontman_server_web/channels/task_channel/mcp_initializer_test.exs`

- [ ] **Step 1: Wrap the unhandled decode test with `capture_log`**

The file already imports `ExUnit.CaptureLog`. Just wrap the test:

```elixir
  describe "handle_response/3 with unhandled decode results" do
    test "project rules: handles JSON that decodes to a map (not a list)" do
      request_id = 1
      state = rules_state(request_id)

      result = %{
        "content" => [%{"text" => ~s({"key": "value"}), "type" => "text"}]
      }

      log =
        capture_log(fn ->
          {new_state, _actions} = MCPInitializer.handle_response(state, request_id, result)

          assert new_state.status == :loading_project_structure
        end)

      assert log =~ "Unexpected project rules format"
    end
  end
```

- [ ] **Step 2: Run the test file and verify zero log noise**

Run: `mix test test/frontman_server_web/channels/task_channel/mcp_initializer_test.exs 2>&1 | grep -E '\[(error|warning)\]'`
Expected: No output

- [ ] **Step 3: Run the test file and verify all tests pass**

Run: `mix test test/frontman_server_web/channels/task_channel/mcp_initializer_test.exs`
Expected: All tests pass, 0 failures

- [ ] **Step 4: Commit**

```bash
git add apps/frontman_server/test/frontman_server_web/channels/task_channel/mcp_initializer_test.exs
git commit -m "fix: capture expected warning in mcp_initializer_test"
```

---

### Task 5: Full suite verification

- [ ] **Step 1: Run the full test suite and verify clean output**

Run: `mix test 2>&1 | grep -E '\[(error|warning)\]' | grep -v 'Postgrex'`
Expected: Zero log lines (or only intermittent timing-dependent lines from `StreamStallTimeout` which are already captured but may race across processes)

- [ ] **Step 2: Run the full test suite and verify all tests pass**

Run: `mix test`
Expected: All 725 tests pass, 0 failures

- [ ] **Step 3: Final commit (if any remaining fixes needed from step 1)**

If step 1 reveals remaining noise, trace it and add `capture_log` to the relevant test, then commit.
