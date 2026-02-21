defmodule SwarmAi.Effect do
  @moduledoc """
  Effects returned by the loop runner
  """
  @type t ::
          {:call_llm, SwarmAi.LLM.t(), messages :: [SwarmAi.Message.t()]}
          | {:execute_tool, SwarmAi.ToolCall.t()}
          | {:emit_event, SwarmAi.Events.event()}
          | {:step_ended, step :: non_neg_integer()}
          | {:complete, result :: String.t()}
          | {:fail, error :: term()}
end
