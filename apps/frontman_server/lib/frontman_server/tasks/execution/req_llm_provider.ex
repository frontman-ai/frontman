defmodule FrontmanServer.Tasks.Execution.ReqLLMProvider do
  @moduledoc false

  @behaviour FrontmanServer.Tasks.Execution.LLMProvider

  @impl true
  def stream_text(model, messages, opts) do
    ReqLLM.stream_text(model, messages, opts)
  end
end
