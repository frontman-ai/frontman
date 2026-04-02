# Tool Execution Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make tools own their timeout and halt behaviour so interactive tools no longer keep the agent process alive, while all tools still run concurrently.

**Architecture:** `SwarmAi.Tool` gains enforced `timeout_ms` and `on_timeout` fields. A new `SwarmAi.ParallelExecutor` module replaces the `async_stream_nolink` closure with a reactive `receive` loop using per-task `Process.send_after` timers. When an `on_timeout: :pause_agent` deadline fires the executor returns `{:halt, {:pause_agent, tool_name, timeout_ms}}`, the effect interpreter in `SwarmAi` short-circuits, `run_streaming` returns `{:paused, ...}`, and `FrontmanServer.Execution` persists an `AgentPaused` interaction — the DB is the resumption point.

**Tech Stack:** Elixir/OTP, TypedStruct, Task.Supervisor, Process timers, Ecto, telemetry

---

### Task 1: `SwarmAi.Tool` — add execution policy fields

**Files:**
- Modify: `apps/swarm_ai/lib/swarm_ai/tool.ex`
- Modify: `apps/swarm_ai/test/swarm_ai/tool_test.exs` (create if absent)

- [ ] **Step 1: Write the failing tests**

Create `apps/swarm_ai/test/swarm_ai/tool_test.exs`:

```elixir
defmodule SwarmAi.ToolTest do
  use ExUnit.Case, async: true

  alias SwarmAi.Tool

  describe "new/1" do
    test "creates a tool with all required fields" do
      tool =
        Tool.new(
          name: "my_tool",
          description: "Does something",
          parameter_schema: %{},
          timeout_ms: 30_000,
          on_timeout: :error
        )

      assert tool.name == "my_tool"
      assert tool.description == "Does something"
      assert tool.parameter_schema == %{}
      assert tool.timeout_ms == 30_000
      assert tool.on_timeout == :error
    end

    test "raises on missing timeout_ms" do
      assert_raise ArgumentError, fn ->
        Tool.new(
          name: "t",
          description: "d",
          parameter_schema: %{},
          on_timeout: :error
        )
      end
    end

    test "raises on missing on_timeout" do
      assert_raise ArgumentError, fn ->
        Tool.new(
          name: "t",
          description: "d",
          parameter_schema: %{},
          timeout_ms: 5_000
        )
      end
    end

    test "raises on unknown key" do
      assert_raise KeyError, fn ->
        Tool.new(
          name: "t",
          description: "d",
          parameter_schema: %{},
          timeout_ms: 5_000,
          on_timeout: :error,
          extra: "nope"
        )
      end
    end
  end
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
./bin/pod-exec mix test apps/swarm_ai/test/swarm_ai/tool_test.exs --no-start
```

Expected: compile error or failures (old `new/3` arity doesn't match).

- [ ] **Step 3: Update `SwarmAi.Tool`**

Replace `apps/swarm_ai/lib/swarm_ai/tool.ex` entirely:

```elixir
defmodule SwarmAi.Tool do
  @moduledoc """
  Tool definition for LLM consumption.

  This is pure data describing a tool's interface and execution policy.
  Swarm doesn't execute tools — it yields ToolCalls for the caller to
  execute via the tool_executor function.

  Both `timeout_ms` and `on_timeout` are required. There are no defaults —
  every tool must explicitly declare its execution policy. Missing either
  field raises at construction time.

  `on_timeout` semantics:
  - `:error` — return an error ToolResult to the LLM, agent continues
  - `:pause_agent` — halt the agent loop cleanly; the caller persists context
    and restarts on the next user message
  """
  use TypedStruct

  typedstruct enforce: true do
    field(:name, String.t())
    field(:description, String.t())
    field(:parameter_schema, map())
    field(:timeout_ms, pos_integer())
    field(:on_timeout, :error | :pause_agent)
  end

  @doc """
  Creates a new tool definition.

  All five fields are required. Raises `ArgumentError` if any is missing
  or `KeyError` if an unknown key is provided.

  ## Example

      Tool.new(
        name: "question",
        description: "Ask the user a question",
        parameter_schema: %{},
        timeout_ms: 120_000,
        on_timeout: :pause_agent
      )
  """
  @spec new(keyword()) :: t()
  def new(attrs) do
    struct!(__MODULE__, attrs)
  end
end
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
./bin/pod-exec mix test apps/swarm_ai/test/swarm_ai/tool_test.exs --no-start
```

Expected: all 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add apps/swarm_ai/lib/swarm_ai/tool.ex apps/swarm_ai/test/swarm_ai/tool_test.exs
git commit -m "feat(swarm_ai): add timeout_ms and on_timeout fields to Tool (#743)"
```

---

### Task 2: `FrontmanServer.Tools.Backend` — add behaviour callbacks

**Files:**
- Modify: `apps/frontman_server/lib/frontman_server/tools/backend.ex`
- Modify: `apps/frontman_server/lib/frontman_server/tools/todo_write.ex`
- Modify: `apps/frontman_server/lib/frontman_server/tools/web_fetch.ex`
- Test: `apps/frontman_server/test/frontman_server/tools/backend_test.exs` (create if absent)

- [ ] **Step 1: Write failing test for `to_swarm_tool/1`**

Create `apps/frontman_server/test/frontman_server/tools/backend_test.exs`:

```elixir
defmodule FrontmanServer.Tools.BackendTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tools.Backend

  defmodule FakeBackendTool do
    @behaviour Backend

    def name, do: "fake_tool"
    def description, do: "A fake tool for testing"
    def parameter_schema, do: %{}
    def timeout_ms, do: 45_000
    def on_timeout, do: :error
    def execute(_args, _ctx), do: {:ok, "done"}
  end

  describe "to_swarm_tool/1" do
    test "builds SwarmAi.Tool with policy fields from callbacks" do
      tool = Backend.to_swarm_tool(FakeBackendTool)

      assert tool.name == "fake_tool"
      assert tool.description == "A fake tool for testing"
      assert tool.parameter_schema == %{}
      assert tool.timeout_ms == 45_000
      assert tool.on_timeout == :error
    end
  end
end
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
./bin/pod-exec mix test apps/frontman_server/test/frontman_server/tools/backend_test.exs --no-start
```

Expected: `SwarmAi.Tool.new/3` arity error or `Tool` construction error (missing required fields).

- [ ] **Step 3: Update `Backend` behaviour and `to_swarm_tool/1`**

Replace `apps/frontman_server/lib/frontman_server/tools/backend.ex`:

```elixir
defmodule FrontmanServer.Tools.Backend do
  @moduledoc """
  Behaviour for backend tools that execute server-side.
  """

  defmodule Context do
    @moduledoc """
    Execution context passed to backend tools.

    The tool_executor is a pre-built function that handles both backend and MCP tool
    execution. Backend tools that spawn sub-agents should use this executor rather than
    creating their own.

    Tools receive all needed data through this context rather than calling back into
    contexts:
    - `llm_opts`: Flat keyword list with `:api_key` and `:model` for LLM calls
    - `mcp_tools`: Pre-converted Swarm tools for sub-agent spawning
    - `context_messages`: Pre-extracted context from read_file results (AGENTS.md, etc.)
    """
    use TypedStruct

    alias FrontmanServer.Accounts.Scope
    alias FrontmanServer.Tasks.Task

    @type executor :: ([SwarmAi.ToolCall.t()] -> [SwarmAi.ToolResult.t()])

    typedstruct do
      field(:scope, Scope.t(), enforce: true)
      field(:task, Task.t(), enforce: true)
      field(:tool_executor, executor(), enforce: true)
      field(:mcp_tools, [SwarmAi.Tool.t()], default: [])
      field(:context_messages, [SwarmAi.Message.t()], default: [])
      # Flat keyword list: [api_key: "...", model: "openrouter:anthropic/..."]
      field(:llm_opts, keyword(), enforce: true)
    end
  end

  @type result :: {:ok, term()} | {:error, String.t()}

  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback parameter_schema() :: map()
  @callback timeout_ms() :: pos_integer()
  @callback on_timeout() :: :error | :pause_agent
  @callback execute(args :: map(), context :: Context.t()) :: result()

  @spec to_swarm_tool(module()) :: SwarmAi.Tool.t()
  def to_swarm_tool(module) do
    SwarmAi.Tool.new(
      name: module.name(),
      description: module.description(),
      parameter_schema: module.parameter_schema(),
      timeout_ms: module.timeout_ms(),
      on_timeout: module.on_timeout()
    )
  end
end
```

- [ ] **Step 4: Add `timeout_ms/0` and `on_timeout/0` to `TodoWrite`**

Open `apps/frontman_server/lib/frontman_server/tools/todo_write.ex` and add after the existing `@callback`-driven functions (alongside `name/0`, `description/0`, `parameter_schema/0`):

```elixir
@impl true
def timeout_ms, do: 30_000

@impl true
def on_timeout, do: :error
```

- [ ] **Step 5: Add `timeout_ms/0` and `on_timeout/0` to `WebFetch`**

Open `apps/frontman_server/lib/frontman_server/tools/web_fetch.ex` and add:

```elixir
@impl true
def timeout_ms, do: 60_000

@impl true
def on_timeout, do: :error
```

- [ ] **Step 6: Run tests**

```bash
./bin/pod-exec mix test apps/frontman_server/test/frontman_server/tools/backend_test.exs --no-start
```

Expected: all pass. Also confirm compile:

```bash
./bin/pod-exec mix compile --no-start 2>&1 | grep -E "warning|error"
```

Expected: no "undefined behaviour" warnings for `TodoWrite` or `WebFetch`.

- [ ] **Step 7: Commit**

```bash
git add apps/frontman_server/lib/frontman_server/tools/backend.ex \
        apps/frontman_server/lib/frontman_server/tools/todo_write.ex \
        apps/frontman_server/lib/frontman_server/tools/web_fetch.ex \
        apps/frontman_server/test/frontman_server/tools/backend_test.exs
git commit -m "feat(frontman): add timeout_ms/on_timeout callbacks to Backend behaviour (#743)"
```

---

### Task 3: `FrontmanServer.Tools.MCP` — add wire fields

**Files:**
- Modify: `apps/frontman_server/lib/frontman_server/tools/mcp.ex`
- Test: `apps/frontman_server/test/frontman_server/tools/mcp_test.exs` (create or extend)

- [ ] **Step 1: Write failing tests**

Create `apps/frontman_server/test/frontman_server/tools/mcp_test.exs`:

```elixir
defmodule FrontmanServer.Tools.MCPTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tools.MCP

  describe "from_map/1" do
    test "parses timeout_ms and on_timeout from wire format" do
      tool =
        MCP.from_map(%{
          "name" => "navigate",
          "description" => "Navigate to a URL",
          "inputSchema" => %{},
          "timeoutMs" => 30_000,
          "onTimeout" => "error"
        })

      assert tool.timeout_ms == 30_000
      assert tool.on_timeout == :error
    end

    test "parses on_timeout: pause_agent" do
      tool =
        MCP.from_map(%{
          "name" => "question",
          "description" => "Ask the user",
          "inputSchema" => %{},
          "timeoutMs" => 120_000,
          "onTimeout" => "pause_agent"
        })

      assert tool.on_timeout == :pause_agent
    end

    test "raises when timeoutMs is absent" do
      assert_raise KeyError, fn ->
        MCP.from_map(%{
          "name" => "navigate",
          "description" => "Navigate",
          "inputSchema" => %{},
          "onTimeout" => "error"
        })
      end
    end

    test "raises when onTimeout is absent" do
      assert_raise KeyError, fn ->
        MCP.from_map(%{
          "name" => "navigate",
          "description" => "Navigate",
          "inputSchema" => %{},
          "timeoutMs" => 30_000
        })
      end
    end
  end

  describe "to_swarm_tools/1" do
    test "passes timeout_ms and on_timeout through without derivation" do
      mcp_tool =
        MCP.from_map(%{
          "name" => "question",
          "description" => "Ask user",
          "inputSchema" => %{},
          "timeoutMs" => 120_000,
          "onTimeout" => "pause_agent",
          "visibleToAgent" => true
        })

      [swarm_tool] = MCP.to_swarm_tools([mcp_tool])

      assert swarm_tool.timeout_ms == 120_000
      assert swarm_tool.on_timeout == :pause_agent
    end
  end
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
./bin/pod-exec mix test apps/frontman_server/test/frontman_server/tools/mcp_test.exs --no-start
```

Expected: failures — `MCP.t()` has no `timeout_ms` or `on_timeout` fields.

- [ ] **Step 3: Update `FrontmanServer.Tools.MCP`**

Replace `apps/frontman_server/lib/frontman_server/tools/mcp.ex`:

```elixir
defmodule FrontmanServer.Tools.MCP do
  @moduledoc """
  Utilities for MCP tools from external clients.
  """

  use TypedStruct

  typedstruct enforce: true do
    field(:name, String.t())
    field(:description, String.t())
    field(:input_schema, map())
    field(:visible_to_agent, boolean(), default: true)
    field(:timeout_ms, pos_integer())
    field(:on_timeout, :error | :pause_agent)
  end

  @spec from_map(map()) :: t()
  def from_map(tool) when is_map(tool) do
    %__MODULE__{
      name: tool["name"],
      description: tool["description"] || "",
      input_schema: tool["inputSchema"] || %{"type" => "object", "properties" => %{}},
      visible_to_agent: Map.get(tool, "visibleToAgent", true),
      timeout_ms: Map.fetch!(tool, "timeoutMs"),
      on_timeout: parse_on_timeout(Map.fetch!(tool, "onTimeout"))
    }
  end

  defp parse_on_timeout("pause_agent"), do: :pause_agent
  defp parse_on_timeout(_), do: :error

  @spec from_maps([map()]) :: [t()]
  def from_maps(tools) when is_list(tools) do
    Enum.map(tools, &from_map/1)
  end

  @spec to_swarm_tools([t()]) :: [SwarmAi.Tool.t()]
  def to_swarm_tools(mcp_tools) when is_list(mcp_tools) do
    mcp_tools
    |> Enum.filter(& &1.visible_to_agent)
    |> Enum.map(&to_swarm_tool/1)
  end

  defp to_swarm_tool(%__MODULE__{} = tool) do
    SwarmAi.Tool.new(
      name: tool.name,
      description: tool.description,
      parameter_schema: tool.input_schema,
      timeout_ms: tool.timeout_ms,
      on_timeout: tool.on_timeout
    )
  end
end
```

Note: `execution_mode` and the `interactive?/1` / `interactive_by_name?/2` functions are removed — the execution policy is now embedded in `on_timeout`. If `ToolExecutor` currently calls `interactive_by_name?`, that call will need to be removed in Task 7.

- [ ] **Step 4: Run tests**

```bash
./bin/pod-exec mix test apps/frontman_server/test/frontman_server/tools/mcp_test.exs --no-start
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add apps/frontman_server/lib/frontman_server/tools/mcp.ex \
        apps/frontman_server/test/frontman_server/tools/mcp_test.exs
git commit -m "feat(frontman): MCP tools declare timeout_ms and on_timeout on wire (#743)"
```

---

### Task 4: `SwarmAi.ParallelExecutor` — new module

**Files:**
- Create: `apps/swarm_ai/lib/swarm_ai/parallel_executor.ex`
- Create: `apps/swarm_ai/test/swarm_ai/parallel_executor_test.exs`

- [ ] **Step 1: Write failing tests**

Create `apps/swarm_ai/test/swarm_ai/parallel_executor_test.exs`:

```elixir
defmodule SwarmAi.ParallelExecutorTest do
  use ExUnit.Case, async: true

  alias SwarmAi.{ParallelExecutor, Tool, ToolCall, ToolResult}

  defp make_tool(name, timeout_ms, on_timeout) do
    Tool.new(
      name: name,
      description: "test tool",
      parameter_schema: %{},
      timeout_ms: timeout_ms,
      on_timeout: on_timeout
    )
  end

  defp make_tc(id, name), do: %ToolCall{id: id, name: name, arguments: "{}"}

  defp start_sup do
    {:ok, sup} = Task.Supervisor.start_link()
    sup
  end

  defp instant_executor(tool_calls) do
    Enum.map(tool_calls, fn tc -> ToolResult.make(tc.id, "done:#{tc.name}", false) end)
  end

  describe "run/4 — normal completion" do
    test "returns {:ok, results} for a single tool" do
      sup = start_sup()
      tool_map = %{"t1" => make_tool("t1", 5_000, :error)}

      result = ParallelExecutor.run([make_tc("id1", "t1")], tool_map, &instant_executor/1, sup)

      assert {:ok, [%ToolResult{id: "id1", content: "done:t1"}]} = result
    end

    test "returns results in original order for concurrent tools" do
      sup = start_sup()

      tool_map = %{
        "slow" => make_tool("slow", 5_000, :error),
        "fast" => make_tool("fast", 5_000, :error)
      }

      executor = fn tool_calls ->
        Enum.map(tool_calls, fn tc ->
          if tc.name == "slow", do: Process.sleep(50)
          ToolResult.make(tc.id, tc.name, false)
        end)
      end

      tcs = [make_tc("slow1", "slow"), make_tc("fast1", "fast")]
      {:ok, [r1, r2]} = ParallelExecutor.run(tcs, tool_map, executor, sup)

      assert r1.id == "slow1"
      assert r2.id == "fast1"
    end

    test "unknown tool name returns error ToolResult, no task spawned" do
      sup = start_sup()
      tool_map = %{}

      {:ok, [result]} = ParallelExecutor.run([make_tc("id1", "unknown_tool")], tool_map, &instant_executor/1, sup)

      assert result.is_error == true
      assert result.content =~ "Unknown tool"
    end
  end

  describe "run/4 — on_timeout: :error" do
    test "timed-out tool returns error ToolResult, agent continues" do
      sup = start_sup()
      tool_map = %{"slow" => make_tool("slow", 10, :error)}

      executor = fn tool_calls ->
        Enum.map(tool_calls, fn tc ->
          Process.sleep(500)
          ToolResult.make(tc.id, "too late", false)
        end)
      end

      {:ok, [result]} = ParallelExecutor.run([make_tc("id1", "slow")], tool_map, executor, sup)

      assert result.is_error == true
      assert result.content =~ "timed out"
    end
  end

  describe "run/4 — on_timeout: :pause_agent" do
    test "returns {:halt, {:pause_agent, tool_name, timeout_ms}} on pause timeout" do
      sup = start_sup()
      tool_map = %{"interactive" => make_tool("interactive", 10, :pause_agent)}

      executor = fn tool_calls ->
        Enum.map(tool_calls, fn tc ->
          Process.sleep(500)
          ToolResult.make(tc.id, "never", false)
        end)
      end

      result = ParallelExecutor.run([make_tc("id1", "interactive")], tool_map, executor, sup)

      assert {:halt, {:pause_agent, "interactive", 10}} = result
    end

    test "mixed batch: one pauses, others are cancelled, returns halt" do
      sup = start_sup()

      tool_map = %{
        "interactive" => make_tool("interactive", 20, :pause_agent),
        "normal" => make_tool("normal", 5_000, :error)
      }

      executor = fn tool_calls ->
        Enum.map(tool_calls, fn tc ->
          if tc.name == "interactive", do: Process.sleep(500)
          ToolResult.make(tc.id, "result", false)
        end)
      end

      tcs = [make_tc("id1", "interactive"), make_tc("id2", "normal")]
      result = ParallelExecutor.run(tcs, tool_map, executor, sup)

      assert {:halt, {:pause_agent, "interactive", 20}} = result
    end

    test "two pause_agent tools with same timeout: exactly one halt returned" do
      sup = start_sup()

      tool_map = %{
        "a" => make_tool("a", 10, :pause_agent),
        "b" => make_tool("b", 10, :pause_agent)
      }

      executor = fn tool_calls ->
        Enum.map(tool_calls, fn tc ->
          Process.sleep(500)
          ToolResult.make(tc.id, "never", false)
        end)
      end

      result = ParallelExecutor.run([make_tc("id1", "a"), make_tc("id2", "b")], tool_map, executor, sup)

      assert {:halt, {:pause_agent, _tool_name, 10}} = result
    end
  end

  describe "run/4 — task crash" do
    test "crashing tool produces error ToolResult, agent continues" do
      sup = start_sup()
      tool_map = %{"crasher" => make_tool("crasher", 5_000, :error)}

      executor = fn _tool_calls -> raise "boom" end

      {:ok, [result]} = ParallelExecutor.run([make_tc("id1", "crasher")], tool_map, executor, sup)

      assert result.is_error == true
      assert result.content =~ "crashed"
    end
  end
end
```

- [ ] **Step 2: Run to confirm they fail**

```bash
./bin/pod-exec mix test apps/swarm_ai/test/swarm_ai/parallel_executor_test.exs --no-start
```

Expected: `SwarmAi.ParallelExecutor` does not exist yet.

- [ ] **Step 3: Create `SwarmAi.ParallelExecutor`**

Create `apps/swarm_ai/lib/swarm_ai/parallel_executor.ex`:

```elixir
defmodule SwarmAi.ParallelExecutor do
  @moduledoc """
  Runs tool calls in parallel with per-task deadlines.

  Each tool's execution policy (`timeout_ms`, `on_timeout`) controls what happens
  when its deadline fires. This module is called from the anonymous function built
  by `Runtime.do_wrap_executor/3`, which executes inside the Runtime task process.
  All `Process.send_after` timers and monitor messages target that process.

  ## Return values

  - `{:ok, [ToolResult.t()]}` — all tools completed (or errored gracefully); results
    in original call order
  - `{:halt, {:pause_agent, tool_name, timeout_ms}}` — a `:pause_agent` deadline fired;
    all remaining tasks cancelled; first deadline wins (ties non-deterministic)
  """

  require Logger

  alias SwarmAi.{Tool, ToolCall, ToolResult}

  @type halt_reason :: {:pause_agent, String.t(), pos_integer()}
  @type result :: {:ok, [ToolResult.t()]} | {:halt, halt_reason()}

  @typep pending_entry :: %{
           ref: reference(),
           pid: pid(),
           timer: reference(),
           tc: ToolCall.t(),
           tool_def: Tool.t()
         }
  @typep immediates :: %{ToolCall.id() => ToolResult.t()}
  @typep pending :: %{reference() => pending_entry()}

  @doc """
  Spawns all tool calls concurrently, collects results with per-task deadlines.

  `tool_map` is a name → `Tool.t()` index. Tool calls with names absent from
  `tool_map` are treated as LLM hallucinations — an error ToolResult is returned
  immediately without spawning a task.
  """
  @spec run([ToolCall.t()], %{String.t() => Tool.t()}, function(), pid() | atom()) :: result()
  def run(tool_calls, tool_map, executor, task_supervisor) do
    {immediates, pending} =
      tool_calls
      |> Enum.map(&spawn_or_reject(&1, tool_map, executor, task_supervisor))
      |> split_results()

    # No stale message flush needed — this runs inside the Runtime task process,
    # which dies after returning. Orphan :deadline messages die with it.
    collect_results(pending, immediates, task_supervisor)
  end

  # Spawns a task for a known tool, or returns an immediate error for unknown tools.
  @spec spawn_or_reject(ToolCall.t(), map(), function(), pid() | atom()) ::
          {:immediate, {ToolCall.id(), ToolResult.t()}} | {:pending, reference(), pending_entry()}
  defp spawn_or_reject(tc, tool_map, executor, task_supervisor) do
    case Map.get(tool_map, tc.name) do
      nil ->
        # LLM hallucinated a tool name — return error, don't spawn a task
        result = ToolResult.make(tc.id, "Unknown tool: #{tc.name}", true)
        {:immediate, {tc.id, result}}

      tool_def ->
        # async_nolink: task crash does not kill the executor process.
        # async_nolink sets up a monitor (ref), so :DOWN is guaranteed in the mailbox.
        task =
          Task.Supervisor.async_nolink(task_supervisor, fn ->
            [result] = executor.([tc])
            result
          end)

        timer = Process.send_after(self(), {:deadline, task.ref}, tool_def.timeout_ms)

        entry = %{
          ref: task.ref,
          pid: task.pid,
          timer: timer,
          tc: tc,
          tool_def: tool_def
        }

        {:pending, task.ref, entry}
    end
  end

  @spec split_results(list()) :: {immediates(), pending()}
  defp split_results(entries) do
    Enum.reduce(entries, {%{}, %{}}, fn
      {:immediate, {id, result}}, {imm, pend} ->
        {Map.put(imm, id, result), pend}

      {:pending, ref, entry}, {imm, pend} ->
        {imm, Map.put(pend, ref, entry)}
    end)
  end

  # Base case: all pending tasks resolved — order results by original tool call order.
  @spec collect_results(pending(), immediates(), pid() | atom()) :: result()
  defp collect_results(pending, results, _task_supervisor) when pending == %{} do
    {:ok, finalize(results)}
  end

  defp collect_results(pending, results, task_supervisor) do
    receive do
      # Task completed successfully — cancel its timer and store result.
      {ref, result} when is_map_key(pending, ref) ->
        Process.demonitor(ref, [:flush])
        %{timer: timer, tc: tc} = Map.fetch!(pending, ref)
        Process.cancel_timer(timer)

        collect_results(
          Map.delete(pending, ref),
          Map.put(results, tc.id, result),
          task_supervisor
        )

      # Task crashed — cancel its timer and store error result.
      # This message arrives because async_nolink sets up a monitor.
      {:DOWN, ref, :process, _pid, reason} when is_map_key(pending, ref) ->
        %{timer: timer, tc: tc} = Map.fetch!(pending, ref)
        Process.cancel_timer(timer)
        error_result = ToolResult.make(tc.id, "Tool crashed: #{inspect(reason)}", true)

        collect_results(
          Map.delete(pending, ref),
          Map.put(results, tc.id, error_result),
          task_supervisor
        )

      # Deadline fired — kill the task and act on on_timeout policy.
      {:deadline, ref} when is_map_key(pending, ref) ->
        handle_deadline(pending, results, ref, task_supervisor)
    end
  end

  @spec handle_deadline(pending(), immediates(), reference(), pid() | atom()) :: result()
  defp handle_deadline(pending, results, ref, task_supervisor) do
    %{tc: tc, tool_def: tool_def, pid: pid} = Map.fetch!(pending, ref)

    # terminate_child is synchronous — child is dead when it returns.
    # async_nolink sets up a monitor, so :DOWN is guaranteed in the mailbox.
    # This invariant breaks if async_nolink is replaced with plain spawn.
    Task.Supervisor.terminate_child(task_supervisor, pid)

    receive do
      {:DOWN, ^ref, :process, _, _} -> :ok
    end

    case tool_def.on_timeout do
      :error ->
        error_result =
          ToolResult.make(tc.id, "Tool timed out after #{tool_def.timeout_ms}ms", true)

        collect_results(
          Map.delete(pending, ref),
          Map.put(results, tc.id, error_result),
          task_supervisor
        )

      :pause_agent ->
        # First :pause_agent wins. If multiple deadlines fire concurrently,
        # whichever :deadline message is dequeued first triggers the halt.
        cancel_remaining(pending, ref, task_supervisor)
        {:halt, {:pause_agent, tc.name, tool_def.timeout_ms}}
    end
  end

  # Tears down all in-flight tasks except the one that triggered the halt.
  # Order matters: cancel timer first (prevents stale :deadline), then kill task,
  # then flush the :DOWN guarantee from async_nolink.
  @spec cancel_remaining(pending(), reference(), pid() | atom()) :: :ok
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

  # Re-order results map into a list matching the original tool_calls order.
  # The `collect_results` loop accumulates into a map keyed by tc.id to avoid
  # the O(n) ordering required by async_stream_nolink's ordered: true guarantee.
  @spec finalize(%{ToolCall.id() => ToolResult.t()}) :: [ToolResult.t()]
  defp finalize(results_map) do
    # Results map keys are tool call IDs; we sort by insertion is wrong —
    # we need to return in original call order. But we don't have the original
    # list here. The caller (run/4) must re-order using the original tool_calls list.
    # Actually finalize is called from collect_results which doesn't have tool_calls.
    # We pass just the map; ordering is preserved by the caller via zip.
    # Since we've been accumulating by tc.id, we just return map values.
    # The Runtime wraps this in the anonymous function that receives the full tool_calls list,
    # so ordering is enforced at that level.
    Map.values(results_map)
  end
end
```

Wait — there's an ordering issue. The `finalize/1` function returns `Map.values(results_map)` which doesn't guarantee original order. We need to pass the original `tool_calls` order to `finalize`. Let me fix this:

Actually, looking at the spec:
> The `ordered: true` guarantee from `async_stream_nolink` is preserved by collecting results into a map keyed by `tc.id` and re-ordering in `finalize/1`.

So `finalize/1` needs the original order. The simplest fix: pass `tool_calls` to `run/4` and use them in `finalize`. Let me rewrite the key parts:

```elixir
def run(tool_calls, tool_map, executor, task_supervisor) do
  {immediates, pending} =
    tool_calls
    |> Enum.map(&spawn_or_reject(&1, tool_map, executor, task_supervisor))
    |> split_results()

  case collect_results(pending, immediates, task_supervisor) do
    {:ok, results_map} -> {:ok, finalize(tool_calls, results_map)}
    {:halt, _} = halt -> halt
  end
end

defp collect_results(pending, results, _task_supervisor) when pending == %{} do
  {:ok, results}  # returns the map, run/4 calls finalize
end

# ... rest of collect_results returns {:ok, map} or {:halt, ...}

defp finalize(tool_calls, results_map) do
  Enum.map(tool_calls, fn tc -> Map.fetch!(results_map, tc.id) end)
end
```

But this means `collect_results` needs to return `{:ok, map}` not `{:ok, list}`. Let me update the implementation to use this cleaner approach.

- [ ] **Step 3 (revised): Create `SwarmAi.ParallelExecutor` with correct ordering**

Replace the file with:

```elixir
defmodule SwarmAi.ParallelExecutor do
  @moduledoc """
  Runs tool calls in parallel with per-task deadlines.

  Each tool's execution policy (`timeout_ms`, `on_timeout`) controls what happens
  when its deadline fires. This module is called from the anonymous function built
  by `Runtime.do_wrap_executor/3`, which executes inside the Runtime task process.
  All `Process.send_after` timers and monitor messages target that process.

  ## Return values

  - `{:ok, [ToolResult.t()]}` — all tools completed (or errored gracefully); results
    in original call order
  - `{:halt, {:pause_agent, tool_name, timeout_ms}}` — a `:pause_agent` deadline fired;
    all remaining tasks cancelled; first deadline wins (ties non-deterministic)
  """

  require Logger

  alias SwarmAi.{Tool, ToolCall, ToolResult}

  @type halt_reason :: {:pause_agent, String.t(), pos_integer()}
  @type result :: {:ok, [ToolResult.t()]} | {:halt, halt_reason()}

  @typep pending_entry :: %{
           ref: reference(),
           pid: pid(),
           timer: reference(),
           tc: ToolCall.t(),
           tool_def: Tool.t()
         }
  @typep results_map :: %{ToolCall.id() => ToolResult.t()}
  @typep pending :: %{reference() => pending_entry()}

  @doc """
  Spawns all tool calls concurrently, collects results with per-task deadlines.

  `tool_map` is a name → `Tool.t()` index. Tool calls with names absent from
  `tool_map` are treated as LLM hallucinations — an error ToolResult is returned
  immediately without spawning a task.
  """
  @spec run([ToolCall.t()], %{String.t() => Tool.t()}, function(), pid() | atom()) :: result()
  def run(tool_calls, tool_map, executor, task_supervisor) do
    {immediates, pending} =
      tool_calls
      |> Enum.map(&spawn_or_reject(&1, tool_map, executor, task_supervisor))
      |> split_results()

    case collect_results(pending, immediates, task_supervisor) do
      {:ok, results_map} -> {:ok, finalize(tool_calls, results_map)}
      {:halt, _} = halt -> halt
    end
  end

  @spec spawn_or_reject(ToolCall.t(), map(), function(), pid() | atom()) ::
          {:immediate, {ToolCall.id(), ToolResult.t()}} | {:pending, reference(), pending_entry()}
  defp spawn_or_reject(tc, tool_map, executor, task_supervisor) do
    case Map.get(tool_map, tc.name) do
      nil ->
        result = ToolResult.make(tc.id, "Unknown tool: #{tc.name}", true)
        {:immediate, {tc.id, result}}

      tool_def ->
        # async_nolink: task crash does not kill this process.
        # async_nolink sets up a monitor (ref), so :DOWN is guaranteed in the mailbox.
        task =
          Task.Supervisor.async_nolink(task_supervisor, fn ->
            [result] = executor.([tc])
            result
          end)

        timer = Process.send_after(self(), {:deadline, task.ref}, tool_def.timeout_ms)

        entry = %{ref: task.ref, pid: task.pid, timer: timer, tc: tc, tool_def: tool_def}
        {:pending, task.ref, entry}
    end
  end

  @spec split_results(list()) :: {results_map(), pending()}
  defp split_results(entries) do
    Enum.reduce(entries, {%{}, %{}}, fn
      {:immediate, {id, result}}, {imm, pend} ->
        {Map.put(imm, id, result), pend}

      {:pending, ref, entry}, {imm, pend} ->
        {imm, Map.put(pend, ref, entry)}
    end)
  end

  @spec collect_results(pending(), results_map(), pid() | atom()) ::
          {:ok, results_map()} | {:halt, halt_reason()}
  defp collect_results(pending, results, _task_supervisor) when pending == %{} do
    {:ok, results}
  end

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

  @spec handle_deadline(pending(), results_map(), reference(), pid() | atom()) ::
          {:ok, results_map()} | {:halt, halt_reason()}
  defp handle_deadline(pending, results, ref, task_supervisor) do
    %{tc: tc, tool_def: tool_def, pid: pid} = Map.fetch!(pending, ref)

    # terminate_child is synchronous — child is dead when it returns.
    # async_nolink sets up a monitor, so :DOWN is guaranteed in the mailbox.
    # This invariant breaks if async_nolink is replaced with plain spawn.
    Task.Supervisor.terminate_child(task_supervisor, pid)

    receive do
      {:DOWN, ^ref, :process, _, _} -> :ok
    end

    case tool_def.on_timeout do
      :error ->
        error_result =
          ToolResult.make(tc.id, "Tool timed out after #{tool_def.timeout_ms}ms", true)

        collect_results(
          Map.delete(pending, ref),
          Map.put(results, tc.id, error_result),
          task_supervisor
        )

      :pause_agent ->
        # First :pause_agent wins. If multiple deadlines fire concurrently,
        # whichever :deadline message is dequeued first triggers the halt.
        cancel_remaining(pending, ref, task_supervisor)
        {:halt, {:pause_agent, tc.name, tool_def.timeout_ms}}
    end
  end

  @spec cancel_remaining(pending(), reference(), pid() | atom()) :: :ok
  defp cancel_remaining(pending, triggered_ref, task_supervisor) do
    pending
    |> Map.delete(triggered_ref)
    |> Enum.each(fn {ref, %{timer: timer, pid: pid}} ->
      # Cancel timer first — prevents a stale :deadline from firing mid-cleanup
      Process.cancel_timer(timer)
      Task.Supervisor.terminate_child(task_supervisor, pid)

      receive do
        {:DOWN, ^ref, :process, _, _} -> :ok
      end
    end)
  end

  # Re-order results map into a list matching the original tool_calls order.
  @spec finalize([ToolCall.t()], results_map()) :: [ToolResult.t()]
  defp finalize(tool_calls, results_map) do
    Enum.map(tool_calls, fn tc -> Map.fetch!(results_map, tc.id) end)
  end
end
```

- [ ] **Step 4: Run tests**

```bash
./bin/pod-exec mix test apps/swarm_ai/test/swarm_ai/parallel_executor_test.exs --no-start
```

Expected: all pass. The timing-based tests use very short timeouts (10ms) which should be reliable.

- [ ] **Step 5: Commit**

```bash
git add apps/swarm_ai/lib/swarm_ai/parallel_executor.ex \
        apps/swarm_ai/test/swarm_ai/parallel_executor_test.exs
git commit -m "feat(swarm_ai): add ParallelExecutor with per-task reactive timers (#743)"
```

---

### Task 5: `SwarmAi.Runtime` — delegate to `ParallelExecutor`

**Files:**
- Modify: `apps/swarm_ai/lib/swarm_ai/runtime.ex`
- Modify: `apps/swarm_ai/test/swarm_ai/runtime_test.exs`

- [ ] **Step 1: Write failing test**

Add to `apps/swarm_ai/test/swarm_ai/runtime_test.exs` inside the `describe "run/5"` block:

```elixir
test "passes tool_defs to executor for timeout policy" do
  runtime = start_runtime!()

  # Tool with 10ms timeout — will timeout but return error (not pause)
  tool_def =
    SwarmAi.Tool.new(
      name: "test_tool",
      description: "test",
      parameter_schema: %{},
      timeout_ms: 10,
      on_timeout: :error
    )

  slow_executor = fn _tool_calls ->
    Process.sleep(500)
    # won't reach here
    []
  end

  llm =
    SwarmAi.Testing.multi_turn_llm([
      {:tool_calls, [%SwarmAi.ToolCall{id: "tc1", name: "test_tool", arguments: "{}"}],
       "calling"},
      {:complete, "done after timeout error"}
    ])

  agent = test_agent(llm)

  {:ok, pid} =
    SwarmAi.Runtime.run(runtime, "task-tool-def", agent, "Hello",
      tool_executor: slow_executor,
      tool_defs: [tool_def]
    )

  await_exit(pid)

  # Should complete (error ToolResult returned to LLM, LLM responds with final message)
  assert_receive {:test_event, "task-tool-def", {:completed, {:ok, "done after timeout error", _}},
                  _metadata},
                 3_000
end
```

- [ ] **Step 2: Run test to confirm it fails (or confirm existing behavior)**

```bash
./bin/pod-exec mix test apps/swarm_ai/test/swarm_ai/runtime_test.exs --no-start
```

- [ ] **Step 3: Update `do_wrap_executor` in `Runtime`**

In `apps/swarm_ai/lib/swarm_ai/runtime.ex`, replace the `do_wrap_executor/3` and `collect_tool_result/1` functions:

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

Remove `collect_tool_result/1` (it was only used by the old `async_stream_nolink` approach).

- [ ] **Step 4: Run tests**

```bash
./bin/pod-exec mix test apps/swarm_ai/test/swarm_ai/runtime_test.exs --no-start
```

Expected: all pass including the new test.

- [ ] **Step 5: Commit**

```bash
git add apps/swarm_ai/lib/swarm_ai/runtime.ex \
        apps/swarm_ai/test/swarm_ai/runtime_test.exs
git commit -m "feat(swarm_ai): Runtime delegates to ParallelExecutor, reads tool_defs opt (#743)"
```

---

### Task 6: `SwarmAi` effect interpreter — handle `{:halt, ...}` from executor

**Files:**
- Modify: `apps/swarm_ai/lib/swarm_ai.ex`
- Modify: `apps/swarm_ai/test/swarm_ai/runtime_test.exs`

The executor now returns `{:ok, [ToolResult.t()]} | {:halt, halt_reason()}`. The `execute_loop` function currently assumes a list. We need to:
1. Change `execute_loop` to return `Loop.t() | {:halt, halt_reason()}` when executor halts
2. Update `run_streaming` to check for `{:halt, ...}` and return `{:paused, halt_reason}`

- [ ] **Step 1: Write failing test in `runtime_test.exs`**

Add to `apps/swarm_ai/test/swarm_ai/runtime_test.exs`:

```elixir
describe "pause_agent" do
  test "pause_agent tool timeout returns :paused result, no :failed event" do
    runtime = start_runtime!()

    pause_tool =
      SwarmAi.Tool.new(
        name: "test_tool",
        description: "pauses",
        parameter_schema: %{},
        timeout_ms: 10,
        on_timeout: :pause_agent
      )

    blocking_executor = fn _tool_calls ->
      Process.sleep(500)
      []
    end

    llm = %SwarmAi.Testing.MockLLM{
      response: fn ->
        {:ok,
         %SwarmAi.LLM.Response{
           content: nil,
           tool_calls: [%SwarmAi.ToolCall{id: "tc1", name: "test_tool", arguments: "{}"}],
           usage: %SwarmAi.LLM.Usage{input_tokens: 10, output_tokens: 5},
           raw: nil
         }}
      end
    }

    agent = test_agent(llm)

    {:ok, pid} =
      SwarmAi.Runtime.run(runtime, "task-pause", agent, "Hello",
        tool_executor: blocking_executor,
        tool_defs: [pause_tool]
      )

    await_exit(pid)

    # Agent should not dispatch :completed or :failed — it paused
    refute_receive {:test_event, "task-pause", {:completed, _}, _}, 200
    refute_receive {:test_event, "task-pause", {:failed, _}, _}, 0
    refute_receive {:test_event, "task-pause", {:crashed, _}, _}, 0
    refute SwarmAi.Runtime.running?(runtime, "task-pause")
  end
end
```

- [ ] **Step 2: Run to confirm it fails**

```bash
./bin/pod-exec mix test apps/swarm_ai/test/swarm_ai/runtime_test.exs "pause_agent" --no-start
```

Expected: test likely hangs or dispatches `:failed` (old behavior: `{:halt, ...}` not handled, falls through to unexpected status).

- [ ] **Step 3: Update `execute_loop` in `swarm_ai.ex`**

In `apps/swarm_ai/lib/swarm_ai.ex`, find the `execute_loop` clause that handles `{:execute_tool, _}` effects (around line 311). Change the `results =` assignment to pattern-match the executor return:

```elixir
defp execute_loop(loop, [{:execute_tool, _} | _] = effects, tool_executor, callbacks) do
  {tool_effects, rest} = split_tool_effects(effects)
  tool_calls = Enum.map(tool_effects, fn {:execute_tool, tc} -> tc end)

  Enum.each(tool_calls, callbacks.on_tool_call)

  loop_id = loop.id
  step = loop.current_step
  metadata = loop.metadata

  Enum.each(tool_calls, &emit_tool_start(loop_id, step, &1, metadata))

  executor_result =
    try do
      tool_executor.(tool_calls)
    rescue
      e ->
        Enum.each(tool_calls, &emit_tool_exception(loop_id, step, &1, e, metadata))
        reraise e, __STACKTRACE__
    end

  case executor_result do
    {:halt, halt_reason} ->
      Telemetry.step_stop(loop.id, loop.current_step, loop.metadata)
      {:halt, halt_reason}

    results when is_list(results) ->
      Enum.zip(tool_calls, results)
      |> Enum.each(fn {tc, result} -> emit_tool_stop(loop_id, step, tc, result, metadata) end)

      {new_effects, updated_loop} =
        Enum.flat_map_reduce(results, loop, fn result, loop_acc ->
          {l, e} = Loop.handle_tool_result(loop_acc, result)
          {e, l}
        end)

      execute_loop(updated_loop, new_effects ++ rest, tool_executor, callbacks)
  end
end
```

- [ ] **Step 4: Update `run_streaming` to handle `{:halt, ...}` from `execute_loop`**

In the same file, find the `run_streaming` function body inside `Telemetry.run_span`. Change the `final_loop = execute_loop(...)` pattern:

```elixir
fn ->
  {loop, effects} = Loop.execute(loop, messages)

  result =
    case execute_loop(loop, effects, tool_executor, callbacks) do
      {:halt, halt_reason} ->
        {:paused, halt_reason}

      %Loop{} = final_loop ->
        case final_loop.status do
          :completed ->
            {:ok, final_loop.result, loop.id}

          :failed ->
            {:error, final_loop.error, loop.id}

          other ->
            {:error, {:unexpected_status, other}, loop.id}
        end
    end

  stop_metadata =
    case result do
      {:paused, _} ->
        %{loop_id: loop.id, status: :paused, step_count: 0, metadata: loop.metadata, output: nil}

      _ ->
        # Original stop metadata — need the final_loop for step_count and output.
        # Since we may have {:halt, ...} we can't always access final_loop here.
        # Use a helper to build it.
        %{loop_id: loop.id, status: :unknown, metadata: loop.metadata}
    end

  {result, stop_metadata}
end
```

Wait, we have a scoping problem — if the result is `{:paused, ...}` we no longer have access to `final_loop` for the stop metadata. Let me restructure:

```elixir
fn ->
  {loop, effects} = Loop.execute(loop, messages)

  {result, final_status, step_count, output} =
    case execute_loop(loop, effects, tool_executor, callbacks) do
      {:halt, halt_reason} ->
        {{:paused, halt_reason}, :paused, length(loop.steps), nil}

      %Loop{} = final_loop ->
        r =
          case final_loop.status do
            :completed -> {:ok, final_loop.result, loop.id}
            :failed -> {:error, final_loop.error, loop.id}
            other -> {:error, {:unexpected_status, other}, loop.id}
          end

        {r, final_loop.status, length(final_loop.steps), final_loop.result}
    end

  {result,
   %{
     loop_id: loop.id,
     status: final_status,
     step_count: step_count,
     metadata: loop.metadata,
     output: output
   }}
end
```

Note: also update the `@spec` for `run_streaming` to include `| {:paused, halt_reason}`:

```elixir
@spec run_streaming(SwarmAi.Agent.t(), message_input(), streaming_opts()) ::
        {:ok, String.t(), SwarmAi.Id.t()}
        | {:error, term(), SwarmAi.Id.t()}
        | {:paused, SwarmAi.ParallelExecutor.halt_reason()}
```

- [ ] **Step 5: Update `run_registered_task` in `Runtime` to handle `{:paused, ...}`**

In `apps/swarm_ai/lib/swarm_ai/runtime.ex`, find `run_registered_task/3` and update the `result` handling:

```elixir
result = SwarmAi.run_streaming(task.agent, task.messages, streaming_opts)

# Unregister BEFORE dispatch so running?/2 returns false first
Registry.unregister(registry, registry_key)
send(watcher, :completed)

case result do
  {:ok, _, _} = ok ->
    dispatch_event(dispatcher, task.key, {:completed, ok}, task.event_context)

  {:error, _, _} = err ->
    dispatch_event(dispatcher, task.key, {:failed, err}, task.event_context)

  {:paused, reason} ->
    :telemetry.execute(
      [:swarm_ai, :runtime, :paused],
      %{count: 1},
      %{key: task.key, reason: reason}
    )
end
```

- [ ] **Step 6: Run all swarm_ai tests**

```bash
./bin/pod-exec mix test apps/swarm_ai --no-start
```

Expected: all pass, including the new `pause_agent` test.

- [ ] **Step 7: Commit**

```bash
git add apps/swarm_ai/lib/swarm_ai.ex apps/swarm_ai/lib/swarm_ai/runtime.ex \
        apps/swarm_ai/test/swarm_ai/runtime_test.exs
git commit -m "feat(swarm_ai): handle {:halt, halt_reason} from executor, return {:paused, ...} (#743)"
```

---

### Task 7: Update existing parallel tool execution tests

**Files:**
- Modify: `apps/swarm_ai/test/swarm_ai/parallel_tool_execution_test.exs`

The existing tests build a custom executor with `async_stream_nolink` directly. These tests verified the old Runtime wrapping behavior. With `ParallelExecutor` now handling concurrency, rewrite to use `SwarmAi.run_streaming` with tool defs.

- [ ] **Step 1: Run existing tests to see what breaks**

```bash
./bin/pod-exec mix test apps/swarm_ai/test/swarm_ai/parallel_tool_execution_test.exs --no-start
```

Note which tests fail and why.

- [ ] **Step 2: Rewrite the parallel test to use `tool_defs`**

Replace `apps/swarm_ai/test/swarm_ai/parallel_tool_execution_test.exs`:

```elixir
defmodule SwarmAi.ParallelToolExecutionTest do
  use SwarmAi.Testing, async: true

  defp make_tool(name, timeout_ms \\ 5_000, on_timeout \\ :error) do
    SwarmAi.Tool.new(
      name: name,
      description: "test",
      parameter_schema: %{},
      timeout_ms: timeout_ms,
      on_timeout: on_timeout
    )
  end

  describe "batch tool execution" do
    test "executes all tools via batch executor" do
      llm =
        multi_turn_llm([
          {:tool_calls,
           [
             %SwarmAi.ToolCall{id: "tc_1", name: "tool_a", arguments: "{}"},
             %SwarmAi.ToolCall{id: "tc_2", name: "tool_b", arguments: "{}"}
           ], "Running..."},
          {:complete, "Done"}
        ])

      agent = test_agent(llm)
      {:ok, sup} = Task.Supervisor.start_link()

      executor = fn tool_calls ->
        Enum.map(tool_calls, fn tc ->
          ToolResult.make(tc.id, "Result for #{tc.name}", false)
        end)
      end

      tool_defs = [make_tool("tool_a"), make_tool("tool_b")]

      {:ok, result, _loop_id} =
        SwarmAi.run_streaming(agent, "Do work",
          tool_executor:
            SwarmAi.ParallelExecutor.run_wrapper(executor, tool_defs, sup)
        )

      assert result == "Done"
    end
  end
end
```

Wait — this approach requires a `run_wrapper` helper that doesn't exist. Instead, let's test through `SwarmAi.Runtime` which is the actual entry point for the parallel executor. Or simply test the `ParallelExecutor` module directly (which we already do in Task 4).

The cleaner approach: rewrite the existing tests to test the same behaviors but using the new `ParallelExecutor` directly or through the Runtime API. Since Task 4 already covers `ParallelExecutor` exhaustively, we can simplify these tests to just verify the integration still works:

Replace `apps/swarm_ai/test/swarm_ai/parallel_tool_execution_test.exs`:

```elixir
defmodule SwarmAi.ParallelToolExecutionTest do
  use SwarmAi.Testing, async: true

  defp make_tool(name, timeout_ms \\ 5_000, on_timeout \\ :error) do
    SwarmAi.Tool.new(
      name: name,
      description: "test",
      parameter_schema: %{},
      timeout_ms: timeout_ms,
      on_timeout: on_timeout
    )
  end

  describe "batch tool execution through Runtime" do
    test "executes multiple tools concurrently" do
      runtime = start_runtime!()

      llm =
        multi_turn_llm([
          {:tool_calls,
           [
             %SwarmAi.ToolCall{id: "tc_1", name: "slow", arguments: "{}"},
             %SwarmAi.ToolCall{id: "tc_2", name: "slow", arguments: "{}"},
             %SwarmAi.ToolCall{id: "tc_3", name: "slow", arguments: "{}"}
           ], "Running..."},
          {:complete, "All done"}
        ])

      agent = test_agent(llm)
      start = System.monotonic_time(:millisecond)

      executor = fn tool_calls ->
        Enum.map(tool_calls, fn tc ->
          Process.sleep(100)
          ToolResult.make(tc.id, "Result", false)
        end)
      end

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-parallel", agent, "Do work",
          default_opts(
            tool_executor: executor,
            tool_defs: [make_tool("slow")]
          )
        )

      await_exit(pid)

      elapsed = System.monotonic_time(:millisecond) - start
      assert_receive {:test_event, "task-parallel", {:completed, {:ok, "All done", _}}, _}
      assert elapsed < 500, "Expected parallel (<500ms) but took #{elapsed}ms"
    end

    test "fault isolation - crashing tool produces error result, agent continues" do
      runtime = start_runtime!()

      llm =
        multi_turn_llm([
          {:tool_calls,
           [
             %SwarmAi.ToolCall{id: "tc_1", name: "good", arguments: "{}"},
             %SwarmAi.ToolCall{id: "tc_2", name: "bad", arguments: "{}"}
           ], "Running..."},
          {:complete, "Handled"}
        ])

      agent = test_agent(llm)

      executor = fn tool_calls ->
        Enum.map(tool_calls, fn tc ->
          case tc.name do
            "bad" -> raise "boom"
            _ -> ToolResult.make(tc.id, "OK", false)
          end
        end)
      end

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-crash", agent, "Do work",
          default_opts(
            tool_executor: executor,
            tool_defs: [make_tool("good"), make_tool("bad")]
          )
        )

      await_exit(pid)
      assert_receive {:test_event, "task-crash", {:completed, {:ok, "Handled", _}}, _}, 2_000
    end

    test "run_blocking still works with single-tool executor" do
      llm =
        multi_turn_llm([
          {:tool_calls,
           [%SwarmAi.ToolCall{id: "tc_1", name: "test", arguments: "{}"}],
           "Running..."},
          {:complete, "Done"}
        ])

      agent = test_agent(llm)

      {:ok, result, _loop_id} =
        SwarmAi.run_blocking(agent, "Do work", fn _tc -> {:ok, "Result"} end)

      assert result == "Done"
    end
  end

  # --- Helpers (reuse runtime_test helpers) ---

  defp start_runtime! do
    name = :"TestRuntime_#{:erlang.unique_integer([:positive])}"
    test_pid = self()

    start_supervised!({SwarmAi.Runtime,
      name: name,
      event_dispatcher: {SwarmAi.RuntimeTest.TestDispatcher, :dispatch, [test_pid]}
    })

    name
  end

  defp default_opts(extra \\ []) do
    Keyword.merge(
      [
        tool_executor: fn tool_calls ->
          Enum.map(tool_calls, fn tc -> ToolResult.make(tc.id, "done", false) end)
        end
      ],
      extra
    )
  end

  defp await_exit(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 3000
  end
end
```

- [ ] **Step 3: Run the updated tests**

```bash
./bin/pod-exec mix test apps/swarm_ai/test/swarm_ai/parallel_tool_execution_test.exs --no-start
```

Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add apps/swarm_ai/test/swarm_ai/parallel_tool_execution_test.exs
git commit -m "test(swarm_ai): update parallel execution tests for ParallelExecutor API (#743)"
```

---

### Task 8: `Interaction.AgentPaused` — new interaction type

**Files:**
- Modify: `apps/frontman_server/lib/frontman_server/tasks/interaction.ex`
- Test: part of frontman integration tests

- [ ] **Step 1: Write failing test**

Add to `apps/frontman_server/test/frontman_server/tasks/interaction_test.exs` (or create it):

```elixir
describe "AgentPaused" do
  test "new/2 builds struct with correct fields" do
    interaction = Interaction.AgentPaused.new("question", 120_000)

    assert interaction.tool_name == "question"
    assert interaction.timeout_ms == 120_000
    assert interaction.reason =~ "question"
    assert interaction.reason =~ "120000"
    assert interaction.reason =~ "pause_agent"
    assert interaction.sequence == 0
    assert is_binary(interaction.id)
    assert %DateTime{} = interaction.timestamp
  end

  test "AgentPaused is in interaction_modules list" do
    assert Interaction.AgentPaused in Interaction.interaction_modules()
  end

  test "AgentPaused is in known_type_strings" do
    assert "agent_paused" in Interaction.known_type_strings()
  end
end
```

- [ ] **Step 2: Run to confirm failure**

```bash
./bin/pod-exec mix test apps/frontman_server/test/frontman_server/tasks/interaction_test.exs --no-start
```

- [ ] **Step 3: Add `AgentPaused` to `interaction.ex`**

In `apps/frontman_server/lib/frontman_server/tasks/interaction.ex`:

1. Add to the `@type t` union:
```elixir
| __MODULE__.AgentPaused.t()
```

2. Add to the `@interaction_modules` list:
```elixir
__MODULE__.AgentPaused,
```

3. Add the module definition after `AgentError` (around line 745):

```elixir
defmodule AgentPaused do
  @moduledoc """
  Recorded when the agent loop is paused due to a tool timeout with
  `on_timeout: :pause_agent`. Stored as an interaction so reconnecting
  clients and the debug-task tool can see why the agent stopped.
  """
  use TypedStruct

  typedstruct enforce: true do
    field(:id, String.t())
    field(:sequence, integer(), default: 0)
    field(:timestamp, DateTime.t())
    field(:reason, String.t())
    field(:tool_name, String.t())
    field(:timeout_ms, pos_integer())
  end

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

defimpl Jason.Encoder, for: AgentPaused do
  def encode(value, opts) do
    Jason.Encode.map(
      %{
        type: "agent_paused",
        id: value.id,
        timestamp: DateTime.to_iso8601(value.timestamp),
        reason: value.reason,
        tool_name: value.tool_name,
        timeout_ms: value.timeout_ms
      },
      opts
    )
  end
end
```

- [ ] **Step 4: Run tests**

```bash
./bin/pod-exec mix test apps/frontman_server/test/frontman_server/tasks/interaction_test.exs --no-start
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add apps/frontman_server/lib/frontman_server/tasks/interaction.ex \
        apps/frontman_server/test/frontman_server/tasks/interaction_test.exs
git commit -m "feat(frontman): add AgentPaused interaction type (#743)"
```

---

### Task 9: `ToolExecutor` — remove interactive inner timeout

**Files:**
- Modify: `apps/frontman_server/lib/frontman_server/tasks/execution/tool_executor.ex`
- Test: `apps/frontman_server/test/frontman_server/tasks/execution/tool_executor_test.exs`

- [ ] **Step 1: Remove `interactive_by_name?` call and `@interactive_tool_timeout_ms`**

In `apps/frontman_server/lib/frontman_server/tasks/execution/tool_executor.ex`:

1. Remove `@interactive_tool_timeout_ms :timer.hours(24)` (line 37)
2. In `execute_mcp_tool/4`, remove the `if Tools.MCP.interactive_by_name?(mcp_tool_defs, tool_call.name)` branch entirely. The function becomes:

```elixir
defp execute_mcp_tool(scope, tool_call, task_id, _mcp_tool_defs) do
  Logger.info("ToolExecutor: Routing to MCP tool #{tool_call.name}")

  tool_call_id = tool_call.id

  # No timeout here — the Runtime's per-task deadline is the only timeout.
  # Interactive tools (on_timeout: :pause_agent) will have the agent halted
  # by ParallelExecutor when the deadline fires; this receive unblocks when
  # the ParallelExecutor kills this task via terminate_child.
  receive do
    {:tool_result, ^tool_call_id, content, is_error} ->
      Registry.unregister(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id})
      if is_error, do: {:error, content}, else: {:ok, content}
  end
end
```

3. Keep `mcp_tool_defs` in all other function signatures (it's still used for sub-agent executor construction in `execute_backend_tool`). Only remove it from `execute_mcp_tool` by ignoring the parameter (`_mcp_tool_defs`).

Simplified final version:

```elixir
defp execute_mcp_tool(scope, tool_call, task_id, _mcp_tool_defs) do
  Logger.info("ToolExecutor: Routing to MCP tool #{tool_call.name}")
  tool_call_id = tool_call.id

  receive do
    {:tool_result, ^tool_call_id, content, is_error} ->
      Registry.unregister(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id})
      if is_error, do: {:error, content}, else: {:ok, content}
  end
end
```

- [ ] **Step 2: Run tests**

```bash
./bin/pod-exec mix test apps/frontman_server/test/frontman_server/tasks/execution/ --no-start
```

Expected: all pass. If there were tests for the interactive timeout branch, they will need updating.

- [ ] **Step 3: Commit**

```bash
git add apps/frontman_server/lib/frontman_server/tasks/execution/tool_executor.ex
git commit -m "feat(frontman): remove interactive_tool_timeout — Runtime deadline is the only timeout (#743)"
```

---

### Task 10: Wire `tool_defs` through `Execution` and handle `:paused` in `SwarmDispatcher`

**Files:**
- Modify: `apps/frontman_server/lib/frontman_server/tasks/execution.ex`
- Modify: `apps/frontman_server/lib/frontman_server/tasks/swarm_dispatcher.ex`

The `{:paused, ...}` result from `run_streaming` is produced inside the Runtime Task process, not returned synchronously from `Runtime.run/5`. The Runtime dispatches it via the `event_dispatcher` MFA, so `SwarmDispatcher` is the right place to persist `AgentPaused`.

- [ ] **Step 1: Update `submit_to_runtime` to pass `tool_defs`**

In `apps/frontman_server/lib/frontman_server/tasks/execution.ex`, change the `SwarmAi.Runtime.run` call in `submit_to_runtime/5`:

```elixir
case SwarmAi.Runtime.run(FrontmanServer.AgentRuntime, task_id, agent, messages,
       metadata: %{task_id: task_id, resolved_key: resolved_key, scope: scope},
       tool_executor: tool_executor,
       tool_defs: mcp_tools
     ) do
```

`mcp_tools` is already assigned earlier in the function as `Map.get(agent, :tools, [])`.

- [ ] **Step 2: Dispatch `:paused` event from `run_registered_task`**

In `apps/swarm_ai/lib/swarm_ai/runtime.ex`, the `{:paused, reason}` case in `run_registered_task` (added in Task 6) should also call `dispatch_event` so `SwarmDispatcher` can persist `AgentPaused`. Update the case arm to:

```elixir
{:paused, {:pause_agent, tool_name, timeout_ms} = reason} ->
  :telemetry.execute(
    [:swarm_ai, :runtime, :paused],
    %{count: 1},
    %{key: task.key, reason: reason}
  )
  dispatch_event(
    dispatcher,
    task.key,
    {:paused, {:timeout, tool_name, timeout_ms}},
    task.event_context
  )
```

- [ ] **Step 3: Handle `:paused` in `SwarmDispatcher.persist/4`**

In `apps/frontman_server/lib/frontman_server/tasks/swarm_dispatcher.ex`, add the `Interaction` alias if absent:

```elixir
alias FrontmanServer.Tasks.Interaction
```

Add this `persist` clause before the `:chunk` clause:

```elixir
# Agent loop paused due to a tool's on_timeout: :pause_agent.
# Persist AgentPaused so reconnecting clients know why the agent stopped.
# No PubSub broadcast — client loads this on next task fetch.
defp persist(%Scope{} = scope, task_id, {:paused, {:timeout, tool_name, timeout_ms}}, _metadata) do
  interaction = Interaction.AgentPaused.new(tool_name, timeout_ms)
  Tasks.append_interaction(scope, task_id, interaction)
  TelemetryEvents.task_stop(task_id)
end
```

- [ ] **Step 4: Handle `:paused` in `Execution.handle_swarm_event/3`**

In `apps/frontman_server/lib/frontman_server/tasks/execution.ex`, add:

```elixir
# Paused — AgentPaused persisted by SwarmDispatcher; no client push needed.
def handle_swarm_event(_scope, _task_id, {:paused, _}), do: :ok
```

- [ ] **Step 5: Run all frontman tests**

```bash
./bin/pod-exec mix test apps/frontman_server --no-start
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add apps/frontman_server/lib/frontman_server/tasks/execution.ex \
        apps/frontman_server/lib/frontman_server/tasks/swarm_dispatcher.ex \
        apps/swarm_ai/lib/swarm_ai/runtime.ex
git commit -m "feat(frontman): wire tool_defs to Runtime, persist AgentPaused on pause (#743)"
```

---

### Task 11: Full integration check and cleanup

**Files:**
- Run all tests
- Fix any remaining `execution_mode` / `interactive?` references

- [ ] **Step 1: Run full test suite**

```bash
./bin/pod-exec mix test --no-start
```

Expected: all pass. Fix any remaining failures before continuing.

- [ ] **Step 2: Check for remaining `execution_mode` and `interactive?` references**

```bash
grep -r "execution_mode\|interactive_by_name\|interactive?" apps/ --include="*.ex" -l
```

Any files still using these (they were removed from `MCP.t()` in Task 3) need to be updated. Remove the references — the policy is now encoded in `on_timeout`.

- [ ] **Step 3: Check for compile warnings**

```bash
./bin/pod-exec mix compile --warnings-as-errors --no-start 2>&1 | head -50
```

Expected: clean. Common issues:
- Behaviour callbacks not implemented: `TodoWrite` or `WebFetch` missing `timeout_ms/0` or `on_timeout/0`
- Missing `{:paused, _}` clause in `handle_swarm_event` (Dialyzer may warn about unhandled patterns)

- [ ] **Step 4: Commit cleanup**

```bash
git add -p
git commit -m "fix(frontman): remove remaining execution_mode and interactive? references (#743)"
```
