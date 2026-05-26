defmodule FrontmanServer.Tasks.Execution.LLMProvider do
  @moduledoc false

  @callback stream_text(String.t(), [ReqLLM.Message.t()], keyword()) ::
              {:ok, term()} | {:error, term()}

  def stream_text(model, messages, opts) do
    Application.get_env(:frontman_server, :llm_provider, ReqLLM).stream_text(
      model,
      messages,
      opts
    )
  end
end
