defmodule SwarmAi.Effect do
  @moduledoc """
  Effects produced by the pure functional loop runner.

  Effects are tagged tuples representing instructions for the impure shell
  (`SwarmAi` module) to execute. The runner never performs side effects
  directly -- it returns these values and the caller interprets them.

  ## Effect Types

  - `{:call_llm, llm, messages}` - make an LLM API call
  - `{:execute_tool, tool_call}` - execute a tool
  - `{:step_ended, step}` - a step completed
  - `{:complete, result}` - loop finished successfully
  - `{:fail, error}` - loop failed
  """
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
