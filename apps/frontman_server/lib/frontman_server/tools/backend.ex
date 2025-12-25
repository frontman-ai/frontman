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
      field :agent_id, String.t(), enforce: true
      field :llm_opts, keyword(), default: []
    end
  end

  @type result :: {:ok, term()} | {:error, String.t()}

  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback parameter_schema() :: map()
  @callback execute(args :: map(), context :: Context.t()) :: result()

  @spec to_llm_tool(module()) :: ReqLLM.Tool.t()
  def to_llm_tool(module) do
    ReqLLM.Tool.new!(
      name: module.name(),
      description: module.description(),
      parameter_schema: module.parameter_schema(),
      # Dummy callback - backend tools are intercepted and routed through Tools.execute_backend_tool/2
      callback: fn _args -> {:ok, nil} end
    )
  end
end
