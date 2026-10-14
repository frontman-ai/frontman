defmodule FrontmanServer.Tasks.CustomerFeedbackIntegrationTest do
  use FrontmanServer.DataCase, async: true
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks
  import FrontmanServer.Test.Fixtures.Tools, only: [mcp_tool: 1]

  alias FrontmanServer.CustomerFeedback
  alias FrontmanServer.CustomerFeedback.Feedback
  alias FrontmanServer.Protocols.MCP
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.InteractionSchema
  alias FrontmanServer.Tools.MCP, as: MCPTool

  @name "request_customer_feedback"

  for output <- [%{"outcome" => "answered", "score" => 0}, %{"outcome" => "skipped"}] do
    test "feedback tool persists #{output["outcome"]} and starts the cooldown" do
      scope = user_scope_fixture()
      task = task_fixture(scope)
      turn = start_turn_fixture(scope, task.id)
      call = %SwarmAi.ToolCall{id: "feedback", name: @name, arguments: "{}"}
      {:ok, _} = Tasks.request_client_tool(scope, task.id, turn, call, :interactive)
      tools = MCPTool.from_maps([mcp_tool(@name), mcp_tool("ordinary_tool")])
      assert Enum.map(CustomerFeedback.filter_tools(tools, scope), & &1.name) == ["ordinary_tool"]

      output = unquote(Macro.escape(output))

      assert {:ok, result, :no_executor} =
               Tasks.resolve_tool_request(
                 scope,
                 task.id,
                 call,
                 MCP.tool_result_text("Untrusted browser reply")
                 |> Map.put("structuredContent", output)
               )

      assert result.result["structuredContent"] == output
      assert MCP.extract_content_text(result.result) == Jason.encode!(output)
      assert Repo.one!(Feedback).score == output["score"]
    end
  end

  test "a feedback answer requires a persisted feedback tool request" do
    scope = user_scope_fixture()
    task = task_fixture(scope)
    turn = start_turn_fixture(scope, task.id)
    ordinary = %SwarmAi.ToolCall{id: "ordinary", name: "ordinary_tool", arguments: "{}"}
    {:ok, _} = Tasks.request_client_tool(scope, task.id, turn, ordinary, :interactive)
    row = Repo.one!(InteractionSchema.for_task(task.id) |> InteractionSchema.of_type(:tool_call))
    {:ok, _} = CustomerFeedback.record_request(scope, row)

    assert {:error, :not_found} =
             Tasks.resolve_tool_request(
               scope,
               task.id,
               %{ordinary | name: @name},
               MCP.tool_result_text("")
               |> Map.put("structuredContent", %{"outcome" => "answered", "score" => 8})
             )
  end
end
