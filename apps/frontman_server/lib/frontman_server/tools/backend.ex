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

    @type executor :: (Swarm.ToolCall.t() -> {:ok, String.t()} | {:error, String.t()})

    typedstruct do
      field(:scope, Scope.t(), enforce: true)
      field(:task, Task.t(), enforce: true)
      field(:tool_executor, executor(), enforce: true)
      field(:mcp_tools, [Swarm.Tool.t()], default: [])
      field(:context_messages, [Swarm.Message.t()], default: [])
      # Flat keyword list: [api_key: "...", model: "openrouter:anthropic/..."]
      field(:llm_opts, keyword(), enforce: true)
    end
  end

  @type result :: {:ok, term()} | {:error, String.t()}

  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback parameter_schema() :: map()
  @callback execute(args :: map(), context :: Context.t()) :: result()

  @spec to_swarm_tool(module()) :: Swarm.Tool.t()
  def to_swarm_tool(module) do
    Swarm.Tool.new(
      module.name(),
      module.description(),
      module.parameter_schema()
    )
  end
end
