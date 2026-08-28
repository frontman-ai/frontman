defmodule FrontmanServerWeb.TaskChannelTest do
  use FrontmanServerWeb.ChannelCase, async: false
  use Oban.Testing, repo: FrontmanServer.Repo

  import FrontmanServer.InteractionCase.Helpers,
    only: [
      agent_error: 2,
      agent_error: 4,
      interaction_event: 2,
      tool_call: 2,
      tool_call: 3,
      turn_started: 1
    ]

  import FrontmanServer.Test.Fixtures.Tasks
  import ExUnit.CaptureLog

  alias FrontmanServer.InteractionCase.Helpers
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.LLMProviderMock
  alias FrontmanServer.Test.Fixtures.LLMProvider
  alias FrontmanServer.Test.Fixtures.ReqLLMResponses
  alias FrontmanServer.Workers.GenerateTitle
  alias FrontmanServerWeb.UserSocket

  alias FrontmanServer.Tasks.Interaction
  alias ModelContextProtocol, as: MCP

  @persisted_restart_model "openrouter:openai/gpt-5.5"
  @logged_output_schema %{
    "type" => "object",
    "properties" => %{"logged" => %{"type" => "boolean"}},
    "required" => ["logged"]
  }

  defp response_metadata(turn_started_id \\ "turn-1", ordinal \\ 0) do
    %{
      turn_started_id: turn_started_id,
      agent_id: "test-frontman",
      ordinal: ordinal,
      timestamp: ~U[2026-07-14 12:30:01.000000Z]
    }
  end

  defp execution_chunk(type, text),
    do: execution_chunk(1, type, text)

  defp execution_chunk(turn_number, type, text, metadata \\ response_metadata()),
    do: {:execution_chunk, turn_number, metadata, %{type: type, text: text}}

  defp execution_tool_call(id, name),
    do:
      {:execution_chunk, 1, response_metadata(),
       %{type: :tool_call, name: name, arguments: %{}, metadata: %{id: id, index: 0}}}

  defp activate_turn(socket, turn_started_id) do
    turn = %{turn_started([]) | id: turn_started_id}
    send(socket.channel_pid, interaction_event(turn, 1))
    assert_state_update_running(socket.assigns.task_id)
  end

  defp agent_failed(message, category \\ "unknown") do
    interaction_event(agent_error(message, "failed", false, category), 1)
  end

  defp broadcast_retryable_error(scope, task_id) do
    user_message_fixture(scope, task_id, [%{"type" => "text", "text" => "retry me"}])
    turn_number = latest_turn_number(task_id)

    {:ok, error_interaction} =
      Tasks.record_execution_outcome(
        scope,
        task_id,
        turn_number,
        {:failed, "Rate limited", true, "rate_limit"}
      )

    error_interaction
  end

  defp agent_cancelled do
    interaction_event(agent_error("Cancelled", "cancelled"), 1)
  end

  defp collect_all_pushes(acc \\ []) do
    receive do
      %Phoenix.Socket.Message{event: event, payload: payload} ->
        collect_all_pushes([{event, payload} | acc])
    after
      200 -> Enum.reverse(acc)
    end
  end

  defp assert_state_update_idle(task_id) do
    assert_push(
      "acp:message",
      %{
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{"sessionUpdate" => "state_update", "state" => "idle"}
        }
      },
      1_000
    )

    refute_running_eventually(task_id)
  end

  defp assert_state_update_running(task_id) do
    assert_push(
      "acp:message",
      %{
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{"sessionUpdate" => "state_update", "state" => "running"}
        }
      },
      1_000
    )
  end

  defp assert_state_update_running_then_idle(task_id) do
    assert_state_update_running(task_id)
    assert_state_update_idle(task_id)
  end

  defp refute_running_eventually(task_id, attempts \\ 50)

  defp refute_running_eventually(task_id, attempts) when attempts > 0 do
    case SwarmAi.running?(FrontmanServer.AgentRuntime, task_id) do
      false ->
        :ok

      true ->
        Process.sleep(10)
        refute_running_eventually(task_id, attempts - 1)
    end
  end

  defp refute_running_eventually(task_id, 0) do
    refute SwarmAi.running?(FrontmanServer.AgentRuntime, task_id),
           "Agent should not be running after completion"
  end

  defp register_tool_receiver(tool_call_id) do
    Registry.register(FrontmanServer.ProcessRegistry, {:tool_call, tool_call_id}, %{
      caller_pid: self()
    })
  end

  defp assert_tool_result_crash(context, content, reason) do
    %{socket: socket, task_id: task_id, scope: scope} = context
    result = %{"resultType" => "complete", "content" => content}
    result = Map.put(result, "structuredContent", %{"logged" => true})
    tool_call = tool_call("call_invalid_result", "testTool")
    register_tool_receiver(tool_call.tool_call_id)

    persist_tool_call_fixture(scope, task_id, start_turn_fixture(scope, task_id), tool_call)

    assert_push("mcp:message", %{"method" => "tools/call", "id" => mcp_request_id})
    channel_pid = socket.channel_pid
    Process.flag(:trap_exit, true)
    push(socket, "mcp:message", JsonRpc.success_response(mcp_request_id, result))
    assert_receive {:EXIT, ^channel_pid, {%RuntimeError{message: message}, _stacktrace}}

    assert message =~
             "#{reason} for task #{task_id}, tool testTool, call #{tool_call.tool_call_id}"

    {:ok, task} = Tasks.get_task(scope, task_id)
    refute Enum.any?(Tasks.interactions(task), &match?(%Interaction.ToolResult{}, &1))
  end

  defp assert_unsupported_tool_result(context, content, content_type) do
    %{socket: socket, task_id: task_id, scope: scope} = context
    tool_call = tool_call("call_unsupported_result", "testTool")
    tool_call_id = tool_call.tool_call_id
    message = "Unsupported MCP tool result content type: #{content_type}"
    register_tool_receiver(tool_call_id)

    persist_tool_call_fixture(scope, task_id, start_turn_fixture(scope, task_id), tool_call)

    assert_push("mcp:message", %{"method" => "tools/call", "id" => mcp_request_id})

    result = %{
      "resultType" => "complete",
      "content" => content,
      "structuredContent" => %{"logged" => true}
    }

    push(socket, "mcp:message", JsonRpc.success_response(mcp_request_id, result))
    :sys.get_state(socket.channel_pid)

    assert Process.alive?(socket.channel_pid)

    assert_receive {:tool_result, ^tool_call_id,
                    [%SwarmAi.Message.ContentPart{type: :text, text: ^message}], true}

    assert {:ok, task} = Tasks.get_task(scope, task_id)

    assert Enum.any?(
             Tasks.interactions(task),
             &match?(%Interaction.ToolResult{is_error: true}, &1)
           )
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

  defp question_answer_response(id, answer, result_overrides \\ %{}) do
    result =
      Map.merge(
        %{
          "resultType" => "complete",
          "content" => [
            %{
              "type" => "text",
              "text" => Jason.encode!(%{"answers" => [%{"answer" => answer}]})
            }
          ]
        },
        result_overrides
      )

    JsonRpc.success_response(id, result)
  end

  defp expect_resumed_model do
    parent = self()

    Mox.expect(LLMProviderMock, :stream_text, fn model, _messages, _opts ->
      send(parent, {:resumed_model, model})
      ReqLLMResponses.response("Resumed")
    end)
  end

  describe "join task:<id>" do
    test "allows one connection per task", %{scope: scope} do
      task_id = task_fixture(scope).id

      {:ok, %{task_id: ^task_id}, _socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      other = socket(UserSocket, "other_user_id", %{scope: scope})

      assert {:error, %{reason: "task_already_joined"}} =
               subscribe_and_join(other, "task:#{task_id}", %{})
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
      scope: scope,
      task_id: task_id,
      user: user
    } do
      complete_mcp_handshake(socket)
      message_id = Ecto.UUID.generate()

      ref =
        push(
          socket,
          "acp:message",
          build_prompt_request(
            message_id: message_id,
            _meta: %{
              "model" => %{"provider" => "openrouter", "value" => "openai/gpt-5.5"},
              "agent" => "test-frontman",
              "traits" => ["react", "typescript"]
            }
          )
        )

      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "user_message_chunk",
            "messageId" => ^message_id,
            "content" => %{"type" => "text", "text" => "Hello"}
          }
        }
      })

      assert_reply(ref, :ok, %{"acp:message" => response})
      assert response["result"] == %{}

      assert_enqueued(
        worker: GenerateTitle,
        args: %{
          user_id: user.id,
          task_id: task_id,
          model: "openrouter:openai/gpt-5.5"
        }
      )

      assert_state_update_running(task_id)

      assert_push("acp:message", %{
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "agent_message_chunk",
            "messageId" => response_message_id,
            "content" => %{"type" => "text", "text" => "Test response"},
            "_meta" => %{
              "frontman.dev/agentId" => "test-frontman",
              "frontman.dev/timestamp" => response_timestamp
            }
          }
        }
      })

      assert_state_update_idle(task_id)

      assert {:ok, task} = Tasks.get_task(scope, task_id)
      assert Enum.any?(task.interaction_rows, &(&1.type == :user_message and &1.id == message_id))
      turn_row = Enum.find(task.interaction_rows, &(&1.type == :turn_started))
      response = Enum.find(Tasks.interactions(task), &match?(%Interaction.AgentResponse{}, &1))
      assert response_message_id == "#{turn_row.id}:0"
      assert DateTime.to_iso8601(response.timestamp) == response_timestamp
    end

    test "live user chunks equal replayed persisted chunks", %{socket: socket, task_id: task_id} do
      message_id = Ecto.UUID.generate()

      selector_annotation =
        Helpers.annotation_block("selector-ann", "button", nil, nil, nil, index: 0)
        |> put_in(
          ["_meta", "selector"],
          ".toolbar > button[data-action='save']"
        )
        |> put_in(
          ["resource"],
          %{
            "uri" => "selector://.toolbar > button[data-action='save']",
            "mimeType" => "text/plain",
            "text" => "Annotated element: <button> matching .toolbar > button[data-action='save']"
          }
        )

      content_blocks = [
        Helpers.text_block("Match these persisted chunks"),
        selector_annotation,
        Helpers.screenshot_block("selector-ann", "c2NyZWVuc2hvdA=="),
        Helpers.current_page_block("https://example.com/editor")
      ]

      ref =
        push(
          socket,
          "acp:message",
          build_acp_request("session/prompt", 46, %{
            "prompt" => content_blocks,
            "_meta" => %{
              "model" => %{"provider" => "openrouter", "value" => "google/gemini-3.1-pro-preview"},
              "agent" => "test-frontman",
              "frontman.dev/messageId" => message_id
            }
          })
        )

      assert_reply(ref, :ok, %{"acp:message" => %{"result" => %{}}})
      live_chunks = collect_all_pushes() |> user_message_updates()

      push(
        socket,
        "acp:message",
        build_acp_request("session/load", 47, %{"sessionId" => task_id})
      )

      :sys.get_state(socket.channel_pid)
      replayed_chunks = collect_all_pushes() |> user_message_updates()

      assert length(live_chunks) == length(content_blocks)
      assert Enum.all?(live_chunks, &(&1["messageId"] == message_id))
      assert replayed_chunks == live_chunks
    end

    test "uses configured default agent when agent is missing", %{
      socket: socket,
      scope: scope,
      task_id: task_id
    } do
      ref =
        push(
          socket,
          "acp:message",
          build_prompt_request(
            id: 45,
            _meta: %{
              "model" => %{"provider" => "openrouter", "value" => "google/gemini-3.1-pro-preview"}
            }
          )
        )

      assert_push("acp:message", %{
        "params" => %{
          "update" => %{
            "sessionUpdate" => "user_message_chunk",
            "_meta" => %{"frontman.dev/agentId" => "test-planner"}
          }
        }
      })

      assert_reply(ref, :ok, %{"acp:message" => %{"result" => %{}}})

      assert {:ok, task} = Tasks.get_task(scope, task_id)
      assert [%Interaction.UserMessage{agent_id: "test-planner"}] = Tasks.interactions(task)
    end

    test "returns invalid params when agent is unknown", %{
      socket: socket,
      scope: scope,
      task_id: task_id
    } do
      ref =
        push(
          socket,
          "acp:message",
          build_prompt_request(
            _meta: %{
              "model" => %{"provider" => "openrouter", "value" => "google/gemini-3.1-pro-preview"},
              "agent" => "missing"
            }
          )
        )

      assert_reply(ref, :ok, %{"acp:message" => response})
      assert response["error"]["code"] == JsonRpc.error_invalid_params()
      assert response["error"]["message"] == "Unknown agent"

      assert {:ok, task} = Tasks.get_task(scope, task_id)
      assert Tasks.interactions(task) == []
    end

    test "rejects duplicate message UUIDs", %{socket: socket} do
      message_id = Ecto.UUID.generate()
      first_ref = push(socket, "acp:message", build_prompt_request(message_id: message_id))
      assert_push("acp:message", %{"params" => %{"update" => %{"messageId" => ^message_id}}})
      assert_reply(first_ref, :ok, %{"acp:message" => %{"result" => %{}}})

      duplicate_ref = push(socket, "acp:message", build_prompt_request(message_id: message_id))
      assert_reply(duplicate_ref, :ok, %{"acp:message" => duplicate_response})
      assert duplicate_response["error"]["code"] == JsonRpc.error_invalid_params()
      assert duplicate_response["error"]["message"] == "Message ID has already been taken"
    end

    for {name, message_id, expected_message} <- [
          {"missing", :missing, "Message ID can't be blank"},
          {"nil", nil, "Message ID can't be blank"},
          {"empty", "", "Message ID can't be blank"},
          {"malformed", "not-a-uuid", "Message ID is invalid"},
          {"non-string", 123, "Message ID is invalid"}
        ] do
      test "rejects #{name} message ID without side effects", %{
        socket: socket,
        scope: scope,
        task_id: task_id
      } do
        meta = %{
          "model" => %{"provider" => "openrouter", "value" => "google/gemini-3.1-pro-preview"},
          "agent" => "test-frontman"
        }

        meta =
          case unquote(Macro.escape(message_id)) do
            :missing -> meta
            message_id -> Map.put(meta, "frontman.dev/messageId", message_id)
          end

        ref =
          push(
            socket,
            "acp:message",
            build_acp_request("session/prompt", 43, %{
              "prompt" => [%{"type" => "text", "text" => "Hello"}],
              "_meta" => meta
            })
          )

        assert_reply(ref, :ok, %{"acp:message" => response})
        assert response["error"]["code"] == JsonRpc.error_invalid_params()
        assert response["error"]["message"] == unquote(expected_message)

        assert {:ok, task} = Tasks.get_task(scope, task_id)
        assert Tasks.interactions(task) == []
        assert all_enqueued(worker: GenerateTitle) == []

        refute_push(
          "acp:message",
          %{"params" => %{"update" => %{"sessionUpdate" => "user_message_chunk"}}},
          100
        )

        refute_push("acp:message", %{"params" => %{"update" => %{"state" => "running"}}}, 100)
      end
    end

    test "returns invalid params for malformed text content block", %{socket: socket} do
      complete_mcp_handshake(socket)

      ref =
        push(
          socket,
          "acp:message",
          build_acp_request("session/prompt", 44, %{
            "prompt" => [%{"type" => "text", "text" => ""}],
            "_meta" => %{
              "model" => %{"provider" => "openrouter", "value" => "google/gemini-3.1-pro-preview"},
              "agent" => "test-frontman",
              "frontman.dev/messageId" => Ecto.UUID.generate()
            }
          })
        )

      assert_reply(ref, :ok, %{"acp:message" => response})
      assert response["error"]["code"] == JsonRpc.error_invalid_params()

      assert response["error"]["message"] ==
               "text content block must include non-empty string text"
    end

    test "accepts before MCP is ready and drains after initialization", %{
      socket: socket,
      task_id: task_id
    } do
      ref = push(socket, "acp:message", build_prompt_request())

      assert_push("acp:message", %{
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{"sessionUpdate" => "user_message_chunk"}
        }
      })

      assert_reply(ref, :ok, %{"acp:message" => %{"result" => %{}}})
      refute_push("acp:message", %{"params" => %{"update" => %{"state" => "running"}}}, 100)

      complete_mcp_handshake(socket)

      assert_state_update_running_then_idle(task_id)
    end

    test "queued follow-up starts after current turn completes", %{
      socket: socket,
      task_id: task_id
    } do
      LLMProvider.expect_llm_responses([
        {:delay, "first response", 200},
        "second response"
      ])

      complete_mcp_handshake(socket)
      first_message_id = Ecto.UUID.generate()
      second_message_id = Ecto.UUID.generate()

      first_ref =
        push(
          socket,
          "acp:message",
          build_prompt_request(id: 11, message_id: first_message_id, text: "first")
        )

      assert_push("acp:message", %{
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{"sessionUpdate" => "user_message_chunk", "messageId" => ^first_message_id}
        }
      })

      assert_reply(first_ref, :ok, %{"acp:message" => %{"id" => 11, "result" => %{}}})
      :sys.get_state(socket.channel_pid)
      assert_state_update_running(task_id)

      second_ref =
        push(
          socket,
          "acp:message",
          build_prompt_request(id: 12, message_id: second_message_id, text: "second")
        )

      assert_push("acp:message", %{
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "user_message_chunk",
            "messageId" => ^second_message_id,
            "content" => %{"type" => "text", "text" => "second"}
          }
        }
      })

      assert_reply(second_ref, :ok, %{"acp:message" => %{"id" => 12, "result" => %{}}})
      refute_push("acp:message", %{"params" => %{"update" => %{"state" => "running"}}}, 100)

      assert_state_update_idle(task_id)
      assert_state_update_running_then_idle(task_id)

      assert {:ok, task} = Tasks.get_task(socket.assigns.scope, task_id)

      assert [^first_message_id, ^second_message_id] =
               task.interaction_rows
               |> Enum.filter(&(&1.type == :turn_started))
               |> Enum.flat_map(& &1.data.user_message_ids)
    end
  end

  defp user_message_updates(pushes) do
    for {"acp:message",
         %{
           "params" => %{
             "update" => %{"sessionUpdate" => "user_message_chunk"} = update
           }
         }} <- pushes,
        do: update
  end

  test "keeps response identity across assistant chunks", %{scope: scope} do
    {socket, _task_id} = join_task_channel(scope)
    turn_started_id = Ecto.UUID.generate()
    metadata = response_metadata(turn_started_id)
    message_id = "#{turn_started_id}:0"
    activate_turn(socket, turn_started_id)

    for text <- ["first", "second"] do
      send(socket.channel_pid, execution_chunk(1, :content, text, metadata))

      assert_push("acp:message", %{
        "params" => %{
          "update" => %{
            "sessionUpdate" => "agent_message_chunk",
            "messageId" => ^message_id,
            "content" => %{"type" => "text", "text" => ^text},
            "_meta" => %{
              "frontman.dev/agentId" => "test-frontman",
              "frontman.dev/timestamp" => "2026-07-14T12:30:01.000000Z"
            }
          }
        }
      })
    end
  end

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
      tool_call =
        tool_call("call_pubsub_#{:rand.uniform(1_000_000)}", "testTool", %{"key" => "value"})

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        task_topic(task_id),
        interaction_event(tool_call, 1)
      )

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "params" => %{"name" => "testTool"}
      })
    end

    test "channel does NOT receive broadcasts to different topics", %{
      socket: _socket,
      task_id: task_id
    } do
      different_topic = "task:different_#{:rand.uniform(1_000_000)}"

      tool_call =
        tool_call("call_different_#{:rand.uniform(1_000_000)}", "otherTool")

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        different_topic,
        interaction_event(tool_call, 1)
      )

      refute_push("mcp:message", %{"params" => %{"name" => "otherTool"}})

      tool_call2 = %{
        tool_call
        | tool_call_id: "call_own_#{:rand.uniform(1_000_000)}",
          tool_name: "ownTool"
      }

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        task_topic(task_id),
        interaction_event(tool_call2, 1)
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
      activate_turn(socket, "turn-1")

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

    test "turn error sends only session/update", %{
      socket: _socket,
      task_id: task_id
    } do
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        task_topic(task_id),
        agent_failed("No API key available")
      )

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "update" => %{
            "sessionUpdate" => "error",
            "message" => "No API key available"
          }
        }
      })

      refute_push("acp:message", %{"error" => %{"code" => -32_000}})
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
        "params" => %{
          "name" => "consoleLog",
          "_meta" => %{
            "ai.frontman/execution-context" => %{"callId" => "call_123"}
          }
        }
      })

      assert is_integer(mcp_request_id)

      mcp_tool_result = %{
        "resultType" => "complete",
        "content" => [%{"type" => "text", "text" => "Logged: hello"}],
        "structuredContent" => %{"logged" => true}
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
            "rawOutput" => %{"logged" => true},
            "content" => [
              %{
                "type" => "content",
                "content" => %{"type" => "text", "text" => "Logged: hello"}
              }
            ]
          }
        }
      })
    end

    test "validates structured content only when tool errors provide it" do
      result = %{
        "resultType" => "complete",
        "content" => [%{"type" => "text", "text" => "tool failed"}],
        "isError" => true
      }

      assert :ok =
               ModelContextProtocol.Schema.validate_call_tool_result(
                 result,
                 @logged_output_schema
               )

      assert :error =
               result
               |> Map.put("structuredContent", %{})
               |> ModelContextProtocol.Schema.validate_call_tool_result(@logged_output_schema)
    end
  end

  describe "todo tool updates" do
    test "pushes tool completion and current plan for a successful todo write", %{
      scope: scope
    } do
      {socket, task_id} = join_task_channel(scope)
      turn_number = start_turn_fixture(scope, task_id)

      tool_call = tool_call("todo-call", "todo_write", %{"todos" => []})
      {:ok, _interaction} = persist_tool_call_fixture(scope, task_id, turn_number, tool_call)
      collect_all_pushes()

      todo = %{
        "id" => Ecto.UUID.generate(),
        "content" => "Fix todo rendering",
        "active_form" => "Fixing todo rendering",
        "status" => "in_progress",
        "priority" => "high",
        "created_at" => DateTime.to_iso8601(DateTime.utc_now()),
        "updated_at" => DateTime.to_iso8601(DateTime.utc_now())
      }

      assert {:ok, _interaction, _executor_status} =
               Tasks.resolve_tool_request(
                 scope,
                 task_id,
                 %{id: "todo-call", name: "todo_write"},
                 %{"content" => [], "structuredContent" => %{"todos" => [todo]}},
                 turn_number: turn_number
               )

      :sys.get_state(socket.channel_pid)

      updates =
        collect_all_pushes()
        |> Enum.filter(fn {event, _payload} -> event == "acp:message" end)
        |> Enum.map(fn {_event, payload} -> get_in(payload, ["params", "update"]) end)

      assert [tool_update, plan_update] = updates

      assert tool_update == %{
               "sessionUpdate" => "tool_call_update",
               "toolCallId" => "todo-call",
               "status" => "completed",
               "rawOutput" => %{"todos" => [todo]},
               "content" => []
             }

      assert plan_update == %{
               "sessionUpdate" => "plan",
               "entries" => [
                 %{
                   "content" => "Fix todo rendering",
                   "status" => "in_progress",
                   "priority" => "high"
                 }
               ]
             }
    end
  end

  describe "MCP initialization" do
    test "sends MCP discovery request on join", %{scope: scope} do
      {_socket, _task_id} = join_task_channel(scope)

      expected_version = ModelContextProtocol.protocol_version()

      assert_push("mcp:message", %{
        "jsonrpc" => "2.0",
        "id" => _id,
        "method" => "server/discover",
        "params" => %{
          "_meta" => %{
            "io.modelcontextprotocol/protocolVersion" => ^expected_version,
            "io.modelcontextprotocol/clientInfo" => %{"name" => "frontman-server"}
          }
        }
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
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)

      complete_mcp_handshake(socket,
        tools: [
          %{
            "name" => "testTool",
            "inputSchema" => %{"type" => "object"},
            "outputSchema" => @logged_output_schema
          }
        ]
      )

      {:ok, socket: socket, task_id: task_id, scope: scope}
    end

    test "rejects response missing jsonrpc field", %{socket: socket} do
      log =
        capture_log(fn ->
          push(socket, "mcp:message", %{
            "id" => 999,
            "result" => %{"_meta" => %{"envApiKey" => "sk-fake-invalid-mcp-marker"}}
          })

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
      refute log =~ "sk-fake-invalid-mcp-marker"
      refute log =~ "envApiKey"
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
        "params" => %{
          "_meta" => %{
            "ai.frontman/execution-context" => %{"callId" => ^tool_call_id}
          }
        }
      })

      assert is_integer(mcp_request_id)

      image_data =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="

      mcp_result =
        image_data
        |> MCP.tool_result_image("image/png")
        |> Map.put("structuredContent", %{"logged" => true})
        |> Map.put("_meta", %{"envApiKey" => "sk-fake-valid-mcp-marker"})

      log =
        capture_log([level: :info], fn ->
          push(socket, "mcp:message", JsonRpc.success_response(mcp_request_id, mcp_result))
          :sys.get_state(socket.channel_pid)
        end)

      refute log =~ "sk-fake-valid-mcp-marker"
      refute log =~ "envApiKey"

      assert_receive {:tool_result, ^tool_call_id,
                      [
                        %SwarmAi.Message.ContentPart{
                          type: :image,
                          data: decoded_image_data,
                          media_type: "image/png"
                        }
                      ], false}

      assert decoded_image_data == Base.decode64!(image_data)

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{"status" => "completed"}
        }
      })
    end

    for {name, content, content_type} <- [
          {"audio", [%{"type" => "audio", "data" => "YXVkaW8=", "mimeType" => "audio/wav"}],
           "audio"},
          {"resource link",
           [%{"type" => "resource_link", "name" => "Example", "uri" => "https://example.com"}],
           "resource_link"},
          {"embedded text resource",
           [
             %{
               "type" => "resource",
               "resource" => %{"uri" => "file:///example.txt", "text" => "example"}
             }
           ], "resource"},
          {"embedded blob resource",
           [
             %{
               "type" => "resource",
               "resource" => %{"uri" => "file:///example.bin", "blob" => "YmxvYg=="}
             }
           ], "resource"},
          {"mixed supported and audio",
           [
             %{"type" => "text", "text" => "partial result"},
             %{"type" => "audio", "data" => "YXVkaW8=", "mimeType" => "audio/wav"}
           ], "audio"}
        ] do
      test "converts #{name} content to a tool error", context do
        assert_unsupported_tool_result(
          context,
          unquote(Macro.escape(content)),
          unquote(content_type)
        )
      end
    end

    test "crashes loudly for malformed MCP tool results", context do
      assert_tool_result_crash(context, "invalid", "Invalid MCP tools/call result")
    end

    test "rejects invalid image data before persistence", context do
      assert_tool_result_crash(
        context,
        [%{"type" => "image", "data" => "invalid", "mimeType" => "image/png"}],
        "Failed to store MCP tools/call result"
      )
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
      assert log =~ "Received MCP response for unknown request"
      assert log =~ "Received MCP error for unknown request"
      refute log =~ "unknown-success"
      refute log =~ "unknown-error"
    end
  end

  describe "session/load wake" do
    test "rejects a session ID different from the joined task", %{scope: scope} do
      task = task_fixture(scope)
      other_task = task_fixture(scope)

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task.id}", %{})

      push(
        socket,
        "acp:message",
        build_acp_request("session/load", 88, %{"sessionId" => other_task.id})
      )

      assert_push("acp:message", %{
        "id" => 88,
        "error" => %{"code" => -32_602, "message" => "Session does not match channel"}
      })
    end

    test "pushes history before a standard load result", %{scope: scope} do
      task = task_fixture(scope)
      {:ok, _message} = user_message_fixture(scope, task.id, user_content("history"))

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task.id}", %{})

      collect_all_pushes()

      push(
        socket,
        "acp:message",
        build_acp_request("session/load", 90, %{"sessionId" => task.id})
      )

      :sys.get_state(socket.channel_pid)

      messages =
        collect_all_pushes()
        |> Enum.filter(fn {event, _payload} -> event == "acp:message" end)
        |> Enum.map(&elem(&1, 1))

      assert [
               %{
                 "method" => "session/update",
                 "params" => %{"update" => %{"sessionUpdate" => "user_message_chunk"}}
               },
               %{
                 "id" => 90,
                 "result" => %{"configOptions" => _config_options}
               },
               %{
                 "method" => "session/update",
                 "params" => %{"update" => %{"sessionUpdate" => "plan", "entries" => []}}
               }
             ] = messages
    end

    test "restores current todo plan after the load result", %{scope: scope} do
      task = task_fixture(scope)
      turn_number = start_turn_fixture(scope, task.id)

      todo_call = tool_call("todo-replay", "todo_write", %{"todos" => []})
      {:ok, _interaction} = persist_tool_call_fixture(scope, task.id, turn_number, todo_call)

      todo = %{
        "id" => Ecto.UUID.generate(),
        "content" => "Restore todo plan",
        "active_form" => "Restoring todo plan",
        "status" => "pending",
        "priority" => "medium",
        "created_at" => DateTime.to_iso8601(DateTime.utc_now()),
        "updated_at" => DateTime.to_iso8601(DateTime.utc_now())
      }

      assert {:ok, _interaction, _executor_status} =
               Tasks.resolve_tool_request(
                 scope,
                 task.id,
                 %{id: "todo-replay", name: "todo_write"},
                 %{"content" => [], "structuredContent" => %{"todos" => [todo]}},
                 turn_number: turn_number
               )

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task.id}", %{})

      collect_all_pushes()

      push(
        socket,
        "acp:message",
        build_acp_request("session/load", 92, %{"sessionId" => task.id})
      )

      :sys.get_state(socket.channel_pid)

      relevant_messages =
        collect_all_pushes()
        |> Enum.filter(fn
          {"acp:message", %{"id" => 92}} ->
            true

          {"acp:message", payload} ->
            get_in(payload, ["params", "update", "sessionUpdate"]) in [
              "tool_call_update",
              "plan"
            ]

          _other ->
            false
        end)
        |> Enum.map(&elem(&1, 1))

      assert [
               %{
                 "params" => %{
                   "update" => %{
                     "sessionUpdate" => "tool_call_update",
                     "toolCallId" => "todo-replay",
                     "status" => "completed",
                     "rawOutput" => %{"todos" => [^todo]}
                   }
                 }
               },
               %{"id" => 92, "result" => %{"configOptions" => _config_options}},
               %{
                 "params" => %{
                   "update" => %{
                     "sessionUpdate" => "plan",
                     "entries" => [
                       %{
                         "content" => "Restore todo plan",
                         "status" => "pending",
                         "priority" => "medium"
                       }
                     ]
                   }
                 }
               }
             ] = relevant_messages
    end

    test "drains accepted work created outside the channel prompt flow", %{scope: scope} do
      task = task_fixture(scope)

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task.id}", %{})

      complete_mcp_handshake(socket)

      {:ok, %Tasks.InteractionSchema{data: %Interaction.UserMessage{}}} =
        Tasks.submit_user_message(scope, %{
          task_id: task.id,
          message_id: Ecto.UUID.generate(),
          message: user_content("queued elsewhere"),
          model: "openrouter:google/gemini-3.1-pro-preview",
          agent_id: "test-frontman"
        })

      push(
        socket,
        "acp:message",
        build_acp_request("session/load", 91, %{"sessionId" => task.id})
      )

      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{"id" => 91, "result" => %{}})
      assert_state_update_running_then_idle(task.id)
    end
  end

  describe "session/cancel" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "cancelled agent error emits idle state", %{
      socket: _socket,
      task_id: task_id
    } do
      Phoenix.PubSub.broadcast(FrontmanServer.PubSub, task_topic(task_id), agent_cancelled())

      assert_push("acp:message", %{
        "params" => %{
          "update" => %{
            "sessionUpdate" => "state_update",
            "state" => "idle",
            "stopReason" => "cancelled"
          }
        }
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
      activate_turn(socket, "turn-1")

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

      tc =
        tool_call(tool_call_id, "write_file", %{"target_file" => "test.txt", "content" => "hello"})

      send(socket.channel_pid, interaction_event(tc, 1))
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{
          "update" => update
        }
      })

      assert update == %{
               "sessionUpdate" => "tool_call_update",
               "toolCallId" => tool_call_id,
               "status" => "pending",
               "rawInput" => %{"target_file" => "test.txt", "content" => "hello"}
             }

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
      tool_call_id = "call_no_start_#{:rand.uniform(1_000_000)}"

      tc = tool_call(tool_call_id, "take_screenshot")

      send(socket.channel_pid, interaction_event(tc, 1))
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{
          "sessionId" => ^task_id,
          "update" => update
        }
      })

      assert update["sessionUpdate"] == "tool_call"
      assert update["toolCallId"] == tool_call_id
      assert update["rawInput"] == %{}
      refute Map.has_key?(update, "content")
    end
  end

  describe "reconnect re-executes unresolved tool calls" do
    setup %{scope: scope} do
      task_id = task_fixture(scope).id

      tool_call_id = "tc_question_#{System.unique_integer([:positive])}"
      tool_call = question_tool_call(tool_call_id, "Test", "A")

      user_message_fixture(
        scope,
        task_id,
        [%{"type" => "text", "text" => "ask me a question"}],
        @persisted_restart_model
      )

      turn_number = latest_turn_number(task_id)

      {:ok, _tool_call} =
        persist_response_tool_call_fixture(scope, task_id, turn_number, "", tool_call)

      {:ok, task_id: task_id, scope: scope, tool_call_id: tool_call_id}
    end

    test "restart ignores stale result model and scrubs legacy result metadata", %{
      scope: scope,
      task_id: task_id,
      tool_call_id: tool_call_id
    } do
      expect_resumed_model()
      turn_number = latest_turn_number(task_id)
      Tasks.handle_swarm_event(scope, task_id, turn_number, {:terminated, :shutdown})

      {:ok, task} = Tasks.get_task(scope, task_id)
      refute Enum.any?(Tasks.interactions(task), &match?(%Interaction.AgentError{}, &1))

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      complete_mcp_handshake(socket)
      push(socket, "acp:message", build_acp_request("session/load", 1, %{"sessionId" => task_id}))
      :sys.get_state(socket.channel_pid)

      messages = collect_all_pushes()

      assert {"mcp:message",
              %{
                "id" => mcp_request_id,
                "params" => %{
                  "_meta" => %{
                    "ai.frontman/execution-context" => %{"callId" => ^tool_call_id}
                  }
                }
              }} =
               Enum.find(messages, fn
                 {"mcp:message", %{"method" => "tools/call", "params" => %{"name" => "question"}}} ->
                   true

                 _ ->
                   false
               end)

      push(
        socket,
        "mcp:message",
        question_answer_response(mcp_request_id, "A", %{
          "_meta" => %{
            "model" => %{"provider" => "openrouter", "value" => "stale/model"},
            "envApiKey" => "sk-fake-legacy-key"
          }
        })
      )

      :sys.get_state(socket.channel_pid)

      assert_receive {:resumed_model, %LLMDB.Model{id: "openai/gpt-5.5"}}, 1_000

      {:ok, task} = Tasks.get_task(scope, task_id)

      tool_results =
        Enum.filter(Tasks.interactions(task), &match?(%Interaction.ToolResult{}, &1))

      assert [
               %Interaction.ToolResult{
                 tool_call_id: ^tool_call_id,
                 is_error: false,
                 result: %{"_meta" => %{}}
               }
             ] = tool_results

      assert_state_update_idle(task_id)
    end

    test "restart waits for every unresolved tool result before resuming", %{
      scope: scope,
      task_id: task_id
    } do
      second_tool_call_id = "tc_question_#{System.unique_integer([:positive])}"
      second_tool_call = question_tool_call(second_tool_call_id, "Second", "B")
      turn_number = latest_turn_number(task_id)

      {:ok, _tool_call} =
        persist_response_tool_call_fixture(scope, task_id, turn_number, "", second_tool_call)

      Tasks.handle_swarm_event(scope, task_id, turn_number, {:terminated, :shutdown})
      expect_resumed_model()

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      complete_mcp_handshake(socket)
      push(socket, "acp:message", build_acp_request("session/load", 1, %{"sessionId" => task_id}))
      :sys.get_state(socket.channel_pid)

      request_ids =
        Enum.reduce(collect_all_pushes(), %{}, fn
          {"mcp:message",
           %{
             "id" => request_id,
             "method" => "tools/call",
             "params" => %{
               "name" => "question",
               "_meta" => %{
                 "ai.frontman/execution-context" => %{"callId" => call_id}
               }
             }
           }},
          acc ->
            Map.put(acc, call_id, request_id)

          _, acc ->
            acc
        end)

      assert map_size(request_ids) == 2

      [{first_call_id, first_request_id}, {final_call_id, final_request_id}] =
        Map.to_list(request_ids)

      push(socket, "mcp:message", question_answer_response(first_request_id, "A"))
      :sys.get_state(socket.channel_pid)

      assert {:ok, ^turn_number, [_remaining_call]} =
               Tasks.get_active_turn_unresolved_tool_calls(scope, task_id)

      refute SwarmAi.running?(FrontmanServer.AgentRuntime, task_id)

      push(socket, "mcp:message", question_answer_response(final_request_id, "B"))
      :sys.get_state(socket.channel_pid)

      assert first_call_id != final_call_id

      assert_receive {:resumed_model, %LLMDB.Model{id: "openai/gpt-5.5"}}, 1_000

      assert_state_update_idle(task_id)
    end

    test "JSON-RPC tool error resumes from persisted turn model", %{
      scope: scope,
      task_id: task_id,
      tool_call_id: tool_call_id
    } do
      expect_resumed_model()
      turn_number = latest_turn_number(task_id)
      Tasks.handle_swarm_event(scope, task_id, turn_number, {:terminated, :shutdown})

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      complete_mcp_handshake(socket)
      push(socket, "acp:message", build_acp_request("session/load", 1, %{"sessionId" => task_id}))
      :sys.get_state(socket.channel_pid)

      messages = collect_all_pushes()

      assert {"mcp:message",
              %{
                "id" => mcp_request_id,
                "params" => %{
                  "_meta" => %{
                    "ai.frontman/execution-context" => %{"callId" => ^tool_call_id}
                  }
                }
              }} =
               Enum.find(messages, fn
                 {"mcp:message", %{"method" => "tools/call", "params" => %{"name" => "question"}}} ->
                   true

                 _ ->
                   false
               end)

      push(socket, "mcp:message", JsonRpc.error_response(mcp_request_id, -32_000, "Tool failed"))
      :sys.get_state(socket.channel_pid)

      assert_receive {:resumed_model, %LLMDB.Model{id: "openai/gpt-5.5"}}, 1_000

      assert_state_update_idle(task_id)
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

      {:ok, _tool_call} =
        persist_response_tool_call_fixture(scope, task_id, first_turn_number, "", first_tc)

      Tasks.resolve_tool_request(
        scope,
        task_id,
        %{id: first_tool_call_id, name: "question"},
        MCP.tool_result_json(%{"answers" => [%{"answer" => "A"}]})
      )

      Tasks.agent_replied(scope, task_id, first_turn_number, "First done")
      Tasks.record_execution_outcome(scope, task_id, first_turn_number, :completed)

      user_message_fixture(scope, task_id, user_content("second turn"))
      second_turn_number = latest_turn_number(task_id)

      {:ok, _tool_call} =
        persist_response_tool_call_fixture(scope, task_id, second_turn_number, "", second_tc)

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

      assert_push("mcp:message", %{
        "id" => discovery_request_id,
        "method" => "server/discover"
      })

      push(
        socket,
        "acp:message",
        build_acp_request("session/load", 1, %{"sessionId" => task_id})
      )

      :sys.get_state(socket.channel_pid)

      refute_push("mcp:message", %{"method" => "tools/call"}, 100)

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(discovery_request_id, mcp_discovery_result())
      )

      :sys.get_state(socket.channel_pid)
      assert_push("mcp:message", %{"id" => tools_id, "method" => "tools/list"})

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(tools_id, mcp_tools_result([]))
      )

      :sys.get_state(socket.channel_pid)

      assert_push("mcp:message", %{
        "id" => rules_id,
        "method" => "tools/call",
        "params" => %{"name" => "load_agent_instructions"}
      })

      push(socket, "mcp:message", JsonRpc.success_response(rules_id, MCP.tool_result_text("")))
      :sys.get_state(socket.channel_pid)

      assert_push("mcp:message", %{
        "id" => tree_id,
        "method" => "tools/call",
        "params" => %{"name" => "list_tree"}
      })

      push(socket, "mcp:message", JsonRpc.success_response(tree_id, MCP.tool_result_text("")))
      :sys.get_state(socket.channel_pid)

      assert_push(
        "mcp:message",
        %{"method" => "tools/call", "id" => mcp_request_id, "params" => %{"name" => "question"}},
        2_000
      )

      push(socket, "mcp:message", question_answer_response(mcp_request_id, "A"))

      :sys.get_state(socket.channel_pid)

      {:ok, task} = Tasks.get_task(scope, task_id)

      tool_results =
        Enum.filter(Tasks.interactions(task), &match?(%Tasks.Interaction.ToolResult{}, &1))

      assert [%Tasks.Interaction.ToolResult{tool_call_id: ^tool_call_id, is_error: false}] =
               tool_results

      assert_state_update_idle(task_id)
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
        MCP.tool_result_json(%{"answers" => [%{"answer" => "A"}]})
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
               Tasks.interactions(task),
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
      refute Enum.any?(Tasks.interactions(task), &match?(%Interaction.AgentRetry{}, &1))

      send(socket.channel_pid, {:fire_retry, retry_state.timer_token})
      :sys.get_state(socket.channel_pid)

      {:ok, task} = Tasks.get_task(scope, task_id)

      assert Enum.any?(
               Tasks.interactions(task),
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
        Tasks.record_execution_outcome(scope, task_id, turn_number, {:failed, "Rate limited"})

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
               Tasks.interactions(task),
               &match?(
                 %Interaction.AgentRetry{
                   retried_error_id: ^retried_error_id
                 },
                 &1
               )
             )

      assert_state_update_idle(task_id)
    end

    test "session/retry_turn rejects client-generated error ids", %{
      scope: scope,
      socket: socket,
      task_id: task_id
    } do
      user_message_fixture(scope, task_id, [%{"type" => "text", "text" => "retry me"}])
      turn_number = latest_turn_number(task_id)

      {:ok, _error_interaction} =
        Tasks.record_execution_outcome(scope, task_id, turn_number, {:failed, "Rate limited"})

      retried_error_id = "error-#{task_id}-2026-06-26T17:13:06.931002Z"

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

      refute Enum.any?(
               Tasks.interactions(task),
               &match?(%Interaction.AgentRetry{}, &1)
             )

      assert_push("acp:message", %{
        "params" => %{
          "update" => %{
            "sessionUpdate" => "error",
            "category" => "retry_unavailable",
            "message" =>
              "That response can no longer be retried. Please send a new message instead."
          }
        }
      })
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
          "update" => %{
            "sessionUpdate" => "state_update",
            "state" => "idle",
            "stopReason" => "cancelled"
          }
        }
      })

      {:ok, task} = Tasks.get_task(scope, task_id)

      refute Enum.any?(
               Tasks.interactions(task),
               &match?(
                 %Interaction.AgentRetry{},
                 &1
               )
             )

      refute Enum.any?(
               Tasks.interactions(task),
               &match?(%Interaction.AgentError{kind: "cancelled"}, &1)
             )
    end
  end
end
