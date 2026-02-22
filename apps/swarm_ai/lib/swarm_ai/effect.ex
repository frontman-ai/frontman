defmodule SwarmAi.Effect do
  @moduledoc """
  Effects produced by the pure functional loop runner.

  Effects are tagged tuples representing instructions for the impure shell
  (`SwarmAi` module) to execute. The runner never performs side effects
  directly -- it returns these values and the caller interprets them.

  ## Effect Types

  - `{:call_llm, llm, messages}` - make an LLM API call
  - `{:execute_tool, tool_call}` - execute a tool
  - `{:emit_event, event}` - emit a domain event
  - `{:step_ended, step}` - a step completed
  - `{:complete, result}` - loop finished successfully
  - `{:fail, error}` - loop failed
  """
  @type t ::
          {:call_llm, SwarmAi.LLM.t(), messages :: [SwarmAi.Message.t()]}
          | {:execute_tool, SwarmAi.ToolCall.t()}
          | {:emit_event, SwarmAi.Events.event()}
          | {:step_ended, step :: non_neg_integer()}
          | {:complete, result :: String.t()}
          | {:fail, error :: term()}
end
