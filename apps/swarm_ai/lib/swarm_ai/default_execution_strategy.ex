defmodule SwarmAi.DefaultExecutionStrategy do
  @moduledoc """
  Batteries-included `ExecutionStrategy` implementation.

  Waits for external tool results via `SwarmAi.Runtime.await_tool_result/3`.
  Suitable for tools whose results are delivered asynchronously (e.g. MCP
  tools executed by a browser client).

  ## Usage

  Use directly:

      SwarmAi.Runtime.run(runtime, key, agent, messages,
        strategy: {SwarmAi.DefaultExecutionStrategy, runtime: runtime, tool_defs: defs}
      )

  Or as a base for domain-specific strategies via `use`:

      defmodule MyApp.AgentStrategy do
        use SwarmAi.DefaultExecutionStrategy

        @impl SwarmAi.ExecutionStrategy
        def on_deadline(state, tool_call) do
          MyApp.Metrics.record_timeout(tool_call.name)
          super(state, tool_call)
        end
      end

  The `use` macro delegates all callbacks to `DefaultExecutionStrategy` and
  marks them `defoverridable`, so you only override what differs.
  """

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

  @impl SwarmAi.ExecutionStrategy
  def init(opts) do
    state = %__MODULE__{
      runtime: Keyword.fetch!(opts, :runtime),
      tool_map: opts |> Keyword.get(:tool_defs, []) |> Map.new(&{&1.name, &1})
    }

    {:ok, state}
  end

  @doc """
  Blocks until `deliver_tool_result/5` sends the result for this tool call.

  ParallelExecutor calls this once per tool in a supervised Task.
  No internal timeout — PE's deadline terminates this process if needed (#760).
  """
  @impl SwarmAi.ExecutionStrategy
  def execute_tool(state, tool_call) do
    result =
      case SwarmAi.Runtime.await_tool_result(state.runtime, tool_call.id) do
        {:ok, content, is_error} ->
          SwarmAi.ToolResult.make(tool_call.id, content, is_error)
      end

    {result, state}
  end

  @doc """
  Returns the timeout policy for a tool. Looks up the tool in `tool_map`
  for its `on_timeout` setting. Defaults to `:error` (continue loop).
  """
  @impl SwarmAi.ExecutionStrategy
  def on_deadline(state, tool_call) do
    policy =
      case Map.get(state.tool_map, tool_call.name) do
        %{on_timeout: :pause_agent} -> :pause
        _ -> :error
      end

    {policy, state}
  end
end
