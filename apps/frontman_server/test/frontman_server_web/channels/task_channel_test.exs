defmodule FrontmanServerWeb.TaskChannelTest do
  use FrontmanServerWeb.ChannelCase, async: true
  use Oban.Testing, repo: FrontmanServer.Repo

  import FrontmanServer.InteractionCase.Helpers
  import FrontmanServer.Test.Fixtures.Tasks

  alias AgentClientProtocol.Content.{ContentItem, TextBlock}
  alias FrontmanServer.Tasks
  alias FrontmanServer.Workers.GenerateTitle
  alias FrontmanServerWeb.UserSocket

  # --- Swarm event builders (match production shapes from Runtime) ---

  defp swarm_chunk(type, text), do: {:swarm_event, {:chunk, %{type: type, text: text}}}

  defp swarm_tool_call_start(id, name),
    do:
      {:swarm_event, {:chunk, %{type: :tool_call_start, tool_call_id: id, tool_call_name: name}}}

  defp swarm_completed,
    do: {:swarm_event, {:completed, {:ok, nil, System.unique_integer([:positive])}}}

  defp swarm_failed(reason),
    do: {:swarm_event, {:failed, {:error, reason, System.unique_integer([:positive])}}}

  defp swarm_cancelled, do: {:swarm_event, {:cancelled, %{loop: nil}}}

  # Collects all pending push messages from the test process mailbox.
  # Phoenix.ChannelTest sends pushes as {:socket_push, event, payload} messages.
  defp collect_all_pushes(acc \\ []) do
    receive do
      %Phoenix.Socket.Message{event: event, payload: payload} ->
        collect_all_pushes([{event, payload} | acc])
    after
      200 -> Enum.reverse(acc)
    end
  end

  # MCP tool definition used in tests that need a registered tool
  @mcp_get_logs_tool %{
    "name" => "get_logs",
    "description" => "Retrieves server logs",
    "inputSchema" => %{
      "type" => "object",
      "properties" => %{"tail" => %{"type" => "integer"}}
    },
    "visibleToAgent" => true
  }

  describe "join task:<id>" do
    test "succeeds when task exists", %{scope: scope} do
      task_id = task_fixture(scope)

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
      {socket, task_id} = join_task_channel(scope)
      {:ok, socket: socket, task_id: task_id}
    end

    test "returns error for unknown method", %{socket: socket} do
      ref =
        push(socket, "acp:message", build_acp_request("unknown/method", 2, %{}))

      assert_reply(ref, :ok, %{"acp:message" => response})
      assert response["error"]["code"] == -32_601
      assert response["error"]["message"] =~ "Method not found"
    end

    test "forwards prompt model and env API key to title generation job", %{
      socket: socket,
      task_id: task_id,
      user: user
    } do
      complete_mcp_handshake(socket)

      push(
        socket,
        "acp:message",
        build_prompt_request(
          _meta: %{
            "openrouterKeyValue" => "sk-or-test",
            "model" => %{"provider" => "openrouter", "value" => "openai/gpt-5.1-codex"}
          }
        )
      )

      :sys.get_state(socket.channel_pid)

      assert_enqueued(
        worker: GenerateTitle,
        args: %{
          user_id: user.id,
          task_id: task_id,
          model: "openrouter:openai/gpt-5.1-codex"
        }
      )
    end
  end

  # Tests that verify the channel is properly subscribed to PubSub.
  # Critical because tool calls are broadcast via PubSub from the agent,
  # and the channel must receive them to route to MCP.
  describe "PubSub subscription" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "channel receives tool call interactions via PubSub broadcast", %{
      socket: _socket,
      task_id: task_id
    } do
      # This test verifies the REAL path: PubSub.broadcast -> channel receives
      # Unlike other tests that use send(socket.channel_pid, ...) directly

      tool_call =
        tool_call("call_pubsub_#{:rand.uniform(1_000_000)}", "testTool", %{"key" => "value"})

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

      tool_call =
        tool_call("call_different_#{:rand.uniform(1_000_000)}", "otherTool")

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

    test "channel receives chunk events via PubSub broadcast", %{
      socket: _socket,
      task_id: task_id
    } do
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        swarm_chunk(:token, "Hello world")
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

    test "channel handles thinking chunk without crashing", %{
      socket: socket,
      task_id: task_id
    } do
      # Thinking chunks and empty-text chunks are silently dropped
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        swarm_chunk(:thinking, "reasoning...")
      )

      refute_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "agent_thinking_chunk"}}
      })

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        swarm_chunk(:token, "")
      )

      refute_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "agent_message_chunk"}}
      })

      # Channel should still be alive and functional
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        swarm_chunk(:token, "after thinking")
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

  describe "failed event handling" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "broadcasts error as session/update notification", %{
      socket: _socket,
      task_id: task_id
    } do
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        swarm_failed("Rate limit exceeded")
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
      push(socket, "acp:message", build_prompt_request(id: 42))
      # Wait for the prompt to be processed
      :sys.get_state(socket.channel_pid)

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        swarm_failed("No API key available")
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
        swarm_failed("Connection failed")
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
  end

  describe "completed event without pending prompt (resume scenario)" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "sends agent_turn_complete notification when pending_prompt_id is nil", %{
      socket: socket,
      task_id: task_id
    } do
      # Simulate: execution was resumed after tool result (no pending prompt),
      # then the agent completes. There's no JSON-RPC request to respond to.
      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), swarm_completed())

      :sys.get_state(socket.channel_pid)

      # Channel should NOT push a JSON-RPC response since there's no pending prompt
      refute_push("acp:message", %{"id" => _, "result" => _})

      # Channel SHOULD push an agent_turn_complete notification so the client
      # can finalize the streaming message and reset its agent-running state.
      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "agent_turn_complete",
            "stopReason" => "end_turn"
          }
        }
      })

      # Channel should still be alive
      assert Process.alive?(socket.channel_pid)
    end

    test "does not interfere with subsequent prompts after nil completion", %{
      socket: socket,
      task_id: task_id
    } do
      # First: completed event with no pending prompt
      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), swarm_completed())

      :sys.get_state(socket.channel_pid)

      # Then: send a real prompt and complete it normally
      push(socket, "acp:message", build_prompt_request(id: 50, text: "Next question"))

      :sys.get_state(socket.channel_pid)

      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), swarm_completed())

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 50,
        "result" => %{"stopReason" => "end_turn"}
      })
    end
  end

  describe "MCP tool call result extraction" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "extracts text content from MCP tool result", %{socket: socket, task_id: task_id} do
      tool_call =
        tool_call("call_123", "consoleLog", %{"message" => "hello"})

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

      # Phoenix.ChannelTest delivers raw Elixir terms (no JSON serialisation),
      # so content arrives as ACP.Content structs rather than plain maps.
      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "tool_call_update",
            "toolCallId" => "call_123",
            "status" => "completed",
            "content" => [%ContentItem{content: %TextBlock{text: "Logged: hello"}}]
          }
        }
      })
    end
  end

  describe "MCP initialization" do
    test "sends MCP initialize request on join", %{scope: scope} do
      {_socket, _task_id} = join_task_channel(scope)

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
      {socket, _task_id} = join_task_channel(scope)

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
      {socket, task_id} = join_task_channel(scope)
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
      tool_call = tool_call("call_valid_test", "testTool")

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
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket, tools: [@mcp_get_logs_tool])
      {:ok, socket: socket, task_id: task_id, scope: scope}
    end

    test "delivers tool response to executor regardless of initialization state", %{scope: scope} do
      # Tool responses should always be delivered to waiting executors.
      # This ensures agents can function even if tool calls happen early in the session.

      {socket, _fresh_task_id} = join_task_channel(scope)

      # Drain the initialize request without responding - initialization is incomplete
      assert_push("mcp:message", %{"id" => _init_request_id, "method" => "initialize"})

      tool_call_id = "call_delivery_#{:rand.uniform(1_000_000)}"
      test_pid = self()

      # Executor registers and waits for tool result
      Registry.register(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id}, %{
        caller_pid: test_pid
      })

      tool_call = tool_call(tool_call_id, "list_dir", %{"path" => "/"})

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

      Registry.unregister(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id})
    end

    test "encodes JSON tool result to string for waiting executor", %{socket: socket} do
      # This test exercises the full flow where:
      # 1. An executor is waiting for a tool result (registered in AgentRegistry)
      # 2. MCP tool returns JSON that gets parsed to a map
      # 3. The result should be encoded to string before sending to executor
      #
      # Without the fix, the executor receives a map which later causes
      # FunctionClauseError in SwarmAi.Message.ContentPart.text/1

      tool_call_id = "call_json_result_#{:rand.uniform(1_000_000)}"
      test_pid = self()

      # Simulate what ToolExecutor.execute_mcp_tool does - register and wait
      Registry.register(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id}, %{
        caller_pid: test_pid
      })

      # Simulate a tool call interaction being broadcast
      tool_call = tool_call(tool_call_id, "get_logs", %{"tail" => 10})

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

      # This is the key assertion - content must be a string for SwarmAi.Message.ContentPart.text/1
      assert is_binary(content),
             "Tool result should be encoded to string, got: #{inspect(content)}"

      # Verify it's valid JSON that can be decoded back
      assert {:ok, decoded} = Jason.decode(content)
      assert is_map(decoded)
      assert Map.has_key?(decoded, "logs")

      # Cleanup
      Registry.unregister(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id})
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

      {socket, _task_id} = join_task_channel(scope)

      # MCP init has started - we receive the initialize request
      assert_push("mcp:message", %{"id" => init_request_id, "method" => "initialize"})

      # Send prompt BEFORE completing MCP handshake
      push(socket, "acp:message", build_prompt_request())
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

      # Handle list_tree for project structure
      assert_push("mcp:message", %{
        "id" => project_structure_request_id,
        "method" => "tools/call",
        "params" => %{"name" => "list_tree"}
      })

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(project_structure_request_id, %{"content" => []})
      )

      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{"method" => "mcp_initialization_complete"})

      # Verify MCP tools are now stored in socket assigns
      channel_socket = :sys.get_state(socket.channel_pid)
      assert length(channel_socket.assigns.mcp_tools) == 1
      assert hd(channel_socket.assigns.mcp_tools).name == "take_screenshot"

      # After MCP init completes, the queued prompt is processed (task_channel.ex:471-479)
      # This creates a UserMessage interaction broadcast via PubSub
      assert_receive {:interaction, %Tasks.Interaction.UserMessage{}}
    end
  end

  describe "session/cancel" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "cancel notification is accepted (no response expected per ACP spec)", %{
      socket: socket
    } do
      # ACP spec: session/cancel is a notification, not a request.
      # No JSON-RPC response should be sent back.
      push(
        socket,
        "acp:message",
        build_acp_request("session/cancel", nil, %{"sessionId" => "irrelevant"})
      )

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
      push(socket, "acp:message", build_prompt_request(id: 99))
      :sys.get_state(socket.channel_pid)

      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), swarm_cancelled())

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
      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), swarm_cancelled())

      :sys.get_state(socket.channel_pid)

      # No prompt response should be pushed
      refute_push("acp:message", %{"result" => %{"stopReason" => "cancelled"}})
    end

    test "cancel does not interfere with subsequent prompts", %{
      socket: socket,
      task_id: task_id
    } do
      # Send first prompt
      push(socket, "acp:message", build_prompt_request(id: 1))

      :sys.get_state(socket.channel_pid)

      # Cancel it
      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), swarm_cancelled())

      assert_push("acp:message", %{
        "id" => 1,
        "result" => %{"stopReason" => "cancelled"}
      })

      # Send a second prompt - this should work normally
      push(socket, "acp:message", build_prompt_request(id: 2, text: "Follow up"))

      :sys.get_state(socket.channel_pid)

      # Complete the second prompt normally
      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), swarm_completed())

      assert_push("acp:message", %{
        "id" => 2,
        "result" => %{"stopReason" => "end_turn"}
      })
    end
  end

  describe "tool_call_start chunk streaming" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
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
        swarm_tool_call_start(tool_call_id, "write_file")
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
      task_id: _task_id
    } do
      tool_call_id = "call_dedup_#{:rand.uniform(1_000_000)}"

      # Step 1: Send tool_call_start chunk (early streaming notification)
      send(socket.channel_pid, swarm_tool_call_start(tool_call_id, "write_file"))
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
      tc =
        tool_call(tool_call_id, "write_file", %{"target_file" => "test.txt", "content" => "hello"})

      send(socket.channel_pid, {:interaction, tc})
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

      tc = tool_call(tool_call_id, "take_screenshot")

      send(socket.channel_pid, {:interaction, tc})
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
      send(socket.channel_pid, swarm_tool_call_start(call_id_1, "write_file"))
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{"update" => %{"toolCallId" => ^call_id_1, "sessionUpdate" => "tool_call"}}
      })

      # Second tool call arrives without prior tool_call_start
      tool_call_2 = tool_call(call_id_2, "read_file", %{"target_file" => "other.txt"})

      send(socket.channel_pid, {:interaction, tool_call_2})
      :sys.get_state(socket.channel_pid)

      # Second tool call should still get its own tool_call create
      assert_push("acp:message", %{
        "params" => %{"update" => %{"toolCallId" => ^call_id_2, "sessionUpdate" => "tool_call"}}
      })
    end
  end

  describe "reconnect re-executes unresolved tool calls" do
    setup %{scope: scope} do
      task_id = task_fixture(scope)

      # Seed DB with the state that exists after a disconnect during a question tool call:
      # user_message → agent_response (with tool_calls metadata) → tool_call (no tool_result)
      tool_call_id = "tc_question_#{System.unique_integer([:positive])}"

      question_args =
        Jason.encode!(%{
          "questions" => [
            %{
              "question" => "Pick one",
              "header" => "Test",
              "options" => [%{"label" => "A", "description" => "Option A"}]
            }
          ]
        })

      reqllm_tc = ReqLLM.ToolCall.new(tool_call_id, "question", question_args)

      Tasks.submit_user_message(
        scope,
        task_id,
        [%{"type" => "text", "text" => "ask me a question"}],
        [],
        agent: %FrontmanServer.Testing.BlockingAgent{}
      )

      Tasks.add_agent_response(scope, task_id, "", %{tool_calls: [reqllm_tc]})
      Tasks.add_tool_call(scope, task_id, reqllm_tc)

      {:ok, task_id: task_id, scope: scope, tool_call_id: tool_call_id}
    end

    test "e2e: reconnect → session/load → tools/call → answer → tool result persisted", %{
      scope: scope,
      task_id: task_id,
      tool_call_id: tool_call_id
    } do
      # Full e2e: join fresh channel, complete MCP handshake, load session,
      # verify tools/call is pushed, respond, verify DB has tool result.
      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      complete_mcp_handshake(socket)

      push(socket, "acp:message", build_acp_request("session/load", 1, %{"sessionId" => task_id}))
      :sys.get_state(socket.channel_pid)

      # Drain history replay + success response, find the tools/call
      messages = collect_all_pushes()

      tools_call =
        Enum.find(messages, fn
          {"mcp:message", %{"method" => "tools/call", "params" => %{"name" => "question"}}} ->
            true

          _ ->
            false
        end)

      assert tools_call, "tools/call for question not found in #{length(messages)} messages"
      {"mcp:message", %{"id" => mcp_request_id}} = tools_call

      # Client answers the question
      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(mcp_request_id, %{
          "content" => [
            %{"type" => "text", "text" => Jason.encode!(%{"answers" => [%{"answer" => "A"}]})}
          ]
        })
      )

      :sys.get_state(socket.channel_pid)

      # Tool result persisted
      {:ok, task} = Tasks.get_task(scope, task_id)
      tool_results = Enum.filter(task.interactions, &match?(%Tasks.Interaction.ToolResult{}, &1))
      assert [result] = tool_results
      assert result.tool_call_id == tool_call_id
      refute result.is_error
    end

    test "e2e: session/load before MCP handshake → answer after handshake → persisted", %{
      scope: scope,
      task_id: task_id,
      tool_call_id: tool_call_id
    } do
      # Production ordering: session/load fires before MCP handshake completes.
      # The tools/call is pushed during/after the handshake. The client answers
      # after the handshake is done.
      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      :sys.get_state(socket.channel_pid)
      assert_push("mcp:message", %{"id" => init_request_id, "method" => "initialize"})

      # session/load BEFORE MCP init
      push(
        socket,
        "acp:message",
        build_acp_request("session/load", 1, %{"sessionId" => task_id})
      )

      :sys.get_state(socket.channel_pid)

      # Complete MCP handshake step by step
      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(init_request_id, %{
          "protocolVersion" => ModelContextProtocol.protocol_version(),
          "capabilities" => %{"tools" => %{}},
          "serverInfo" => %{"name" => "test-mcp", "version" => "1.0.0"}
        })
      )

      :sys.get_state(socket.channel_pid)
      assert_push("mcp:message", %{"method" => "notifications/initialized"})
      assert_push("mcp:message", %{"id" => tools_id, "method" => "tools/list"})
      push(socket, "mcp:message", JsonRpc.success_response(tools_id, %{"tools" => []}))
      :sys.get_state(socket.channel_pid)

      assert_push("mcp:message", %{
        "id" => rules_id,
        "method" => "tools/call",
        "params" => %{"name" => "load_agent_instructions"}
      })

      push(socket, "mcp:message", JsonRpc.success_response(rules_id, %{"content" => []}))
      :sys.get_state(socket.channel_pid)

      assert_push("mcp:message", %{
        "id" => tree_id,
        "method" => "tools/call",
        "params" => %{"name" => "list_tree"}
      })

      push(socket, "mcp:message", JsonRpc.success_response(tree_id, %{"content" => []}))
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{"method" => "mcp_initialization_complete"})

      # Now find the tools/call that was pushed during the handshake
      assert_push(
        "mcp:message",
        %{"method" => "tools/call", "id" => mcp_request_id, "params" => %{"name" => "question"}},
        2_000
      )

      # Client answers
      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(mcp_request_id, %{
          "content" => [
            %{"type" => "text", "text" => Jason.encode!(%{"answers" => [%{"answer" => "A"}]})}
          ]
        })
      )

      :sys.get_state(socket.channel_pid)

      # Tool result persisted
      {:ok, task} = Tasks.get_task(scope, task_id)
      tool_results = Enum.filter(task.interactions, &match?(%Tasks.Interaction.ToolResult{}, &1))
      assert [result] = tool_results
      assert result.tool_call_id == tool_call_id
      refute result.is_error
    end

    test "tools/call is pushed AFTER session/load success response (ordering guarantee)", %{
      scope: scope,
      task_id: task_id
    } do
      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      complete_mcp_handshake(socket)

      push(socket, "acp:message", build_acp_request("session/load", 1, %{"sessionId" => task_id}))
      :sys.get_state(socket.channel_pid)

      messages = collect_all_pushes()

      session_load_idx =
        Enum.find_index(messages, fn
          {"acp:message", %{"id" => 1, "result" => %{}}} -> true
          _ -> false
        end)

      tools_call_idx =
        Enum.find_index(messages, fn
          {"mcp:message", %{"method" => "tools/call", "params" => %{"name" => "question"}}} ->
            true

          _ ->
            false
        end)

      assert session_load_idx != nil, "session/load success not found"
      assert tools_call_idx != nil, "tools/call not found"

      assert session_load_idx < tools_call_idx,
             "tools/call (idx #{tools_call_idx}) arrived BEFORE session/load success (idx #{session_load_idx})"
    end

    test "resolved tool calls are NOT re-dispatched", %{
      scope: scope,
      task_id: task_id,
      tool_call_id: tool_call_id
    } do
      # Add a tool result so the tool call is resolved
      Tasks.add_tool_result(
        scope,
        task_id,
        %{id: tool_call_id, name: "question"},
        %{"answers" => [%{"answer" => "A"}]},
        false
      )

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      complete_mcp_handshake(socket)

      push(socket, "acp:message", build_acp_request("session/load", 1, %{"sessionId" => task_id}))
      :sys.get_state(socket.channel_pid)

      messages = collect_all_pushes()

      tools_call =
        Enum.find(messages, fn
          {"mcp:message", %{"method" => "tools/call", "params" => %{"name" => "question"}}} ->
            true

          _ ->
            false
        end)

      assert tools_call == nil, "Resolved tool call should NOT be re-dispatched"
    end
  end

  describe "transient error triggers retrying notification" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "retryable error pushes error notification with retryAt", %{
      socket: _socket,
      task_id: task_id
    } do
      error = %FrontmanServer.Tasks.Execution.LLMError{
        message: "Rate limited",
        category: "rate_limit",
        retryable: true
      }

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        swarm_failed(error)
      )

      assert_push("acp:message", %{
        "params" => %{
          "update" => %{
            "sessionUpdate" => "error",
            "attempt" => 1,
            "retryAt" => _
          }
        }
      })
    end

    test "non-retryable error pushes error notification without retryAt", %{
      socket: _socket,
      task_id: task_id
    } do
      error = %FrontmanServer.Tasks.Execution.LLMError{
        message: "Auth failed",
        category: "auth",
        retryable: false
      }

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        swarm_failed(error)
      )

      assert_push("acp:message", %{
        "params" => %{
          "update" => %{"sessionUpdate" => "error", "message" => "Auth failed"}
        }
      })
    end
  end

  describe "retry flow" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "session/retry_turn notification creates AgentRetry interaction", %{
      scope: scope,
      socket: socket,
      task_id: task_id
    } do
      error = %FrontmanServer.Tasks.Execution.LLMError{
        message: "Rate limited",
        category: "rate_limit",
        retryable: true
      }

      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), swarm_failed(error))
      :sys.get_state(socket.channel_pid)

      retried_error_id = "error-#{task_id}-some-timestamp"

      push(
        socket,
        "acp:message",
        build_acp_request("session/retry_turn", nil, %{
          "sessionId" => task_id,
          "retriedErrorId" => retried_error_id
        })
      )

      :sys.get_state(socket.channel_pid)

      {:ok, task} = Tasks.get_task(scope, task_id)

      assert Enum.any?(
               task.interactions,
               &match?(
                 %FrontmanServer.Tasks.Interaction.AgentRetry{
                   retried_error_id: ^retried_error_id
                 },
                 &1
               )
             )
    end

    test "second transient error increments retry attempt instead of resetting to 1", %{
      socket: _socket,
      task_id: task_id
    } do
      error = %FrontmanServer.Tasks.Execution.LLMError{
        message: "Rate limited",
        category: "rate_limit",
        retryable: true
      }

      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), swarm_failed(error))

      assert_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "error", "attempt" => 1, "retryAt" => _}}
      })

      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), swarm_failed(error))

      assert_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "error", "attempt" => 2, "retryAt" => _}}
      })
    end
  end

  describe "retry bug: stale coordinator after successful retry" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "after successful retry, next transient error starts a fresh coordinator at attempt 1",
         %{
           socket: socket,
           task_id: task_id
         } do
      error = %FrontmanServer.Tasks.Execution.LLMError{
        message: "Rate limited",
        category: "rate_limit",
        retryable: true
      }

      # First transient error — coordinator starts
      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), swarm_failed(error))
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "error", "attempt" => 1, "retryAt" => _}}
      })

      # Simulate the timer firing :fire_retry (skip 2s default delay)
      send(socket.channel_pid, :fire_retry)
      :sys.get_state(socket.channel_pid)

      # Execution succeeds — handle_turn_ended should stop and clear the coordinator
      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), swarm_completed())
      :sys.get_state(socket.channel_pid)
      flush_mailbox()

      # New turn hits a transient error — should start fresh at attempt 1
      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), swarm_failed(error))
      :sys.get_state(socket.channel_pid)

      # BUG: handle_turn_ended does not clear retry_coordinator, so handle_transient_error
      # finds the stale pid and calls execution_failed/2 on it, reporting attempt 2.
      assert_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "error", "attempt" => 1, "retryAt" => _}}
      })
    end
  end

  describe "cancelling retry via session/cancel" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "ends the turn and leaves the channel operational", %{
      socket: socket,
      task_id: task_id
    } do
      error = %FrontmanServer.Tasks.Execution.LLMError{
        message: "Rate limited",
        category: "rate_limit",
        retryable: true
      }

      # Trigger a transient error so retry state is created
      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), swarm_failed(error))
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "error", "attempt" => 1, "retryAt" => _}}
      })

      # Verify retry state exists
      %{assigns: assigns} = :sys.get_state(socket.channel_pid)
      assert %FrontmanServer.Tasks.RetryCoordinator{} = assigns[:retry_state]

      # Cancel via session/cancel (no execution running, so :not_running path)
      push(
        socket,
        "acp:message",
        build_acp_request("session/cancel", nil, %{"sessionId" => task_id})
      )

      :sys.get_state(socket.channel_pid)

      # Channel pushes turn-complete with cancelled stop reason
      assert_push("acp:message", %{
        "params" => %{
          "update" => %{"sessionUpdate" => "agent_turn_complete", "stopReason" => "cancelled"}
        }
      })

      # Retry state cleared, channel alive
      assert Process.alive?(socket.channel_pid)
      %{assigns: assigns} = :sys.get_state(socket.channel_pid)
      assert is_nil(assigns[:retry_state])
    end
  end

  describe "retry bug: category missing from retrying notification" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "retrying notification includes the actual error category, not 'unknown'", %{
      socket: _socket,
      task_id: task_id
    } do
      error = %FrontmanServer.Tasks.Execution.LLMError{
        message: "Rate limited",
        category: "rate_limit",
        retryable: true
      }

      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), swarm_failed(error))

      # BUG: RetryCoordinator.schedule_retry/1 omits error_info.category from the
      # :retrying_status tuple. The channel's handle_info handler cannot forward
      # it to ACP.build_error_notification, which defaults category to "unknown".
      assert_push("acp:message", %{
        "params" => %{
          "update" => %{
            "sessionUpdate" => "error",
            "category" => "rate_limit",
            "attempt" => 1,
            "retryAt" => _
          }
        }
      })
    end
  end

  describe "bug: session/cancel during retry countdown is silently ignored" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "cancel during retry countdown stops the coordinator and ends the turn", %{
      socket: socket,
      task_id: task_id
    } do
      error = %FrontmanServer.Tasks.Execution.LLMError{
        message: "Rate limited",
        category: "rate_limit",
        retryable: true
      }

      # Trigger a transient error — coordinator starts, enters countdown
      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), swarm_failed(error))
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "error", "attempt" => 1, "retryAt" => _}}
      })

      # Verify retry state exists
      %{assigns: %{retry_state: retry_state}} = :sys.get_state(socket.channel_pid)
      assert %FrontmanServer.Tasks.RetryCoordinator{} = retry_state

      # User clicks stop — sends session/cancel while NO execution is running
      # (we're in the countdown window between retrying_status and trigger_retry)
      push(
        socket,
        "acp:message",
        build_acp_request("session/cancel", nil, %{"sessionId" => task_id})
      )

      :sys.get_state(socket.channel_pid)

      # The coordinator should be cancelled and turn should end
      assert_push("acp:message", %{
        "params" => %{
          "update" => %{"sessionUpdate" => "agent_turn_complete", "stopReason" => "cancelled"}
        }
      })

      # Retry state should be cleared
      %{assigns: assigns} = :sys.get_state(socket.channel_pid)
      assert is_nil(assigns[:retry_state])

      # Channel remains operational
      assert Process.alive?(socket.channel_pid)
    end

    test "cancel during countdown prevents trigger_retry from firing", %{
      socket: socket,
      task_id: task_id
    } do
      error = %FrontmanServer.Tasks.Execution.LLMError{
        message: "Rate limited",
        category: "rate_limit",
        retryable: true
      }

      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), swarm_failed(error))
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "error", "attempt" => 1, "retryAt" => _}}
      })

      # Cancel during countdown
      push(
        socket,
        "acp:message",
        build_acp_request("session/cancel", nil, %{"sessionId" => task_id})
      )

      :sys.get_state(socket.channel_pid)
      flush_mailbox()

      # Wait long enough for the retry delay to have fired (base_delay is 2s in prod,
      # but we can't control it here — wait a reasonable amount)
      Process.sleep(200)

      # No trigger_retry should have caused a new execution or retrying_status push
      refute_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "error", "attempt" => 2}}
      })
    end

    test "stale :fire_retry in mailbox after cancel does not start execution", %{
      socket: socket,
      task_id: task_id
    } do
      error = %FrontmanServer.Tasks.Execution.LLMError{
        message: "Rate limited",
        category: "rate_limit",
        retryable: true
      }

      # Trigger transient error — retry state created, timer scheduled
      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), swarm_failed(error))
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "error", "attempt" => 1, "retryAt" => _}}
      })

      # Cancel during countdown — clears retry state
      push(
        socket,
        "acp:message",
        build_acp_request("session/cancel", nil, %{"sessionId" => task_id})
      )

      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{
          "update" => %{"sessionUpdate" => "agent_turn_complete", "stopReason" => "cancelled"}
        }
      })

      flush_mailbox()

      # Simulate the race: :fire_retry arrives AFTER cancel cleared retry_state
      # (timer fired right before cancel, message was already in mailbox)
      send(socket.channel_pid, :fire_retry)
      :sys.get_state(socket.channel_pid)

      # No execution should start — no error notification, no swarm activity
      refute_push("acp:message", _)

      # Channel still alive and retry_state still nil
      assert Process.alive?(socket.channel_pid)
      %{assigns: assigns} = :sys.get_state(socket.channel_pid)
      assert is_nil(assigns[:retry_state])
    end
  end

  describe "bug: execution_start_error during retry leaves zombie coordinator" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "execution_start_error after trigger_retry cleans up the coordinator", %{
      socket: socket,
      task_id: task_id
    } do
      error = %FrontmanServer.Tasks.Execution.LLMError{
        message: "Rate limited",
        category: "rate_limit",
        retryable: true
      }

      # Trigger a transient error — coordinator starts
      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), swarm_failed(error))
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "error", "attempt" => 1, "retryAt" => _}}
      })

      %{assigns: %{retry_state: retry_state}} = :sys.get_state(socket.channel_pid)
      assert %FrontmanServer.Tasks.RetryCoordinator{} = retry_state

      # Timer fires :fire_retry → channel calls maybe_start_execution
      # but execution fails to start (e.g. API key expired)
      send(socket.channel_pid, :fire_retry)
      :sys.get_state(socket.channel_pid)

      # Simulate execution start failure
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:execution_start_error, "API key expired"}
      )

      :sys.get_state(socket.channel_pid)

      # Channel should push an error notification for the start failure
      assert_push("acp:message", %{
        "params" => %{
          "update" => %{"sessionUpdate" => "error", "message" => "API key expired"}
        }
      })

      # The coordinator assign must be cleared so it doesn't corrupt future retries
      %{assigns: assigns} = :sys.get_state(socket.channel_pid)
      assert is_nil(assigns[:retry_state])
    end

    test "subsequent transient error after zombie cleanup starts fresh at attempt 1", %{
      socket: socket,
      task_id: task_id
    } do
      error = %FrontmanServer.Tasks.Execution.LLMError{
        message: "Rate limited",
        category: "rate_limit",
        retryable: true
      }

      # First: transient error → coordinator starts
      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), swarm_failed(error))
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "error", "attempt" => 1, "retryAt" => _}}
      })

      # trigger_retry fires, but execution fails to start
      send(socket.channel_pid, :fire_retry)
      :sys.get_state(socket.channel_pid)

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:execution_start_error, "API key expired"}
      )

      :sys.get_state(socket.channel_pid)
      flush_mailbox()

      # Now a new transient error arrives — should start a FRESH coordinator at attempt 1
      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), swarm_failed(error))
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "error", "attempt" => 1, "retryAt" => _}}
      })
    end
  end

  describe "bug: non-retryable error must clear retry_state" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "non-retryable error after retry clears state for next turn", %{
      socket: socket,
      task_id: task_id
    } do
      retryable_error = %FrontmanServer.Tasks.Execution.LLMError{
        message: "Rate limited",
        category: "rate_limit",
        retryable: true
      }

      non_retryable_error = %FrontmanServer.Tasks.Execution.LLMError{
        message: "Invalid API key",
        category: "auth",
        retryable: false
      }

      # First: transient error creates retry state at attempt 1
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        swarm_failed(retryable_error)
      )

      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "error", "attempt" => 1, "retryAt" => _}}
      })

      # Retry fires, but execution hits a non-retryable error
      send(socket.channel_pid, :fire_retry)
      :sys.get_state(socket.channel_pid)

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        swarm_failed(non_retryable_error)
      )

      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{
          "update" => %{"sessionUpdate" => "error", "message" => "Invalid API key"}
        }
      })

      # retry_state MUST be cleared after the non-retryable error
      %{assigns: assigns} = :sys.get_state(socket.channel_pid)
      assert is_nil(assigns[:retry_state])

      flush_mailbox()

      # New turn: another transient error should start fresh at attempt 1
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        swarm_failed(retryable_error)
      )

      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "error", "attempt" => 1, "retryAt" => _}}
      })
    end
  end
end
