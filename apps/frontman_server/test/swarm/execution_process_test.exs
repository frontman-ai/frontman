defmodule Swarm.ExecutionProcessTest do
  use FrontmanServer.SwarmCase, async: true

  describe "ExecutionProcess.run/3 success path" do
    @tag execute_opts: true
    test "returns result from successful LLM call", %{execute_opts: opts} do
      agent = test_agent(mock_llm("Success!"))

      assert {:ok, "Success!"} = ExecutionProcess.run(agent, "Hello", opts)
    end

    @tag execute_opts: true
    test "emits Started event when execution begins", %{execute_opts: opts} do
      agent = test_agent(mock_llm("Done", delay_ms: 20))

      Task.async(fn -> ExecutionProcess.run(agent, "Hello", opts) end)

      assert_receive {:event, %Events.Started{message: "Hello"}}, 1000
    end

    @tag execute_opts: true
    test "emits Completed event when execution succeeds", %{execute_opts: opts} do
      agent = test_agent(mock_llm("Success"))

      ExecutionProcess.run(agent, "Hello", opts)

      assert_received {:event, %Events.Started{}}
      assert_received {:event, %Events.Completed{result: "Success"}}
    end
  end

  describe "ExecutionProcess.run/3 error handling" do
    @tag execute_opts: true
    test "returns error when LLM fails", %{execute_opts: opts} do
      agent = test_agent(mock_llm({:error, :timeout}))

      assert {:error, :timeout} = ExecutionProcess.run(agent, "Hello", opts)
    end

    @tag execute_opts: true
    test "emits Failed event when LLM errors", %{execute_opts: opts} do
      agent = test_agent(mock_llm({:error, :rate_limited}))

      ExecutionProcess.run(agent, "Hello", opts)

      assert_received {:event, %Events.Started{}}
      assert_received {:event, %Events.Failed{error: :rate_limited}}
    end

    @tag execute_opts: true
    test "handles LLM errors from exceptions", %{execute_opts: opts} do
      error_fn = fn -> {:error, :something_went_wrong} end
      agent = test_agent(mock_llm(error_fn))

      assert {:error, :something_went_wrong} = ExecutionProcess.run(agent, "Hello", opts)
    end
  end

  describe "concurrent executions" do
    test "multiple executions can run in parallel" do
      agent1 = test_agent(mock_llm("Response 1", delay_ms: 50))
      agent2 = test_agent(mock_llm("Response 2", delay_ms: 50))

      opts = test_opts()

      task1 = Task.async(fn -> ExecutionProcess.run(agent1, "First", opts) end)
      task2 = Task.async(fn -> ExecutionProcess.run(agent2, "Second", opts) end)

      assert {:ok, "Response 1"} = Task.await(task1)
      assert {:ok, "Response 2"} = Task.await(task2)
    end
  end
end
