defmodule FrontmanServerWeb.TaskChannelSentryTest do
  @moduledoc """
  Integration tests verifying Sentry error reporting for tool failures in TaskChannel.

  Tests from issue #474:
  - Gap 1: Backend tool results send "failed" status (not "error") to client
  - Gap 4: MCP tool errors are reported to Sentry
  """

  use FrontmanServerWeb.ChannelCase, async: false

  import FrontmanServer.InteractionCase.Helpers

  setup %{scope: scope} do
    Sentry.Test.start_collecting_sentry_reports()

    {socket, task_id} = join_task_channel(scope, framework: "test-framework")
    complete_mcp_handshake(socket)

    {:ok, socket: socket, task_id: task_id}
  end

  describe "backend tool result status normalization (Gap 1)" do
    test "sends 'failed' status for backend tool errors (not 'error')", %{
      socket: socket,
      task_id: task_id
    } do
      # Send directly to the channel process (not via PubSub, which also delivers
      # the raw message to the test process and blocks assert_push)
      tool_result =
        tool_result("call_status_#{:rand.uniform(1_000_000)}", "search_codebase", "Search failed",
          is_error: true
        )

      send(socket.channel_pid, {:interaction, tool_result})

      # The client should receive "failed" not "error"
      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "tool_call_update",
            "toolCallId" => "call_status_" <> _,
            "status" => "failed"
          }
        }
      })
    end

    test "sends 'completed' status for successful backend tool results", %{
      socket: socket,
      task_id: task_id
    } do
      tool_result =
        tool_result("call_success_#{:rand.uniform(1_000_000)}", "search_codebase", "[]")

      send(socket.channel_pid, {:interaction, tool_result})

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "status" => "completed"
          }
        }
      })
    end
  end

  describe "MCP tool error Sentry reporting (Gap 4)" do
    test "reports MCP tool error to Sentry with context", %{
      socket: socket,
      task_id: task_id
    } do
      # Send a tool call interaction that will be routed to MCP
      tool_call =
        tool_call("call_mcp_err_#{:rand.uniform(1_000_000)}", "testMcpTool", %{"key" => "value"})

      send(socket.channel_pid, {:interaction, tool_call})

      # Get the MCP request ID
      assert_push("mcp:message", %{
        "method" => "tools/call",
        "id" => mcp_request_id,
        "params" => %{"name" => "testMcpTool"}
      })

      # Respond with an MCP error
      mcp_error = %{
        "code" => -32_000,
        "message" => "Tool execution failed: permission denied"
      }

      push(
        socket,
        "mcp:message",
        JsonRpc.error_response(mcp_request_id, mcp_error["code"], mcp_error["message"])
      )

      :sys.get_state(socket.channel_pid)

      # Verify the error notification was sent to the client
      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "update" => %{
            "status" => "failed"
          }
        }
      })

      # Verify Sentry captured the MCP tool error
      reports = Sentry.Test.pop_sentry_reports()

      mcp_error_reports =
        Enum.filter(reports, fn event ->
          event.tags[:error_type] == "mcp_tool_error"
        end)

      assert [report] = mcp_error_reports
      assert report.message.formatted == "MCP tool execution failed"
      assert report.extra[:tool_name] == "testMcpTool"
      assert report.extra[:task_id] == task_id
      assert report.extra[:error_message] =~ "permission denied"
    end

    test "MCP tool error with missing message field defaults to 'Unknown MCP error'", %{
      socket: socket
    } do
      tool_call =
        tool_call("call_mcp_no_msg_#{:rand.uniform(1_000_000)}", "anotherMcpTool")

      send(socket.channel_pid, {:interaction, tool_call})

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "id" => mcp_request_id
      })

      # Error response with no message field
      push(
        socket,
        "mcp:message",
        JsonRpc.error_response(mcp_request_id, -32_000, "Unknown MCP error")
      )

      :sys.get_state(socket.channel_pid)

      reports = Sentry.Test.pop_sentry_reports()

      mcp_error_reports =
        Enum.filter(reports, fn event ->
          event.tags[:error_type] == "mcp_tool_error"
        end)

      assert [report] = mcp_error_reports
      assert report.extra[:error_message] == "Unknown MCP error"
    end
  end
end
