defmodule FrontmanServer.Tasks.Execution.SubAgentMcpRoutingTest do
  @moduledoc """
  Tests for MCP tool routing from sub-agents spawned by backend tools.

  These tests verify that when backend tools spawn sub-agents that call MCP
  tools, the MCP requests are properly routed through the TaskChannel to the
  client.

  ## Architecture

  `start_mcp_tool/3` is called by PE in its own process to:
  1. Register PE's pid in ToolCallRegistry (so {:tool_result, ...} routes back to PE)
  2. Publish the ToolCall interaction (for TaskChannel routing to the client)

  This ensures MCP tools work correctly for both main agents and sub-agents.
  """

  use FrontmanServer.ExecutionCase
  use FrontmanServerWeb.ChannelCase

  import FrontmanServer.InteractionCase.Helpers
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.RootAgent
  alias FrontmanServer.Tasks.Execution.ToolExecutor
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServerWeb.UserSocket
  alias JsonRpc

  describe "ToolExecutor MCP tool routing" do
    setup %{scope: scope} do
      task_id = task_fixture(scope, framework: "nextjs")

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
      tool_call = swarm_tool_call("take_screenshot", ~s({"selector": "#main"}))

      # start_mcp_tool registers self() in the registry and publishes the interaction.
      # Here, the test process acts as PE.
      ToolExecutor.start_mcp_tool(scope, task_id, tool_call)

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
    end

    test "full agent execution with MCP tool routing", %{
      socket: socket,
      task_id: task_id,
      scope: scope
    } do
      # Integration test using full Swarm execution with a provider response that returns an MCP tool call
      mcp_tool_call = swarm_tool_call("take_screenshot", ~s({"selector": "#content"}))

      mcp_tool_def = %FrontmanServer.Tools.MCP{
        name: "take_screenshot",
        description: "Take a screenshot",
        input_schema: %{},
        on_timeout: :pause_agent,
        timeout_ms: 60_000
      }

      expect_llm_responses([{:tool_calls, [mcp_tool_call], ""}, "Component implemented!"])

      llm_opts = [api_key: "test-key", model: "openrouter:anthropic/claude-sonnet-4-20250514"]

      raw_executor =
        ToolExecutor.make_executor(scope, task_id,
          backend_tool_modules: [],
          mcp_tools: [],
          mcp_tool_defs: [mcp_tool_def],
          llm_opts: llm_opts
        )

      # Wrap executor with PE so run_streaming receives plain ToolResults.
      {:ok, task_sup} = Task.Supervisor.start_link()

      executor = fn tool_calls ->
        executions = raw_executor.(tool_calls)

        case SwarmAi.ParallelExecutor.run(executions, task_sup) do
          {:ok, results} -> results
          {:halt, _} = halt -> halt
        end
      end

      executor_task =
        Task.async(fn ->
          agent = RootAgent.new(llm_opts: llm_opts)

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
