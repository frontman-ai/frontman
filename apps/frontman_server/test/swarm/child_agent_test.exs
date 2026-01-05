defmodule Swarm.ChildAgentTest do
  @moduledoc """
  Integration tests for sub-agent spawning via run_child/5.
  """
  use FrontmanServer.SwarmCase, async: true

  alias Swarm.{SpawnChildAgent, ChildResult, Message}

  describe "run_child/5" do
    test "executes child agent to completion" do
      child_agent = test_agent(mock_llm("Child completed the analysis"))
      spawn_request = SpawnChildAgent.new(child_agent, "Analyze the auth module")

      parent_loop_id = Swarm.Id.generate("loop")
      tool_call_id = "tc_spawn_123"
      tool_executor = fn _tc -> {:ok, "tool result"} end

      child_result =
        Swarm.run_child(parent_loop_id, 1, tool_call_id, spawn_request, tool_executor)

      assert %ChildResult{} = child_result
      assert child_result.status == :completed
      assert child_result.result == "Child completed the analysis"
      assert child_result.step_count >= 1
      assert child_result.duration_ms >= 0
    end

    test "child loop tracks parent linkage" do
      child_agent = test_agent(mock_llm("Done"))
      spawn_request = SpawnChildAgent.new(child_agent, "Task")

      parent_loop_id = Swarm.Id.generate("loop")
      parent_step = 3

      child_result =
        Swarm.run_child(parent_loop_id, parent_step, "tc_1", spawn_request, fn _ -> {:ok, ""} end)

      assert child_result.loop.parent_id == parent_loop_id
      assert child_result.loop.parent_step == parent_step
    end

    test "child receives task as user message" do
      child_agent = test_agent(mock_llm("Acknowledged"))
      spawn_request = SpawnChildAgent.new(child_agent, "Please analyze module X")

      child_result =
        Swarm.run_child(Swarm.Id.generate("loop"), 1, "tc_1", spawn_request, fn _ -> {:ok, ""} end)

      [step | _] = child_result.loop.steps
      user_message = Enum.find(step.input_messages, &(&1.role == :user))

      assert Message.text(user_message) == "Please analyze module X"
    end

    test "child handles tool calls during execution" do
      child_llm =
        multi_turn_llm([
          {:tool_calls,
           [%ToolCall{id: "tc_1", name: "read_file", arguments: ~s({"path": "auth.ex"})}], nil},
          {:complete, "Analysis complete: found 3 issues"}
        ])

      child_agent = test_agent(child_llm)
      spawn_request = SpawnChildAgent.new(child_agent, "Analyze auth")

      tool_executor = fn tc ->
        assert tc.name == "read_file"
        {:ok, "def authenticate(user), do: :ok"}
      end

      child_result =
        Swarm.run_child(Swarm.Id.generate("loop"), 1, "tc_spawn", spawn_request, tool_executor)

      assert child_result.status == :completed
      assert child_result.result == "Analysis complete: found 3 issues"
      assert child_result.step_count >= 2
    end

    test "returns failed status when child LLM errors" do
      child_agent = test_agent(mock_llm({:error, :network_timeout}))
      spawn_request = SpawnChildAgent.new(child_agent, "Do something")

      child_result =
        Swarm.run_child(Swarm.Id.generate("loop"), 1, "tc_1", spawn_request, fn _ -> {:ok, ""} end)

      assert child_result.status == :failed
      assert child_result.error == :network_timeout
    end

    test "child can spawn grandchild (recursive)" do
      grandchild_agent = test_agent(mock_llm("Grandchild done"))

      child_llm =
        multi_turn_llm([
          {:tool_calls, [%ToolCall{id: "tc_1", name: "delegate", arguments: "{}"}], nil},
          {:complete, "Child got grandchild result"}
        ])

      child_agent = test_agent(child_llm)
      spawn_request = SpawnChildAgent.new(child_agent, "Parent task")

      tool_executor = fn tc ->
        case tc.name do
          "delegate" -> {:spawn, SpawnChildAgent.new(grandchild_agent, "Grandchild task")}
          _ -> {:ok, "default"}
        end
      end

      child_result =
        Swarm.run_child(Swarm.Id.generate("loop"), 1, "tc_spawn", spawn_request, tool_executor)

      assert child_result.status == :completed
      assert child_result.result == "Child got grandchild result"
    end
  end

  describe "telemetry" do
    setup do
      test_pid = self()
      ref = make_ref()
      handler_id = "test-handler-#{inspect(ref)}"

      :telemetry.attach_many(
        handler_id,
        [
          [:swarm, :child, :spawn, :start],
          [:swarm, :child, :spawn, :stop],
          [:swarm, :child, :spawn, :exception]
        ],
        fn event, measurements, metadata, _config ->
          send(test_pid, {ref, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)
      %{telemetry_ref: ref}
    end

    test "emits start event with parent and tool_call linkage", %{telemetry_ref: ref} do
      child_agent = test_agent(mock_llm("Done"))
      spawn_request = SpawnChildAgent.new(child_agent, "Task")

      parent_loop_id = Swarm.Id.generate("loop")
      tool_call_id = "tc_spawn_456"

      _result =
        Swarm.run_child(parent_loop_id, 2, tool_call_id, spawn_request, fn _ -> {:ok, ""} end)

      assert_receive {^ref, [:swarm, :child, :spawn, :start], _measurements, metadata}
      assert metadata.parent_loop_id == parent_loop_id
      assert metadata.parent_step == 2
      assert metadata.tool_call_id == tool_call_id
      assert metadata.task == "Task"
    end

    test "emits stop event with child info", %{telemetry_ref: ref} do
      child_agent = test_agent(mock_llm("Child completed"))
      spawn_request = SpawnChildAgent.new(child_agent, "Task")

      parent_loop_id = Swarm.Id.generate("loop")

      _result =
        Swarm.run_child(parent_loop_id, 1, "tc_1", spawn_request, fn _ -> {:ok, ""} end)

      assert_receive {^ref, [:swarm, :child, :spawn, :stop], _measurements, metadata}
      assert metadata.parent_loop_id == parent_loop_id
      assert metadata.child_status == :completed
      assert is_integer(metadata.child_step_count)
      assert is_integer(metadata.duration_ms)
    end

    test "emits exception event with tool_call_id on crash", %{telemetry_ref: ref} do
      child_llm =
        multi_turn_llm([
          {:tool_calls, [%ToolCall{id: "tc_1", name: "crash", arguments: "{}"}], nil}
        ])

      child_agent = test_agent(child_llm)
      spawn_request = SpawnChildAgent.new(child_agent, "Crash test")

      parent_loop_id = Swarm.Id.generate("loop")
      tool_call_id = "tc_spawn_crash"

      assert_raise RuntimeError, "kaboom", fn ->
        Swarm.run_child(parent_loop_id, 1, tool_call_id, spawn_request, fn _tc ->
          raise "kaboom"
        end)
      end

      assert_receive {^ref, [:swarm, :child, :spawn, :exception], _measurements, metadata}
      assert metadata.parent_loop_id == parent_loop_id
      assert metadata.tool_call_id == tool_call_id
      assert metadata.kind == :error
    end
  end
end
