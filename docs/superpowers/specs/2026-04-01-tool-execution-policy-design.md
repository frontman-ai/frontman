# Tool Execution Policy Design

**Date:** 2026-04-01
**Branch:** issue-743-feat-enable-parallel-tool

## Problem

The parallel tool executor in `SwarmAi.Runtime` uses a single 25-hour timeout for all tools via `async_stream_nolink`. This has two problems:

1. **Interactive tools** (e.g. `question`) block the agent task for up to 24 hours waiting for human input, keeping a supervised process alive unnecessarily.
2. **All timeout behavior** is hardcoded in `swarm_ai` — error ToolResult regardless of tool type. The decision of what to do on timeout belongs to the tool, not the framework.

The fix: tools declare their own execution policy. The Runtime reads this policy and acts accordingly.

## Design

### Principle

**`swarm_ai`** owns the mechanism: parallel execution, per-task deadline tracking, two possible timeout outcomes.

**`frontman_server`** owns the policy: which tools are interactive, what timeouts make sense, encoded in tool definitions at construction time.

The seam is `SwarmAi.Tool` — it carries the execution policy fields that the Runtime reads.

---

### 1. `SwarmAi.Tool` — execution policy fields

Two new enforced fields:

```elixir
typedstruct enforce: true do
  field(:name, String.t())
  field(:description, String.t())
  field(:parameter_schema, map())
  field(:timeout_ms, pos_integer())
  field(:on_timeout, :error | :pause_agent)
end
```

**No defaults.** Every tool must explicitly declare both. Missing either crashes at construction time — misconfigured tools fail loudly, not silently at runtime.

`on_timeout` semantics:
- `:error` — return an error `ToolResult` to the LLM, agent continues
- `:pause_agent` — exit the agent process cleanly (`:normal`), no event dispatched, DB state is the resumption point

`SwarmAi.Tool.new/3` becomes `SwarmAi.Tool.new/3` with keyword opts — `timeout_ms:` and `on_timeout:` are required keys. Calling without them raises `KeyError` at construction time.

---

### 2. `FrontmanServer.Tools.Backend` — explicit behaviour callbacks

`Backend` behaviour gains two required callbacks:

```elixir
@callback timeout_ms() :: pos_integer()
@callback on_timeout() :: :error | :pause_agent
```

Every backend tool module must implement both. `Backend.to_swarm_tool/1` passes them through:

```elixir
def to_swarm_tool(module) do
  SwarmAi.Tool.new(
    module.name(),
    module.description(),
    module.parameter_schema(),
    timeout_ms: module.timeout_ms(),
    on_timeout: module.on_timeout()
  )
end
```

All existing backend tools are synchronous server-side operations — they will declare `on_timeout: :error`. The timeout value is per-tool (e.g. a sub-agent spawning tool needs a longer timeout than a simple file read).

---

### 3. `FrontmanServer.Tools.MCP` — explicit wire fields

`Tools.MCP.t()` gains two fields parsed directly from the client-sent tool definition:

```elixir
field(:timeout_ms, pos_integer())
field(:on_timeout, :error | :pause_agent)
```

`from_map/1` parses `timeoutMs` and `onTimeout` from the wire format. If either is absent — crash. The MCP client is responsible for declaring both on every tool.

`to_swarm_tool/1` is a straight pass-through, no derivation:

```elixir
def to_swarm_tool(%__MODULE__{} = t) do
  SwarmAi.Tool.new(t.name, t.description, t.input_schema,
    timeout_ms: t.timeout_ms,
    on_timeout: t.on_timeout
  )
end
```

The `execution_policy/1` derivation function does not exist. MCP tools own their policy.

---

### 4. `SwarmAi.Runtime` — per-task timeout executor

`do_wrap_executor` replaces `Task.Supervisor.async_stream_nolink` (single global timeout) with per-task `Task.Supervisor.async_nolink` + a deadline-tracking yield loop.

```elixir
defp do_wrap_executor(opts, executor, task_supervisor) do
  tool_defs = Keyword.get(opts, :tool_defs, [])

  parallel_executor = fn tool_calls ->
    start_ms = System.monotonic_time(:millisecond)

    tasks =
      Enum.map(tool_calls, fn tc ->
        task = Task.Supervisor.async_nolink(task_supervisor, fn ->
          [result] = executor.([tc])
          result
        end)
        tool_def = Enum.find(tool_defs, &(&1.name == tc.name))
        deadline = start_ms + tool_def.timeout_ms
        {task, tc, tool_def, deadline}
      end)

    collect_with_per_task_timeouts(tasks)
  end

  Keyword.put(opts, :tool_executor, parallel_executor)
end
```

**`collect_with_per_task_timeouts`** loops using `Task.yield_many` with the next-expiring deadline as the wait window. Each iteration:
- Completed tasks: pass result through or convert `{:exit, reason}` to error ToolResult
- Expired tasks: kill with `:brutal_kill`, then check `tool_def.on_timeout`:
  - `:error` → error ToolResult, continue collecting remaining tasks
  - `:pause_agent` → `exit(:normal)` immediately — unwinds the agent task, `after` block unregisters from Registry, death watcher sees `:normal` and dispatches nothing

If a `ToolCall` has no matching entry in `tool_defs` — crash. No silent fallback.

The `ordered: true` guarantee from `async_stream_nolink` is preserved by collecting results into a map keyed by `tc.id` and re-ordering at the end.

---

### 5. Wiring `tool_defs` through

`Execution.submit_to_runtime` passes `mcp_tools` (already `[SwarmAi.Tool.t()]` after `to_swarm_tools/1`) as `tool_defs`:

```elixir
SwarmAi.Runtime.run(FrontmanServer.AgentRuntime, task_id, agent, messages,
  metadata: ...,
  tool_executor: tool_executor,
  tool_defs: mcp_tools
)
```

No transformation. `Runtime.run/5` passes `opts` down to `wrap_executor_with_parallel` which reads `tool_defs` from opts.

---

### 6. `ToolExecutor` — remove interactive inner timeout

`@interactive_tool_timeout_ms` and its `after` clause are removed. The interactive `receive` becomes unconditional:

```elixir
receive do
  {:tool_result, ^tool_call_id, content, is_error} ->
    Registry.unregister(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id})
    if is_error, do: {:error, content}, else: {:ok, content}
end
```

The Runtime's per-task deadline is the only timeout for interactive tools.

`@tool_timeout_ms` on non-interactive MCP tools stays — they handle their own timeouts and return before the Runtime deadline fires.

---

## Data Flow

```
Execution.submit_to_runtime
    builds mcp_tools ([SwarmAi.Tool.t()] with timeout_ms + on_timeout)
    passes tool_defs: mcp_tools to Runtime.run/5

Runtime.do_wrap_executor
    reads tool_defs from opts
    starts one async_nolink task per tool call
    tracks per-task deadlines

collect_with_per_task_timeouts
    loops via Task.yield_many
    completed → pass through
    {:exit, reason} → error ToolResult
    expired + :error → error ToolResult
    expired + :pause_agent → exit(:normal)

Agent exits :normal
    after block: Registry.unregister
    death watcher: sees :normal → dispatches nothing
    DB: question interaction intact, completed tool results intact

Next user message
    Execution.run loads all DB interactions
    Agent restarts with full context
```

---

## What Does Not Change

- `SwarmAi.Loop`, `SwarmAi.Loop.Runner` — pure functional, untouched
- Death watcher lifecycle and event dispatch — unchanged
- Registry-based duplicate detection — unchanged
- Non-interactive tool inner timeouts in `ToolExecutor` — unchanged
- `async_stream_nolink` crash isolation guarantee — preserved (tasks are still nolink)

---

## Testing

**`SwarmAi` (unit)**
- `Tool.new` without `timeout_ms` or `on_timeout` crashes at construction
- Runtime executor: non-interactive timeout → error ToolResult, agent continues
- Runtime executor: `pause_agent` timeout → agent exits `:normal`, watcher dispatches nothing
- Ordered results preserved across mixed completion order
- Existing parallel executor tests pass

**`FrontmanServer` (unit)**
- `Tools.Backend.to_swarm_tool/1` calls `timeout_ms/0` and `on_timeout/0` on the module
- Each backend tool module compiles only when both callbacks are implemented
- `Tools.MCP.from_map/1` crashes when `timeoutMs` or `onTimeout` absent
- `Tools.MCP.to_swarm_tool/1` maps fields through without derivation
- `ToolExecutor` interactive path: `receive` has no `after` clause

**Integration**
- Batch with non-interactive timeout: error ToolResult returned to LLM, agent continues
- Batch with interactive timeout: agent exits `:normal`, DB intact, next `Execution.run` restarts cleanly
- Existing execution tests pass
