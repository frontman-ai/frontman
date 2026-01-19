defmodule FrontmanServer.Agents.ExecutionTest do
  @moduledoc """
  Tests for agent execution flow.

  These tests exercise the full agent execution using test LLM implementations
  from SwarmCase, catching issues like duplicate tool call broadcasts.
  """

  use FrontmanServer.SwarmCase, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Tasks
  alias Swarm.ToolCall

  describe "MCP tool call broadcast" do
    setup do
      pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
      on_exit(fn -> Sandbox.stop_owner(pid) end)

      {:ok, user} =
        Accounts.register_user(%{
          email: "exec_test_#{System.unique_integer([:positive])}@test.local",
          name: "Test User",
          password: "testpassword123!"
        })

      scope = Scope.for_user(user)
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "test-framework")

      # Subscribe to task topic to receive interaction broadcasts
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.topic(task_id))

      {:ok, task_id: task_id, scope: scope}
    end

    test "broadcasts tool call interaction exactly once for MCP tools", %{
      task_id: task_id,
      scope: scope
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

      # Start agent via add_user_message with custom agent
      user_content = [%{"type" => "text", "text" => "Please call the MCP tool"}]
      {:ok, _} = Tasks.add_user_message(scope, task_id, user_content, [], agent: agent)

      # Collect all tool call interactions broadcast via PubSub
      # Wait for broadcasts (tool executor has 60s timeout, but we'll collect what we get)
      tool_call_broadcasts = collect_tool_call_broadcasts(mcp_tool_call.id, 2_000)

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
      pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
      on_exit(fn -> Sandbox.stop_owner(pid) end)

      {:ok, user} =
        Accounts.register_user(%{
          email: "timing_test_#{System.unique_integer([:positive])}@test.local",
          name: "Test User",
          password: "testpassword123!"
        })

      scope = Scope.for_user(user)
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "test-framework")

      # Subscribe to receive broadcasts
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.topic(task_id))

      {:ok, task_id: task_id, scope: scope}
    end

    test "agent is registered before interaction is broadcast", %{task_id: task_id, scope: scope} do
      # Verify registration happens BEFORE broadcast to prevent race condition.
      # ToolExecutor registers in AgentRegistry, then publishes interaction.
      # When we receive the interaction broadcast, the agent should be registered.
      tool_call_id = "call_#{System.unique_integer([:positive])}"

      mcp_tool_call = %ToolCall{id: tool_call_id, name: "mcp_tool", arguments: ~s({})}
      llm = tool_then_complete_llm([mcp_tool_call], "Done!")
      agent = test_agent(llm, "TestAgent")

      # Start agent via add_user_message with custom agent
      user_content = [%{"type" => "text", "text" => "Call tool"}]
      {:ok, _} = Tasks.add_user_message(scope, task_id, user_content, [], agent: agent)

      # Wait for the interaction broadcast
      assert_receive {:interaction, %Tasks.Interaction.ToolCall{tool_call_id: ^tool_call_id}},
                     5_000

      # At this point, agent should be registered for the tool call
      registered =
        case Registry.lookup(FrontmanServer.AgentRegistry, {:tool_call, tool_call_id}) do
          [{_pid, _}] -> true
          [] -> false
        end

      assert registered,
             "Agent not registered when tool call broadcast - race condition exists"
    end
  end
end
