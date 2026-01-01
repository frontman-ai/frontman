defmodule Swarm.IntegrationTest do
  use FrontmanServer.SwarmCase, async: true

  describe "Swarm.execute/3" do
    @tag echo_agent: true
    test "executes agent and returns LLM response", %{echo_agent: agent} do
      assert {:ok, "Echo: Hello"} = Swarm.execute(agent, "Hello")
    end

    @tag error_agent: :rate_limited
    test "returns error when LLM fails", %{error_agent: agent} do
      assert {:error, :rate_limited} = Swarm.execute(agent, "Test")
    end

    @tag error_agent: {:network_error, "Connection refused"}
    test "propagates LLM error details", %{error_agent: agent} do
      assert {:error, {:network_error, "Connection refused"}} = Swarm.execute(agent, "Test")
    end
  end

  describe "event emission" do
    @tag echo_agent: true
    test "emits Started and Completed events on success", %{echo_agent: agent} do
      test_pid = self()
      opts = %Swarm.ExecuteOpts{on_event: fn e -> send(test_pid, {:event, e}) end}

      Swarm.execute(agent, "Test", opts)

      assert_received {:event, %Events.Started{message: "Test"}}
      assert_received {:event, %Events.Completed{result: "Echo: Test"}}
    end

    @tag error_agent: :failed
    test "emits Started and Failed events on error", %{error_agent: agent} do
      test_pid = self()
      opts = %Swarm.ExecuteOpts{on_event: fn e -> send(test_pid, {:event, e}) end}

      Swarm.execute(agent, "Test", opts)

      assert_received {:event, %Events.Started{message: "Test"}}
      assert_received {:event, %Events.Failed{error: :failed}}
    end

    @tag echo_agent: true
    test "events contain execution_id", %{echo_agent: agent} do
      test_pid = self()
      opts = %Swarm.ExecuteOpts{on_event: fn e -> send(test_pid, {:event, e}) end}

      Swarm.execute(agent, "Test", opts)

      assert_received {:event, %Events.Started{execution_id: exec_id}}
      assert_received {:event, %Events.Completed{execution_id: ^exec_id}}
      assert String.starts_with?(exec_id, "loop_")
    end
  end

  describe "execution options" do
    test "respects custom max_steps" do
      agent = test_agent(mock_llm("Response"))
      opts = %Swarm.ExecuteOpts{max_steps: 5}

      assert {:ok, "Response"} = Swarm.execute(agent, "Test", opts)
    end

    test "uses default options when not provided" do
      agent = test_agent(mock_llm("Response"))

      assert {:ok, "Response"} = Swarm.execute(agent, "Test")
    end
  end
end
