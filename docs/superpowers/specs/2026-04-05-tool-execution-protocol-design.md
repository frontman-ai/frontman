# Tool Execution Protocol Design

**Date:** 2026-04-05
**Status:** Approved

## Problem

`ParallelExecutor` manages tool execution through two opaque mechanisms that share ownership of the same operation:

1. A global `on_deadline` closure callback for side effects (DB writes, Sentry)
2. A `receive...after` safety-net inside each MCP task that competes with PE's deadline timer

Both fire at `600_000ms` for default MCP tools. Whichever message arrives in PE's mailbox first — `{:DOWN, ...}` from the task's `exit(:timeout)` or `{:deadline, ref}` from PE's own timer — determines whether Sentry fires, which result string the LLM sees, and whether the DB gets one or two writes. The race is non-deterministic and silent.

The root cause: the executor function signature `[ToolCall.t()] -> [ToolResult.t()]` is opaque. PE cannot distinguish "something that computes" from "something that awaits a message." Both run as Tasks with an internal receive loop racing PE's external deadline.

## Design

### Core Insight

MCP tools do not execute — they await a message from the browser client. Spawning a Task whose only job is to block on `receive` creates a second process with a second timeout mechanism. Move MCP tool lifecycle into PE's existing receive loop, where it belongs.

Use a formal `ToolExecution` type (a tagged struct) so PE knows at the type level how to handle each tool, and the compiler catches missing cases.

Use `{module, function, args}` MFA tuples for callbacks instead of closures. MFA tuples are inspectable, loggable, and match the existing `event_dispatcher` pattern in `SwarmAi.Runtime`.

### New Type: `SwarmAi.ToolExecution`

Two structs — one per execution kind. PE pattern-matches on the struct type.

```elixir
defmodule SwarmAi.ToolExecution.Sync do
  use TypedStruct

  typedstruct enforce: true do
    field :tool_call,         SwarmAi.ToolCall.t()
    field :timeout_ms,        pos_integer()
    field :on_timeout_policy, :error | :pause_agent
    field :run,        {module(), atom(), list()}
    # apply(mod, fun, args ++ [tool_call]) :: ToolResult.t()
    field :on_timeout, {module(), atom(), list()}
    # apply(mod, fun, args ++ [tool_call, :triggered | :cancelled]) :: :ok
  end
end

defmodule SwarmAi.ToolExecution.Await do
  use TypedStruct

  typedstruct enforce: true do
    field :tool_call,         SwarmAi.ToolCall.t()
    field :timeout_ms,        pos_integer()
    field :on_timeout_policy, :error | :pause_agent
    field :start,       {module(), atom(), list()}
    # apply(mod, fun, args ++ [tool_call]) :: :ok  (called in PE's own process)
    field :message_key, term()
    # PE matches {:tool_result, message_key, content, is_error} in its receive loop
    field :on_timeout,  {module(), atom(), list()}
    # apply(mod, fun, args ++ [tool_call, :triggered | :cancelled]) :: :ok
  end
end

@type t :: SwarmAi.ToolExecution.Sync.t() | SwarmAi.ToolExecution.Await.t()
```

The executor contract changes from:

```elixir
[ToolCall.t()] -> [ToolResult.t()]      # opaque: runs the tool
```

to:

```elixir
[ToolCall.t()] -> [ToolExecution.t()]   # describes how to run the tool
```

PE is the only thing that executes. The executor builds descriptions.

### Revised `SwarmAi.ParallelExecutor`

**New signature** — `tool_map` and `on_deadline` parameters are gone:

```elixir
@spec run([ToolExecution.t()], pid() | atom()) ::
        {:ok, [ToolResult.t()]} | {:halt, halt_reason()}
```

**Two maps in PE's collect loop:**

```elixir
pending  :: %{reference() => pending_entry()}  # keyed by slot ref (both kinds)
awaiting :: %{term() => reference()}           # message_key → slot ref (await only)
```

**Spawning per kind:**

```elixir
# Sync — same as today
task = Task.Supervisor.async_nolink(sup, fn ->
  apply(mod, fun, args ++ [exec.tool_call])
end)
timer = Process.send_after(self(), {:deadline, task.ref}, exec.timeout_ms)
pending = Map.put(pending, task.ref, %{kind: :sync, exec: exec, timer: timer, pid: task.pid})

# Await — start runs in PE's own process so self() = PE's pid
ref = make_ref()
apply(mod, fun, args ++ [exec.tool_call])  # registers PE's pid in ToolCallRegistry
timer = Process.send_after(self(), {:deadline, ref}, exec.timeout_ms)
pending  = Map.put(pending, ref, %{kind: :await, exec: exec, timer: timer})
awaiting = Map.put(awaiting, exec.message_key, ref)
```

**Receive loop — one new arm added:**

```elixir
receive do
  {ref, result} when is_map_key(pending, ref) ->
    # sync task completed normally

  {:DOWN, ref, :process, _pid, reason} when is_map_key(pending, ref) ->
    # sync task crashed

  {:tool_result, key, content, is_error} when is_map_key(awaiting, key) ->
    # await tool received browser client response
    ref = Map.fetch!(awaiting, key)
    %{exec: exec, timer: timer} = Map.fetch!(pending, ref)
    Process.cancel_timer(timer)
    result = ToolResult.make(exec.tool_call.id, content, is_error)
    collect_results(
      Map.delete(pending, ref),
      Map.delete(awaiting, key),
      Map.put(results, exec.tool_call.id, result),
      sup
    )

  {:deadline, ref} when is_map_key(pending, ref) ->
    handle_deadline(pending, awaiting, ref, sup)
end
```

**`handle_deadline` unified for both kinds:**

```elixir
defp handle_deadline(pending, awaiting, ref, sup) do
  %{kind: kind, exec: exec} = Map.fetch!(pending, ref)

  # Side effects via MFA — same call regardless of kind
  apply(mod, fun, args ++ [exec.tool_call, :triggered])

  # Teardown differs by kind
  awaiting =
    case kind do
      :sync ->
        Task.Supervisor.terminate_child(sup, exec.pid)
        receive do {:DOWN, ^ref, :process, _, _} -> :ok end
        awaiting

      :await ->
        Map.delete(awaiting, exec.message_key)
    end

  # Policy handling unchanged
  case exec.on_timeout_policy do
    :error ->
      result = ToolResult.make(exec.tool_call.id,
        "Tool timed out after #{exec.timeout_ms}ms", true)
      collect_results(Map.delete(pending, ref), awaiting,
        Map.put(results, exec.tool_call.id, result), sup)

    :pause_agent ->
      cancel_remaining(Map.delete(pending, ref), awaiting, ref, sup)
      {:halt, {:pause_agent, exec.tool_call.id, exec.tool_call.name, exec.timeout_ms}}
  end
end
```

### Revised `FrontmanServer.ToolExecutor`

`make_executor` returns a single executor function (no more `{executor, on_deadline}` tuple):

```elixir
def make_executor(%Scope{} = scope, task_id, opts) do
  exec_opts = build_exec_opts(opts)

  fn tool_calls ->
    Enum.map(tool_calls, &build_execution(&1, scope, task_id, exec_opts))
  end
end

defp build_execution(tool_call, scope, task_id, exec_opts) do
  case Map.fetch(exec_opts.backend_module_map, tool_call.name) do
    {:ok, module} ->
      %ToolExecution.Sync{
        tool_call:         tool_call,
        timeout_ms:        module.timeout_ms(),
        on_timeout_policy: module.on_timeout(),
        run:       {__MODULE__, :run_backend_tool, [scope, module, task_id, exec_opts]},
        on_timeout: {__MODULE__, :handle_timeout, [scope, task_id, module.on_timeout()]}
      }

    :error ->
      tool_def = find_mcp_tool_def!(tool_call.name, exec_opts)
      %ToolExecution.Await{
        tool_call:         tool_call,
        timeout_ms:        tool_def.timeout_ms,
        on_timeout_policy: tool_def.on_timeout,
        start:       {__MODULE__, :start_mcp_tool, [scope, task_id]},
        message_key: tool_call.id,
        on_timeout:  {__MODULE__, :handle_timeout, [scope, task_id, tool_def.on_timeout]}
      }
  end
end
```

**Three public callback functions** (called by PE via MFA — `@doc false`):

```elixir
# Called by PE in a spawned task. Returns ToolResult.t().
# DB write is a side effect inside (existing execute_backend_tool logic).
def run_backend_tool(scope, module, task_id, exec_opts, tool_call)

# Called by PE in its own process (self() = PE's pid).
# Registers PE in ToolCallRegistry and publishes the ToolCall interaction.
def start_mcp_tool(scope, task_id, tool_call)

# Called by PE on deadline. Side effects only — PE handles ToolResult and halt logic.
def handle_timeout(scope, task_id, :error, tool_call, _reason)
  # Tasks.add_tool_result + Sentry

def handle_timeout(_scope, _task_id, :pause_agent, _tool_call, :triggered)
  # :ok — SwarmDispatcher persists via {:paused, ...} event

def handle_timeout(scope, task_id, :pause_agent, tool_call, :cancelled)
  # Tasks.add_tool_result with cancellation message
```

### Simplified `Runtime.do_wrap_executor`

```elixir
defp do_wrap_executor(opts, inner_executor, task_supervisor) do
  parallel_executor = fn tool_calls ->
    executions = inner_executor.(tool_calls)
    SwarmAi.ParallelExecutor.run(executions, task_supervisor)
  end

  Keyword.put(opts, :tool_executor, parallel_executor)
end
```

`tool_defs` and `on_deadline` options are removed entirely.

## What Disappears

| Removed | Replaced by |
|---------|-------------|
| `execute_mcp_tool/4` and its `receive...after` safety-net | PE's `{:tool_result, ...}` receive arm |
| `{executor, on_deadline}` tuple return from `make_executor` | Single executor function |
| `tool_map` and `on_deadline` params to `ParallelExecutor.run` | Fields on `ToolExecution` structs |
| `resolve_timeout_policy/2` | `exec.on_timeout_policy` on the struct |
| `@tool_timeout_ms` constant | Per-tool `timeout_ms` field |
| `ToolExecutor.execute/4` public function | Test-only; tests rewritten against callback functions |

## Testing

`ToolExecution` structs are plain data — tests can assert on exactly what was built without threading a full executor pipeline:

```elixir
test "MCP tool produces Await execution with correct policy" do
  [execution] = make_executor(scope, task_id, opts).(mcp_tool_call())
  assert %ToolExecution.Await{
    on_timeout_policy: :pause_agent,
    message_key: ^tool_call_id,
    on_timeout: {ToolExecutor, :handle_timeout, [^scope, ^task_id, :pause_agent]}
  } = execution
end
```

`handle_timeout/5`, `start_mcp_tool/3`, and `run_backend_tool/5` are named public functions — directly unit testable.

`ParallelExecutor` tests construct `ToolExecution` structs with test MFA callbacks that record calls — no timing-sensitive receive loops.

The race condition requires no test: it is structurally impossible. There is no task for MCP tools, and no competing timeout mechanism.

## Migration Order

1. **SwarmAi** — add `ToolExecution.Sync` and `ToolExecution.Await`, update `ParallelExecutor.run/2`, update `Runtime.do_wrap_executor`. Compiles independently.
2. **FrontmanServer** — update `make_executor`, implement the three public callbacks, delete `execute_mcp_tool`. Update `ToolCallRegistry` routing (already correct — `start_mcp_tool` calls `register_mcp_tool` with `self()` = PE's pid).
3. **Tests** — update `parallel_executor_test`, `parallel_tool_execution_test`, `tool_executor_test`, `tool_error_sentry_test`, `runtime_test`.
