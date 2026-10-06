defmodule FrontmanServerWeb.TasksChannelTest do
  use FrontmanServerWeb.ChannelCase, async: false

  import FrontmanServer.BillingFixtures
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks
  import ExUnit.CaptureLog

  alias FrontmanServer.Billing
  alias FrontmanServer.Protocols.ACP
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks.TaskSchema
  alias FrontmanServerWeb.UserSocket

  setup %{scope: scope} do
    {:ok, _, socket} =
      UserSocket
      |> socket("user_id", %{scope: scope})
      |> subscribe_and_join("tasks", %{})

    {:ok, socket: socket, scope: scope}
  end

  describe "join tasks" do
    test "pushes billing status update when billing changes", %{socket: _socket, scope: scope} do
      subscription_for_scope_fixture(scope, %{status: "active"})

      assert :ok = Billing.broadcast_status_changed(scope.user.id)

      assert_push("billing_status_updated", %{
        status: "active",
        access_allowed: true,
        has_billing_customer: true,
        interval: :monthly
      })
    end
  end

  describe "ACP initialize" do
    test "does not log client metadata", %{socket: socket} do
      version = ACP.protocol_version()

      log =
        capture_log([level: :info], fn ->
          push(socket, "acp:message", %{
            "jsonrpc" => "2.0",
            "id" => 1,
            "method" => "initialize",
            "params" => %{
              "protocolVersion" => version,
              "clientInfo" => %{
                "name" => "test-client",
                "version" => "1.0.0",
                "_meta" => %{"envApiKey" => "sk-fake-client-info-marker"}
              }
            }
          })

          assert_push("config_options_updated", %{})
          assert_acp_reply(%{"id" => 1})
        end)

      refute log =~ "sk-fake-client-info-marker"
      refute log =~ "envApiKey"
    end

    for requested_version <- [0, 1, 2, 999, 65_535] do
      @requested_version requested_version
      test "returns version 1 for requested version #{requested_version}", %{socket: socket} do
        client_info = %{"name" => "test-client", "version" => "1.0.0"}

        push(socket, "acp:message", %{
          "jsonrpc" => "2.0",
          "id" => "initialize-version",
          "method" => "initialize",
          "params" => %{
            "protocolVersion" => @requested_version,
            "clientInfo" => client_info,
            "clientCapabilities" => %{
              "_meta" => %{"frontman.dev" => %{"agentAttribution" => %{"version" => 1}}}
            }
          }
        })

        assert_push("config_options_updated", %{"configOptions" => _})
        assert_push("billing_status_updated", %{status: "none", access_allowed: false})

        assert_acp_reply(%{
          "jsonrpc" => "2.0",
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
        push(socket, "acp:message", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "initialize",
          "params" => %{
            "protocolVersion" => @requested_version,
            "clientCapabilities" => %{
              "_meta" => %{"frontman.dev" => %{"agentAttribution" => "invalid"}}
            }
          }
        })

        assert_acp_reply(%{
          "jsonrpc" => "2.0",
          "id" => 1,
          "error" => %{
            "code" => -32_602,
            "message" => "Invalid Frontman agent attribution capability metadata"
          }
        })

        refute Map.has_key?(:sys.get_state(socket.channel_pid).assigns, :acp_client_info)
        refute_push("config_options_updated", %{})
        refute_push("billing_status_updated", %{})
      end
    end

    test "pushes billing status update", %{socket: socket} do
      version = ACP.protocol_version()

      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => version,
          "clientInfo" => %{"name" => "test-client", "version" => "1.0.0"}
        }
      })

      assert_push("billing_status_updated", %{
        status: "none",
        access_allowed: false,
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
        push(socket, "acp:message", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "initialize",
          "params" => %{"protocolVersion" => @invalid_version}
        })

        assert_acp_reply(%{
          "jsonrpc" => "2.0",
          "id" => 1,
          "error" => %{
            "code" => -32_602,
            "message" => "Invalid protocolVersion: must be an integer between 0 and 65535"
          }
        })

        refute Map.has_key?(:sys.get_state(socket.channel_pid).assigns, :acp_client_info)
        refute_push("config_options_updated", %{})
        refute_push("billing_status_updated", %{})
      end
    end

    test "fails without protocol version", %{socket: socket} do
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{}
      })

      assert_acp_reply(%{
        "jsonrpc" => "2.0",
        "id" => 1,
        "error" => %{
          "code" => -32_602,
          "message" => "Missing required field: protocolVersion"
        }
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

      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{"protocolVersion" => ACP.protocol_version(), "clientInfo" => client_info}
      })

      assert_acp_reply(%{"id" => 1, "result" => %{}})
      :ok
    end

    test "creates task with a stable Frontman metadata ID", %{socket: socket, scope: scope} do
      allow_access_for_scope_fixture(scope)
      id = Ecto.UUID.generate()

      push_session_new(socket, 2, session_new_params(id))
      assert_acp_reply(%{"id" => 2, "result" => %{"sessionId" => ^id}})

      assert {:ok, %{id: ^id, framework: :nextjs}} =
               FrontmanServer.Tasks.get_task_with_history(scope, id)
    end

    test "standard params without proprietary ID generate a new ID for each request", %{
      socket: socket,
      scope: scope
    } do
      allow_access_for_scope_fixture(scope)

      push_session_new(socket, 2, %{"cwd" => "/", "mcpServers" => []})
      assert_acp_reply(%{"id" => 2, "result" => %{"sessionId" => first_id}})
      assert {:ok, ^first_id} = Ecto.UUID.cast(first_id)
      assert {:ok, %{framework: :nextjs}} = FrontmanServer.Tasks.get_task(scope, first_id)

      push_session_new(socket, 3, %{
        "cwd" => "/",
        "mcpServers" => [],
        "additionalDirectories" => [],
        "_meta" => %{"other.vendor/trace" => %{"opaque" => true}}
      })

      assert_acp_reply(%{"id" => 3, "result" => %{"sessionId" => second_id}})
      refute first_id == second_id
      assert {:ok, _task} = FrontmanServer.Tasks.get_task(scope, second_id)

      push_session_new(socket, 4, %{"cwd" => "/", "mcpServers" => [], "_meta" => nil})
      assert_acp_reply(%{"id" => 4, "result" => %{"sessionId" => third_id}})
      refute third_id in [first_id, second_id]
      assert {:ok, _task} = FrontmanServer.Tasks.get_task(scope, third_id)
    end

    test "rejects inactive billing before creating or retrying a task", %{
      socket: socket,
      scope: scope
    } do
      id = task_fixture(scope).id
      new_id = Ecto.UUID.generate()

      for {request_id, session_id} <- [{2, id}, {3, new_id}] do
        push_session_new(socket, request_id, session_new_params(session_id))

        assert_acp_reply(%{
          "id" => ^request_id,
          "error" => %{
            "code" => -32_010,
            "message" => "Finish billing setup to start using Frontman."
          }
        })
      end

      assert {:error, :not_found} = FrontmanServer.Tasks.get_task(scope, new_id)
    end

    test "creates task for trialing billing", %{socket: socket, scope: scope} do
      subscription_for_scope_fixture(scope, %{status: "trialing"})
      id = Ecto.UUID.generate()
      push_session_new(socket, 2, session_new_params(id))
      assert_acp_reply(%{"id" => 2, "result" => %{"sessionId" => ^id}})
      assert {:ok, _task} = FrontmanServer.Tasks.get_task(scope, id)
    end

    @tag framework: "vite"
    test "stores the explicit vite framework", %{socket: socket, scope: scope} do
      allow_access_for_scope_fixture(scope)
      id = Ecto.UUID.generate()
      push_session_new(socket, 2, session_new_params(id))
      assert_acp_reply(%{"id" => 2, "result" => %{"sessionId" => ^id}})
      assert Repo.get!(TaskSchema, id).framework == :vite
    end

    test "rejects malformed and unsupported workspace, MCP and ID settings", %{
      socket: socket,
      scope: scope
    } do
      allow_access_for_scope_fixture(scope)
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
        push_session_new(socket, request_id, invalid)

        assert_acp_reply(%{
          "id" => ^request_id,
          "error" => %{"code" => -32_602, "message" => message}
        })

        assert message =~ "Invalid or unsupported session/new parameters"
      end

      assert Repo.aggregate(TaskSchema, :count, :id) == 0
    end

    test "same-user retries preserve one row and reject another user's ID", %{
      socket: socket,
      scope: scope
    } do
      allow_access_for_scope_fixture(scope)
      existing_id = task_fixture(scope, framework: "vite").id

      for request_id <- 2..3 do
        params = session_new_params(existing_id)
        params = Map.update!(params, "_meta", &Map.put(&1, "other.vendor/trace", true))
        push_session_new(socket, request_id, params)
        assert_acp_reply(%{"id" => ^request_id, "result" => %{"sessionId" => ^existing_id}})
      end

      assert Repo.get!(TaskSchema, existing_id).framework == :vite
      assert Repo.aggregate(TaskSchema.by_id(existing_id), :count, :id) == 1
      other_id = task_fixture(user_scope_fixture()).id
      push_session_new(socket, 4, session_new_params(other_id))

      assert_acp_reply(%{
        "id" => 4,
        "error" => %{"code" => -32_602, "message" => "Failed to create session"}
      })
    end

    @tag framework: nil
    test "requires explicit framework/client metadata without a fallback", %{socket: socket} do
      push_session_new(socket, 2, %{"cwd" => "/", "mcpServers" => []})

      assert_acp_reply(%{
        "id" => 2,
        "error" => %{"code" => -32_602, "message" => "Missing framework in clientInfo"}
      })
    end

    @tag framework: "unsupported"
    test "rejects unsupported framework without creating a task", %{socket: socket, scope: scope} do
      allow_access_for_scope_fixture(scope)
      push_session_new(socket, 2, %{"cwd" => "/", "mcpServers" => []})

      assert_acp_reply(%{
        "id" => 2,
        "error" => %{"code" => -32_602, "message" => "Failed to create session"}
      })

      assert Repo.aggregate(TaskSchema, :count, :id) == 0
    end
  end

  defp session_new_params(id) do
    %{"cwd" => "/", "mcpServers" => [], "_meta" => %{"frontman.dev/sessionId" => id}}
  end

  defp push_session_new(socket, id, params) do
    push(socket, "acp:message", %{
      "jsonrpc" => "2.0",
      "id" => id,
      "method" => "session/new",
      "params" => params
    })
  end

  describe "ACP unknown method" do
    test "returns method not found error", %{socket: socket} do
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "unknown/method",
        "params" => %{}
      })

      assert_acp_reply(%{
        "jsonrpc" => "2.0",
        "id" => 1,
        "error" => %{
          "code" => -32_601,
          "message" => "Method not found"
        }
      })
    end
  end

  describe "list_sessions" do
    test "returns empty list when user has no tasks", %{socket: socket} do
      ref = push(socket, "list_sessions", %{})
      assert_reply(ref, :ok, %{"sessions" => []})
    end

    test "returns sessions with correct fields", %{socket: socket, scope: scope} do
      task_id = task_fixture(scope).id

      ref = push(socket, "list_sessions", %{})
      assert_reply(ref, :ok, %{"sessions" => [session]})

      assert session["sessionId"] == task_id
      assert session["title"] == "New Task"
      assert {:ok, _, _} = DateTime.from_iso8601(session["createdAt"])
      assert {:ok, _, _} = DateTime.from_iso8601(session["updatedAt"])
    end

    test "returns multiple sessions", %{socket: socket, scope: scope} do
      task1_id = task_fixture(scope).id
      task2_id = task_fixture(scope).id

      ref = push(socket, "list_sessions", %{})
      assert_reply(ref, :ok, %{"sessions" => sessions})

      assert length(sessions) == 2
      session_ids = Enum.map(sessions, & &1["sessionId"])
      assert task1_id in session_ids
      assert task2_id in session_ids
    end

    test "only returns tasks for authenticated user", %{socket: socket, scope: scope} do
      my_task_id = task_fixture(scope).id

      other_scope = user_scope_fixture()
      _other_task_id = task_fixture(other_scope, framework: "vite").id

      ref = push(socket, "list_sessions", %{})
      assert_reply(ref, :ok, %{"sessions" => [session]})
      assert session["sessionId"] == my_task_id
    end
  end

  describe "delete_session" do
    test "deletes session and returns empty result", %{socket: socket, scope: scope} do
      task_id = task_fixture(scope).id

      assert {:ok, _task} = FrontmanServer.Tasks.get_task_with_history(scope, task_id)

      ref = push(socket, "delete_session", %{"sessionId" => task_id})
      assert_reply(ref, :ok, %{})

      assert {:error, :not_found} = FrontmanServer.Tasks.get_task_with_history(scope, task_id)
    end

    test "only deletes own sessions", %{socket: socket, scope: scope} do
      _my_task_id = task_fixture(scope).id

      other_scope = user_scope_fixture()
      other_task_id = task_fixture(other_scope, framework: "vite").id

      ref = push(socket, "delete_session", %{"sessionId" => other_task_id})
      assert_reply(ref, :error, _)

      assert {:ok, _task} = FrontmanServer.Tasks.get_task_with_history(other_scope, other_task_id)
    end
  end
end
