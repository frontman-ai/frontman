defmodule FrontmanServer.Agents.SubAgentLifecycleTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Agents.AgentServer

  describe "sub-agent result flow" do
    test "parent processes result and triggers next iteration" do
      test_pid = self()
      on_event = fn event -> send(test_pid, {:event, event}) end

      {:ok, parent_pid} =
        GenServer.start_link(
          AgentServer,
          {:root,
           %{
             agent_id: "parent_123",
             task_id: "task_result_#{System.unique_integer()}",
             tools: [],
             on_event: on_event
           }}
        )

      fake_sub_agent = %FrontmanServer.Agents.SubAgent{
        id: "sub_456",
        tool_call_id: "call_456",
        role: :research,
        task: "find info",
        pid: self(),
        status: :running,
        started_at: System.monotonic_time(:millisecond)
      }

      :sys.replace_state(parent_pid, fn state ->
        %{state | pending_sub_agents: %{"sub_456" => fake_sub_agent}}
      end)

      send(parent_pid, {:sub_agent_result, "sub_456", "The research result"})

      assert_receive {:event, {:sub_agent_completed, "parent_123", completed, duration}}, 1000
      assert completed.id == "sub_456"
      assert completed.status == :completed
      assert completed.result == "The research result"
      assert duration >= 0

      assert_receive {:event, {:need_iteration, "parent_123"}}, 1000

      GenServer.stop(parent_pid)
    end
  end

  describe "sub-agent crash propagation" do
    test "parent handles crash and triggers next iteration" do
      test_pid = self()
      on_event = fn event -> send(test_pid, {:event, event}) end

      {:ok, parent_pid} =
        GenServer.start_link(
          AgentServer,
          {:root,
           %{
             agent_id: "parent_crash",
             task_id: "task_crash_#{System.unique_integer()}",
             tools: [],
             on_event: on_event
           }}
        )

      sub_agent_pid = spawn(fn -> Process.sleep(:infinity) end)

      fake_sub_agent = %FrontmanServer.Agents.SubAgent{
        id: "sub_crash",
        tool_call_id: "call_crash",
        role: :research,
        task: "crash task",
        pid: sub_agent_pid,
        status: :running,
        started_at: System.monotonic_time(:millisecond)
      }

      :sys.replace_state(parent_pid, fn state ->
        %{state | pending_sub_agents: %{"sub_crash" => fake_sub_agent}}
      end)

      send(parent_pid, {:DOWN, make_ref(), :process, sub_agent_pid, {:error, :crashed}})

      assert_receive {:event, {:sub_agent_failed, "parent_crash", failed, duration}}, 1000
      assert failed.id == "sub_crash"
      assert failed.status == :failed
      assert failed.error == {:error, :crashed}
      assert duration >= 0

      assert_receive {:event, {:need_iteration, "parent_crash"}}, 1000

      GenServer.stop(parent_pid)
    end
  end

  describe "parent death handling" do
    test "sub-agent terminates when parent dies" do
      on_event = fn _event -> :ok end

      {:ok, sub_agent_pid} =
        GenServer.start_link(
          AgentServer,
          {:sub_agent,
           %{
             agent_id: "sub_orphan",
             task_id: "task_orphan_#{System.unique_integer()}",
             tools: [],
             on_event: on_event,
             parent_agent_id: "fake_parent",
             parent_pid: self(),
             role: :research,
             task: "test task"
           }}
        )

      assert Process.alive?(sub_agent_pid)

      send(sub_agent_pid, {:DOWN, make_ref(), :process, self(), :normal})

      Process.sleep(50)
      refute Process.alive?(sub_agent_pid)
    end
  end

  describe "nesting prevention" do
    test "sub-agents have no supervisor to spawn children" do
      on_event = fn _event -> :ok end

      {:ok, sub_agent_pid} =
        GenServer.start_link(
          AgentServer,
          {:sub_agent,
           %{
             agent_id: "sub_nested",
             task_id: "task_nested_#{System.unique_integer()}",
             tools: [],
             on_event: on_event,
             parent_agent_id: "parent_123",
             parent_pid: self(),
             role: :research,
             task: "test task"
           }}
        )

      state = :sys.get_state(sub_agent_pid)

      assert state.sub_agent_supervisor == nil
      assert state.parent_agent_id == "parent_123"

      GenServer.stop(sub_agent_pid)
    end
  end

  describe "direct tool result routing" do
    test "tool result delivered directly to owning agent via Registry" do
      test_pid = self()
      task_id = "task_direct_#{System.unique_integer()}"
      sub_agent_id = "sub_direct_#{System.unique_integer()}"
      tool_call_id = "tool_#{System.unique_integer()}"

      # Start sub-agent with Registry registration
      {:ok, sub_agent_pid} =
        GenServer.start_link(
          AgentServer,
          {:sub_agent,
           %{
             agent_id: sub_agent_id,
             task_id: task_id,
             tools: [],
             on_event: fn event -> send(test_pid, {:sub_event, event}) end,
             parent_agent_id: "fake_parent",
             parent_pid: self(),
             role: :research,
             task: "test task"
           }},
          name:
            {:via, Registry,
             {FrontmanServer.AgentRegistry, {:agent, sub_agent_id},
              %{
                task_id: task_id,
                parent_agent_id: "fake_parent",
                role: :research,
                state: :processing
              }}}
        )

      # Sub-agent has a pending tool call - manually add and register it
      :sys.replace_state(sub_agent_pid, fn state ->
        %{state | pending_tool_calls: %{tool_call_id => %{id: tool_call_id, name: "test_tool"}}}
      end)

      # Register tool call for direct routing
      Registry.register(FrontmanServer.AgentRegistry, {:tool_call, tool_call_id}, sub_agent_id)

      # Route tool result directly via Agents module
      :ok = FrontmanServer.Agents.notify_tool_result(task_id, tool_call_id, "the result", false)

      # Sub-agent should receive and trigger iteration
      assert_receive {:sub_event, {:need_iteration, ^sub_agent_id}}, 1000

      GenServer.stop(sub_agent_pid)
    end

    test "tool result not delivered to parent when sub-agent owns the tool call" do
      test_pid = self()
      task_id = "task_isolation_#{System.unique_integer()}"
      parent_agent_id = "parent_isolation_#{System.unique_integer()}"
      sub_agent_id = "sub_isolation_#{System.unique_integer()}"
      tool_call_id = "tool_isolation_#{System.unique_integer()}"

      # Start parent agent
      {:ok, _parent_pid} =
        GenServer.start_link(
          AgentServer,
          {:root,
           %{
             agent_id: parent_agent_id,
             task_id: task_id,
             tools: [],
             on_event: fn event -> send(test_pid, {:parent_event, event}) end
           }},
          name:
            {:via, Registry,
             {FrontmanServer.AgentRegistry, {:agent, parent_agent_id},
              %{
                task_id: task_id,
                parent_agent_id: nil,
                role: :root,
                state: :processing
              }}}
        )

      # Start sub-agent
      {:ok, sub_agent_pid} =
        GenServer.start_link(
          AgentServer,
          {:sub_agent,
           %{
             agent_id: sub_agent_id,
             task_id: task_id,
             tools: [],
             on_event: fn event -> send(test_pid, {:sub_event, event}) end,
             parent_agent_id: parent_agent_id,
             parent_pid: self(),
             role: :research,
             task: "test task"
           }},
          name:
            {:via, Registry,
             {FrontmanServer.AgentRegistry, {:agent, sub_agent_id},
              %{
                task_id: task_id,
                parent_agent_id: parent_agent_id,
                role: :research,
                state: :processing
              }}}
        )

      # Sub-agent has a pending tool call
      :sys.replace_state(sub_agent_pid, fn state ->
        %{state | pending_tool_calls: %{tool_call_id => %{id: tool_call_id, name: "test_tool"}}}
      end)

      # Register tool call for direct routing
      Registry.register(FrontmanServer.AgentRegistry, {:tool_call, tool_call_id}, sub_agent_id)

      # Route tool result
      :ok = FrontmanServer.Agents.notify_tool_result(task_id, tool_call_id, "the result", false)

      # Sub-agent receives the result
      assert_receive {:sub_event, {:need_iteration, ^sub_agent_id}}, 1000

      # Parent should NOT receive anything
      refute_receive {:parent_event, {:need_iteration, _}}, 100
    end
  end

  describe "multiple pending sub-agents" do
    test "waits for all before triggering next iteration" do
      test_pid = self()
      on_event = fn event -> send(test_pid, {:event, event}) end

      {:ok, parent_pid} =
        GenServer.start_link(
          AgentServer,
          {:root,
           %{
             agent_id: "parent_multi",
             task_id: "task_multi_#{System.unique_integer()}",
             tools: [],
             on_event: on_event
           }}
        )

      sub1 = %FrontmanServer.Agents.SubAgent{
        id: "sub_1",
        tool_call_id: "call_1",
        role: :research,
        task: "task 1",
        pid: self(),
        status: :running,
        started_at: System.monotonic_time(:millisecond)
      }

      sub2 = %FrontmanServer.Agents.SubAgent{
        id: "sub_2",
        tool_call_id: "call_2",
        role: :planning,
        task: "task 2",
        pid: self(),
        status: :running,
        started_at: System.monotonic_time(:millisecond)
      }

      :sys.replace_state(parent_pid, fn state ->
        %{state | pending_sub_agents: %{"sub_1" => sub1, "sub_2" => sub2}}
      end)

      send(parent_pid, {:sub_agent_result, "sub_1", "Result 1"})

      assert_receive {:event, {:sub_agent_completed, "parent_multi", _, _}}, 1000
      refute_receive {:event, {:need_iteration, _}}, 100

      send(parent_pid, {:sub_agent_result, "sub_2", "Result 2"})

      assert_receive {:event, {:sub_agent_completed, "parent_multi", _, _}}, 1000
      assert_receive {:event, {:need_iteration, "parent_multi"}}, 1000

      GenServer.stop(parent_pid)
    end
  end
end
