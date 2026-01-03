defmodule Swarm.Effect do
  @moduledoc """
  Effects returned by the loop runner
  """
  @type t ::
          {:call_llm, Swarm.LLM.t(), messages :: [Swarm.Message.t()]}
          | {:execute_tool, Swarm.ToolCall.t()}
          | {:emit_event, Swarm.Events.event()}
          | {:complete, result :: String.t()}
          | {:fail, error :: term()}
end
