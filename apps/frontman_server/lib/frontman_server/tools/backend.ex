defmodule FrontmanServer.Tools.Backend do
  @moduledoc """
  Behaviour for backend tools that execute server-side.
  """

  defmodule Context do
    @moduledoc """
    Execution context passed to backend tools.

    The `tool_executor` is a pre-built description executor for use with
    `SwarmAi.Runtime.run/5`. It maps `[ToolCall.t()]` to `[ToolExecution.t()]`
    (descriptions), not final results — `SwarmAi.Runtime` wraps it with
    `ParallelExecutor` before handing it to the execution loop.

    Backend tools that spawn sub-agents should pass this executor as the
    `tool_executor` option to `SwarmAi.Runtime.run/5`. Do not pass it directly
    to `SwarmAi.run_streaming/3`, which expects a result-producing function.

    Tools receive all needed data through this context rather than calling back into
    contexts:
    - `llm_opts`: Flat keyword list with `:api_key` and `:model` for LLM calls
    - `mcp_tools`: Pre-converted Swarm tools for sub-agent spawning
    - `context_messages`: Pre-extracted context from read_file results (AGENTS.md, etc.)
    """
    use TypedStruct

    alias FrontmanServer.Accounts.Scope
    alias FrontmanServer.Tasks.Task

    @type executor :: ([SwarmAi.ToolCall.t()] -> [SwarmAi.ToolExecution.Sync.t() | SwarmAi.ToolExecution.Await.t()])

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
