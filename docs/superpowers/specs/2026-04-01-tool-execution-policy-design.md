# Tool Execution Policy Design

**Date:** 2026-04-01
**Branch:** issue-743-feat-enable-parallel-tool
**Revised:** 2026-04-02 — 5-whys review (ternary outcomes, data structures, API surface, timer model, hallucination handling)
**Revised:** 2026-04-02 — address JV-style review (struct ergonomics, stale timer docs, defensive DOWN flush, cancel_remaining impl, telemetry on pause, AgentPaused interaction)
**Revised:** 2026-04-02 — JV-style fixes (ParallelExecutor module, behaviour for executor, consistent pending map, flush stale messages, log instead of raise in cleanup, remove AgentPaused.sequence default)
**Revised:** 2026-04-02 — second review (extract handle_deadline, drop defensive timeouts, extract halt_reason type, type immediates map, fix AgentPaused.sequence ownership, document first-pause-wins)
**Revised:** 2026-04-02 — JV review round (drop Executor behaviour, delete flush_stale_messages, keep typedstruct, add process ownership doc, add monitor invariant comments, AgentPaused.sequence default: 0, telemetry %{count: 1}, add dual-pause test)

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
- `:pause_agent` — halt the agent loop cleanly (see §4), persist an `AgentPaused` interaction (see §8), DB state is the resumption point

`typedstruct enforce: true` generates `@enforce_keys` on all fields — a missing key raises at struct construction, not at runtime deep in the executor. This is consistent with every other struct in the codebase (`MCP`, `Loop`, `Backend.Context`).

```elixir
@spec new(keyword()) :: t()
def new(attrs) do
  struct!(__MODULE__, attrs)
end
```

`struct!` raises on missing or unknown keys. Callers use keyword lists for readable call sites:

```elixir
Tool.new(
  name: "question",
  description: "Ask the user",
  parameter_schema: %{},
  timeout_ms: 86_400_000,
  on_timeout: :pause_agent
)
```

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
    name: module.name(),
    description: module.description(),
    parameter_schema: module.parameter_schema(),
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
  SwarmAi.Tool.new(
    name: t.name,
    description: t.description,
    parameter_schema: t.input_schema,
    timeout_ms: t.timeout_ms,
    on_timeout: t.on_timeout
  )
end
```

The `execution_policy/1` derivation function does not exist. MCP tools own their policy.

---

### 4. `SwarmAi.ParallelExecutor` — per-task timeout executor

The receive loop, timer management, and task teardown are complex enough to warrant their own module — not a closure inside `do_wrap_executor`. This makes the process lifecycle explicit and the code testable in isolation.

#### Return type

The parallel executor returns a widened result type:

```elixir
@type halt_reason :: {:pause_agent, String.t(), pos_integer()}
@type result :: {:ok, [ToolResult.t()]} | {:halt, halt_reason()}
```

No `Executor` behaviour — the call site in `do_wrap_executor` wraps the executor in an anonymous function, so `Loop` never dispatches through a behaviour module. The `@spec` on `ParallelExecutor.run/4` is the contract.

`SwarmAi` (the effect interpreter) checks the executor return:
- `{:ok, results}` — feed results back to the LLM, continue the loop
- `{:halt, {:pause_agent, tool_name, timeout_ms}}` — stop the loop, return `{:paused, {:timeout, tool_name, timeout_ms}}` to the Runtime

The Runtime task dispatches based on the loop's return value:

```elixir
case Loop.run(agent, messages, opts) do
  {:ok, response}     -> dispatch(:completed, response)
  {:error, reason}    -> dispatch(:failed, reason)
  {:paused, reason}   ->
    :telemetry.execute([:swarm_ai, :runtime, :paused], %{count: 1}, %{
      task_id: task_id,
      reason: reason
    })
    # No domain event dispatched — the AgentPaused interaction (persisted by
    # FrontmanServer, see §8) is the observable record. Telemetry covers
    # operational debugging (dashboards, alerts).
end
```

No `exit()` calls. The task returns normally in all three cases. The death watcher only handles unexpected crashes (abnormal exits), not semantic outcomes.

#### Module structure

```elixir
defmodule SwarmAi.ParallelExecutor do
  @moduledoc """
  Runs tool calls in parallel with per-task deadlines.
  Each tool's execution policy (timeout_ms, on_timeout) controls
  what happens when its deadline fires.

  This module's `run/4` is called from the anonymous function built
  by `Runtime.do_wrap_executor/3`, which executes inside the Runtime
  task process. All `Process.send_after` timers and monitor messages
  target that process.
  """

  require Logger
end
```

#### Pending entry shape

Every in-flight task is tracked by a single, consistent map entry keyed by task ref:

```elixir
@typep pending_entry :: %{
  ref: reference(),
  pid: pid(),
  timer: reference(),
  tc: ToolCall.t(),
  tool_def: Tool.t()
}

@typep immediates :: %{ToolCall.id() => ToolResult.t()}
@typep pending :: %{reference() => pending_entry()}
```

All clauses in `collect_results` destructure the same shape — no field appears in one clause but not another.

#### `execute/1` — entry point

`do_wrap_executor` builds the module's state and delegates:

```elixir
defp do_wrap_executor(opts, executor, task_supervisor) do
  tool_defs = Keyword.get(opts, :tool_defs, [])
  tool_map = Map.new(tool_defs, fn tool -> {tool.name, tool} end)

  parallel_executor = fn tool_calls ->
    SwarmAi.ParallelExecutor.run(tool_calls, tool_map, executor, task_supervisor)
  end

  Keyword.put(opts, :tool_executor, parallel_executor)
end
```

The `run/4` function spawns tasks and builds the pending map:

```elixir
@spec run([ToolCall.t()], %{String.t() => Tool.t()}, function(), pid()) :: Executor.result()
def run(tool_calls, tool_map, executor, task_supervisor) do
  {immediates, pending} =
    tool_calls
    |> Enum.map(fn tc -> spawn_or_reject(tc, tool_map, executor, task_supervisor) end)
    |> split_results()

  # No stale message flush needed — this runs inside the Runtime task process,
  # which dies after returning. Orphan :deadline messages die with it.
  collect_results(pending, immediates, task_supervisor)
end
```

#### `spawn_or_reject/4` and `split_results/1`

```elixir
defp spawn_or_reject(tc, tool_map, executor, task_supervisor) do
  case Map.get(tool_map, tc.name) do
    nil ->
      # LLM hallucinated a tool name — return error, don't spawn a task
      {:immediate, {tc.id, ToolResult.make(tc.id, "Unknown tool: #{tc.name}", true)}}

    tool_def ->
      task = Task.Supervisor.async_nolink(task_supervisor, fn ->
        [result] = executor.([tc])
        result
      end)
      timer = Process.send_after(self(), {:deadline, task.ref}, tool_def.timeout_ms)
      {:pending, task.ref, %{ref: task.ref, pid: task.pid, timer: timer, tc: tc, tool_def: tool_def}}
  end
end

defp split_results(entries) do
  Enum.reduce(entries, {%{}, %{}}, fn
    {:immediate, {id, result}}, {imm, pend} ->
      {Map.put(imm, id, result), pend}

    {:pending, ref, entry}, {imm, pend} ->
      {imm, Map.put(pend, ref, entry)}
  end)
end
```

- `Map.get` returning `nil` → error ToolResult, no task spawned. The LLM gets feedback ("Unknown tool") and can self-correct.
- `Map.fetch!` is not used because a missing tool name is expected (LLM hallucination), not a bug.
- System misconfiguration (tool exists but policy undefined) is caught at `Tool.new/1` construction time (`struct!` raises on missing keys) — before the agent starts.

#### Reactive timer model

Instead of a `Task.yield_many` loop with deadline arithmetic, each task gets its own timer via `Process.send_after` at spawn time. A single `receive` loop handles two message types:

```elixir
defp collect_results(pending, results, _task_supervisor) when pending == %{}, do: {:ok, finalize(results)}

defp collect_results(pending, results, task_supervisor) do
  receive do
    {ref, result} when is_map_key(pending, ref) ->
      Process.demonitor(ref, [:flush])
      %{timer: timer, tc: tc} = Map.fetch!(pending, ref)
      Process.cancel_timer(timer)
      collect_results(
        Map.delete(pending, ref),
        Map.put(results, tc.id, result),
        task_supervisor
      )

    {:DOWN, ref, :process, _pid, reason} when is_map_key(pending, ref) ->
      %{timer: timer, tc: tc} = Map.fetch!(pending, ref)
      Process.cancel_timer(timer)
      error_result = ToolResult.make(tc.id, "Tool crashed: #{inspect(reason)}", true)
      collect_results(
        Map.delete(pending, ref),
        Map.put(results, tc.id, error_result),
        task_supervisor
      )

    {:deadline, ref} when is_map_key(pending, ref) ->
      handle_deadline(pending, results, ref, task_supervisor)
  end
end

defp handle_deadline(pending, results, ref, task_supervisor) do
  %{tc: tc, tool_def: tool_def, pid: pid} = Map.fetch!(pending, ref)
  Task.Supervisor.terminate_child(task_supervisor, pid)
  # terminate_child is synchronous — child is dead when it returns.
  # async_nolink sets up a monitor, so :DOWN is guaranteed in the mailbox.
  # This invariant breaks if async_nolink is replaced with plain spawn.
  receive do
    {:DOWN, ^ref, :process, _, _} -> :ok
  end

  case tool_def.on_timeout do
    :error ->
      error_result = ToolResult.make(tc.id, "Tool timed out after #{tool_def.timeout_ms}ms", true)
      collect_results(
        Map.delete(pending, ref),
        Map.put(results, tc.id, error_result),
        task_supervisor
      )

    :pause_agent ->
      # First :pause_agent wins. If multiple deadlines fire concurrently,
      # whichever :deadline message is dequeued first triggers the halt.
      # Remaining tasks (including other timed-out ones) are cancelled.
      cancel_remaining(pending, ref, task_supervisor)
      {:halt, {:pause_agent, tc.name, tool_def.timeout_ms}}
  end
end
```

#### `cancel_remaining/3`

When `:pause_agent` fires, all other in-flight tasks are torn down:

```elixir
defp cancel_remaining(pending, triggered_ref, task_supervisor) do
  pending
  |> Map.delete(triggered_ref)
  |> Enum.each(fn {ref, %{timer: timer, pid: pid}} ->
    Process.cancel_timer(timer)
    Task.Supervisor.terminate_child(task_supervisor, pid)
    receive do
      {:DOWN, ^ref, :process, _, _} -> :ok
    end
  end)
end
```

Order matters: cancel the timer first (prevents a stale `:deadline` from firing mid-cleanup), then kill the task, then flush the `:DOWN`. If `cancel_timer` returns `false`, a `:deadline` message is already in the mailbox — this is harmless because the Runtime task process dies after `run/4` returns, taking orphan messages with it.

**Why this is better than the yield loop:**
- No deadline arithmetic — `Process.send_after` handles per-task timing, the BEAM wakes us exactly when needed
- No "compute minimum timeout" step — each timer fires independently
- Single `receive` loop with pattern matching — idiomatic Erlang/Elixir state machine
- `{ref, result}` and `{:DOWN, ...}` are the natural messages from `async_nolink` tasks

The `ordered: true` guarantee from `async_stream_nolink` is preserved by collecting results into a map keyed by `tc.id` and re-ordering in `finalize/1`.

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

### 7. `SwarmAi.Loop` — handle widened executor return type

The Loop's tool execution step checks the executor's return:

```elixir
case tool_executor.(tool_calls) do
  {:ok, results} ->
    # append tool results to messages, continue loop
    {:cont, updated_messages}

  {:halt, {:pause_agent, tool_name, timeout_ms}} ->
    {:halt, {:paused, {:timeout, tool_name, timeout_ms}}}
end
```

`Loop.run/3` returns `{:ok, response} | {:error, reason} | {:paused, {:timeout, tool_name, timeout_ms}}`.

`Loop.Runner` propagates the halt — no special logic, just pattern matching on the loop's return.

---

### 8. `FrontmanServer.Tasks.Interaction.AgentPaused` — observable pause record

A new interaction type so "why did the agent stop?" is answerable from the DB without log archaeology.

```elixir
defmodule AgentPaused do
  @moduledoc """
  Recorded when the agent loop is paused due to a tool timeout
  with `on_timeout: :pause_agent`. Stored as an interaction so
  reconnecting clients and the debug-task tool can see the final state.
  """
  use TypedStruct

  typedstruct do
    field(:id, String.t(), enforce: true)
    field(:sequence, integer(), default: 0)
    field(:timestamp, DateTime.t(), enforce: true)
    field(:reason, String.t(), enforce: true)
    field(:tool_name, String.t(), enforce: true)
    field(:timeout_ms, pos_integer(), enforce: true)
  end

  @doc """
  `sequence` defaults to 0 and is overwritten by `Interactions.append/2`
  which owns the ordering invariant. Matches the pattern used by all
  other interaction types.
  """
  def new(tool_name, timeout_ms) do
    alias FrontmanServer.Tasks.Interaction

    %__MODULE__{
      id: Interaction.new_id(),
      timestamp: Interaction.now(),
      reason: "Tool #{tool_name} timed out after #{timeout_ms}ms (on_timeout: :pause_agent)",
      tool_name: tool_name,
      timeout_ms: timeout_ms
    }
  end
end
```

Added to the `@interaction_modules` list and `Interaction.t()` union in `interaction.ex`.

The Runtime's `{:paused, reason}` handler in `FrontmanServer.Execution` persists this interaction before returning:

```elixir
{:paused, {:timeout, tool_name, timeout_ms}} ->
  interaction = Interaction.AgentPaused.new(tool_name, timeout_ms)
  Interactions.append(task_id, interaction)  # append assigns sequence
  # No :completed or :failed event — DB state is the resumption point
```

This means the `:pause_agent` path in `collect_results` returns the tool context:

```elixir
:pause_agent ->
  cancel_remaining(pending, ref, task_supervisor)
  {:halt, {:pause_agent, tc.name, tool_def.timeout_ms}}
```

And the Loop propagates it: `{:halt, {:paused, {:timeout, tool_name, timeout_ms}}}`.

---

## Data Flow

```
Execution.submit_to_runtime
    builds mcp_tools ([SwarmAi.Tool.t()] with timeout_ms + on_timeout)
    passes tool_defs: mcp_tools to Runtime.run/5

Runtime.do_wrap_executor
    builds tool_map, delegates to ParallelExecutor.run/4

ParallelExecutor.run/4
    spawn_or_reject per tool call (skips unknown tools with error ToolResult)
    split_results into immediates map + pending map (consistent entry shape: ref, pid, timer, tc, tool_def)
    collect_results (receive loop):
        {ref, result} → cancel timer, store result
        {:DOWN, ref, _, _, reason} → cancel timer, error ToolResult
        {:deadline, ref} → handle_deadline (kill task, flush DOWN), check on_timeout:
            :error → error ToolResult, continue collecting
            :pause_agent → cancel remaining (timers first, then tasks, then flush DOWNs),
                            return {:halt, {:pause_agent, tool_name, timeout_ms}}
                            (first :pause_agent wins, ties are non-deterministic)
    (no stale message flush — process dies after returning)

Loop handles executor return
    {:ok, results} → continue loop
    {:halt, {:pause_agent, _, _}} → return {:paused, {:timeout, tool_name, timeout_ms}}

Runtime task handles loop return
    {:ok, response} → dispatch :completed
    {:error, reason} → dispatch :failed
    {:paused, reason} → emit telemetry [:swarm_ai, :runtime, :paused]

FrontmanServer.Execution handles Runtime return
    {:paused, {:timeout, tool_name, timeout_ms}} →
        persist AgentPaused interaction, no domain event dispatch

Death watcher
    only handles unexpected crashes (abnormal exits)
    :normal exits = task returned a value, already dispatched

Next user message
    Execution.run loads all DB interactions
    Agent restarts with full context
```

---

## What Does Not Change

- Death watcher lifecycle and event dispatch for crashes — unchanged
- Registry-based duplicate detection — unchanged
- Non-interactive tool inner timeouts in `ToolExecutor` — unchanged
- `async_nolink` crash isolation guarantee — preserved (tasks are still nolink)

## What Does Change

- New `SwarmAi.ParallelExecutor` module — extracted from closure, owns receive loop + timer lifecycle (no behaviour — the anonymous function wrapper means Loop never dispatches through a module)
- `SwarmAi` effect interpreter — handles widened executor return (`{:ok, results} | {:halt, halt_reason()}`)
- `SwarmAi.Loop`, `SwarmAi.Loop.Runner` — handle `{:halt, {:pause_agent, _, _}}` from executor
- Executor return type — widened to `{:ok, [ToolResult]} | {:halt, halt_reason()}` with `halt_reason :: {:pause_agent, tool_name, timeout_ms}`
- `Tool` struct — `@enforce_keys` + `new/1` with keyword list (was 3-field struct)
- Timer model — `Process.send_after` + `receive` replaces `Task.yield_many` loop
- No stale message flush — process dies after returning, orphan messages die with it
- Unknown tool handling — error ToolResult instead of crash
- New `Interaction.AgentPaused` type — persisted on `:pause_agent` for debugging (sequence assigned by `Interactions.append/2`)
- Telemetry — `[:swarm_ai, :runtime, :paused]` event emitted on pause

---

## Testing

**`SwarmAi` (unit)**
- `Tool.new/1` with missing key raises `ArgumentError` (via `struct!`)
- `Tool.new/1` with unknown key raises `ArgumentError`
- `ParallelExecutor.run/4` returns `{:ok, results}` for normal completion
- `ParallelExecutor.run/4` returns `{:halt, {:pause_agent, tool_name, timeout_ms}}` on `:pause_agent` timeout
- Non-interactive timeout → `{:ok, [...error ToolResult...]}`, agent continues
- Unknown tool name → error ToolResult in results, no task spawned
- `split_results/1` separates immediates from pending entries with consistent map shape
- Loop returns `{:paused, {:timeout, tool_name, timeout_ms}}` when executor returns `{:halt, ...}`
- cancel_remaining: cancels timers first, then kills tasks, then flushes DOWNs
- Loop returns `{:ok, response}` on normal completion
- Ordered results preserved across mixed completion order
- Existing parallel executor tests updated for new return type
- Timer cancellation: completed task's timer is cancelled (no stale `:deadline` messages)
- Task crash (`{:DOWN}`) produces error ToolResult, agent continues
- Two `:pause_agent` tools with identical timeout: exactly one `{:halt, {:pause_agent, _, _}}` returned (assert shape, not tool name — ordering is non-deterministic)

**`FrontmanServer` (unit)**
- `Tools.Backend.to_swarm_tool/1` calls `timeout_ms/0` and `on_timeout/0` on the module
- Each backend tool module compiles only when both callbacks are implemented
- `Tools.MCP.from_map/1` crashes when `timeoutMs` or `onTimeout` absent
- `Tools.MCP.to_swarm_tool/1` maps fields through without derivation
- `ToolExecutor` interactive path: `receive` has no `after` clause
- `Interaction.AgentPaused.new/2` produces correct reason string and fields (sequence defaults to 0, overwritten by append)
- `AgentPaused` is in `interaction_modules` list and `Interaction.t()` union

**Integration**
- Batch with non-interactive timeout: error ToolResult returned to LLM, agent continues
- Batch with interactive timeout: loop returns `{:paused, {:timeout, ...}}`, AgentPaused interaction persisted, telemetry emitted, DB intact, next `Execution.run` restarts cleanly
- Batch with hallucinated tool name: error ToolResult returned, agent self-corrects
- Mixed batch (some complete, one pauses): remaining tasks cancelled, `{:halt, {:pause_agent, tool_name, timeout_ms}}` returned
- Existing execution tests updated for widened return type
