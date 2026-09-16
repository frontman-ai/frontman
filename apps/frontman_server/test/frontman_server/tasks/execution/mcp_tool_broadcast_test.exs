defmodule FrontmanServer.Tasks.Execution.MCPToolBroadcastTest do
  @moduledoc """
  Tests for agent execution flow.

  These tests exercise the full agent execution using test LLM implementations
  from SwarmCase, catching issues like duplicate tool call broadcasts.
  """

  use FrontmanServer.ExecutionCase

  import FrontmanServer.InteractionCase.Helpers,
    only: [assert_receive_interaction: 2, swarm_tool_call: 2]

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks
  import FrontmanServer.Test.Fixtures.Tools, only: [mcp_tool: 2]

  import FrontmanServer.DataCase, only: [setup_sandbox: 1]
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tools.MCP

  setup [:setup_sandbox, :setup_user, :setup_task]

  describe "MCP tool call broadcast" do
    test "registers before broadcasting one tool call and preserves its response metadata", %{
      task_id: task_id,
      scope: scope
    } do
      mcp_tool_call = swarm_tool_call("some_mcp_tool", ~s({"arg": "value"}))

      some_mcp_tool_def =
        MCP.from_map(
          mcp_tool("some_mcp_tool", %{
            "_meta" => %{"ai.frontman/tool-metadata" => %{"executionMode" => "Interactive"}}
          })
        )

      expect_llm_responses([{:tool_calls, [mcp_tool_call], "Done!"}])

      execution_request = execution_request_fixture(mcp_tools: [some_mcp_tool_def])

      {:ok, _, _} =
        submit_user_message_and_run(
          scope,
          task_id,
          execution_request,
          user_content("Please call the MCP tool")
        )

      expected_id = mcp_tool_call.id
      assert_receive_interaction(%Tasks.Interaction.ToolCall{tool_call_id: ^expected_id}, 1)

      assert [{_pid, _}] =
               Registry.lookup(FrontmanServer.ProcessRegistry, {:tool_call, task_id, expected_id})

      refute_receive {:interaction,
                      %{data: %Tasks.Interaction.ToolCall{tool_call_id: ^expected_id}}},
                     2_000

      {:ok, task} = Tasks.get_task_with_history(scope, task_id)

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
end
