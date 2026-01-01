defmodule Swarm.SpawnChildAgent do
  use TypedStruct

  typedstruct do
    field :agent, Swarm.Agent.t(), enforce: true
    field :task, String.t(), enforce: true
    field :context_message, String.t()
    field :tools, [Swarm.Tool.t()]
    field :replace_tools, boolean(), default: false
    field :wait, boolean(), default: true
    field :timeout_ms, pos_integer()
    field :max_steps, pos_integer()
  end
end
