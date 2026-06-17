defmodule FrontmanServerWeb.TaskChannelTest do
  use FrontmanServerWeb.ChannelCase, async: false
  use Oban.Testing, repo: FrontmanServer.Repo

  import FrontmanServer.InteractionCase.Helpers
  import FrontmanServer.Test.Fixtures.Tasks

  alias AgentClientProtocol.Content.{ContentItem, TextBlock}
  alias FrontmanServer.Tasks
  alias FrontmanServer.Workers.GenerateTitle
  alias FrontmanServerWeb.UserSocket

  alias FrontmanServer.Tasks.Interaction
  alias ModelContextProtocol, as: MCP

  # --- Live execution chunk builders ---

  defp execution_chunk(type, text),
    do: {:execution_chunk, 1, %{type: type, text: text}}

  defp execution_tool_call(id, name),
    do:
      {:execution_chunk, 1,
       %{type: :tool_call, name: name, arguments: %{}, metadata: %{id: id, index: 0}}}

  defp agent_completed,
    do: {:interaction, Interaction.AgentCompleted.new(), 1}

  defp agent_failed(message, category \\ "unknown"),
    do: {:interaction, Interaction.AgentError.new(message, "failed", false, category), 1}

  defp broadcast_retryable_error(scope, task_id) do
    user_message_fixture(scope, task_id, [%{"type" => "text", "text" => "retry me"}])
    turn_number = latest_turn_number(task_id)

    {:ok, error_interaction} =
      Tasks.record_agent_run_result(
        scope,
        task_id,
        turn_number,
        {:failed, "Rate limited", true, "rate_limit"}
      )

    error_interaction
  end

  defp agent_cancelled,
    do: {:interaction, Interaction.AgentError.new("Cancelled", "cancelled"), 1}

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

  defp assert_agent_turn_complete(task_id) do
    assert_push(
      "acp:message",
      %{
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{"sessionUpdate" => "agent_turn_complete"}
        }
      },
      1_000
    )
  end

  defp register_tool_receiver(tool_call_id) do
    Registry.register(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id}, %{
      caller_pid: self()
    })
  end

  defp question_tool_call(id, header, label) do
    args =
      Jason.encode!(%{
        "questions" => [
          %{
            "question" => "Pick one",
            "header" => header,
            "options" => [%{"label" => label, "description" => "Option #{label}"}]
          }
        ]
      })

    %SwarmAi.ToolCall{id: id, name: "question", arguments: args}
  end

  defp tool_call_metadata(%SwarmAi.ToolCall{} = tool_call) do
    %{"id" => tool_call.id, "name" => tool_call.name, "arguments" => tool_call.arguments}
  end

  defp redispatched_question_header?(
         {"mcp:message",
          %{
            "method" => "tools/call",
            "params" => %{"name" => "question", "arguments" => %{"questions" => questions}}
          }},
         header
       ),
       do: match?([%{"header" => ^header}], questions)

  defp redispatched_question_header?(_message, _header), do: false

  defp question_answer_response(id, answer) do
    JsonRpc.success_response(id, %{
      "content" => [
        %{"type" => "text", "text" => Jason.encode!(%{"answers" => [%{"answer" => answer}]})}
      ]
    })
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
      task_id = task_fixture(scope).id

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

    test "forwards prompt model to title generation job", %{
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
            "model" => %{"provider" => "openrouter", "value" => "openai/gpt-5.5"},
            "traits" => ["react", "typescript"]
          }
        )
      )

      %{assigns: assigns} = :sys.get_state(socket.channel_pid)

      assert assigns.last_execution.project_traits == [:react, :typescript]

      assert_enqueued(
        worker: GenerateTitle,
        args: %{
          user_id: user.id,
          task_id: task_id,
          model: "openrouter:openai/gpt-5.5"
        }
      )

      assert_agent_turn_complete(task_id)
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

      # Broadcast via PubSub - this is what Tasks.request_client_tool does in production
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        task_topic(task_id),
        {:interaction, tool_call, 1}
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
        {:interaction, tool_call, 1}
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
        task_topic(task_id),
        {:interaction, tool_call2, 1}
      )

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "params" => %{"name" => "ownTool"}
      })
    end

    test "channel handles thinking chunk without crashing", %{
      socket: socket,
      task_id: task_id
    } do
      # Thinking chunks and empty-text chunks are silently dropped
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        task_topic(task_id),
        execution_chunk(:thinking, "reasoning...")
      )

      refute_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "agent_thinking_chunk"}}
      })

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        task_topic(task_id),
        execution_chunk(:content, "")
      )

      refute_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "agent_message_chunk"}}
      })

      # Channel should still be alive and functional
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        task_topic(task_id),
        execution_chunk(:content, "after thinking")
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
        task_topic(task_id),
        agent_failed("Rate limit exceeded")
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
      :sys.replace_state(socket.channel_pid, fn state ->
        put_in(state.assigns[:pending_prompt], %{
          turn_number: 1,
          jsonrpc_id: 42
        })
      end)

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        task_topic(task_id),
        agent_failed("No API key available")
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
        task_topic(task_id),
        agent_failed("Connection failed")
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

    test "sends agent_turn_complete notification when pending_prompt is nil", %{
      socket: socket,
      task_id: task_id
    } do
      # Simulate: execution was resumed after tool result (no pending prompt),
      # then the agent completes. There's no JSON-RPC request to respond to.
      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, task_topic(task_id), agent_completed())

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
  end

  describe "MCP tool call result extraction" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id, scope: scope}
    end

    test "extracts text content from MCP tool result", %{
      socket: socket,
      task_id: task_id,
      scope: scope
    } do
      tool_call =
        tool_call("call_123", "consoleLog", %{"message" => "hello"})

      turn_number = start_turn_fixture(scope, task_id)
      register_tool_receiver(tool_call.tool_call_id)

      {:ok, _interaction} = persist_tool_call_fixture(scope, task_id, turn_number, tool_call)

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "id" => mcp_request_id,
        "params" => %{"name" => "consoleLog", "callId" => "call_123"}
      })

      assert is_integer(mcp_request_id)

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

    test "wordpress completes after tools/list without filesystem tool calls", %{scope: scope} do
      {socket, _task_id} = join_task_channel(scope, framework: "wordpress")

      complete_mcp_handshake(socket, load_project_context: false)

      refute_push("mcp:message", %{"method" => "tools/call"})

      channel_socket = :sys.get_state(socket.channel_pid)
      assert channel_socket.assigns.mcp_status == :ready
    end
  end

  describe "MCP response validation" do
    import ExUnit.CaptureLog

    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id, scope: scope}
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

    test "accepts valid MCP response", %{socket: socket, task_id: task_id, scope: scope} do
      tool_call = tool_call("call_valid_test", "testTool")
      tool_call_id = tool_call.tool_call_id
      turn_number = start_turn_fixture(scope, task_id)
      register_tool_receiver(tool_call.tool_call_id)

      {:ok, _interaction} = persist_tool_call_fixture(scope, task_id, turn_number, tool_call)

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "id" => mcp_request_id,
        "params" => %{"callId" => ^tool_call_id}
      })

      assert is_integer(mcp_request_id)

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

    test "ignores MCP responses with string IDs instead of crashing", %{socket: socket} do
      log =
        capture_log(fn ->
          push(socket, "mcp:message", JsonRpc.success_response("unknown-success", %{}))

          push(
            socket,
            "mcp:message",
            JsonRpc.error_response("unknown-error", -32_000, "Tool failed")
          )

          :sys.get_state(socket.channel_pid)
        end)

      assert Process.alive?(socket.channel_pid)
      assert log =~ ~s(Received MCP response for unknown request_id: "unknown-success")
      assert log =~ ~s(Received MCP error for unknown request_id: "unknown-error")
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
      assert_receive {:interaction, %Tasks.Interaction.UserMessage{}, _turn_number}
      assert_agent_turn_complete(socket.assigns.task_id)
    end
  end

  describe "session/cancel" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "cancel resolves pending prompt with stopReason 'cancelled'", %{
      socket: socket,
      task_id: task_id
    } do
      :sys.replace_state(socket.channel_pid, fn state ->
        put_in(state.assigns[:pending_prompt], %{
          turn_number: 1,
          jsonrpc_id: 99
        })
      end)

      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, task_topic(task_id), agent_cancelled())

      # The pending prompt should resolve with stopReason: "cancelled"
      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 99,
        "result" => %{"stopReason" => "cancelled"}
      })
    end
  end

  describe "tool_call chunk streaming" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "deduplicates tool_call_create when interaction arrives after tool_call", %{
      socket: socket,
      task_id: _task_id
    } do
      tool_call_id = "call_dedup_#{:rand.uniform(1_000_000)}"

      # Step 1: Send tool_call chunk (early streaming notification)
      send(socket.channel_pid, execution_tool_call(tool_call_id, "write_file"))
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

      send(socket.channel_pid, {:interaction, tc, 1})
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

    test "sends tool_call_create for interactions without prior tool_call", %{
      socket: socket,
      task_id: task_id
    } do
      # Tool calls that arrive without a prior tool_call should still get
      # the normal tool_call_create notification
      tool_call_id = "call_no_start_#{:rand.uniform(1_000_000)}"

      tc = tool_call(tool_call_id, "take_screenshot")

      send(socket.channel_pid, {:interaction, tc, 1})
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
  end

  describe "reconnect re-executes unresolved tool calls" do
    setup %{scope: scope} do
      task_id = task_fixture(scope).id

      tool_call_id = "tc_question_#{System.unique_integer([:positive])}"
      tool_call = question_tool_call(tool_call_id, "Test", "A")

      user_message_fixture(scope, task_id, [%{"type" => "text", "text" => "ask me a question"}])
      turn_number = latest_turn_number(task_id)

      Tasks.agent_replied(scope, task_id, turn_number, "", %{
        "tool_calls" => [tool_call_metadata(tool_call)]
      })

      Tasks.request_client_tool(scope, task_id, turn_number, tool_call)

      {:ok, task_id: task_id, scope: scope, tool_call_id: tool_call_id}
    end

    test "e2e: restart → session/load → tools/call → answer → tool result persisted", %{
      scope: scope,
      task_id: task_id,
      tool_call_id: tool_call_id
    } do
      turn_number = latest_turn_number(task_id)

      Tasks.handle_swarm_event(scope, task_id, turn_number, {:terminated, :shutdown})

      {:ok, task} = Tasks.get_task(scope, task_id)
      refute Enum.any?(task.interactions, &match?(%Interaction.AgentError{}, &1))

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

      assert tools_call, "tools/call for question not found in #{length(messages)} messages"

      {"mcp:message", %{"id" => mcp_request_id, "params" => %{"callId" => ^tool_call_id}}} =
        tools_call

      assert is_integer(mcp_request_id)

      push(socket, "mcp:message", question_answer_response(mcp_request_id, "A"))

      :sys.get_state(socket.channel_pid)

      {:ok, task} = Tasks.get_task(scope, task_id)
      tool_results = Enum.filter(task.interactions, &match?(%Tasks.Interaction.ToolResult{}, &1))

      assert [%Tasks.Interaction.ToolResult{tool_call_id: ^tool_call_id, is_error: false}] =
               tool_results

      assert_agent_turn_complete(task_id)
    end

    test "e2e: restart → same-browser stale answer id → tool result persisted", %{
      scope: scope,
      task_id: task_id,
      tool_call_id: tool_call_id
    } do
      turn_number = latest_turn_number(task_id)

      Tasks.handle_swarm_event(scope, task_id, turn_number, {:terminated, :shutdown})

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      complete_mcp_handshake(socket)

      push(socket, "mcp:message", question_answer_response(tool_call_id, "A"))
      :sys.get_state(socket.channel_pid)

      {:ok, task} = Tasks.get_task(scope, task_id)
      tool_results = Enum.filter(task.interactions, &match?(%Tasks.Interaction.ToolResult{}, &1))

      assert [%Tasks.Interaction.ToolResult{tool_call_id: ^tool_call_id, is_error: false}] =
               tool_results

      assert_agent_turn_complete(task_id)
    end

    test "e2e: restart → stale answer → resumed completion → next prompt accepted", %{
      scope: scope,
      task_id: task_id,
      tool_call_id: tool_call_id
    } do
      turn_number = latest_turn_number(task_id)

      Tasks.handle_swarm_event(scope, task_id, turn_number, {:terminated, :shutdown})

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      complete_mcp_handshake(socket)

      push(socket, "mcp:message", question_answer_response(tool_call_id, "A"))
      :sys.get_state(socket.channel_pid)

      assert_agent_turn_complete(task_id)

      push(socket, "acp:message", build_prompt_request(id: 77, text: "next prompt"))
      :sys.get_state(socket.channel_pid)

      refute_push(
        "acp:message",
        %{"id" => 77, "error" => %{"message" => "Agent already running"}},
        100
      )

      assert_push(
        "acp:message",
        %{"id" => 77, "result" => %{"stopReason" => "end_turn"}},
        5_000
      )

      {:ok, task} = Tasks.get_task(scope, task_id)

      assert 2 == Enum.count(task.interactions, &match?(%Interaction.UserMessage{}, &1))
    end

    test "e2e: reconnect re-dispatches unresolved tool calls from a later turn after a prior turn completed",
         %{
           scope: scope
         } do
      task_id = task_fixture(scope).id
      first_tool_call_id = "tc_question_#{System.unique_integer([:positive])}"
      second_tool_call_id = "tc_question_#{System.unique_integer([:positive])}"

      first_tc = question_tool_call(first_tool_call_id, "First turn", "A")
      second_tc = question_tool_call(second_tool_call_id, "Second turn", "B")

      user_message_fixture(scope, task_id, user_content("first turn"))
      first_turn_number = latest_turn_number(task_id)

      Tasks.agent_replied(scope, task_id, first_turn_number, "", %{
        "tool_calls" => [tool_call_metadata(first_tc)]
      })

      Tasks.request_client_tool(scope, task_id, first_turn_number, first_tc)

      Tasks.resolve_tool_request(
        scope,
        task_id,
        %{id: first_tool_call_id, name: "question"},
        MCP.tool_result_json(%{"answers" => [%{"answer" => "A"}]}),
        false
      )

      Tasks.agent_replied(scope, task_id, first_turn_number, "First done")
      Tasks.record_agent_run_result(scope, task_id, first_turn_number, :completed)

      user_message_fixture(scope, task_id, user_content("second turn"))
      second_turn_number = latest_turn_number(task_id)

      Tasks.agent_replied(scope, task_id, second_turn_number, "", %{
        "tool_calls" => [tool_call_metadata(second_tc)]
      })

      Tasks.request_client_tool(scope, task_id, second_turn_number, second_tc)

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      complete_mcp_handshake(socket)

      push(socket, "acp:message", build_acp_request("session/load", 1, %{"sessionId" => task_id}))
      :sys.get_state(socket.channel_pid)

      messages = collect_all_pushes()

      assert Enum.any?(messages, &redispatched_question_header?(&1, "Second turn"))
      refute Enum.any?(messages, &redispatched_question_header?(&1, "First turn"))
    end

    test "e2e: session/load before MCP handshake → answer after handshake → persisted", %{
      scope: scope,
      task_id: task_id,
      tool_call_id: tool_call_id
    } do
      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      :sys.get_state(socket.channel_pid)
      assert_push("mcp:message", %{"id" => init_request_id, "method" => "initialize"})

      push(
        socket,
        "acp:message",
        build_acp_request("session/load", 1, %{"sessionId" => task_id})
      )

      :sys.get_state(socket.channel_pid)

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

      assert_push(
        "mcp:message",
        %{"method" => "tools/call", "id" => mcp_request_id, "params" => %{"name" => "question"}},
        2_000
      )

      push(socket, "mcp:message", question_answer_response(mcp_request_id, "A"))

      :sys.get_state(socket.channel_pid)

      {:ok, task} = Tasks.get_task(scope, task_id)
      tool_results = Enum.filter(task.interactions, &match?(%Tasks.Interaction.ToolResult{}, &1))

      assert [%Tasks.Interaction.ToolResult{tool_call_id: ^tool_call_id, is_error: false}] =
               tool_results

      assert_agent_turn_complete(task_id)
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

      assert is_integer(session_load_idx), "session/load success not found"

      tools_call_idx =
        Enum.find_index(messages, fn
          {"mcp:message", %{"method" => "tools/call", "params" => %{"name" => "question"}}} ->
            true

          _ ->
            false
        end)

      assert is_integer(tools_call_idx), "tools/call not found"

      assert session_load_idx < tools_call_idx,
             "tools/call (idx #{tools_call_idx}) arrived BEFORE session/load success (idx #{session_load_idx})"
    end

    test "resolved tool calls are NOT re-dispatched", %{
      scope: scope,
      task_id: task_id,
      tool_call_id: tool_call_id
    } do
      Tasks.resolve_tool_request(
        scope,
        task_id,
        %{id: tool_call_id, name: "question"},
        MCP.tool_result_json(%{"answers" => [%{"answer" => "A"}]}),
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

  describe "retry flow" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "retryable error schedules retry and records AgentRetry only when timer fires", %{
      scope: scope,
      socket: socket,
      task_id: task_id
    } do
      error_interaction = broadcast_retryable_error(scope, task_id)

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

      retried_error_id = error_interaction.id

      {:ok, task} = Tasks.get_task(scope, task_id)

      refute Enum.any?(
               task.interactions,
               &match?(
                 %Interaction.AgentRetry{
                   retried_error_id: ^retried_error_id
                 },
                 &1
               )
             )

      %{assigns: %{retry_state: retry_state}} = :sys.get_state(socket.channel_pid)
      assert retry_state.retried_error_id == retried_error_id

      send(socket.channel_pid, {:fire_retry, make_ref()})
      :sys.get_state(socket.channel_pid)

      {:ok, task} = Tasks.get_task(scope, task_id)
      refute Enum.any?(task.interactions, &match?(%Interaction.AgentRetry{}, &1))

      send(socket.channel_pid, {:fire_retry, retry_state.timer_token})
      :sys.get_state(socket.channel_pid)

      {:ok, task} = Tasks.get_task(scope, task_id)

      assert Enum.any?(
               task.interactions,
               &match?(
                 %Interaction.AgentRetry{
                   retried_error_id: ^retried_error_id
                 },
                 &1
               )
             )
    end

    test "non-retryable error pushes error notification without retryAt", %{
      socket: _socket,
      task_id: task_id
    } do
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        task_topic(task_id),
        agent_failed("Auth failed", "auth")
      )

      assert_push("acp:message", %{
        "params" => %{
          "update" => %{"sessionUpdate" => "error", "message" => "Auth failed"}
        }
      })
    end

    test "session/retry_turn notification creates AgentRetry interaction", %{
      scope: scope,
      socket: socket,
      task_id: task_id
    } do
      user_message_fixture(scope, task_id, [%{"type" => "text", "text" => "retry me"}])
      turn_number = latest_turn_number(task_id)

      {:ok, error_interaction} =
        Tasks.record_agent_run_result(scope, task_id, turn_number, {:failed, "Rate limited"})

      retried_error_id = error_interaction.id

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
                 %Interaction.AgentRetry{
                   retried_error_id: ^retried_error_id
                 },
                 &1
               )
             )

      assert_agent_turn_complete(task_id)
    end

    test "cancel during retry countdown clears pending retry without recording retry", %{
      scope: scope,
      socket: socket,
      task_id: task_id
    } do
      broadcast_retryable_error(scope, task_id)

      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "error", "attempt" => 1, "retryAt" => _}}
      })

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

      {:ok, task} = Tasks.get_task(scope, task_id)

      refute Enum.any?(
               task.interactions,
               &match?(
                 %Interaction.AgentRetry{},
                 &1
               )
             )

      refute Enum.any?(
               task.interactions,
               &match?(%Interaction.AgentError{kind: "cancelled"}, &1)
             )
    end
  end
end
