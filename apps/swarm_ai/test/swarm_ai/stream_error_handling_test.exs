defmodule SwarmAi.StreamErrorHandlingTest do
  @moduledoc """
  Tests that stream consumption errors (raises, exits) in execute_llm_call
  are caught and routed through Loop.handle_error as {:failed, ...} instead
  of crashing the process.
  """

  use SwarmAi.Testing, async: true

  describe "stream raise → graceful failure" do
    test "StreamErrorLLM raise is caught and returns {:error, reason, loop_id}" do
      error_llm = %StreamErrorLLM{error_message: "provider returned HTTP 400"}
      agent = test_agent(error_llm, "RaiseTestAgent")

      result =
        SwarmAi.run_blocking(agent, "Hello", fn _tc -> {:ok, "done"} end)

      assert {:error, reason, _loop_id} = result
      assert %RuntimeError{message: "provider returned HTTP 400"} = reason
    end
  end

  describe "ErrorLLM → graceful failure (existing behavior)" do
    test "returns {:error, reason, loop_id}" do
      agent = test_agent(%ErrorLLM{error: :provider_down}, "ErrorTestAgent")

      assert {:error, :provider_down, _loop_id} =
               SwarmAi.run_blocking(agent, "Hello", fn _tc -> {:ok, "done"} end)
    end
  end
end
