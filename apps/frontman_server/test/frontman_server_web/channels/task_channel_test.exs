defmodule FrontmanServerWeb.TaskChannelTest do
  use FrontmanServerWeb.ChannelCase, async: true

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServerWeb.UserSocket

  describe "join task:<id>" do
    test "succeeds when task exists", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "test-framework")

      {:ok, reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      assert reply == %{task_id: task_id}
      assert socket.assigns.task_id == task_id
    end

    test "fails when task does not exist", %{scope: scope} do
      nonexistent_task_id = Ecto.UUID.generate()

      {:error, reply} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{nonexistent_task_id}", %{})

      assert reply == %{reason: "task_not_found"}
    end
  end

  describe "session/prompt" do
    setup %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "test-framework")

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
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

      assert_reply(ref, :ok, %{"acp:message" => response})
      assert response["error"]["code"] == -32_601
      assert response["error"]["message"] =~ "Method not found"
    end
  end

  describe "PubSub subscription" do
    @moduledoc """
    Tests that verify the channel is properly subscribed to PubSub.

    This is critical because tool calls are broadcast via PubSub from the agent,
    and the channel must receive them to route to MCP. Previous tests used
    send(socket.channel_pid, ...) which bypassed PubSub entirely.
    """

    setup %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "test-framework")

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      complete_mcp_handshake(socket)

      {:ok, socket: socket, task_id: task_id}
    end

    test "channel receives tool call interactions via PubSub broadcast", %{
      socket: _socket,
      task_id: task_id
    } do
      # This test verifies the REAL path: PubSub.broadcast -> channel receives
      # Unlike other tests that use send(socket.channel_pid, ...) directly

      tool_call = %Interaction.ToolCall{
        id: Interaction.new_id(),
        sequence: Interaction.new_sequence(),
        tool_call_id: "call_pubsub_#{:rand.uniform(1_000_000)}",
        tool_name: "testTool",
        arguments: %{"key" => "value"},
        timestamp: Interaction.now()
      }

      # Broadcast via PubSub - this is what Tasks.add_tool_call does in production
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:interaction, tool_call}
      )

      # If the channel is subscribed to PubSub, it should route this to MCP
      assert_push("mcp:message", %{
        "method" => "tools/call",
        "params" => %{"name" => "testTool"}
      })
    end

    test "channel does NOT receive broadcasts to different topics", %{
      socket: _socket,
      task_id: task_id
    } do
      # Verify that the channel only receives broadcasts to its specific topic
      # This proves the subscription is topic-specific, not global
      different_topic = "task:different_#{:rand.uniform(1_000_000)}"

      tool_call = %Interaction.ToolCall{
        id: Interaction.new_id(),
        sequence: Interaction.new_sequence(),
        tool_call_id: "call_different_#{:rand.uniform(1_000_000)}",
        tool_name: "otherTool",
        arguments: %{},
        timestamp: Interaction.now()
      }

      # Broadcast to a DIFFERENT topic
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        different_topic,
        {:interaction, tool_call}
      )

      # Channel should NOT receive this since it's subscribed to task_id's topic
      refute_push("mcp:message", %{"params" => %{"name" => "otherTool"}})

      # But it SHOULD still receive broadcasts to its own topic
      tool_call2 = %{
        tool_call
        | tool_call_id: "call_own_#{:rand.uniform(1_000_000)}",
          tool_name: "ownTool"
      }

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:interaction, tool_call2}
      )

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "params" => %{"name" => "ownTool"}
      })
    end

    test "channel receives agent stream tokens via PubSub broadcast", %{
      socket: _socket,
      task_id: task_id
    } do
      # Broadcast a stream token via PubSub
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:stream_token, "Hello world"}
      )

      # Channel should forward this as an ACP notification
      # Note: content is wrapped in a map with type: "text"
      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "update" => %{
            "sessionUpdate" => "agent_message_chunk",
            "content" => %{"type" => "text", "text" => "Hello world"}
          }
        }
      })
    end

    test "channel handles stream_thinking without crashing", %{
      socket: socket,
      task_id: task_id
    } do
      # Broadcast a thinking token via PubSub
      # This should be handled gracefully (no-op handler) rather than crashing
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:stream_thinking, "reasoning about the task..."}
      )

      # Channel should NOT forward thinking tokens to client (client infers thinking state)
      refute_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "agent_thinking_chunk"}}
      })

      # But the channel should still be alive and functional
      # Verify by sending a stream_token which SHOULD work
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:stream_token, "after thinking"}
      )

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "update" => %{
            "sessionUpdate" => "agent_message_chunk",
            "content" => %{"type" => "text", "text" => "after thinking"}
          }
        }
      })

      # Verify channel process is still alive
      assert Process.alive?(socket.channel_pid)
    end
  end

  describe "agent_error handling" do
    setup %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "test-framework")

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      complete_mcp_handshake(socket)

      {:ok, socket: socket, task_id: task_id}
    end

    test "broadcasts error as session/update notification", %{
      socket: _socket,
      task_id: task_id
    } do
      # Simulate agent error via PubSub
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:agent_error, "Rate limit exceeded"}
      )

      # Assert session/update notification was pushed with error
      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "error",
            "message" => "Rate limit exceeded"
          }
        }
      })
    end

    test "sends JSON-RPC error response when prompt is pending", %{
      socket: socket,
      task_id: task_id
    } do
      # First, send a prompt to set pending_prompt_id
      prompt_request = %{
        "jsonrpc" => "2.0",
        "id" => 42,
        "method" => "session/prompt",
        "params" => %{
          "prompt" => %{
            "messages" => [
              %{
                "role" => "user",
                "content" => %{"type" => "text", "text" => "Hello"}
              }
            ]
          }
        }
      }

      push(socket, "acp:message", prompt_request)
      # Wait for the prompt to be processed
      :sys.get_state(socket.channel_pid)

      # Simulate agent error
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:agent_error, "No API key available"}
      )

      # Assert session/update notification is pushed
      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "update" => %{
            "sessionUpdate" => "error",
            "message" => "No API key available"
          }
        }
      })

      # Assert JSON-RPC error response is also pushed
      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 42,
        "error" => %{
          "code" => -32_000,
          "message" => "No API key available"
        }
      })
    end

    test "handles error when no pending prompt (only sends session/update)", %{
      socket: _socket,
      task_id: task_id
    } do
      # No pending prompt - just broadcast error directly
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:agent_error, "Connection failed"}
      )

      # Should get session/update notification
      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "update" => %{
            "sessionUpdate" => "error",
            "message" => "Connection failed"
          }
        }
      })

      # Should NOT get a JSON-RPC error response (no pending prompt id)
      refute_push("acp:message", %{"error" => %{"code" => -32_000}})
    end

    test "handles different error messages correctly", %{
      socket: _socket,
      task_id: task_id
    } do
      error_messages = [
        "Free requests exhausted. Add your API key in Settings to continue.",
        "No API key available for this request.",
        "Request failed: connection timeout"
      ]

      for message <- error_messages do
        Phoenix.PubSub.broadcast(
          FrontmanServer.PubSub,
          Tasks.topic(task_id),
          {:agent_error, message}
        )

        assert_push("acp:message", %{
          "method" => "session/update",
          "params" => %{
            "update" => %{
              "sessionUpdate" => "error",
              "message" => ^message
            }
          }
        })
      end
    end
  end

  describe "MCP tool call result extraction" do
    setup %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "test-framework")

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      complete_mcp_handshake(socket)

      {:ok, socket: socket, task_id: task_id}
    end

    test "extracts text content from MCP tool result", %{socket: socket, task_id: task_id} do
      tool_call = %Interaction.ToolCall{
        id: Interaction.new_id(),
        sequence: Interaction.new_sequence(),
        tool_call_id: "call_123",
        tool_name: "consoleLog",
        arguments: %{"message" => "hello"},
        timestamp: Interaction.now()
      }

      send(socket.channel_pid, {:interaction, tool_call})

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "id" => mcp_request_id,
        "params" => %{"name" => "consoleLog"}
      })

      mcp_tool_result = %{
        "content" => [%{"type" => "text", "text" => "Logged: hello"}]
      }

      push(socket, "mcp:message", JsonRpc.success_response(mcp_request_id, mcp_tool_result))
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
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
      })
    end
  end

  describe "MCP initialization" do
    test "sends MCP initialize request on join", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "test-framework")

      {:ok, _reply, _socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      expected_version = ModelContextProtocol.protocol_version()

      assert_push("mcp:message", %{
        "jsonrpc" => "2.0",
        "id" => _id,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => ^expected_version,
          "clientInfo" => %{"name" => "frontman-server"}
        }
      })
    end

    test "completes handshake and sends initialized notification", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "test-framework")

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      assert_push("mcp:message", %{"id" => request_id})

      init_result = %{
        "protocolVersion" => ModelContextProtocol.protocol_version(),
        "capabilities" => %{"tools" => %{}},
        "serverInfo" => %{"name" => "browser-mcp", "version" => "1.0.0"}
      }

      push(socket, "mcp:message", JsonRpc.success_response(request_id, init_result))
      :sys.get_state(socket.channel_pid)

      assert_push("mcp:message", %{
        "jsonrpc" => "2.0",
        "method" => "notifications/initialized"
      })
    end
  end

  describe "MCP response validation" do
    import ExUnit.CaptureLog

    setup %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "test-framework")

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      complete_mcp_handshake(socket)

      {:ok, socket: socket, task_id: task_id}
    end

    test "rejects response missing jsonrpc field", %{socket: socket} do
      log =
        capture_log(fn ->
          push(socket, "mcp:message", %{"id" => 999, "result" => %{}})
          :sys.get_state(socket.channel_pid)

          assert_push("mcp:message", %{
            "jsonrpc" => "2.0",
            "method" => "error",
            "params" => %{
              "message" => "Invalid JSON-RPC response",
              "reason" => "invalid_message"
            }
          })
        end)

      assert log =~ "Invalid MCP response"
    end

    test "rejects response with wrong jsonrpc version", %{socket: socket} do
      log =
        capture_log(fn ->
          push(socket, "mcp:message", %{"jsonrpc" => "1.0", "id" => 999, "result" => %{}})
          :sys.get_state(socket.channel_pid)

          assert_push("mcp:message", %{
            "method" => "error",
            "params" => %{"reason" => "invalid_version"}
          })
        end)

      assert log =~ "Invalid MCP response"
    end

    test "rejects response missing id", %{socket: socket} do
      log =
        capture_log(fn ->
          push(socket, "mcp:message", %{"jsonrpc" => "2.0", "result" => %{}})
          :sys.get_state(socket.channel_pid)

          assert_push("mcp:message", %{"method" => "error"})
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
            "error" => %{"code" => -32_601, "message" => "Error"}
          })

          :sys.get_state(socket.channel_pid)

          assert_push("mcp:message", %{"method" => "error"})
        end)

      assert log =~ "Invalid MCP response"
    end

    test "accepts valid MCP response", %{socket: socket, task_id: task_id} do
      tool_call = %Interaction.ToolCall{
        id: Interaction.new_id(),
        sequence: Interaction.new_sequence(),
        tool_call_id: "call_valid_test",
        tool_name: "testTool",
        arguments: %{},
        timestamp: Interaction.now()
      }

      send(socket.channel_pid, {:interaction, tool_call})

      assert_push("mcp:message", %{"method" => "tools/call", "id" => mcp_request_id})

      mcp_result = %{"content" => [%{"type" => "text", "text" => "Success"}]}
      push(socket, "mcp:message", JsonRpc.success_response(mcp_request_id, mcp_result))
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{"status" => "completed"}
        }
      })
    end
  end

  describe "MCP tool result flows to waiting executor" do
    @moduletag timeout: 30_000

    setup %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "test-framework")

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      complete_mcp_handshake_with_tools(socket)

      {:ok, socket: socket, task_id: task_id, scope: scope}
    end

    test "delivers tool response to executor regardless of initialization state", %{scope: scope} do
      # Tool responses should always be delivered to waiting executors.
      # This ensures agents can function even if tool calls happen early in the session.

      fresh_task_id = Ecto.UUID.generate()
      {:ok, ^fresh_task_id} = Tasks.create_task(scope, fresh_task_id, "test-framework")

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{fresh_task_id}", %{})

      # Drain the initialize request without responding - initialization is incomplete
      assert_push("mcp:message", %{"id" => _init_request_id, "method" => "initialize"})

      tool_call_id = "call_delivery_#{:rand.uniform(1_000_000)}"
      test_pid = self()

      # Executor registers and waits for tool result
      Registry.register(FrontmanServer.AgentRegistry, {:tool_call, tool_call_id}, %{
        caller_pid: test_pid
      })

      tool_call = %Interaction.ToolCall{
        id: Interaction.new_id(),
        sequence: Interaction.new_sequence(),
        tool_call_id: tool_call_id,
        tool_name: "list_dir",
        arguments: %{"path" => "/"},
        timestamp: Interaction.now()
      }

      send(socket.channel_pid, {:interaction, tool_call})

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "id" => mcp_request_id,
        "params" => %{"name" => "list_dir"}
      })

      tool_result = %{
        "content" => [%{"type" => "text", "text" => "file1.txt\nfile2.txt"}]
      }

      push(socket, "mcp:message", JsonRpc.success_response(mcp_request_id, tool_result))

      # Executor should receive the result
      assert_receive {:tool_result, ^tool_call_id, content, false}, 5_000

      assert is_binary(content)
      assert content =~ "file1.txt"

      Registry.unregister(FrontmanServer.AgentRegistry, {:tool_call, tool_call_id})
    end

    test "encodes JSON tool result to string for waiting executor", %{socket: socket} do
      # This test exercises the full flow where:
      # 1. An executor is waiting for a tool result (registered in AgentRegistry)
      # 2. MCP tool returns JSON that gets parsed to a map
      # 3. The result should be encoded to string before sending to executor
      #
      # Without the fix, the executor receives a map which later causes
      # FunctionClauseError in Swarm.Message.ContentPart.text/1

      tool_call_id = "call_json_result_#{:rand.uniform(1_000_000)}"
      test_pid = self()

      # Simulate what ToolExecutor.execute_mcp_tool does - register and wait
      Registry.register(FrontmanServer.AgentRegistry, {:tool_call, tool_call_id}, %{
        caller_pid: test_pid
      })

      # Simulate a tool call interaction being broadcast
      tool_call = %Interaction.ToolCall{
        id: Interaction.new_id(),
        sequence: Interaction.new_sequence(),
        tool_call_id: tool_call_id,
        tool_name: "get_logs",
        arguments: %{"tail" => 10},
        timestamp: Interaction.now()
      }

      send(socket.channel_pid, {:interaction, tool_call})

      # Wait for the tool call to be routed to MCP
      assert_push("mcp:message", %{
        "method" => "tools/call",
        "id" => mcp_request_id,
        "params" => %{"name" => "get_logs"}
      })

      # Respond with a JSON result that parse_tool_result will convert to a map
      json_result = %{
        "content" => [
          %{
            "type" => "text",
            "text" =>
              Jason.encode!(%{
                "logs" => [
                  %{
                    "timestamp" => "2026-01-05T10:42:21.102Z",
                    "level" => "console",
                    "message" => "GET / 200 261.81ms"
                  }
                ],
                "totalMatched" => 1,
                "bufferSize" => 1,
                "hasMore" => false
              })
          }
        ]
      }

      push(socket, "mcp:message", JsonRpc.success_response(mcp_request_id, json_result))

      # The waiting executor should receive a message with the result
      # The result should be a STRING (encoded JSON), not a map
      assert_receive {:tool_result, ^tool_call_id, content, false}, 5_000

      # This is the key assertion - content must be a string for Swarm.Message.ContentPart.text/1
      assert is_binary(content),
             "Tool result should be encoded to string, got: #{inspect(content)}"

      # Verify it's valid JSON that can be decoded back
      assert {:ok, decoded} = Jason.decode(content)
      assert is_map(decoded)
      assert Map.has_key?(decoded, "logs")

      # Cleanup
      Registry.unregister(FrontmanServer.AgentRegistry, {:tool_call, tool_call_id})
    end
  end

  describe "MCP tools race condition" do
    test "queued prompt is processed with MCP tools after initialization completes", %{
      scope: scope
    } do
      # Verifies the prompt queuing mechanism:
      # 1. Prompt sent before MCP init is queued in socket assigns
      # 2. MCP init completes, storing tools in socket assigns
      # 3. Queued prompt is processed with the loaded MCP tools

      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "test-framework")

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      # MCP init has started - we receive the initialize request
      assert_push("mcp:message", %{"id" => init_request_id, "method" => "initialize"})

      # Send prompt BEFORE completing MCP handshake
      prompt_request = %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "session/prompt",
        "params" => %{
          "prompt" => %{
            "messages" => [
              %{
                "role" => "user",
                "content" => %{"type" => "text", "text" => "Implement the header"}
              }
            ]
          }
        }
      }

      push(socket, "acp:message", prompt_request)
      :sys.get_state(socket.channel_pid)

      # NOW complete MCP init with tools
      init_result = %{
        "protocolVersion" => ModelContextProtocol.protocol_version(),
        "capabilities" => %{"tools" => %{}},
        "serverInfo" => %{"name" => "test-mcp", "version" => "1.0.0"}
      }

      push(socket, "mcp:message", JsonRpc.success_response(init_request_id, init_result))
      :sys.get_state(socket.channel_pid)

      assert_push("mcp:message", %{"method" => "notifications/initialized"})
      assert_push("mcp:message", %{"id" => tools_request_id, "method" => "tools/list"})

      tools_result = %{
        "tools" => [
          %{
            "name" => "take_screenshot",
            "description" => "Takes a screenshot of the page",
            "inputSchema" => %{"type" => "object", "properties" => %{}}
          }
        ]
      }

      push(socket, "mcp:message", JsonRpc.success_response(tools_request_id, tools_result))
      :sys.get_state(socket.channel_pid)

      # Handle load_agent_instructions
      assert_push("mcp:message", %{
        "id" => project_rules_request_id,
        "method" => "tools/call",
        "params" => %{"name" => "load_agent_instructions"}
      })

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(project_rules_request_id, %{"content" => []})
      )

      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{"method" => "project_rules_initialized"})

      # Verify MCP tools are now stored in socket assigns
      channel_socket = :sys.get_state(socket.channel_pid)
      assert length(channel_socket.assigns.mcp_tools) == 1
      assert hd(channel_socket.assigns.mcp_tools).name == "take_screenshot"

      # After MCP init completes, the queued prompt is processed (task_channel.ex:471-479)
      # This creates a UserMessage interaction broadcast via PubSub
      assert_receive {:interaction, %Tasks.Interaction.UserMessage{}}
    end
  end

  # Completes the MCP handshake with tools registered
  defp complete_mcp_handshake_with_tools(socket) do
    :sys.get_state(socket.channel_pid)
    assert_push("mcp:message", %{"id" => init_request_id, "method" => "initialize"})

    init_result = %{
      "protocolVersion" => ModelContextProtocol.protocol_version(),
      "capabilities" => %{"tools" => %{}},
      "serverInfo" => %{"name" => "test-mcp", "version" => "1.0.0"}
    }

    push(socket, "mcp:message", JsonRpc.success_response(init_request_id, init_result))
    :sys.get_state(socket.channel_pid)

    assert_push("mcp:message", %{"method" => "notifications/initialized"})
    assert_push("mcp:message", %{"id" => tools_request_id, "method" => "tools/list"})

    # Register an MCP tool that returns JSON
    tools_result = %{
      "tools" => [
        %{
          "name" => "get_logs",
          "description" => "Retrieves server logs",
          "inputSchema" => %{
            "type" => "object",
            "properties" => %{"tail" => %{"type" => "integer"}}
          },
          "visibleToAgent" => true
        }
      ]
    }

    push(socket, "mcp:message", JsonRpc.success_response(tools_request_id, tools_result))
    :sys.get_state(socket.channel_pid)

    assert_push("mcp:message", %{
      "id" => project_rules_request_id,
      "method" => "tools/call",
      "params" => %{"name" => "load_agent_instructions"}
    })

    push(
      socket,
      "mcp:message",
      JsonRpc.success_response(project_rules_request_id, %{"content" => []})
    )

    :sys.get_state(socket.channel_pid)

    assert_push("acp:message", %{"method" => "project_rules_initialized"})
  end

  describe "session/cancel" do
    setup %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "test-framework")

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      complete_mcp_handshake(socket)

      {:ok, socket: socket, task_id: task_id}
    end

    test "cancel notification is accepted (no response expected per ACP spec)", %{
      socket: socket
    } do
      # ACP spec: session/cancel is a notification, not a request.
      # No JSON-RPC response should be sent back.
      cancel_notification = %{
        "jsonrpc" => "2.0",
        "method" => "session/cancel",
        "params" => %{"sessionId" => "irrelevant"}
      }

      push(socket, "acp:message", cancel_notification)

      # Allow time for processing
      :sys.get_state(socket.channel_pid)

      # No response should be pushed (notifications don't get responses)
      refute_push("acp:message", %{"id" => _})
    end

    test "cancel resolves pending prompt with stopReason 'cancelled'", %{
      socket: socket,
      task_id: task_id
    } do
      # Send a prompt to set pending_prompt_id
      prompt_request = %{
        "jsonrpc" => "2.0",
        "id" => 99,
        "method" => "session/prompt",
        "params" => %{
          "prompt" => %{
            "messages" => [
              %{
                "role" => "user",
                "content" => %{"type" => "text", "text" => "Hello"}
              }
            ]
          }
        }
      }

      push(socket, "acp:message", prompt_request)
      :sys.get_state(socket.channel_pid)

      # Simulate the agent being cancelled via PubSub
      # (In production, ExecutionMonitor broadcasts this after Process.exit)
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        :agent_cancelled
      )

      # The pending prompt should resolve with stopReason: "cancelled"
      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 99,
        "result" => %{"stopReason" => "cancelled"}
      })
    end

    test "cancel with no pending prompt is a no-op", %{
      socket: socket,
      task_id: task_id
    } do
      # No prompt was sent, so no pending_prompt_id exists
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        :agent_cancelled
      )

      :sys.get_state(socket.channel_pid)

      # No prompt response should be pushed
      refute_push("acp:message", %{"result" => %{"stopReason" => "cancelled"}})
    end

    test "cancel does not interfere with subsequent prompts", %{
      socket: socket,
      task_id: task_id
    } do
      # Send first prompt
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "session/prompt",
        "params" => %{
          "prompt" => %{
            "messages" => [
              %{"role" => "user", "content" => %{"type" => "text", "text" => "Hello"}}
            ]
          }
        }
      })

      :sys.get_state(socket.channel_pid)

      # Cancel it
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        :agent_cancelled
      )

      assert_push("acp:message", %{
        "id" => 1,
        "result" => %{"stopReason" => "cancelled"}
      })

      # Send a second prompt - this should work normally
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "session/prompt",
        "params" => %{
          "prompt" => %{
            "messages" => [
              %{"role" => "user", "content" => %{"type" => "text", "text" => "Follow up"}}
            ]
          }
        }
      })

      :sys.get_state(socket.channel_pid)

      # Complete the second prompt normally
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        :agent_completed
      )

      assert_push("acp:message", %{
        "id" => 2,
        "result" => %{"stopReason" => "end_turn"}
      })
    end
  end

  describe "tool_call_start streaming" do
    setup %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "test-framework")

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      complete_mcp_handshake(socket)

      {:ok, socket: socket, task_id: task_id}
    end

    test "broadcasts early ACP tool_call notification on tool_call_start", %{
      socket: _socket,
      task_id: task_id
    } do
      tool_call_id = "call_early_#{:rand.uniform(1_000_000)}"

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:tool_call_start, tool_call_id, "write_file"}
      )

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "tool_call",
            "toolCallId" => ^tool_call_id,
            "title" => "write_file",
            "status" => "pending"
          }
        }
      })
    end

    test "deduplicates tool_call_create when interaction arrives after tool_call_start", %{
      socket: socket,
      task_id: task_id
    } do
      tool_call_id = "call_dedup_#{:rand.uniform(1_000_000)}"

      # Step 1: Send tool_call_start (early streaming notification)
      send(socket.channel_pid, {:tool_call_start, tool_call_id, "write_file"})
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{
          "update" => %{
            "sessionUpdate" => "tool_call",
            "toolCallId" => ^tool_call_id
          }
        }
      })

      # Step 2: Send the full interaction (which normally would also send tool_call_create)
      tool_call = %Interaction.ToolCall{
        id: Interaction.new_id(),
        sequence: Interaction.new_sequence(),
        tool_call_id: tool_call_id,
        tool_name: "write_file",
        arguments: %{"target_file" => "test.txt", "content" => "hello"},
        timestamp: Interaction.now()
      }

      send(socket.channel_pid, {:interaction, tool_call})
      :sys.get_state(socket.channel_pid)

      # Should get a tool_call_update with args, but NOT a duplicate tool_call create
      assert_push("acp:message", %{
        "params" => %{
          "update" => %{
            "sessionUpdate" => "tool_call_update",
            "toolCallId" => ^tool_call_id,
            "status" => "pending"
          }
        }
      })

      # Verify no duplicate tool_call create was sent
      refute_push("acp:message", %{
        "params" => %{
          "update" => %{
            "sessionUpdate" => "tool_call",
            "toolCallId" => ^tool_call_id
          }
        }
      })
    end

    test "sends tool_call_create for interactions without prior tool_call_start", %{
      socket: socket,
      task_id: task_id
    } do
      # Tool calls that arrive without a prior tool_call_start should still get
      # the normal tool_call_create notification
      tool_call_id = "call_no_start_#{:rand.uniform(1_000_000)}"

      tool_call = %Interaction.ToolCall{
        id: Interaction.new_id(),
        sequence: Interaction.new_sequence(),
        tool_call_id: tool_call_id,
        tool_name: "take_screenshot",
        arguments: %{},
        timestamp: Interaction.now()
      }

      send(socket.channel_pid, {:interaction, tool_call})
      :sys.get_state(socket.channel_pid)

      # Should get the standard tool_call create notification
      assert_push("acp:message", %{
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "tool_call",
            "toolCallId" => ^tool_call_id
          }
        }
      })

      # And the tool_call_update with arguments
      assert_push("acp:message", %{
        "params" => %{
          "update" => %{
            "sessionUpdate" => "tool_call_update",
            "toolCallId" => ^tool_call_id
          }
        }
      })
    end

    test "tracks multiple tool calls independently", %{
      socket: socket
    } do
      call_id_1 = "call_multi_1_#{:rand.uniform(1_000_000)}"
      call_id_2 = "call_multi_2_#{:rand.uniform(1_000_000)}"

      # Announce first tool call via streaming
      send(socket.channel_pid, {:tool_call_start, call_id_1, "write_file"})
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{"update" => %{"toolCallId" => ^call_id_1, "sessionUpdate" => "tool_call"}}
      })

      # Second tool call arrives without prior tool_call_start
      tool_call_2 = %Interaction.ToolCall{
        id: Interaction.new_id(),
        sequence: Interaction.new_sequence(),
        tool_call_id: call_id_2,
        tool_name: "read_file",
        arguments: %{"target_file" => "other.txt"},
        timestamp: Interaction.now()
      }

      send(socket.channel_pid, {:interaction, tool_call_2})
      :sys.get_state(socket.channel_pid)

      # Second tool call should still get its own tool_call create
      assert_push("acp:message", %{
        "params" => %{"update" => %{"toolCallId" => ^call_id_2, "sessionUpdate" => "tool_call"}}
      })
    end
  end

  # Completes the MCP handshake (initialize + tools/list + load_agent_instructions).
  #
  # Uses :sys.get_state/1 as a synchronization barrier after each push to ensure
  # the channel process has fully processed the message before we assert the
  # response. Without these barriers, under CI load (especially coverage runs),
  # the channel process may not be scheduled in time and assert_push times out.
  defp complete_mcp_handshake(socket) do
    # Wait for channel to process the deferred :start_mcp_init message
    :sys.get_state(socket.channel_pid)
    assert_push("mcp:message", %{"id" => init_request_id, "method" => "initialize"})

    init_result = %{
      "protocolVersion" => ModelContextProtocol.protocol_version(),
      "capabilities" => %{"tools" => %{}},
      "serverInfo" => %{"name" => "test-mcp", "version" => "1.0.0"}
    }

    push(socket, "mcp:message", JsonRpc.success_response(init_request_id, init_result))
    :sys.get_state(socket.channel_pid)

    assert_push("mcp:message", %{"method" => "notifications/initialized"})
    assert_push("mcp:message", %{"id" => tools_request_id, "method" => "tools/list"})

    push(socket, "mcp:message", JsonRpc.success_response(tools_request_id, %{"tools" => []}))
    :sys.get_state(socket.channel_pid)

    assert_push("mcp:message", %{
      "id" => project_rules_request_id,
      "method" => "tools/call",
      "params" => %{"name" => "load_agent_instructions"}
    })

    push(
      socket,
      "mcp:message",
      JsonRpc.success_response(project_rules_request_id, %{"content" => []})
    )

    :sys.get_state(socket.channel_pid)

    assert_push("acp:message", %{
      "method" => "project_rules_initialized"
    })
  end
end
