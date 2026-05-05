defmodule FrontmanServer.Test.Fixtures.LLMProvider do
  @moduledoc false

  import Mox

  alias FrontmanServer.Tasks.Execution.LLMProviderMock
  alias FrontmanServer.Test.Fixtures.ReqLLMResponses

  def expect_llm_responses(responses) do
    Mox.verify_on_exit!(%{})

    Enum.each(responses, fn response ->
      expect(LLMProviderMock, :stream_text, fn _model, _messages, _opts ->
        ReqLLMResponses.response(response)
      end)
    end)
  end

  def stub_llm_response(response) do
    stub(LLMProviderMock, :stream_text, fn _model, _messages, _opts ->
      ReqLLMResponses.response(response)
    end)
  end
end
