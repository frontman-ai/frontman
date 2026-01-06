defmodule FrontmanServer.Agents.ExecutionTest do
  @moduledoc """
  Tests for agent execution flow.

  These tests exercise the full agent execution using test LLM implementations
  from SwarmCase, catching issues like duplicate tool call broadcasts.
  """

  use FrontmanServer.SwarmCase, async: false

  alias FrontmanServer.Agents
  alias FrontmanServer.Tasks
  alias Swarm.ToolCall

  describe "MCP tool call broadcast" do
    setup do
      task_id = "test_task_#{System.unique_integer([:positive])}"
      agent_id = "agent_#{System.unique_integer([:positive])}"
      {:ok, ^task_id} = Tasks.create_task(task_id)

      # Subscribe to task topic to receive interaction broadcasts
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.topic(task_id))

      {:ok, task_id: task_id, agent_id: agent_id}
    end

    test "broadcasts tool call interaction exactly once for MCP tools", %{
      task_id: task_id,
      agent_id: agent_id
    } do
      # Create a tool call that will be routed to MCP (not a backend tool)
      mcp_tool_call = %ToolCall{
        id: "call_mcp_test_#{System.unique_integer([:positive])}",
        name: "some_mcp_tool",
        arguments: ~s({"arg": "value"})
      }

      # Create an LLM that returns a tool call on first turn, then completes
      llm = tool_then_complete_llm([mcp_tool_call], "Done!")
      agent = test_agent(llm, "MCPToolTestAgent")

      # Build initial message
      messages = [Swarm.Message.user("Please call the MCP tool")]

      # ToolExecutor now handles interaction publishing internally.
      # on_event no longer receives :tool_call events.
      on_event = fn _event -> :ok end

      # Start execution in a task so we can collect broadcasts
      executor_task =
        Task.async(fn ->
          Agents.run_agent_sync(agent, task_id, agent_id, messages, on_event: on_event)
        end)

      # Collect all tool call interactions broadcast via PubSub
      # Wait for broadcasts (tool executor has 60s timeout, but we'll collect what we get)
      tool_call_broadcasts = collect_tool_call_broadcasts(mcp_tool_call.id, 2_000)

      # Clean up - the executor task will timeout on MCP, but we have our data
      Task.shutdown(executor_task, :brutal_kill)

      # THE KEY ASSERTION: tool call should be broadcast exactly ONCE
      # If this fails with count > 1, we have the duplicate bug
      assert length(tool_call_broadcasts) == 1,
             "Expected exactly 1 tool call broadcast, got #{length(tool_call_broadcasts)}. " <>
               "This indicates Tasks.add_tool_call is being called multiple times."
    end
  end

  # Collects all {:interaction, %ToolCall{}} broadcasts for a specific tool call ID
  defp collect_tool_call_broadcasts(expected_tool_call_id, timeout_ms) do
    collect_tool_call_broadcasts(expected_tool_call_id, timeout_ms, [])
  end

  defp collect_tool_call_broadcasts(expected_tool_call_id, timeout_ms, acc) do
    receive do
      {:interaction, %Tasks.Interaction.ToolCall{tool_call_id: ^expected_tool_call_id} = tc} ->
        # Found a matching tool call broadcast, keep collecting
        collect_tool_call_broadcasts(expected_tool_call_id, timeout_ms, [tc | acc])

      {:interaction, _other} ->
        # Different interaction, ignore and keep collecting
        collect_tool_call_broadcasts(expected_tool_call_id, timeout_ms, acc)
    after
      timeout_ms ->
        # Timeout reached, return what we collected
        Enum.reverse(acc)
    end
  end

  describe "MCP tool registration timing" do
    setup do
      task_id = "test_race_#{System.unique_integer([:positive])}"
      {:ok, ^task_id} = Tasks.create_task(task_id)

      # Subscribe to receive broadcasts
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.topic(task_id))

      {:ok, task_id: task_id}
    end

    test "agent is registered before interaction is broadcast", %{task_id: task_id} do
      # Verify registration happens BEFORE broadcast to prevent race condition.
      # ToolExecutor registers in AgentRegistry, then publishes interaction.
      # When we receive the interaction broadcast, the agent should be registered.
      agent_id = "agent_#{System.unique_integer([:positive])}"
      tool_call_id = "call_#{System.unique_integer([:positive])}"

      mcp_tool_call = %ToolCall{id: tool_call_id, name: "mcp_tool", arguments: ~s({})}
      llm = tool_then_complete_llm([mcp_tool_call], "Done!")
      agent = test_agent(llm, "TestAgent")
      messages = [Swarm.Message.user("Call tool")]

      task =
        Task.async(fn ->
          Agents.run_agent_sync(agent, task_id, agent_id, messages, on_event: fn _ -> :ok end)
        end)

      # Wait for the interaction broadcast
      assert_receive {:interaction, %Tasks.Interaction.ToolCall{tool_call_id: ^tool_call_id}},
                     5_000

      # At this point, agent should be registered
      registered =
        case Registry.lookup(FrontmanServer.AgentRegistry, {:tool_call, tool_call_id}) do
          [{_pid, _}] -> true
          [] -> false
        end

      Task.shutdown(task, :brutal_kill)

      assert registered,
             "Agent not registered when tool call broadcast - race condition exists"
    end
  end
end
