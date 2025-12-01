defmodule FrontmanServerWeb.SessionChannelTest do
  use FrontmanServerWeb.ChannelCase, async: true

  alias FrontmanServerWeb.UserSocket
  alias FrontmanServerWeb.{JsonRpc, MCPProtocol}
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction

  describe "join session:<id>" do
    test "succeeds when session exists" do
      session_id = "sess_test_#{:rand.uniform(1_000_000)}"
      {:ok, ^session_id} = Tasks.create_task(session_id, %{})

      {:ok, reply, socket} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("session:#{session_id}", %{})

      assert reply == %{session_id: session_id}
      assert socket.assigns.session_id == session_id
    end

    test "fails when session does not exist" do
      {:error, reply} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("session:nonexistent_session", %{})

      assert reply == %{reason: "session_not_found"}
    end
  end

  describe "session/prompt" do
    setup do
      session_id = "sess_test_#{:rand.uniform(1_000_000)}"
      {:ok, ^session_id} = Tasks.create_task(session_id, %{})

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("session:#{session_id}", %{})

      {:ok, socket: socket, session_id: session_id}
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
      session_id = "sess_tool_#{:rand.uniform(1_000_000)}"
      {:ok, ^session_id} = Tasks.create_task(session_id, %{})

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("session:#{session_id}", %{})

      # Complete MCP initialization handshake using existing helpers
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

      {:ok, socket: socket, session_id: session_id}
    end

    test "extracts text content from nested MCP tool result structure", %{
      socket: socket,
      session_id: session_id
    } do
      # Create a tool call interaction using the domain struct
      tool_call = %Interaction.ToolCall{
        id: Interaction.new_id(),
        agent_id: "test_agent",
        tool_call_id: "call_123",
        tool_name: "consoleLog",
        arguments: %{"message" => "hello"},
        timestamp: Interaction.now()
      }

      # Send the tool call interaction to the channel (simulating agent behavior)
      send(socket.channel_pid, {:interaction, tool_call})

      # Channel should push MCP request to browser
      assert_push "mcp:message", %{
        "method" => "tools/call",
        "id" => mcp_request_id,
        "params" => %{"name" => "consoleLog"}
      }

      # Browser sends back MCP response per MCP CallToolResult spec
      # Structure: {content: [...], isError?: bool}
      mcp_tool_result = %{
        "content" => [%{"type" => "text", "text" => "Logged: hello"}]
      }

      push(socket, "mcp:message", JsonRpc.success_response(mcp_request_id, mcp_tool_result))

      # Channel should send ACP completed notification with extracted text
      # ACP spec uses "contents" (plural) for tool_call_update
      assert_push "acp:message", %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^session_id,
          "update" => %{
            "sessionUpdate" => "tool_call_update",
            "toolCallId" => "call_123",
            "status" => "completed",
            "contents" => contents
          }
        }
      }

      # Extract the text from the ACP content structure
      [%{"content" => %{"text" => result_text}}] = contents

      # Verify tool result text is correctly extracted from MCP CallToolResult
      assert result_text == "Logged: hello"
    end
  end

  describe "MCP initialization" do
    test "sends MCP initialize request on join" do
      session_id = "sess_mcp_#{:rand.uniform(1_000_000)}"
      {:ok, ^session_id} = Tasks.create_task(session_id, %{})

      {:ok, _reply, _socket} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("session:#{session_id}", %{})

      # Agent should push MCP initialize request to browser
      assert_push "mcp:message", %{
        "jsonrpc" => "2.0",
        "id" => _id,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => "DRAFT-2025-v3",
          "clientInfo" => %{"name" => "frontman-server"}
        }
      }
    end

    test "handles MCP initialize response and sends initialized notification" do
      session_id = "sess_mcp_#{:rand.uniform(1_000_000)}"
      {:ok, ^session_id} = Tasks.create_task(session_id, %{})

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("session:#{session_id}", %{})

      # Get the initialize request to capture the id
      assert_push "mcp:message", %{"id" => request_id}

      # Browser sends response
      push(socket, "mcp:message", %{
        "jsonrpc" => "2.0",
        "id" => request_id,
        "result" => %{
          "protocolVersion" => "DRAFT-2025-v3",
          "capabilities" => %{"tools" => %{}},
          "serverInfo" => %{"name" => "browser-mcp", "version" => "1.0.0"}
        }
      })

      # Agent should send initialized notification
      assert_push "mcp:message", %{
        "jsonrpc" => "2.0",
        "method" => "notifications/initialized"
      }
    end
  end

  describe "MCP response validation" do
    setup do
      session_id = "sess_mcp_val_#{:rand.uniform(1_000_000)}"
      {:ok, ^session_id} = Tasks.create_task(session_id, %{})

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("session:#{session_id}", %{})

      # Complete MCP initialization
      assert_push "mcp:message", %{"id" => init_request_id}

      init_result = %{
        "protocolVersion" => MCPProtocol.protocol_version(),
        "capabilities" => %{"tools" => %{}},
        "serverInfo" => %{"name" => "test-mcp", "version" => "1.0.0"}
      }

      push(socket, "mcp:message", JsonRpc.success_response(init_request_id, init_result))
      assert_push "mcp:message", %{"method" => "notifications/initialized"}
      assert_push "mcp:message", %{"id" => tools_request_id}
      push(socket, "mcp:message", JsonRpc.success_response(tools_request_id, %{"tools" => []}))

      {:ok, socket: socket, session_id: session_id}
    end

    test "logs error and sends notification for invalid MCP response - missing jsonrpc field",
         %{socket: socket} do
      import ExUnit.CaptureLog

      log =
        capture_log(fn ->
          # Send malformed response
          push(socket, "mcp:message", %{"id" => 999, "result" => %{}})

          # Give channel time to process
          Process.sleep(10)
        end)

      assert log =~ "Invalid MCP response"
      assert log =~ "invalid_message"

      # Should receive error notification
      assert_push "mcp:message", %{
        "jsonrpc" => "2.0",
        "method" => "error",
        "params" => %{
          "message" => "Invalid JSON-RPC response",
          "reason" => "invalid_message"
        }
      }
    end

    test "logs error and sends notification for invalid MCP response - wrong jsonrpc version",
         %{socket: socket} do
      import ExUnit.CaptureLog

      log =
        capture_log(fn ->
          push(socket, "mcp:message", %{"jsonrpc" => "1.0", "id" => 999, "result" => %{}})
          Process.sleep(10)
        end)

      assert log =~ "Invalid MCP response"
      assert log =~ "invalid_version"

      assert_push "mcp:message", %{
        "method" => "error",
        "params" => %{"reason" => "invalid_version"}
      }
    end

    test "logs error and sends notification for invalid MCP response - missing id",
         %{socket: socket} do
      import ExUnit.CaptureLog

      log =
        capture_log(fn ->
          push(socket, "mcp:message", %{"jsonrpc" => "2.0", "result" => %{}})
          Process.sleep(10)
        end)

      assert log =~ "Invalid MCP response"

      assert_push "mcp:message", %{
        "method" => "error"
      }
    end

    test "logs error and sends notification for invalid MCP response - both result and error",
         %{socket: socket} do
      import ExUnit.CaptureLog

      log =
        capture_log(fn ->
          push(socket, "mcp:message", %{
            "jsonrpc" => "2.0",
            "id" => 999,
            "result" => %{},
            "error" => %{"code" => -32601, "message" => "Error"}
          })

          Process.sleep(10)
        end)

      assert log =~ "Invalid MCP response"

      assert_push "mcp:message", %{
        "method" => "error"
      }
    end

    test "still handles valid MCP responses correctly", %{socket: socket, session_id: session_id} do
      # Create a tool call to generate pending MCP call
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

      # Send valid MCP response - should work exactly as before
      mcp_result = %{"content" => [%{"type" => "text", "text" => "Success"}]}
      push(socket, "mcp:message", JsonRpc.success_response(mcp_request_id, mcp_result))

      # Should receive ACP completion notification
      assert_push "acp:message", %{
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^session_id,
          "update" => %{
            "status" => "completed"
          }
        }
      }
    end
  end
end
