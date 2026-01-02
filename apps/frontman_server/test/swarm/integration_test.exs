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
end
