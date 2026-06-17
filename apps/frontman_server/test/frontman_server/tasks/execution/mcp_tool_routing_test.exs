defmodule FrontmanServer.Tasks.Execution.McpToolRoutingTest do
  @moduledoc false

  use FrontmanServer.ExecutionCase
  use FrontmanServerWeb.ChannelCase

  import FrontmanServer.InteractionCase.Helpers
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

      # Join TaskChannel to intercept MCP requests
      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      # Drain MCP initialization request
      assert_push("mcp:message", %{"method" => "initialize"})

      # Subscribe to PubSub to see what interactions are published
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, task_topic(task_id))

      {:ok, socket: socket, task_id: task_id, scope: scope}
    end

    test "MCP tool calls are automatically routed to channel", %{
      task_id: task_id,
      scope: scope
    } do
      {:ok, _message} = user_message_fixture(scope, task_id, user_content("test turn"))
      turn_number = latest_turn_number(task_id)

      tool_call = swarm_tool_call("take_screenshot", ~s({"selector": "#main"}))

      ToolExecutor.start_mcp_tool(scope, task_id, turn_number, tool_call)

      assert_push(
        "mcp:message",
        %{
          "method" => "tools/call",
          "params" => %{"name" => "take_screenshot"}
        },
        2_000
      )

      assert_receive {:interaction, %Interaction.ToolCall{tool_name: "take_screenshot"},
                      _turn_number},
                     500
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

      {:ok, _api_key} = Providers.upsert_api_key(scope, "openrouter", "test-key")

      {:ok, _interaction, _turn_number} =
        Tasks.submit_user_message(
          scope,
          Map.merge(
            execution_request_fixture(
              mcp_tools: [mcp_tool_def],
              model: "openrouter:anthropic/claude-sonnet-4-20250514",
              project_traits: []
            ),
            %{
              task_id: task_id,
              message: user_content("Implement the component")
            }
          )
        )

      # Verify MCP request is pushed to channel
      assert_push(
        "mcp:message",
        %{
          "method" => "tools/call",
          "id" => mcp_request_id,
          "params" => %{"name" => "take_screenshot"}
        },
        5_000
      )

      # Respond to the MCP request so agent can continue
      mcp_response = %{
        "content" => [
          %{"type" => "text", "text" => ~s({"screenshot": "base64data"})}
        ]
      }

      push(socket, "mcp:message", JsonRpc.success_response(mcp_request_id, mcp_response))

      assert_receive {:interaction, %Tasks.Interaction.AgentCompleted{}, _turn_number},
                     10_000
    end
  end
end
