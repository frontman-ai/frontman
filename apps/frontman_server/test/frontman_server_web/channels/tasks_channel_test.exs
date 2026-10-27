defmodule FrontmanServerWeb.TasksChannelTest do
  use FrontmanServerWeb.ChannelCase, async: false

  import FrontmanServer.BillingFixtures
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks
  import ExUnit.CaptureLog

  alias FrontmanServer.Billing
  alias FrontmanServer.Protocols.ACP
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.TaskSchema
  alias FrontmanServerWeb.UserSocket
  alias Phoenix.Socket.V2.JSONSerializer

  setup %{scope: scope} do
    {:ok, _, socket} =
      UserSocket
      |> socket("user_id", %{scope: scope})
      |> subscribe_and_join("tasks", %{})

    {:ok, socket: socket, scope: scope}
  end

  defp request(socket, method, id, params),
    do: push(socket, "acp:message", build_acp_request(method, id, params))

  describe "join tasks" do
    test "pushes billing status update when billing changes", %{scope: scope} do
      subscription_for_scope_fixture(scope, %{status: "active"})
      assert :ok = Billing.broadcast_status_changed(scope.user.id)

      assert_push("billing_status_updated", %{
        status: "active",
        can_start_turn: true,
        has_billing_customer: true,
        interval: :monthly
      })
    end
  end

  describe "ACP initialize" do
    test "catalog updates can be encoded by the WebSocket serializer", %{socket: socket} do
      request(socket, "initialize", 1, %{"protocolVersion" => ACP.protocol_version()})

      assert_receive %Phoenix.Socket.Message{
                       event: "model_catalog_updated",
                       payload: %{"groups" => [_ | _]}
                     } = message

      assert {:socket_push, :text, encoded} = JSONSerializer.encode!(message)

      assert [_, _, "tasks", "model_catalog_updated", %{"groups" => [_ | _]}] =
               encoded |> IO.iodata_to_binary() |> Jason.decode!()
    end

    test "does not log client metadata", %{socket: socket} do
      log =
        capture_log([level: :info], fn ->
          request(socket, "initialize", 1, %{
            "protocolVersion" => ACP.protocol_version(),
            "clientInfo" => %{
              "name" => "test-client",
              "version" => "1.0.0",
              "_meta" => %{"envApiKey" => "sk-fake-client-info-marker"}
            }
          })

          assert_push("model_catalog_updated", %{"groups" => [_ | _]})
          assert_acp_reply(%{"id" => 1})
        end)

      refute log =~ "sk-fake-client-info-marker"
      refute log =~ "envApiKey"
    end

    for requested_version <- [0, 1, 2, 999, 65_535] do
      @requested_version requested_version
      test "returns version 1 for requested version #{requested_version}", %{socket: socket} do
        client_info = %{"name" => "test-client", "version" => "1.0.0"}

        request(socket, "initialize", "initialize-version", %{
          "protocolVersion" => @requested_version,
          "clientInfo" => client_info,
          "clientCapabilities" => %{
            "_meta" => %{"frontman.dev" => %{"agentAttribution" => %{"version" => 1}}}
          }
        })

        assert_push("model_catalog_updated", %{
          "groups" => [%{"group" => _, "options" => [_ | _]} | _]
        })

        assert_push("billing_status_updated", %{status: "none", can_start_turn: true})

        assert_acp_reply(%{
          "id" => "initialize-version",
          "result" => %{
            "protocolVersion" => 1,
            "agentInfo" => %{"name" => "frontman-server"},
            "agentCapabilities" => %{
              "_meta" => %{
                "frontman.dev" => %{
                  "agentAttribution" => %{"version" => 1},
                  "agents" => [%{"id" => "test-frontman"}, %{"id" => "test-planner"}],
                  "defaultAgentId" => "test-planner"
                }
              }
            }
          }
        })

        assert :sys.get_state(socket.channel_pid).assigns.acp_client_info == client_info
      end
    end

    for requested_version <- [1, 999] do
      @requested_version requested_version
      test "rejects malformed attribution metadata for version #{requested_version}", %{
        socket: socket
      } do
        request(socket, "initialize", 1, %{
          "protocolVersion" => @requested_version,
          "clientCapabilities" => %{
            "_meta" => %{"frontman.dev" => %{"agentAttribution" => "invalid"}}
          }
        })

        assert_acp_reply(%{
          "id" => 1,
          "error" => %{
            "code" => -32_602,
            "message" => "Invalid Frontman agent attribution capability metadata"
          }
        })

        refute Map.has_key?(:sys.get_state(socket.channel_pid).assigns, :acp_client_info)
        refute_push("model_catalog_updated", %{})
        refute_push("billing_status_updated", %{})
      end
    end

    test "pushes billing status update", %{socket: socket} do
      request(socket, "initialize", 1, %{"protocolVersion" => ACP.protocol_version()})

      assert_push("billing_status_updated", %{
        status: "none",
        can_start_turn: true,
        pretrial_runs_remaining: 5,
        has_billing_customer: false,
        interval: nil,
        current_period_end: nil,
        trial_end: nil,
        cancel_at: nil,
        canceled_at: nil
      })
    end

    for invalid_version <- [-1, 65_536, 1.0, 1.5, "1", true, false, nil, %{}, []] do
      @invalid_version invalid_version
      test "rejects malformed protocol version #{inspect(invalid_version)}", %{socket: socket} do
        request(socket, "initialize", 1, %{"protocolVersion" => @invalid_version})

        assert_acp_reply(%{
          "id" => 1,
          "error" => %{
            "code" => -32_602,
            "message" => "Invalid protocolVersion: must be an integer between 0 and 65535"
          }
        })

        refute Map.has_key?(:sys.get_state(socket.channel_pid).assigns, :acp_client_info)
        refute_push("model_catalog_updated", %{})
        refute_push("billing_status_updated", %{})
      end
    end

    test "fails without protocol version", %{socket: socket} do
      request(socket, "initialize", 1, %{})

      assert_acp_reply(%{
        "id" => 1,
        "error" => %{"code" => -32_602, "message" => "Missing required field: protocolVersion"}
      })
    end
  end

  describe "ACP session/new" do
    setup %{socket: socket} = context do
      client_info =
        case Map.get(context, :framework, "nextjs") do
          nil ->
            nil

          framework ->
            %{
              "name" => "test-client",
              "version" => "1.0.0",
              "_meta" => %{"framework" => framework}
            }
        end

      request(socket, "initialize", 1, %{
        "protocolVersion" => ACP.protocol_version(),
        "clientInfo" => client_info
      })

      assert_acp_reply(%{"id" => 1, "result" => %{}})
      :ok
    end

    for {status, framework, expected} <- [
          {"active", "nextjs", :nextjs},
          {"trialing", "vite", :vite}
        ] do
      @tag framework: framework
      test "creates #{framework} sessions with #{status} billing and selected model", %{
        socket: socket,
        scope: scope
      } do
        subscription_for_scope_fixture(scope, %{status: unquote(status)})
        id = Ecto.UUID.generate()
        model = "openrouter:google/gemini-3.1-pro-preview"
        params = session_new_params(id)
        params = Map.update!(params, "_meta", &Map.put(&1, "frontman.dev/model", model))
        request(socket, "session/new", 2, params)

        assert_acp_reply(%{
          "id" => 2,
          "result" => %{"sessionId" => ^id, "configOptions" => [%{"currentValue" => ^model}]}
        })

        assert {:ok, task} = Tasks.get_task(scope, id)
        assert task.framework == unquote(expected)
        assert task.current_model == model
      end
    end

    test "rejects invalid explicit model preferences before creating a session", %{
      socket: socket,
      scope: scope
    } do
      for model <- [nil, 42, "", "missing:model"] do
        id = Ecto.UUID.generate()
        params = session_new_params(id)
        params = Map.update!(params, "_meta", &Map.put(&1, "frontman.dev/model", model))
        request(socket, "session/new", 2, params)
        assert_acp_reply(%{"id" => 2, "error" => %{"code" => -32_602}})
        assert {:error, :not_found} = Tasks.get_task(scope, id)
      end
    end

    test "unselected sessions require a model before accepting prompts", %{
      socket: socket,
      scope: scope
    } do
      id = Ecto.UUID.generate()
      request(socket, "session/new", 2, session_new_params(id))

      assert_acp_reply(%{
        "id" => 2,
        "result" => %{"sessionId" => ^id, "configOptions" => []}
      })

      assert {:ok, %{id: ^id, framework: :nextjs, current_model: nil}} =
               Tasks.get_task(scope, id)

      {:ok, _, session} =
        UserSocket
        |> socket("session-user", %{scope: scope})
        |> subscribe_and_join("task:#{id}", %{})

      prompt = %{"sessionId" => id, "prompt" => user_content("Hello")}

      assert_reply(request(session, "session/prompt", 3, prompt), :ok, %{
        "acp:message" => %{"id" => 3, "error" => %{"code" => -32_602}}
      })

      assert {:ok, %{interaction_rows: []}} = Tasks.get_task_with_history(scope, id)

      model = "openrouter:openai/gpt-5.5"

      assert_reply(
        request(session, "session/set_config_option", 4, %{
          "sessionId" => id,
          "configId" => "model",
          "value" => model
        }),
        :ok,
        %{"acp:message" => %{"result" => %{"configOptions" => [%{"currentValue" => ^model}]}}}
      )

      assert_reply(request(session, "session/prompt", 5, prompt), :ok, %{
        "acp:message" => %{"id" => 5, "result" => %{}}
      })

      assert {:ok, task} = Tasks.get_task_with_history(scope, id)
      assert task.current_model == model
      assert [%Tasks.Interaction.UserMessage{model: ^model}] = Tasks.interactions(task)
    end

    test "standard params without proprietary ID generate a new ID for each request", %{
      socket: socket,
      scope: scope
    } do
      request(socket, "session/new", 2, %{"cwd" => "/", "mcpServers" => []})
      assert_acp_reply(%{"id" => 2, "result" => %{"sessionId" => first_id}})
      assert {:ok, ^first_id} = Ecto.UUID.cast(first_id)
      assert {:ok, %{framework: :nextjs}} = Tasks.get_task(scope, first_id)

      request(socket, "session/new", 3, %{
        "cwd" => "/",
        "mcpServers" => [],
        "additionalDirectories" => [],
        "_meta" => %{"other.vendor/trace" => %{"opaque" => true}}
      })

      assert_acp_reply(%{"id" => 3, "result" => %{"sessionId" => second_id}})
      refute first_id == second_id
      assert {:ok, _task} = Tasks.get_task(scope, second_id)

      request(socket, "session/new", 4, %{"cwd" => "/", "mcpServers" => [], "_meta" => nil})
      assert_acp_reply(%{"id" => 4, "result" => %{"sessionId" => third_id}})
      refute third_id in [first_id, second_id]
      assert {:ok, _task} = Tasks.get_task(scope, third_id)
    end

    test "rejects exhausted allowance before creating or retrying a task", %{
      socket: socket,
      scope: scope
    } do
      id = task_fixture(scope).id
      new_id = Ecto.UUID.generate()
      run_allowance_fixture(scope, 5)

      for {request_id, session_id} <- [{2, id}, {3, new_id}] do
        request(socket, "session/new", request_id, session_new_params(session_id))

        assert_acp_reply(%{
          "id" => ^request_id,
          "error" => %{
            "code" => -32_010,
            "message" => "Keep going with a 7-day free Pro trial. Card required."
          }
        })
      end

      assert {:error, :not_found} = Tasks.get_task(scope, new_id)
    end

    test "rejects malformed and unsupported workspace, MCP and ID settings", %{
      socket: socket
    } do
      id = Ecto.UUID.generate()
      params = session_new_params(id)

      invalid_params = [
        %{},
        %{"sessionId" => id},
        Map.put(params, "sessionId", id),
        Map.delete(params, "cwd"),
        Map.put(params, "cwd", ""),
        Map.put(params, "cwd", "relative/path"),
        Map.put(params, "cwd", "/another/workspace"),
        Map.put(params, "cwd", 1),
        Map.delete(params, "mcpServers"),
        Map.put(params, "mcpServers", %{}),
        Map.put(params, "mcpServers", [nil]),
        Map.put(params, "mcpServers", [
          %{"name" => "stdio", "command" => "/bin/server", "args" => [], "env" => []}
        ]),
        Map.put(params, "mcpServers", [
          %{
            "type" => "http",
            "name" => "http",
            "url" => "https://example.com/mcp",
            "headers" => []
          }
        ]),
        Map.put(params, "mcpServers", [
          %{"type" => "sse", "name" => "sse", "url" => "https://example.com/sse", "headers" => []}
        ]),
        Map.put(params, "additionalDirectories", ["/another/root"]),
        Map.put(params, "additionalDirectories", "invalid"),
        Map.put(params, "_meta", "invalid"),
        session_new_params("not-a-valid-uuid"),
        session_new_params(nil),
        session_new_params(42)
      ]

      for {invalid, request_id} <- Enum.with_index(invalid_params, 2) do
        request(socket, "session/new", request_id, invalid)

        assert_acp_reply(%{
          "id" => ^request_id,
          "error" => %{"code" => -32_602, "message" => message}
        })

        assert message =~ "Invalid or unsupported session/new parameters"
      end

      assert Repo.aggregate(TaskSchema, :count, :id) == 0
    end

    test "same-user retries preserve selection and reject another user's ID", %{
      socket: socket,
      scope: scope
    } do
      existing = task_fixture(scope, framework: "vite")
      existing_id = existing.id
      current_model = existing.current_model

      for request_id <- 2..3 do
        params = session_new_params(existing_id)

        params =
          Map.update!(
            params,
            "_meta",
            &Map.merge(&1, %{
              "other.vendor/trace" => true,
              "frontman.dev/model" => "openrouter:google/gemini-3.1-pro-preview"
            })
          )

        request(socket, "session/new", request_id, params)

        assert_acp_reply(%{
          "id" => ^request_id,
          "result" => %{
            "sessionId" => ^existing_id,
            "configOptions" => [%{"currentValue" => ^current_model}]
          }
        })
      end

      assert Repo.get!(TaskSchema, existing_id).framework == :vite
      assert Repo.get!(TaskSchema, existing_id).current_model == current_model
      assert Repo.aggregate(TaskSchema.by_id(existing_id), :count, :id) == 1
      other_id = task_fixture(user_scope_fixture()).id

      other_params =
        Map.update!(
          session_new_params(other_id),
          "_meta",
          &Map.put(&1, "frontman.dev/model", current_model)
        )

      request(socket, "session/new", 4, other_params)

      assert_acp_reply(%{
        "id" => 4,
        "error" => %{"code" => -32_602, "message" => "Failed to create session"}
      })
    end

    @tag framework: nil
    test "requires explicit framework/client metadata without a fallback", %{socket: socket} do
      request(socket, "session/new", 2, %{"cwd" => "/", "mcpServers" => []})

      assert_acp_reply(%{
        "id" => 2,
        "error" => %{"code" => -32_602, "message" => "Missing framework in clientInfo"}
      })
    end

    @tag framework: "unsupported"
    test "rejects unsupported framework without creating a task", %{socket: socket} do
      request(socket, "session/new", 2, %{
        "cwd" => "/",
        "mcpServers" => [],
        "_meta" => %{"frontman.dev/model" => "openrouter:openai/gpt-5.5"}
      })

      assert_acp_reply(%{
        "id" => 2,
        "error" => %{"code" => -32_602, "message" => "Framework is invalid"}
      })

      assert Repo.aggregate(TaskSchema, :count, :id) == 0
    end
  end

  defp session_new_params(id) do
    %{"cwd" => "/", "mcpServers" => [], "_meta" => %{"frontman.dev/sessionId" => id}}
  end

  describe "ACP unknown method" do
    test "returns method not found error", %{socket: socket} do
      request(socket, "unknown/method", 1, %{})

      assert_acp_reply(%{
        "id" => 1,
        "error" => %{"code" => -32_601, "message" => "Method not found"}
      })
    end
  end

  describe "list_sessions" do
    test "lists only owned sessions with their metadata", %{socket: socket, scope: scope} do
      assert_reply(push(socket, "list_sessions", %{}), :ok, %{"sessions" => []})
      first = task_fixture(scope).id
      assert_reply(push(socket, "list_sessions", %{}), :ok, %{"sessions" => [session]})
      assert session["sessionId"] == first
      assert session["title"] == "New Task"
      assert {:ok, _, _} = DateTime.from_iso8601(session["createdAt"])
      assert {:ok, _, _} = DateTime.from_iso8601(session["updatedAt"])
      second = task_fixture(scope).id
      task_fixture(user_scope_fixture(), framework: "vite")
      assert_reply(push(socket, "list_sessions", %{}), :ok, %{"sessions" => sessions})
      assert Enum.sort(Enum.map(sessions, & &1["sessionId"])) == Enum.sort([first, second])
    end
  end

  describe "delete_session" do
    test "deletes session and returns empty result", %{socket: socket, scope: scope} do
      task_id = task_fixture(scope).id
      assert_reply(push(socket, "delete_session", %{"sessionId" => task_id}), :ok, %{})
      assert {:error, :not_found} = Tasks.get_task(scope, task_id)
    end

    test "only deletes own sessions", %{socket: socket} do
      other_scope = user_scope_fixture()
      other_task_id = task_fixture(other_scope, framework: "vite").id
      assert_reply(push(socket, "delete_session", %{"sessionId" => other_task_id}), :error, _)
      assert {:ok, _task} = Tasks.get_task(other_scope, other_task_id)
    end
  end
end
