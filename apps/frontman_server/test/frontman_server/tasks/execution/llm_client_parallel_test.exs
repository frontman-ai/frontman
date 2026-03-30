defmodule FrontmanServer.Tasks.Execution.LLMClientParallelTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Execution.LLMClient

  describe "parallel_tool_calls" do
    test "parallel_tool_calls is enabled by default in stream opts" do
      client = LLMClient.new(llm_opts: [api_key: "test-key"])
      assert Keyword.get(client.llm_opts, :parallel_tool_calls) == nil
    end

    test "caller can override parallel_tool_calls to false" do
      client = LLMClient.new(llm_opts: [api_key: "test-key", parallel_tool_calls: false])
      assert Keyword.get(client.llm_opts, :parallel_tool_calls) == false
    end
  end
end
