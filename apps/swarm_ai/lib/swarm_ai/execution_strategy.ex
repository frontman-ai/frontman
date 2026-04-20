defmodule SwarmAi.ExecutionStrategy do
  @moduledoc """
  Behaviour for tool execution strategies.

  Replaces the `{executor_fn, on_deadline_fn}` closure tuple with a composable,
  testable module interface following the `{module, opts}` convention used by
  Oban, Broadway, and other modern Elixir libraries.

  ## Usage

  Pass a strategy as `{module, opts}` to `SwarmAi.Runtime.run/5`:

      SwarmAi.Runtime.run(MyApp.AgentRuntime, task_id, agent, messages,
        strategy: {MyApp.AgentStrategy, scope: scope, task_id: task_id}
      )

  The `opts` keyword list is forwarded to `c:init/1`, which builds the
  strategy's own state. `ParallelExecutor` then calls `c:execute_tool/2`
  once per tool in a supervised `Task`, and `c:on_deadline/2` when a tool's
  timeout fires.

  ## Relationship to the Agent protocol

  The `SwarmAi.Agent` protocol handles identity concerns: system prompt,
  LLM client, available tools, `should_terminate?`. `ExecutionStrategy`
  handles runtime mechanics: how to execute a tool, what to do on timeout.
  They are complementary, not overlapping.
  """

  @type state :: term()

  @doc """
  Called once before execution starts. Build strategy state from opts.

  Return `{:ok, state}` to proceed, or `{:error, reason}` to abort
  the agent loop before it starts (dispatches `{:failed, ...}`).
  """
  @callback init(opts :: keyword()) :: {:ok, state()} | {:error, term()}

  @doc """
  Execute a single tool call. Returns the result and updated state.

  `ParallelExecutor` calls this once per tool in a supervised `Task`,
  handling parallelism and per-tool deadlines. The strategy only decides
  how to execute the individual tool.

  For MCP tools that wait on external results, implementations should call
  `SwarmAi.Runtime.await_tool_result/3` to block until the result arrives.
  For backend tools, implementations call the tool module directly.
  """
  @callback execute_tool(state(), SwarmAi.ToolCall.t()) ::
              {SwarmAi.ToolResult.t(), state()}

  @doc """
  Called when a tool's deadline fires.

  Return values:
  - `{:error, state}` — produce an error `ToolResult`, agent loop continues
  - `{:pause, state}` — cleanly halt the loop (Swarm emits `:paused` event)
  """
  @callback on_deadline(state(), SwarmAi.ToolCall.t()) ::
              {:error | :pause, state()}

  @doc """
  Called after each LLM response to decide whether to continue the loop.

  Return `:halt` to stop before the agent's own `should_terminate?` check.
  Optional — defaults to always `:continue`.
  """
  @callback should_continue?(state(), SwarmAi.Loop.t()) ::
              {:continue | :halt, state()}

  @optional_callbacks should_continue?: 2
end
