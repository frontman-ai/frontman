# Backend Tool Crash & Timeout Fix

**Date:** 2026-04-02
**Branch:** issue-743-feat-enable-parallel-tool

## Problem

Two open issues from PR #761 review, both rooted in the same invariant violation:
**every persisted `ToolCall` must have a matching `ToolResult`**.

### Issue 1 — `Task.async` link propagates EXIT on backend tool crash

`await_backend_tool` uses `Task.async`, which creates a bidirectional link. When
`module.execute` crashes during `Task.yield`, the EXIT signal kills the caller
before `Task.yield` can return `{:exit, reason}`. The `{:error, reason}` branch
(and its `Tasks.add_tool_result` call) is unreachable. No ToolResult is persisted.

### Issue 2 — ParallelExecutor timeout fires before `await_backend_tool` timeout

`todo_write` declares `timeout_ms: 30_000`; `@tool_timeout_ms` is 60_000.
ParallelExecutor kills the outer task at 30s — well before `Task.yield` fires —
bypassing all persistence and Sentry reporting in `execute_backend_tool`.
For `web_fetch` (both 60s), there is a race with an unpredictable winner.

### Root cause — hidden global dependency

`make_executor/3` calls `Tools.find_tool/1` internally to resolve backend
tool modules. This compile-time list is invisible to callers, making it
impossible to inject test stubs without ETS hacks or mock registries. The
asymmetry is also architecturally inconsistent: MCP tools and `llm_opts` are
passed explicitly by the caller; backend tool modules are not.

## Design

### 1. Make backend tool modules an explicit dependency

Add `Tools.backend_tool_modules/0 :: [module()]` (the raw module list).

`make_executor/3` gains a `backend_tool_modules: [module()]` opt. Internally it
builds a `%{name => module}` map and replaces the `Tools.find_tool/1` call with
a map lookup. The executor is now a pure function of its inputs — no hidden
globals.

All production call sites pass `backend_tool_modules: Tools.backend_tool_modules()`.
Tests pass stubs directly.

Thread `backend_tool_modules:` through `Tasks.submit_user_message` →
`Execution.run` → `submit_to_runtime` → `make_executor` (same pattern as the
existing `agent:` override).

### 2. Fix `execute_backend_tool` — adopt the MCP trap-exit pattern

Remove `await_backend_tool` and `@tool_timeout_ms`. ParallelExecutor is the sole
timeout authority; each backend tool already declares `timeout_ms`/`on_timeout`.

Add `{Task.Supervisor, name: FrontmanServer.BackendToolSupervisor}` to
`application.ex`.

New execution pattern (mirrors `execute_mcp_tool`):

```elixir
Process.flag(:trap_exit, true)

task = Task.Supervisor.async_nolink(FrontmanServer.BackendToolSupervisor, fn ->
  module.execute(args, context)
end)

result =
  receive do
    {^task_ref, value} ->
      Process.demonitor(task.ref, [:flush])
      value

    {:DOWN, ^task_ref, :process, _, reason} ->
      # Inner task crashed — no EXIT propagation (async_nolink)
      {:error, {:crashed, reason}}

    {:EXIT, _from, :shutdown} ->
      # ParallelExecutor timed out this task (on_timeout: :error).
      # Kill inner task, persist ToolResult, then re-exit so ParallelExecutor
      # receives the expected DOWN message.
      Task.Supervisor.terminate_child(FrontmanServer.BackendToolSupervisor, task.pid)
      receive do {:DOWN, ^task_ref, :process, _, _} -> :ok after 5_000 -> :ok end
      {:error, :timeout}
      # (caller persists ToolResult + Sentry, then calls exit(:shutdown))

    {:EXIT, _from, :kill} ->
      # Brutal kill — no cleanup window
      exit(:kill)
  end

Process.flag(:trap_exit, false)
```

After the receive, `execute_backend_tool` persists a `ToolResult` for every
outcome — success, crash, and timeout — then calls Sentry for errors.
For `:timeout`, it calls `exit(:shutdown)` after persisting so ParallelExecutor
gets the expected DOWN message.

The `:shutdown` → `:kill` grace period (OTP default: 5 s) is sufficient for a
single DB write. `:kill` is only sent if cleanup exceeds the grace period.

### 3. Testing strategy

**Stub modules** — defined inline in test files, conforming to the `Backend`
behaviour. No ETS, no mock registries.

```elixir
defmodule CrashTool do
  @behaviour FrontmanServer.Tools.Backend
  def name, do: "crash_tool"
  def description, do: "crashes"
  def parameter_schema, do: %{"type" => "object", "properties" => %{}}
  def timeout_ms, do: 5_000
  def on_timeout, do: :error
  def execute(_args, _ctx), do: raise("boom")
end

defmodule HangTool do
  @behaviour FrontmanServer.Tools.Backend
  def name, do: "hang_tool"
  def description, do: "hangs"
  def parameter_schema, do: %{"type" => "object", "properties" => %{}}
  def timeout_ms, do: 100
  def on_timeout, do: :error
  def execute(_args, _ctx), do: Process.sleep(:infinity)
end
```

**Domain/context tests** (`execution_test.exs`) — assert the DB invariant:

| Scenario | Assertion |
|---|---|
| Backend tool crashes | `ToolResult` exists in DB, `is_error: true`; agent completes normally |
| Backend tool times out (ParallelExecutor fires) | Same |

**Channel integration tests** (`task_channel_test.exs`) — assert the client contract only:

| Scenario | Assertion |
|---|---|
| Backend tool crashes | `session/update` with `agent_turn_complete` pushed; pending `session/prompt` RPC resolved |
| Backend tool times out | Same |

Channel tests do not re-assert DB state — that is the domain tests' job.

## Files changed

| File | Change |
|---|---|
| `apps/frontman_server/lib/frontman_server/tools.ex` | Add `backend_tool_modules/0` |
| `apps/frontman_server/lib/frontman_server/tasks/execution/tool_executor.ex` | Thread `backend_tool_modules`, remove `await_backend_tool` + `@tool_timeout_ms`, adopt trap-exit pattern in `execute_backend_tool` |
| `apps/frontman_server/lib/frontman_server/tasks/execution.ex` | Pass `backend_tool_modules:` to `make_executor` |
| `apps/frontman_server/lib/frontman_server/application.ex` | Add `FrontmanServer.BackendToolSupervisor` |
| `apps/frontman_server/test/frontman_server/tasks/execution_test.exs` | Add domain tests for crash + timeout |
| `apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs` | Add channel tests for crash + timeout |
