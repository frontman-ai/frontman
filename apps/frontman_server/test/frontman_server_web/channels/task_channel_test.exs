defmodule FrontmanServerWeb.TaskChannelTest do
  use FrontmanServerWeb.ChannelCase, async: true

  alias FrontmanServerWeb.UserSocket
  alias FrontmanServerWeb.{JsonRpc, MCPProtocol}
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction

  describe "join task:<id>" do
    test "succeeds when task exists" do
      task_id = "sess_test_#{:rand.uniform(1_000_000)}"
      {:ok, ^task_id} = Tasks.create_task(task_id)

      {:ok, reply, socket} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("task:#{task_id}", %{})

      assert reply == %{task_id: task_id}
      assert socket.assigns.task_id == task_id
    end

    test "fails when task does not exist" do
      {:error, reply} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("task:nonexistent_task", %{})

      assert reply == %{reason: "task_not_found"}
    end
  end

  describe "session/prompt" do
    setup do
      task_id = "sess_test_#{:rand.uniform(1_000_000)}"
      {:ok, ^task_id} = Tasks.create_task(task_id)

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("task:#{task_id}", %{})

      {:ok, socket: socket, task_id: task_id}
    end

    test "returns error for unknown method", %{socket: socket} do
      ref =
        push(socket, "acp:message", %{
          "jsonrpc" => "2.0",
          "id" => 2,
          "method" => "unknown/method"
        })

      assert_reply ref, :ok, %{"acp:message" => response}
      assert response["error"]["code"] == -32601
      assert response["error"]["message"] =~ "Method not found"
    end
  end

  describe "MCP tool call result extraction" do
    setup do
      task_id = "sess_tool_#{:rand.uniform(1_000_000)}"
      {:ok, ^task_id} = Tasks.create_task(task_id)

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("task:#{task_id}", %{})

      complete_mcp_handshake(socket)

      {:ok, socket: socket, task_id: task_id}
    end

    test "extracts text content from MCP tool result", %{socket: socket, task_id: task_id} do
      tool_call = %Interaction.ToolCall{
        id: Interaction.new_id(),
        agent_id: "test_agent",
        tool_call_id: "call_123",
        tool_name: "consoleLog",
        arguments: %{"message" => "hello"},
        timestamp: Interaction.now()
      }

      send(socket.channel_pid, {:interaction, tool_call})

      assert_push "mcp:message", %{
        "method" => "tools/call",
        "id" => mcp_request_id,
        "params" => %{"name" => "consoleLog"}
      }

      mcp_tool_result = %{
        "content" => [%{"type" => "text", "text" => "Logged: hello"}]
      }

      push(socket, "mcp:message", JsonRpc.success_response(mcp_request_id, mcp_tool_result))

      assert_push "acp:message", %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "tool_call_update",
            "toolCallId" => "call_123",
            "status" => "completed",
            "content" => [%{"content" => %{"text" => "Logged: hello"}}]
          }
        }
      }
    end
  end

  describe "MCP initialization" do
    test "sends MCP initialize request on join" do
      task_id = "sess_mcp_#{:rand.uniform(1_000_000)}"
      {:ok, ^task_id} = Tasks.create_task(task_id)

      {:ok, _reply, _socket} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("task:#{task_id}", %{})

      expected_version = MCPProtocol.protocol_version()

      assert_push "mcp:message", %{
        "jsonrpc" => "2.0",
        "id" => _id,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => ^expected_version,
          "clientInfo" => %{"name" => "frontman-server"}
        }
      }
    end

    test "completes handshake and sends initialized notification" do
      task_id = "sess_mcp_#{:rand.uniform(1_000_000)}"
      {:ok, ^task_id} = Tasks.create_task(task_id)

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("task:#{task_id}", %{})

      assert_push "mcp:message", %{"id" => request_id}

      init_result = %{
        "protocolVersion" => MCPProtocol.protocol_version(),
        "capabilities" => %{"tools" => %{}},
        "serverInfo" => %{"name" => "browser-mcp", "version" => "1.0.0"}
      }

      push(socket, "mcp:message", JsonRpc.success_response(request_id, init_result))

      assert_push "mcp:message", %{
        "jsonrpc" => "2.0",
        "method" => "notifications/initialized"
      }
    end
  end

  describe "MCP response validation" do
    import ExUnit.CaptureLog

    setup do
      task_id = "sess_mcp_val_#{:rand.uniform(1_000_000)}"
      {:ok, ^task_id} = Tasks.create_task(task_id)

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("task:#{task_id}", %{})

      complete_mcp_handshake(socket)

      {:ok, socket: socket, task_id: task_id}
    end

    test "rejects response missing jsonrpc field", %{socket: socket} do
      log =
        capture_log(fn ->
          push(socket, "mcp:message", %{"id" => 999, "result" => %{}})

          assert_push "mcp:message", %{
            "jsonrpc" => "2.0",
            "method" => "error",
            "params" => %{
              "message" => "Invalid JSON-RPC response",
              "reason" => "invalid_message"
            }
          }
        end)

      assert log =~ "Invalid MCP response"
    end

    test "rejects response with wrong jsonrpc version", %{socket: socket} do
      log =
        capture_log(fn ->
          push(socket, "mcp:message", %{"jsonrpc" => "1.0", "id" => 999, "result" => %{}})

          assert_push "mcp:message", %{
            "method" => "error",
            "params" => %{"reason" => "invalid_version"}
          }
        end)

      assert log =~ "Invalid MCP response"
    end

    test "rejects response missing id", %{socket: socket} do
      log =
        capture_log(fn ->
          push(socket, "mcp:message", %{"jsonrpc" => "2.0", "result" => %{}})

          assert_push "mcp:message", %{"method" => "error"}
        end)

      assert log =~ "Invalid MCP response"
    end

    test "rejects response with both result and error", %{socket: socket} do
      log =
        capture_log(fn ->
          push(socket, "mcp:message", %{
            "jsonrpc" => "2.0",
            "id" => 999,
            "result" => %{},
            "error" => %{"code" => -32601, "message" => "Error"}
          })

          assert_push "mcp:message", %{"method" => "error"}
        end)

      assert log =~ "Invalid MCP response"
    end

    test "accepts valid MCP response", %{socket: socket, task_id: task_id} do
      tool_call = %Interaction.ToolCall{
        id: Interaction.new_id(),
        agent_id: "test_agent",
        tool_call_id: "call_valid_test",
        tool_name: "testTool",
        arguments: %{},
        timestamp: Interaction.now()
      }

      send(socket.channel_pid, {:interaction, tool_call})

      assert_push "mcp:message", %{"method" => "tools/call", "id" => mcp_request_id}

      mcp_result = %{"content" => [%{"type" => "text", "text" => "Success"}]}
      push(socket, "mcp:message", JsonRpc.success_response(mcp_request_id, mcp_result))

      assert_push "acp:message", %{
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{"status" => "completed"}
        }
      }
    end
  end

  # Completes the MCP handshake (initialize + tools/list)
  defp complete_mcp_handshake(socket) do
    assert_push "mcp:message", %{"id" => init_request_id, "method" => "initialize"}

    init_result = %{
      "protocolVersion" => MCPProtocol.protocol_version(),
      "capabilities" => %{"tools" => %{}},
      "serverInfo" => %{"name" => "test-mcp", "version" => "1.0.0"}
    }

    push(socket, "mcp:message", JsonRpc.success_response(init_request_id, init_result))

    assert_push "mcp:message", %{"method" => "notifications/initialized"}
    assert_push "mcp:message", %{"id" => tools_request_id, "method" => "tools/list"}

    push(socket, "mcp:message", JsonRpc.success_response(tools_request_id, %{"tools" => []}))
  end
end
