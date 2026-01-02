defmodule Swarm.IntegrationTest do
  use FrontmanServer.SwarmCase, async: true

  describe "Swarm.start/3" do
    @tag echo_agent: true
    test "returns immediately with execution handle", %{echo_agent: agent} do
      {:ok, execution} = Swarm.start(agent, "Hello")
      assert is_binary(execution.id)
      assert is_pid(execution.pid)
    end

    @tag echo_agent: true
    test "sends Started event to caller", %{echo_agent: agent} do
      {:ok, execution} = Swarm.start(agent, "Test")
      assert_receive {:swarm, exec_id, %Events.Started{message: "Test"}}, 1000
      assert exec_id == execution.id
    end

    @tag echo_agent: true
    test "sends Completed event when done", %{echo_agent: agent} do
      {:ok, execution} = Swarm.start(agent, "Test")
      assert_receive {:swarm, _, %Events.Started{}}, 1000
      assert_receive {:swarm, exec_id, %Events.Completed{result: "Echo: Test"}}, 1000
      assert exec_id == execution.id
    end

    @tag error_agent: :rate_limited
    test "sends Failed event on error", %{error_agent: agent} do
      {:ok, execution} = Swarm.start(agent, "Test")
      assert_receive {:swarm, _, %Events.Started{}}, 1000
      assert_receive {:swarm, exec_id, %Events.Failed{error: :rate_limited}}, 1000
      assert exec_id == execution.id
    end

    @tag echo_agent: true
    test "events contain matching execution_id", %{echo_agent: agent} do
      {:ok, execution} = Swarm.start(agent, "Test")
      assert_receive {:swarm, exec_id, %Events.Started{execution_id: event_exec_id}}, 1000
      assert exec_id == event_exec_id
      assert exec_id == execution.id
    end
  end

  describe "Swarm.await/1" do
    @tag echo_agent: true
    test "blocks until complete and returns result", %{echo_agent: agent} do
      {:ok, execution} = Swarm.start(agent, "Test")
      assert {:ok, "Echo: Test"} = Swarm.await(execution)
    end

    @tag error_agent: :failed
    test "returns error on failure", %{error_agent: agent} do
      {:ok, execution} = Swarm.start(agent, "Test")
      assert {:error, :failed} = Swarm.await(execution)
    end

    test "respects timeout" do
      slow_llm = mock_llm("Response", delay_ms: 500)
      agent = test_agent(slow_llm)
      {:ok, execution} = Swarm.start(agent, "Test")
      assert {:error, :timeout} = Swarm.await(execution, timeout: 50)
    end
  end

  describe "custom subscriber" do
    @tag echo_agent: true
    test "sends events to specified subscriber", %{echo_agent: agent} do
      parent = self()

      subscriber =
        spawn(fn ->
          receive do
            msg -> send(parent, {:got, msg})
          end
        end)

      opts = %Swarm.ExecuteOpts{subscriber: subscriber}
      {:ok, _} = Swarm.start(agent, "Test", opts)

      assert_receive {:got, {:swarm, _, %Events.Started{}}}, 1000
    end
  end

  describe "execution options" do
    test "respects custom max_steps" do
      agent = test_agent(mock_llm("Response"))
      {:ok, execution} = Swarm.start(agent, "Test")
      assert {:ok, "Response"} = Swarm.await(execution)
    end
  end

  describe "multi-turn tool flow" do
    test "LLM → tool call → tool result → LLM → complete" do
      tc = %Swarm.ToolCall{id: "tc_1", name: "get_data", arguments: ~s({"key":"value"})}

      llm =
        multi_turn_llm([
          {:tool_calls, [tc], "Let me fetch that"},
          {:complete, "Here's the data: processed_result"}
        ])

      agent = test_agent(llm)

      {:ok, execution} = Swarm.start(agent, "Get my data")

      # 1. Started
      assert_receive {:swarm, _, %Events.Started{message: "Get my data"}}, 1000

      # 2. Tool call requested
      assert_receive {:swarm, _, %Events.ToolCallRequested{tool_call: received_tc}}, 1000
      assert received_tc.id == "tc_1"
      assert received_tc.name == "get_data"

      # 3. Provide tool result
      Swarm.notify_tool_result(execution, "tc_1", "processed_result", false)

      # 4. Completed
      assert_receive {:swarm, _, %Events.Completed{result: result}}, 1000
      assert result =~ "processed_result"
    end

    test "handles multiple parallel tool calls" do
      tc1 = %Swarm.ToolCall{id: "tc_1", name: "tool_a", arguments: "{}"}
      tc2 = %Swarm.ToolCall{id: "tc_2", name: "tool_b", arguments: "{}"}

      llm =
        multi_turn_llm([
          {:tool_calls, [tc1, tc2], "Calling two tools"},
          {:complete, "Combined: result_a + result_b"}
        ])

      agent = test_agent(llm)

      {:ok, execution} = Swarm.start(agent, "Test")

      assert_receive {:swarm, _, %Events.Started{}}, 1000
      assert_receive {:swarm, _, %Events.ToolCallRequested{tool_call: %{id: "tc_1"}}}, 1000
      assert_receive {:swarm, _, %Events.ToolCallRequested{tool_call: %{id: "tc_2"}}}, 1000

      # Order shouldn't matter
      Swarm.notify_tool_result(execution, "tc_2", "result_b", false)
      Swarm.notify_tool_result(execution, "tc_1", "result_a", false)

      assert_receive {:swarm, _, %Events.Completed{}}, 1000
    end

    test "handles error tool results" do
      tc = %Swarm.ToolCall{id: "tc_1", name: "failing_tool", arguments: "{}"}

      llm =
        multi_turn_llm([
          {:tool_calls, [tc], "Trying tool"},
          {:complete, "Handled the error gracefully"}
        ])

      agent = test_agent(llm)

      {:ok, execution} = Swarm.start(agent, "Test")

      assert_receive {:swarm, _, %Events.ToolCallRequested{}}, 1000
      Swarm.notify_tool_result(execution, "tc_1", "Error: something failed", true)

      assert_receive {:swarm, _, %Events.Completed{}}, 1000
    end
  end
end
