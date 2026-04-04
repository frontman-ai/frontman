# Swarm / Domain Boundary Redesign

**Date:** 2026-04-04
**Status:** Approved

## Problem

The domain (`frontman_server`) currently owns infrastructure that belongs to Swarm:

- `FrontmanServer.ToolCallRegistry` — a supervised Registry that routes MCP tool results from the channel back to the correct executor process. This is a process rendezvous mechanism, not a domain concern.
- `Execution.notify_tool_result/4` — looks up the executor PID in that registry and sends it a message. Domain code managing process routing.
- `{executor_fn, on_deadline_fn}` tuple — opaque closures passed to `SwarmAi.Runtime.run/4`. Hard to test, hard to compose, don't document their interface.
- `:notified | :no_executor` threaded through `Tasks.add_tool_result/5` — Swarm executor lifecycle state leaking through the domain's persistence API.
- Pause/resume logic in `TaskChannel` (`all_pending_tools_resolved?`, `maybe_resume_agent`) — agent lifecycle management in the transport layer.

The root cause: Swarm exposes an opaque closure interface that forces the domain to reimplement Swarm-level infrastructure alongside it.

## Goals

1. The domain thinks only about messages and interactions — not executor PIDs, registries, or process routing.
2. Swarm is batteries-included: works without any customisation for simple cases.
3. Swarm is fully interchangeable: users can replace tool execution strategy, pause/resume strategy, or the whole agent loop policy.
4. OTP structure follows modern Elixir library conventions (`{module, opts}` + behaviours, Oban/Broadway style). No `use` macros for basic usage.

## Design

### Boundary

**Swarm gains:**
- `SwarmAi.ExecutionStrategy` behaviour
- `SwarmAi.DefaultExecutionStrategy` module (batteries-included implementation)
- `SwarmAi.Runtime.deliver_tool_result/5`
- Tool result routing Registry, moved inside `SwarmAi.Runtime`'s own supervision subtree

**Swarm loses:**
- `tool_executor:` closure option from `Runtime.run/4`
- `on_deadline:` closure option from `Runtime.run/4`

**Domain loses:**
- `FrontmanServer.ToolCallRegistry` — removed from `application.ex` entirely
- `Execution.notify_tool_result/4` — replaced by `SwarmAi.Runtime.deliver_tool_result/5`
- `ToolExecutor` module — replaced by `FrontmanServer.Tasks.AgentStrategy`
- `:notified | :no_executor` return tag from `Tasks.add_tool_result/5` — returns `{:ok, interaction} | {:error, reason}` only

**Domain keeps:**
- All interaction persistence (UserMessage, AgentResponse, ToolCall, ToolResult, AgentPaused, etc.)
- The decision of when to call `Runtime.run` — including server-restart resume logic
- `SwarmDispatcher` — event persistence + PubSub broadcast, unchanged
- `maybe_resume_agent` — still the domain's decision; triggered when `deliver_tool_result` returns `:no_executor`

---

### `SwarmAi.ExecutionStrategy` behaviour

Replaces the `{executor_fn, on_deadline_fn}` closure tuple. Configured as `{module, opts}` — `opts` is passed to `init/1` to build the strategy's own state.

```elixir
defmodule SwarmAi.ExecutionStrategy do
  @type state :: term()

  @doc "Called once before execution starts. Build strategy state from opts."
  @callback init(opts :: keyword()) :: {:ok, state} | {:error, term()}

  @doc """
  Execute a single tool call. Returns result and updated state.
  Swarm's ParallelExecutor calls this once per tool in a supervised Task,
  handling parallelism and per-tool deadlines. The strategy only decides
  how to execute the individual tool.
  """
  @callback execute_tool(state, SwarmAi.ToolCall.t()) :: {SwarmAi.ToolResult.t(), state}

  @doc """
  Called when a tool's deadline fires.
  - {:error, state}  — produce an error ToolResult, agent loop continues
  - {:pause, state}  — cleanly halt the loop (Swarm emits :paused event)
  """
  @callback on_deadline(state, SwarmAi.ToolCall.t()) :: {:error | :pause, state}

  @doc """
  Called after each LLM response to decide whether to continue the loop.
  Return :halt to stop before the agent's own should_terminate? check.
  Optional — defaults to always :continue.
  """
  @callback should_continue?(state, SwarmAi.Loop.t()) :: {:continue | :halt, state}

  @optional_callbacks should_continue?: 2
end
```

**Usage in `Runtime.run`:**

```elixir
SwarmAi.Runtime.run(FrontmanServer.AgentRuntime, task_id, agent, messages,
  strategy: {FrontmanServer.Tasks.AgentStrategy,
             scope: scope, task_id: task_id, mcp_tool_defs: mcp_tool_defs, ...},
  metadata: %{task_id: task_id, resolved_key: resolved_key, scope: scope}
)
```

The `Agent` protocol continues to handle identity concerns (system prompt, LLM client, available tools, `should_terminate?`). `ExecutionStrategy` handles runtime mechanics. They are complementary, not overlapping.

---

### `SwarmAi.Runtime.deliver_tool_result/5`

```elixir
@spec deliver_tool_result(
        runtime :: atom(),
        task_id :: String.t(),
        tool_call_id :: String.t(),
        result :: term(),
        is_error :: boolean()
      ) :: :delivered | :no_executor
def deliver_tool_result(runtime, task_id, tool_call_id, result, is_error)
```

Returns `:delivered` when a live executor received the result, `:no_executor` when none was waiting (e.g. server restarted mid-execution). The caller decides what to do with `:no_executor`.

**Internal routing:**

Swarm adds a tool result routing Registry to `SwarmAi.Runtime`'s own supervision subtree, alongside the existing running-agent Registry. Its name is derived from the runtime name (e.g. `SwarmAi.Runtime.tool_registry_name(name)`) and is opaque to the domain.

Strategies that need to wait for an external result call `SwarmAi.Runtime.await_tool_result/3`, a Swarm-provided helper that registers the calling process and blocks:

```elixir
# Inside AgentStrategy.execute_tools/2, for MCP tools:
SwarmAi.Runtime.await_tool_result(FrontmanServer.AgentRuntime, tool_call.id, timeout: 600_000)
# Returns {:ok, content} | {:error, reason}
```

The registry key is `{task_id, tool_call_id}`. Swarm derives `task_id` from the executor process's own registration, so the strategy only passes `tool_call_id`.

**Domain side — `TaskChannel` change:**

```elixir
# Before
case Tasks.add_tool_result(scope, task_id, tool_call_ref, result, is_error) do
  {:ok, _interaction, :notified} -> :ok
  {:ok, _interaction, :no_executor} -> maybe_resume_agent(...)
end

# After
{:ok, _interaction} = Tasks.add_tool_result(scope, task_id, tool_call_ref, result, is_error)

case SwarmAi.Runtime.deliver_tool_result(
       FrontmanServer.AgentRuntime, task_id, tool_call_id, result, is_error) do
  :delivered -> :ok
  :no_executor -> maybe_resume_agent(...)
end
```

---

### `SwarmAi.DefaultExecutionStrategy`

The batteries-included implementation. Ships with Swarm so most users never implement the behaviour directly.

```elixir
defmodule SwarmAi.DefaultExecutionStrategy do
  @behaviour SwarmAi.ExecutionStrategy

  defmacro __using__(_opts) do
    quote do
      @behaviour SwarmAi.ExecutionStrategy
      defdelegate init(opts), to: SwarmAi.DefaultExecutionStrategy
      defdelegate execute_tool(state, tool_call), to: SwarmAi.DefaultExecutionStrategy
      defdelegate on_deadline(state, tool_call), to: SwarmAi.DefaultExecutionStrategy
      defoverridable init: 1, execute_tool: 2, on_deadline: 2
    end
  end

  defstruct [:runtime, :tool_map]

  def init(opts) do
    state = %__MODULE__{
      runtime:  Keyword.fetch!(opts, :runtime),
      tool_map: opts |> Keyword.get(:tool_defs, []) |> Map.new(&{&1.name, &1})
    }
    {:ok, state}
  end

  # ParallelExecutor calls this once per tool in a supervised Task.
  # Block until deliver_tool_result is called from outside (e.g. TaskChannel).
  def execute_tool(state, tool_call) do
    result =
      case SwarmAi.Runtime.await_tool_result(state.runtime, tool_call.id) do
        {:ok, content}   -> SwarmAi.ToolResult.make(tool_call.id, content, false)
        {:error, reason} -> SwarmAi.ToolResult.make(tool_call.id, reason, true)
      end
    {result, state}
  end

  def on_deadline(state, tool_call) do
    policy =
      case Map.get(state.tool_map, tool_call.name) do
        %{on_timeout: policy} -> policy
        nil -> :error
      end
    {policy, state}
  end
end
```

`DefaultExecutionStrategy` has no concept of MCP, backend tools, or browser clients. The `use` macro lets domain strategies stay minimal — override only what differs, call `super/2` to augment rather than replace:

```elixir
defmodule MyApp.AgentStrategy do
  use SwarmAi.DefaultExecutionStrategy

  @impl SwarmAi.ExecutionStrategy
  def on_deadline(state, tool_call) do
    MyApp.Metrics.record_timeout(tool_call.name)
    super(state, tool_call)
  end
end
```

---

### Domain `AgentStrategy`

`FrontmanServer.Tasks.ToolExecutor` is replaced by `FrontmanServer.Tasks.AgentStrategy`. A plain struct — no closures, no captured PIDs:

```elixir
defmodule FrontmanServer.Tasks.AgentStrategy do
  @behaviour SwarmAi.ExecutionStrategy

  defstruct [:scope, :task_id, :backend_module_map, :mcp_tool_defs, :mcp_tools, :llm_opts]

  def init(opts) do
    state = %__MODULE__{
      scope:              Keyword.fetch!(opts, :scope),
      task_id:            Keyword.fetch!(opts, :task_id),
      backend_module_map: opts |> Keyword.fetch!(:backend_tool_modules) |> build_module_map(),
      mcp_tool_defs:      Keyword.fetch!(opts, :mcp_tool_defs),
      mcp_tools:          Keyword.fetch!(opts, :mcp_tools),
      llm_opts:           Keyword.fetch!(opts, :llm_opts)
    }
    {:ok, state}
  end

  def execute_tool(state, tool_call) do
    result = build_tool_result(tool_call, state)
    {result, state}
  end

  def on_deadline(state, tool_call) do
    policy =
      case Map.get(state.backend_module_map, tool_call.name) do
        nil    -> find_mcp_policy(tool_call.name, state.mcp_tool_defs)
        module -> module.on_timeout()
      end
    {policy, state}
  end
end
```

---

### Error handling

| Failure point | Owner | Outcome |
|---|---|---|
| `init/1` returns `{:error, reason}` | Swarm | Dispatches `{:failed, {:error, reason, nil}}` before loop starts |
| `execute_tools/2` raises | Swarm | Catches at ParallelExecutor boundary, dispatches `{:crashed, ...}` |
| `on_deadline/2` returns `{:pause, state}` | Swarm | Dispatches `{:paused, {:timeout, ...}}` |
| `on_deadline/2` returns `{:error, state}` | Swarm | Produces error ToolResult, loop continues |
| `await_tool_result` safety-net timeout | Swarm | Exits executor process → crash path |
| `deliver_tool_result` returns `:no_executor` | Domain | Check `all_pending_tools_resolved?`, conditionally call `maybe_resume_agent` |

`SwarmDispatcher` and `TaskChannel` error handling are unchanged — they respond to the same dispatched events as today.

---

### Testing

**Strategy unit tests** — struct + behaviour means `AgentStrategy` is fully testable without Swarm:

```elixir
test "on_deadline returns :pause for MCP tools with pause_agent policy" do
  {:ok, state} = AgentStrategy.init(
    scope: scope,
    task_id: "t1",
    backend_tool_modules: [],
    mcp_tool_defs: [%MCP{name: "browser_click", on_timeout: :pause_agent}],
    mcp_tools: [],
    llm_opts: []
  )

  tool_call = %SwarmAi.ToolCall{id: "tc1", name: "browser_click", arguments: "{}"}
  assert {policy, _state} = AgentStrategy.on_deadline(state, tool_call)
  assert policy == :pause
end
```

**Integration tests** — use `SwarmAi.DefaultExecutionStrategy` with a mock tool server. Existing `FrontmanServer.Testing.BlockingAgent` pattern continues unchanged.

**`deliver_tool_result` tests** — Swarm's own test suite covers registry mechanics. Domain tests verify: persist interaction → call `deliver_tool_result` → assert return value.

---

## Files changed

### `apps/swarm_ai`
- `lib/swarm_ai/execution_strategy.ex` — new behaviour
- `lib/swarm_ai/default_execution_strategy.ex` — new default implementation
- `lib/swarm_ai/runtime.ex` — add `deliver_tool_result/5`, `await_tool_result/3`; add internal tool routing Registry to supervision subtree; replace `tool_executor:` + `on_deadline:` opts with `strategy:` opt
- `lib/swarm_ai/parallel_executor.ex` — call `strategy.execute_tool/2` per task instead of raw closure; call `strategy.on_deadline/2` on deadline instead of raw closure

### `apps/frontman_server`
- `lib/frontman_server/application.ex` — remove `{Registry, ..., name: FrontmanServer.ToolCallRegistry}`
- `lib/frontman_server/tasks/execution/agent_strategy.ex` — new (replaces `tool_executor.ex`)
- `lib/frontman_server/tasks/execution/tool_executor.ex` — deleted
- `lib/frontman_server/tasks/execution.ex` — remove `notify_tool_result/4`; update `submit_to_runtime` to pass `strategy:` opt
- `lib/frontman_server/tasks.ex` — `add_tool_result/5` returns `{:ok, interaction} | {:error, reason}` only
- `lib/frontman_server_web/channels/task_channel.ex` — call `deliver_tool_result/5` directly; remove `:notified | :no_executor` handling from `store_tool_result`
