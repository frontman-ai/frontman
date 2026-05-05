defmodule FrontmanServer.Tasks.Execution.LLMClientParallelTest do
  use ExUnit.Case, async: true

  import Mox

  alias FrontmanServer.Tasks.Execution.LLMClient
  alias FrontmanServer.Tasks.Execution.LLMProviderMock

  setup :verify_on_exit!

  describe "parallel_tool_calls" do
    test "parallel_tool_calls is enabled by default in provider opts" do
      expect(LLMProviderMock, :stream_text, fn _model, _messages, opts ->
        assert Keyword.fetch!(opts, :parallel_tool_calls) == true
        {:ok, stream_response([])}
      end)

      client = LLMClient.new(llm_opts: [api_key: "test-key"])
      assert {:ok, _stream} = SwarmAi.LLM.stream(client, [SwarmAi.Message.user("Hello")], [])
    end

    test "caller can override parallel_tool_calls to false in provider opts" do
      expect(LLMProviderMock, :stream_text, fn _model, _messages, opts ->
        assert Keyword.fetch!(opts, :parallel_tool_calls) == false
        {:ok, stream_response([])}
      end)

      client = LLMClient.new(llm_opts: [api_key: "test-key", parallel_tool_calls: false])
      assert {:ok, _stream} = SwarmAi.LLM.stream(client, [SwarmAi.Message.user("Hello")], [])
    end
  end

  defp stream_response(chunks) do
    %{stream: chunks, cancel: fn -> :ok end}
  end
end
