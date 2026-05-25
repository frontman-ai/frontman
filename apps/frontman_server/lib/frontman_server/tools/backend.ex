# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tools.Backend do
  @moduledoc """
  Behaviour for backend tools that execute server-side.
  """

  defmodule Context do
    @moduledoc """
    Execution context passed to backend tools.

    Tools receive all needed data through this context rather than calling back into
    contexts.
    """
    use TypedStruct

    alias FrontmanServer.Tasks.Task

    typedstruct do
      field(:task, Task.t(), enforce: true)
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
