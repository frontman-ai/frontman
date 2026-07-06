defmodule FrontmanServer.Tasks.Execution.MCPToolBroadcastTest do
  @moduledoc """
  Tests for agent execution flow.

  These tests exercise the full agent execution using test LLM implementations
  from SwarmCase, catching issues like duplicate tool call broadcasts.
  """

  use FrontmanServer.ExecutionCase

  import FrontmanServer.InteractionCase.Helpers,
    only: [assert_receive_interaction: 2, swarm_tool_call: 1, swarm_tool_call: 2]

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tools.MCP

  describe "MCP tool call broadcast" do
    setup do
      pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
      on_exit(fn -> Sandbox.stop_owner(pid) end)

      scope = user_scope_fixture()
      task_id = task_with_pubsub_fixture(scope, framework: "nextjs").id

      {:ok, task_id: task_id, scope: scope}
    end

    test "broadcasts tool call interaction exactly once for MCP tools", %{
      task_id: task_id,
      scope: scope
    } do
      # Create a tool call that will be routed to MCP (not a backend tool)
      mcp_tool_call = swarm_tool_call("some_mcp_tool", ~s({"arg": "value"}))

      # Provide a tool def so ParallelExecutor can find and route the call
      some_mcp_tool_def = %MCP{
        name: "some_mcp_tool",
        description: "A test MCP tool",
        input_schema: %{},
        timeout_ms: 60_000,
        on_timeout: :pause_agent
      }

      # Create an LLM that returns a tool call on first turn, then completes
      expect_llm_responses([{:tool_calls, [mcp_tool_call], "Done!"}])

      execution_request = execution_request_fixture(mcp_tools: [some_mcp_tool_def])

      {:ok, _, _} =
        submit_user_message_and_run(
          scope,
          task_id,
          execution_request,
          user_content("Please call the MCP tool")
        )

      # Collect all tool call interactions broadcast via PubSub
      # Wait for broadcasts (tool executor has 60s timeout, but we'll collect what we get)
      tool_call_broadcasts = collect_tool_call_broadcasts(mcp_tool_call.id, 2_000)

      # THE KEY ASSERTION: tool call should be broadcast exactly ONCE
      # If this fails with count > 1, we have the duplicate bug
      assert length(tool_call_broadcasts) == 1,
             "Expected exactly 1 tool call broadcast, got #{length(tool_call_broadcasts)}. " <>
               "This indicates Tasks.request_client_tool is being called multiple times."

      {:ok, task} = Tasks.get_task(scope, task_id)

      assert %Tasks.Interaction.AgentResponse{metadata: %{"tool_calls" => [persisted_call]}} =
               Enum.find(task.interactions, &match?(%Tasks.Interaction.AgentResponse{}, &1))

      assert persisted_call["id"] == mcp_tool_call.id
      assert persisted_call["name"] == "some_mcp_tool"
      assert Jason.decode!(persisted_call["arguments"]) == %{"arg" => "value"}
      refute Map.has_key?(persisted_call, "function")

      assert :ok = Tasks.cancel_execution(scope, task_id)

      assert_receive_interaction(%Tasks.Interaction.AgentError{kind: "cancelled"}, _turn_number)
    end
  end

  # Collects all interaction-row broadcasts for a specific tool call ID
  defp collect_tool_call_broadcasts(expected_tool_call_id, timeout_ms) do
    collect_tool_call_broadcasts(expected_tool_call_id, timeout_ms, [])
  end

  defp submit_user_message_and_run(scope, task_id, execution_request, message) do
    case Tasks.submit_user_message(
           scope,
           Map.merge(execution_request, %{task_id: task_id, message: message})
         ) do
      {:ok, interaction} ->
        case Tasks.run_next_turn(scope, task_id, execution_request) do
          :ok ->
            {:ok, interaction, latest_turn_number(task_id)}

          result when result in [:already_running, :no_accepted_messages] ->
            {:error, result}

          result ->
            result
        end

      result ->
        result
    end
  end

  defp collect_tool_call_broadcasts(expected_tool_call_id, timeout_ms, acc) do
    receive do
      {:interaction,
       %{data: %Tasks.Interaction.ToolCall{tool_call_id: ^expected_tool_call_id} = tc}} ->
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

      scope = user_scope_fixture()
      task_id = task_with_pubsub_fixture(scope, framework: "nextjs").id

      {:ok, task_id: task_id, scope: scope}
    end

    test "agent is registered before interaction is broadcast", %{task_id: task_id, scope: scope} do
      # Verify registration happens BEFORE broadcast to prevent race condition.
      # ToolExecutor registers in ToolCallRegistry, then publishes interaction.
      # When we receive the interaction broadcast, the agent should be registered.
      mcp_tool_call = swarm_tool_call("mcp_tool")
      expected_id = mcp_tool_call.id

      mcp_tool_def = %MCP{
        name: "mcp_tool",
        description: "A test MCP tool",
        input_schema: %{},
        timeout_ms: 60_000,
        on_timeout: :pause_agent
      }

      expect_llm_responses([{:tool_calls, [mcp_tool_call], "Done!"}])

      execution_request = execution_request_fixture(mcp_tools: [mcp_tool_def])

      {:ok, _, _} =
        submit_user_message_and_run(scope, task_id, execution_request, user_content("Call tool"))

      # Wait for the interaction broadcast
      assert_receive_interaction(
        %Tasks.Interaction.ToolCall{tool_call_id: ^expected_id},
        _turn_number
      )

      # At this point, agent should be registered for the tool call
      registered =
        case Registry.lookup(FrontmanServer.ToolCallRegistry, {:tool_call, expected_id}) do
          [{_pid, _}] -> true
          [] -> false
        end

      assert registered,
             "Agent not registered when tool call broadcast - race condition exists"

      assert :ok = Tasks.cancel_execution(scope, task_id)

      assert_receive_interaction(%Tasks.Interaction.AgentError{kind: "cancelled"}, _turn_number)
    end
  end
end
