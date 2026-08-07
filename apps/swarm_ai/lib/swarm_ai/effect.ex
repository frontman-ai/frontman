defmodule SwarmAi.Effect do
  @type t ::
          {:call_llm, SwarmAi.LLM.t(), messages :: [SwarmAi.Message.t()]}
          | {:execute_tool, SwarmAi.ToolCall.t()}
          | {:step_ended, step :: non_neg_integer()}
          | {:complete, result :: String.t()}
          | {:fail, error :: term()}

  @spec call_llm(SwarmAi.LLM.t(), [SwarmAi.Message.t()]) :: t()
  def call_llm(llm, messages), do: {:call_llm, llm, messages}

  @spec execute_tool(SwarmAi.ToolCall.t()) :: t()
  def execute_tool(tool_call), do: {:execute_tool, tool_call}

  @spec step_ended(non_neg_integer()) :: t()
  def step_ended(step), do: {:step_ended, step}

  @spec complete(String.t()) :: t()
  def complete(result), do: {:complete, result}

  @spec fail(term()) :: t()
  def fail(error), do: {:fail, error}
end
