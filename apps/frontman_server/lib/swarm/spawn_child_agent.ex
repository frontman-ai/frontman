defmodule Swarm.SpawnChildAgent do
  @moduledoc """
  Request to spawn a child agent, returned by tool executors.

  Tools return `{:spawn, request}` when they want to delegate work
  to a sub-agent instead of returning a direct result.
  """
  use TypedStruct

  typedstruct do
    field :agent, Swarm.Agent.t(), enforce: true
    field :task, String.t(), enforce: true
    field :timeout_ms, pos_integer()
    field :max_steps, pos_integer()
  end

  @spec new(Swarm.Agent.t(), String.t(), keyword()) :: t()
  def new(agent, task, opts \\ []) do
    %__MODULE__{
      agent: agent,
      task: task,
      timeout_ms: opts[:timeout_ms],
      max_steps: opts[:max_steps]
    }
  end
end
