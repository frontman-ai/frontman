defmodule FrontmanServer.Tools.Backend do
  defmodule Context do
    @enforce_keys [:task]
    defstruct task: nil
  end

  @type result :: map()
  @type access :: :read | :write | :read_write

  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback access() :: access()
  @callback parameter_schema() :: map()
  @callback timeout_ms() :: pos_integer()
  @callback on_timeout() :: :error | :pause_agent
  @callback execute(args :: map(), context :: %Context{}) :: result()

  def to_swarm_tool(module) do
    SwarmAi.Tool.new(
      name: module.name(),
      description: module.description(),
      access: module.access(),
      parameter_schema: module.parameter_schema(),
      timeout_ms: module.timeout_ms(),
      on_timeout: module.on_timeout()
    )
  end
end
