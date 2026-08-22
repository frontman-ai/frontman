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
      mcp_tool_call = swarm_tool_call("some_mcp_tool", ~s({"arg": "value"}))

      some_mcp_tool_def = %MCP{
        name: "some_mcp_tool",
        description: "A test MCP tool",
        input_schema: %{},
        timeout_ms: 60_000,
        on_timeout: :pause_agent
      }

      expect_llm_responses([{:tool_calls, [mcp_tool_call], "Done!"}])

      execution_request = execution_request_fixture(mcp_tools: [some_mcp_tool_def])

      {:ok, _, _} =
        submit_user_message_and_run(
          scope,
          task_id,
          execution_request,
          user_content("Please call the MCP tool")
        )

      tool_call_broadcasts = collect_tool_call_broadcasts(mcp_tool_call.id, 2_000)

      assert length(tool_call_broadcasts) == 1,
             "Expected exactly 1 tool call broadcast, got #{length(tool_call_broadcasts)}. " <>
               "This indicates Tasks.request_client_tool is being called multiple times."

      {:ok, task} = Tasks.get_task(scope, task_id)

      assert %Tasks.Interaction.AgentResponse{metadata: %{"tool_calls" => [persisted_call]}} =
               Enum.find(
                 Tasks.interactions(task),
                 &match?(%Tasks.Interaction.AgentResponse{}, &1)
               )

      assert persisted_call["id"] == mcp_tool_call.id
      assert persisted_call["name"] == "some_mcp_tool"
      assert Jason.decode!(persisted_call["arguments"]) == %{"arg" => "value"}
      refute Map.has_key?(persisted_call, "function")

      assert :ok = Tasks.cancel_execution(scope, task_id)

      assert_receive_interaction(%Tasks.Interaction.AgentError{kind: "cancelled"}, _turn_number)
    end
  end

  defp collect_tool_call_broadcasts(expected_tool_call_id, timeout_ms) do
    collect_tool_call_broadcasts(expected_tool_call_id, timeout_ms, [])
  end

  defp submit_user_message_and_run(scope, task_id, execution_request, message) do
    case Tasks.submit_user_message(
           scope,
           %{
             task_id: task_id,
             message: %{
               id: Ecto.UUID.generate(),
               content: message,
               model: execution_request.model,
               agent_id: execution_request.agent_id
             }
           }
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
        collect_tool_call_broadcasts(expected_tool_call_id, timeout_ms, [tc | acc])

      {:interaction, _other} ->
        collect_tool_call_broadcasts(expected_tool_call_id, timeout_ms, acc)
    after
      timeout_ms ->
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

      assert_receive_interaction(
        %Tasks.Interaction.ToolCall{tool_call_id: ^expected_id},
        _turn_number
      )

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
