defmodule FrontmanServer.Agents.SubAgentLifecycleTest do
  use FrontmanServer.AgentCase, async: true

  describe "sub-agent result flow" do
    @tag fixtures: [:parent_agent, :fake_sub_agent]
    test "parent processes result and triggers next iteration", %{
      parent_agent: %{pid: parent_pid, id: parent_id},
      fake_sub_agent: fake_sub_agent
    } do
      inject_sub_agent(parent_pid, fake_sub_agent)

      send(parent_pid, {:sub_agent_result, fake_sub_agent.id, "The research result"})

      assert_receive {:event, {:sub_agent_completed, ^parent_id, completed, duration}}, 1000
      assert completed.id == fake_sub_agent.id
      assert completed.status == :completed
      assert completed.result == "The research result"
      assert duration >= 0

      assert_receive {:event, {:need_iteration, ^parent_id}}, 1000
    end
  end

  describe "sub-agent crash propagation" do
    @tag fixtures: [:parent_agent]
    test "parent handles crash and triggers next iteration", %{
      parent_agent: %{pid: parent_pid, id: parent_id}
    } do
      sub_agent_pid = spawn(fn -> Process.sleep(:infinity) end)

      fake_sub_agent = sub_agent_struct(id: "sub_crash", tool_call_id: "call_crash", pid: sub_agent_pid)
      inject_sub_agent(parent_pid, fake_sub_agent)

      send(parent_pid, {:DOWN, make_ref(), :process, sub_agent_pid, {:error, :crashed}})

      assert_receive {:event, {:sub_agent_failed, ^parent_id, failed, duration}}, 1000
      assert failed.id == "sub_crash"
      assert failed.status == :failed
      assert failed.error == {:error, :crashed}
      assert duration >= 0

      assert_receive {:event, {:need_iteration, ^parent_id}}, 1000
    end
  end

  describe "parent death handling" do
    @tag fixtures: [:sub_agent]
    test "sub-agent terminates when parent dies", %{sub_agent: %{pid: sub_agent_pid}} do
      assert Process.alive?(sub_agent_pid)

      send(sub_agent_pid, {:DOWN, make_ref(), :process, self(), :normal})

      Process.sleep(50)
      refute Process.alive?(sub_agent_pid)
    end
  end

  describe "nesting prevention" do
    @tag fixtures: [:sub_agent], parent_agent_id: "parent_123"
    test "sub-agents cannot spawn children (parent_id blocks it)", %{
      sub_agent: %{pid: sub_agent_pid}
    } do
      state = get_agent_state(sub_agent_pid)

      # Sub-agents have a parent_id, which blocks spawning in spawn_sub_agents/2
      assert state.agent.parent_id == "parent_123"
    end
  end

  describe "direct tool result routing" do
    @tag fixtures: [:registered_parent_agent, :registered_sub_agent, :tool_call]
    test "tool result delivered directly to owning agent via Registry", %{
      sub_agent: %{pid: sub_agent_pid, id: sub_agent_id, task_id: task_id},
      tool_call: tool_call
    } do
      inject_tool_call(sub_agent_pid, tool_call)
      register_tool_call(tool_call.id, sub_agent_id)

      :ok = FrontmanServer.Agents.notify_tool_result(task_id, tool_call.id, "the result", false)

      assert_receive {:event, {:need_iteration, ^sub_agent_id}}, 1000
    end

    @tag fixtures: [:registered_parent_agent, :registered_sub_agent, :tool_call]
    test "tool result not delivered to parent when sub-agent owns the tool call", %{
      parent_agent: %{id: _parent_id},
      sub_agent: %{pid: sub_agent_pid, id: sub_agent_id, task_id: task_id},
      tool_call: tool_call
    } do
      inject_tool_call(sub_agent_pid, tool_call)
      register_tool_call(tool_call.id, sub_agent_id)

      :ok = FrontmanServer.Agents.notify_tool_result(task_id, tool_call.id, "the result", false)

      # Sub-agent receives the result
      assert_receive {:event, {:need_iteration, ^sub_agent_id}}, 1000

      # Parent should NOT receive anything
      refute_receive {:event, {:need_iteration, _}}, 100
    end
  end

  describe "multiple pending sub-agents" do
    @tag fixtures: [:parent_agent]
    test "waits for all before triggering next iteration", %{
      parent_agent: %{pid: parent_pid, id: parent_id}
    } do
      sub1 = sub_agent_struct(id: "sub_1", tool_call_id: "call_1", role: :research, message: "message 1")
      sub2 = sub_agent_struct(id: "sub_2", tool_call_id: "call_2", role: :planning, message: "message 2")

      inject_sub_agents(parent_pid, [sub1, sub2])

      send(parent_pid, {:sub_agent_result, "sub_1", "Result 1"})

      assert_receive {:event, {:sub_agent_completed, ^parent_id, _, _}}, 1000
      refute_receive {:event, {:need_iteration, _}}, 100

      send(parent_pid, {:sub_agent_result, "sub_2", "Result 2"})

      assert_receive {:event, {:sub_agent_completed, ^parent_id, _, _}}, 1000
      assert_receive {:event, {:need_iteration, ^parent_id}}, 1000
    end
  end
end
