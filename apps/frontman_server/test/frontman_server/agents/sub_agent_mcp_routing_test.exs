defmodule FrontmanServer.Agents.SubAgentMcpRoutingTest do
  @moduledoc """
  Tests for MCP tool routing from sub-agents spawned by backend tools.

  These tests verify that when backend tools (like implement_component) spawn
  sub-agents that call MCP tools, the MCP requests are properly routed through
  the TaskChannel to the client.

  ## Architecture

  ToolExecutor owns interaction publishing for MCP tools internally:
  1. Registers in AgentRegistry (for receiving response)
  2. Publishes interaction via Tasks.add_tool_call (for TaskChannel routing)
  3. Waits for client response via receive

  This ensures MCP tools work correctly for both main agents and sub-agents
  without requiring callers to handle interaction publishing.
  """

  use FrontmanServer.SwarmCase, async: false
  use FrontmanServerWeb.ChannelCase

  alias FrontmanServer.Agents.ToolExecutor
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServerWeb.UserSocket
  alias JsonRpc
  alias Swarm.ToolCall

  describe "ToolExecutor MCP tool routing" do
    setup do
      task_id = "sess_subagent_mcp_#{:rand.uniform(1_000_000)}"
      {:ok, ^task_id} = Tasks.create_task(task_id)

      # Join TaskChannel to intercept MCP requests
      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("task:#{task_id}", %{})

      # Drain MCP initialization request
      assert_push "mcp:message", %{"method" => "initialize"}

      # Subscribe to PubSub to see what interactions are published
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.topic(task_id))

      {:ok, socket: socket, task_id: task_id}
    end

    test "MCP tool calls are automatically routed to channel", %{
      task_id: task_id
    } do
      # ToolExecutor now owns interaction publishing - MCP tools are automatically routed
      executor = ToolExecutor.make_executor(task_id)

      tool_call = %ToolCall{
        id: "call_#{:rand.uniform(1_000_000)}",
        name: "get_figma_node",
        arguments: ~s({"nodeId": "0:1234"})
      }

      executor_task =
        Task.async(fn ->
          executor.(tool_call)
        end)

      # MCP request SHOULD be pushed to channel automatically
      assert_push "mcp:message",
                  %{
                    "method" => "tools/call",
                    "params" => %{"name" => "get_figma_node"}
                  },
                  2_000

      # Verify interaction was published via PubSub
      assert_receive {:interaction, %Interaction.ToolCall{tool_name: "get_figma_node"}}, 500

      Task.shutdown(executor_task, :brutal_kill)
    end

    test "full agent execution with MCP tool routing", %{
      socket: socket,
      task_id: task_id
    } do
      # Integration test using full Swarm execution with a test LLM that returns an MCP tool call
      mcp_tool_call = %ToolCall{
        id: "call_figma_#{:rand.uniform(1_000_000)}",
        name: "get_figma_node",
        arguments: ~s({"nodeId": "0:1934", "includeImage": true})
      }

      llm = tool_then_complete_llm([mcp_tool_call], "Component implemented!")
      agent = test_agent(llm, "ComponentImplementAgent")

      # Simple executor - ToolExecutor handles MCP routing internally
      executor = ToolExecutor.make_executor(task_id)

      executor_task =
        Task.async(fn ->
          Swarm.run_blocking(agent, [Swarm.Message.user("Implement the component")], executor)
        end)

      # Verify MCP request is pushed to channel
      assert_push "mcp:message",
                  %{
                    "method" => "tools/call",
                    "id" => mcp_request_id,
                    "params" => %{"name" => "get_figma_node"}
                  },
                  5_000

      # Respond to the MCP request so agent can continue
      mcp_response = %{
        "content" => [
          %{"type" => "text", "text" => ~s({"node": {"id": "0:1934", "type": "FRAME"}})}
        ]
      }

      push(socket, "mcp:message", JsonRpc.success_response(mcp_request_id, mcp_response))

      # Agent should complete
      result = Task.await(executor_task, 10_000)
      assert {:ok, "Component implemented!"} = result
    end
  end
end
