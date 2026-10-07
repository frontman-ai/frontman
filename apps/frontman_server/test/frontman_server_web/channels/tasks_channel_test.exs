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

  defp initialize(socket, framework \\ "nextjs") do
    request(socket, "initialize", 1, %{
      "protocolVersion" => ACP.protocol_version(),
      "clientInfo" => %{
        "name" => "test-client",
        "version" => "1.0.0",
        "_meta" => %{"framework" => framework}
      }
    })

    assert_push("acp:message", %{
      "id" => 1,
      "result" => %{"protocolVersion" => 1, "agentInfo" => %{"name" => "frontman-server"}}
    })
  end

  defp request(socket, method, id, params),
    do: push(socket, "acp:message", build_acp_request(method, id, params))

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
          request(socket, "initialize", 1, %{
            "protocolVersion" => version,
            "clientInfo" => %{
              "name" => "test-client",
              "version" => "1.0.0",
              "_meta" => %{"envApiKey" => "sk-fake-client-info-marker"}
            }
          })

          assert_push("model_catalog_updated", [_ | _])
          assert_push("acp:message", %{"id" => 1})
        end)

      refute log =~ "sk-fake-client-info-marker"
      refute log =~ "envApiKey"
    end

    test "succeeds with matching protocol version", %{socket: socket} do
      version = ACP.protocol_version()

      request(socket, "initialize", 1, %{
        "protocolVersion" => version,
        "clientInfo" => %{"name" => "test-client", "version" => "1.0.0"}
      })

      assert_push("model_catalog_updated", [%{"group" => _, "options" => [_ | _]} | _])

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "result" => %{
          "protocolVersion" => ^version,
          "agentInfo" => %{"name" => "frontman-server"},
          "agentCapabilities" => %{
            "_meta" => %{
              "frontman.dev" => %{
                "agents" => [%{"id" => "test-frontman"}, %{"id" => "test-planner"}],
                "defaultAgentId" => "test-planner"
              }
            }
          }
        }
      })
    end

    test "rejects malformed Frontman agent attribution metadata", %{socket: socket} do
      request(socket, "initialize", 1, %{
        "protocolVersion" => ACP.protocol_version(),
        "clientCapabilities" => %{
          "_meta" => %{"frontman.dev" => %{"agentAttribution" => "invalid"}}
        }
      })

      assert_push("acp:message", %{
        "id" => 1,
        "error" => %{
          "code" => -32_602,
          "message" => "Invalid Frontman agent attribution capability metadata"
        }
      })
    end

    test "pushes billing status update", %{socket: socket} do
      version = ACP.protocol_version()

      request(socket, "initialize", 1, %{
        "protocolVersion" => version,
        "clientInfo" => %{"name" => "test-client", "version" => "1.0.0"}
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

    test "fails with wrong protocol version", %{socket: socket} do
      request(socket, "initialize", 1, %{"protocolVersion" => 999})

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "error" => %{
          "code" => -32_600,
          "message" => "Unsupported protocol version"
        }
      })
    end

    test "fails without protocol version", %{socket: socket} do
      request(socket, "initialize", 1, %{})

      assert_push("acp:message", %{
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
    test "creates task and returns sessionId", %{socket: socket, scope: scope} do
      allow_access_for_scope_fixture(scope)

      initialize(socket)

      client_session_id = Ecto.UUID.generate()

      model = "openrouter:google/gemini-3.1-pro-preview"

      request(socket, "session/new", 2, %{
        "sessionId" => client_session_id,
        "_meta" => %{"frontman.dev/model" => model}
      })

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "result" => %{
          "sessionId" => ^client_session_id,
          "configOptions" => [%{"currentValue" => ^model = current_model}]
        }
      })

      assert {:ok, task} = FrontmanServer.Tasks.get_task_with_history(scope, client_session_id)
      assert task.id == client_session_id
      assert task.framework == :nextjs
      assert task.current_model == current_model
    end

    test "rejects invalid explicit preferences before creating a session", %{
      socket: socket,
      scope: scope
    } do
      allow_access_for_scope_fixture(scope)
      initialize(socket)

      for meta <- [
            %{},
            %{"frontman.dev/model" => nil},
            %{"frontman.dev/model" => 42},
            %{"frontman.dev/model" => ""},
            %{"frontman.dev/model" => "missing:model"}
          ] do
        id = Ecto.UUID.generate()
        request(socket, "session/new", 2, %{"sessionId" => id, "_meta" => meta})

        assert_push("acp:message", %{"id" => 2, "error" => %{"code" => -32_602}})
        assert {:error, :not_found} = FrontmanServer.Tasks.get_task(scope, id)
      end
    end

    test "rejects inactive billing before creating task", %{socket: socket, scope: scope} do
      initialize(socket)

      client_session_id = Ecto.UUID.generate()

      request(socket, "session/new", 2, %{"sessionId" => client_session_id})

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "error" => %{
          "code" => -32_010,
          "message" => "Finish billing setup to start using Frontman."
        }
      })

      assert {:error, :not_found} = FrontmanServer.Tasks.get_task(scope, client_session_id)
    end

    test "creates task for trialing billing", %{socket: socket, scope: scope} do
      subscription_for_scope_fixture(scope, %{status: "trialing"})

      initialize(socket)

      client_session_id = Ecto.UUID.generate()

      request(socket, "session/new", 2, %{
        "sessionId" => client_session_id,
        "_meta" => %{"frontman.dev/model" => "openrouter:openai/gpt-5.5"}
      })

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "result" => %{"sessionId" => ^client_session_id}
      })

      assert {:ok, _task} = FrontmanServer.Tasks.get_task(scope, client_session_id)
    end

    for {framework, expected} <- [{"nextjs", :nextjs}, {"vite", :vite}] do
      test "stores #{framework} framework ID from clientInfo", %{socket: socket, scope: scope} do
        allow_access_for_scope_fixture(scope)
        initialize(socket, unquote(framework))
        id = Ecto.UUID.generate()

        request(socket, "session/new", 2, %{
          "sessionId" => id,
          "_meta" => %{"frontman.dev/model" => "openrouter:openai/gpt-5.5"}
        })

        assert_push("acp:message", %{
          "jsonrpc" => "2.0",
          "id" => 2,
          "result" => %{"sessionId" => ^id}
        })

        assert {:ok, task} = FrontmanServer.Tasks.get_task_with_history(scope, id)
        assert task.id == id
        assert task.framework == unquote(expected)
        assert Repo.get!(TaskSchema, id).framework == unquote(expected)
      end
    end

    test "returns error when session/new called without sessionId", %{socket: socket} do
      initialize(socket)

      request(socket, "session/new", 2, %{})

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "error" => %{
          "code" => -32_602,
          "message" => "Missing required field: sessionId"
        }
      })
    end

    test "returns error when session/new called with invalid UUID", %{socket: socket} do
      initialize(socket)

      request(socket, "session/new", 2, %{"sessionId" => "not-a-valid-uuid"})

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "error" => %{
          "code" => -32_602,
          "message" => "Invalid sessionId: must be a valid UUID"
        }
      })
    end

    test "same-user session/new retries return the existing row", %{
      socket: socket,
      scope: scope
    } do
      allow_access_for_scope_fixture(scope)

      initialize(socket)

      existing_id = task_fixture(scope, framework: "vite").id
      model = "openrouter:google/gemini-3.1-pro-preview"

      request(socket, "session/new", 2, %{
        "sessionId" => existing_id,
        "_meta" => %{"frontman.dev/model" => model}
      })

      assert_push("acp:message", %{
        "id" => 2,
        "result" => %{
          "sessionId" => ^existing_id,
          "configOptions" => [%{"currentValue" => ^model}]
        }
      })

      assert Repo.get!(TaskSchema, existing_id).framework == :vite
      assert Repo.get!(TaskSchema, existing_id).current_model == model
      assert Repo.aggregate(TaskSchema.by_id(existing_id), :count, :id) == 1
      other_id = task_fixture(user_scope_fixture()).id

      request(socket, "session/new", 3, %{
        "sessionId" => other_id,
        "_meta" => %{"frontman.dev/model" => model}
      })

      assert_push("acp:message", %{
        "id" => 3,
        "error" => %{"code" => -32_602, "message" => "Failed to create session"}
      })
    end

    test "returns error when session/new called without clientInfo", %{socket: socket} do
      request(socket, "session/new", 1, %{"sessionId" => Ecto.UUID.generate()})

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "error" => %{
          "code" => -32_602,
          "message" => "Missing framework in clientInfo"
        }
      })
    end
  end

  describe "ACP unknown method" do
    test "returns method not found error", %{socket: socket} do
      request(socket, "unknown/method", 1, %{})

      assert_push("acp:message", %{
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
