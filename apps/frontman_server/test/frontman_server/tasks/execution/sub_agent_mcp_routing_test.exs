defmodule FrontmanServer.Tasks.Execution.SubAgentMcpRoutingTest do
  @moduledoc """
  Tests for MCP tool routing from sub-agents spawned by backend tools.

  These tests verify that when backend tools spawn sub-agents that call MCP
  tools, the MCP requests are properly routed through the TaskChannel to the
  client.

  ## Architecture

  ToolExecutor owns interaction publishing for MCP tools internally:
  1. Registers in ToolCallRegistry (for receiving response)
  2. Publishes interaction via Tasks (for TaskChannel routing)
  3. Waits for client response via receive

  This ensures MCP tools work correctly for both main agents and sub-agents
  without requiring callers to handle interaction publishing.
  """

  use SwarmAi.Testing, async: false
  use FrontmanServerWeb.ChannelCase

  import FrontmanServer.InteractionCase.Helpers

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.ToolExecutor
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServerWeb.UserSocket
  alias JsonRpc

  describe "ToolExecutor MCP tool routing" do
    setup %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "test-framework")

      # Join TaskChannel to intercept MCP requests
      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      # Drain MCP initialization request
      assert_push("mcp:message", %{"method" => "initialize"})

      # Subscribe to PubSub to see what interactions are published
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.topic(task_id))

      {:ok, socket: socket, task_id: task_id, scope: scope}
    end

    test "MCP tool calls are automatically routed to channel", %{
      task_id: task_id,
      scope: scope
    } do
      # Build executor that calls Tasks directly for persistence
      llm_opts = [api_key: "test-key", model: "openrouter:anthropic/claude-sonnet-4-20250514"]
      executor = ToolExecutor.make_executor(scope, task_id, llm_opts: llm_opts)

      tool_call = swarm_tool_call("take_screenshot", ~s({"selector": "#main"}))

      executor_task =
        Task.async(fn ->
          executor.([tool_call])
        end)

      # MCP request SHOULD be pushed to channel automatically
      assert_push(
        "mcp:message",
        %{
          "method" => "tools/call",
          "params" => %{"name" => "take_screenshot"}
        },
        2_000
      )

      # Verify interaction was published via PubSub
      assert_receive {:interaction, %Interaction.ToolCall{tool_name: "take_screenshot"}}, 500

      Task.shutdown(executor_task, :brutal_kill)
    end

    test "full agent execution with MCP tool routing", %{
      socket: socket,
      task_id: task_id,
      scope: scope
    } do
      # Integration test using full Swarm execution with a test LLM that returns an MCP tool call
      mcp_tool_call = swarm_tool_call("take_screenshot", ~s({"selector": "#content"}))

      llm = tool_then_complete_llm([mcp_tool_call], "Component implemented!")
      agent = test_agent(llm, "ComponentImplementAgent")

      # Build executor that calls Tasks directly
      llm_opts = [api_key: "test-key", model: "openrouter:anthropic/claude-sonnet-4-20250514"]
      executor = ToolExecutor.make_executor(scope, task_id, llm_opts: llm_opts)

      executor_task =
        Task.async(fn ->
          SwarmAi.run_streaming(agent, [SwarmAi.Message.user("Implement the component")],
            tool_executor: executor
          )
        end)

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

      # Agent should complete
      result = Task.await(executor_task, 10_000)
      assert {:ok, "Component implemented!", _loop_id} = result
    end
  end
end
