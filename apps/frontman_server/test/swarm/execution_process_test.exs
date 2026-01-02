defmodule Swarm.ExecutionProcessTest do
  use FrontmanServer.SwarmCase, async: true

  describe "ExecutionProcess.start_async/4 success path" do
    test "returns pid and execution_id" do
      agent = test_agent(mock_llm("Success!"))
      subscriber = self()

      {:ok, %{pid: pid, execution_id: exec_id}} =
        ExecutionProcess.start_async(agent, "Hello", test_opts(), subscriber)

      assert is_pid(pid)
      assert is_binary(exec_id)
      assert String.starts_with?(exec_id, "loop_")
    end

    test "sends Started event when execution begins" do
      agent = test_agent(mock_llm("Done", delay_ms: 20))
      subscriber = self()

      {:ok, %{execution_id: exec_id}} =
        ExecutionProcess.start_async(agent, "Hello", test_opts(), subscriber)

      assert_receive {:swarm, ^exec_id, %Events.Started{message: "Hello"}}, 1000
    end

    test "sends Completed event when execution succeeds" do
      agent = test_agent(mock_llm("Success"))
      subscriber = self()

      {:ok, %{execution_id: exec_id}} =
        ExecutionProcess.start_async(agent, "Hello", test_opts(), subscriber)

      assert_receive {:swarm, ^exec_id, %Events.Started{}}, 1000
      assert_receive {:swarm, ^exec_id, %Events.Completed{result: "Success"}}, 1000
    end
  end

  describe "ExecutionProcess.start_async/4 error handling" do
    test "sends Failed event when LLM fails" do
      agent = test_agent(mock_llm({:error, :timeout}))
      subscriber = self()

      {:ok, %{execution_id: exec_id}} =
        ExecutionProcess.start_async(agent, "Hello", test_opts(), subscriber)

      assert_receive {:swarm, ^exec_id, %Events.Started{}}, 1000
      assert_receive {:swarm, ^exec_id, %Events.Failed{error: :timeout}}, 1000
    end

    test "sends Failed event with error details" do
      agent = test_agent(mock_llm({:error, :rate_limited}))
      subscriber = self()

      {:ok, %{execution_id: exec_id}} =
        ExecutionProcess.start_async(agent, "Hello", test_opts(), subscriber)

      assert_receive {:swarm, ^exec_id, %Events.Started{}}, 1000
      assert_receive {:swarm, ^exec_id, %Events.Failed{error: :rate_limited}}, 1000
    end
  end

  describe "concurrent executions" do
    test "multiple executions can run in parallel" do
      agent1 = test_agent(mock_llm("Response 1", delay_ms: 50))
      agent2 = test_agent(mock_llm("Response 2", delay_ms: 50))

      subscriber = self()
      opts = test_opts()

      {:ok, %{execution_id: exec_id1}} =
        ExecutionProcess.start_async(agent1, "First", opts, subscriber)

      {:ok, %{execution_id: exec_id2}} =
        ExecutionProcess.start_async(agent2, "Second", opts, subscriber)

      # Both should complete
      assert_receive {:swarm, ^exec_id1, %Events.Completed{result: "Response 1"}}, 1000
      assert_receive {:swarm, ^exec_id2, %Events.Completed{result: "Response 2"}}, 1000
    end
  end
end
