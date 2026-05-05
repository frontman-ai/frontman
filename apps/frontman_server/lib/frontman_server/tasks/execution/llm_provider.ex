defmodule FrontmanServer.Tasks.Execution.LLMProvider do
  @moduledoc """
  Behaviour for the external LLM streaming boundary used by `LLMClient`.

  Production delegates to ReqLLM. Tests can replace this boundary with Mox
  without swapping out Frontman's RootAgent.
  """

  @callback stream_text(String.t(), [ReqLLM.Message.t()], keyword()) ::
              {:ok, term()} | {:error, term()}

  @spec stream_text(String.t(), [ReqLLM.Message.t()], keyword()) ::
          {:ok, term()} | {:error, term()}
  def stream_text(model, messages, opts) do
    provider().stream_text(model, messages, opts)
  end

  defp provider do
    Application.fetch_env!(:frontman_server, :llm_provider)
  end
end
