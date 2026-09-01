defmodule FrontmanServer.Tasks.Execution.McpToolRoutingTest do
  @moduledoc false

  use FrontmanServer.ExecutionCase
  use FrontmanServerWeb.ChannelCase

  import FrontmanServer.InteractionCase.Helpers,
    only: [assert_receive_interaction: 3, swarm_tool_call: 2]

  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.Providers
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.ToolExecutor
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tools.MCP
  alias FrontmanServerWeb.UserSocket
  alias JsonRpc

  describe "ToolExecutor MCP tool routing" do
    setup %{scope: scope} do
      task_id = task_fixture(scope, framework: "nextjs").id

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("tasks", %{})

      push(socket, "mcp:ready", %{})
      assert_push("mcp:message", %{"method" => "server/discover"})

      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, task_topic(task_id))

      {:ok, socket: socket, task_id: task_id, scope: scope}
    end

    test "MCP tool calls are routed directly to the connection channel", %{
      task_id: task_id,
      scope: scope
    } do
      {:ok, _message} = user_message_fixture(scope, task_id, user_content("test turn"))
      turn_number = latest_turn_number(task_id)

      tool_call = swarm_tool_call("take_screenshot", ~s({"selector": "#main"}))

      ToolExecutor.start_mcp_tool(scope, task_id, turn_number, nil, tool_call)

      assert_push(
        "mcp:message",
        %{
          "method" => "tools/call",
          "params" => %{"name" => "take_screenshot"}
        },
        2_000
      )

      assert_receive_interaction(
        %Interaction.ToolCall{tool_name: "take_screenshot"},
        _turn_number,
        500
      )
    end

    test "full agent execution with MCP tool routing", %{
      socket: socket,
      task_id: task_id,
      scope: scope
    } do
      mcp_tool_call = swarm_tool_call("take_screenshot", ~s({"selector": "#content"}))

      mcp_tool_def = %MCP{
        name: "take_screenshot",
        description: "Take a screenshot",
        input_schema: %{},
        on_timeout: :pause_agent,
        timeout_ms: 60_000
      }

      expect_llm_responses([{:tool_calls, [mcp_tool_call], ""}, "Component implemented!"])

      :ok = Providers.upsert_api_key(scope, "openrouter", "test-key")

      execution_request =
        execution_request_fixture(
          mcp_tools: [mcp_tool_def],
          model: "openrouter:anthropic/claude-sonnet-4.6",
          project_traits: []
        )

      {:ok, _interaction, _turn_number} =
        submit_user_message_and_run(
          scope,
          task_id,
          execution_request,
          user_content("Implement the component")
        )

      assert_push(
        "mcp:message",
        %{
          "method" => "tools/call",
          "id" => mcp_request_id,
          "params" => %{"name" => "take_screenshot"}
        },
        5_000
      )

      mcp_response = %{
        "resultType" => "complete",
        "content" => [
          %{"type" => "text", "text" => ~s({"screenshot": "base64data"})}
        ]
      }

      push(socket, "mcp:message", JsonRpc.success_response(mcp_request_id, mcp_response))

      assert_receive_interaction(%Tasks.Interaction.AgentCompleted{}, _turn_number, 10_000)

      {:ok, task} = Tasks.get_task(scope, task_id)

      assert %Interaction.ToolResult{is_error: false} =
               Enum.find(Tasks.interactions(task), &match?(%Interaction.ToolResult{}, &1))
    end
  end

  defp submit_user_message_and_run(scope, task_id, execution_request, message) do
    case Tasks.submit_user_message(
           scope,
           Map.merge(execution_request, %{
             task_id: task_id,
             message_id: Ecto.UUID.generate(),
             message: message
           })
         ) do
      {:ok, interaction} ->
        case Tasks.execute_next_turn(scope, task_id, execution_request) do
          :ok ->
            {:ok, interaction, FrontmanServer.Test.Fixtures.Tasks.latest_turn_number(task_id)}

          result when result in [:already_running, :no_accepted_messages] ->
            {:error, result}

          result ->
            result
        end

      result ->
        result
    end
  end
end
