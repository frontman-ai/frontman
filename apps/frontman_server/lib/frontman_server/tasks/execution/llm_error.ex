defmodule FrontmanServer.Tasks.Execution.LLMError do
  defexception message: nil, category: "unknown", retryable: false

  @impl true
  def message(%__MODULE__{message: msg}), do: msg
end
