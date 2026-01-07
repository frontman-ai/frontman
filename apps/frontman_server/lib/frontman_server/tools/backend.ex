defmodule FrontmanServer.Tools.Backend do
  @moduledoc """
  Behaviour for backend tools that execute server-side.
  """

  defmodule Context do
    @moduledoc """
    Execution context passed to backend tools.
    """
    use TypedStruct

    alias FrontmanServer.Tasks.Task

    typedstruct do
      field :task, Task.t(), enforce: true
      field :llm_opts, keyword(), default: []
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
