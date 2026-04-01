defmodule SwarmAi.Runtime.AgentTask do
  @moduledoc """
  What the runtime was asked to run.
  """
  use TypedStruct

  typedstruct enforce: true do
    field(:key, term())
    field(:agent, SwarmAi.Agent.t())
    field(:messages, SwarmAi.message_input())
    field(:loop_config, keyword())
    field(:event_context, map(), default: %{})
  end
end
