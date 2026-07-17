defmodule FrontmanServerWeb.TasksChannelTest do
  use FrontmanServerWeb.ChannelCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias AgentClientProtocol, as: ACP
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

  describe "ACP initialize" do
    test "succeeds with matching protocol version", %{socket: socket} do
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

      assert_push("config_options_updated", %{"configOptions" => _})

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "result" => %{
          "protocolVersion" => ^version,
          "agentInfo" => %{"name" => "frontman-server"}
        }
      })
    end

    test "rejects malformed Frontman agent attribution metadata", %{socket: socket} do
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => ACP.protocol_version(),
          "clientCapabilities" => %{
            "_meta" => %{"frontman.dev" => %{"agentAttribution" => "invalid"}}
          }
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

    test "fails with wrong protocol version", %{socket: socket} do
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{"protocolVersion" => 999}
      })

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
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{}
      })

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
      version = ACP.protocol_version()

      # Initialize first to set clientInfo with framework in metadata
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => version,
          "clientInfo" => %{
            "name" => "test-client",
            "version" => "1.0.0",
            "_meta" => %{"framework" => "nextjs"}
          }
        }
      })

      assert_push("acp:message", %{"id" => 1, "result" => %{}})

      # Now create session with client-generated sessionId
      client_session_id = Ecto.UUID.generate()

      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "session/new",
        "params" => %{"sessionId" => client_session_id}
      })

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "result" => %{
          "sessionId" => ^client_session_id,
          "_meta" => %{
            "frontman.dev/agents" => [
              %{"id" => "test-frontman"},
              %{"id" => "test-planner"}
            ]
          }
        }
      })

      # Verify task was created with the client-provided ID
      assert {:ok, task} = FrontmanServer.Tasks.get_task(scope, client_session_id)
      assert task.id == client_session_id
      assert task.framework == :nextjs
    end

    test "stores framework ID from clientInfo", %{socket: socket, scope: scope} do
      version = ACP.protocol_version()

      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => version,
          "clientInfo" => %{
            "name" => "frontman-client",
            "version" => "1.0.0",
            "_meta" => %{"framework" => "nextjs"}
          }
        }
      })

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "result" => %{
          "protocolVersion" => ^version,
          "agentInfo" => %{"name" => "frontman-server"}
        }
      })

      # Then create a session with client-generated sessionId
      client_session_id = Ecto.UUID.generate()

      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "session/new",
        "params" => %{"sessionId" => client_session_id}
      })

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "result" => %{"sessionId" => ^client_session_id}
      })

      assert {:ok, task} = FrontmanServer.Tasks.get_task(scope, client_session_id)
      assert task.id == client_session_id
      assert task.framework == :nextjs
      assert Repo.get!(TaskSchema, client_session_id).framework == :nextjs
    end

    test "stores vite framework ID from clientInfo", %{socket: socket, scope: scope} do
      version = ACP.protocol_version()

      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => version,
          "clientInfo" => %{
            "name" => "frontman-client",
            "version" => "1.0.0",
            "_meta" => %{"framework" => "vite"}
          }
        }
      })

      assert_push("acp:message", %{"id" => 1, "result" => %{}})

      client_session_id = Ecto.UUID.generate()

      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "session/new",
        "params" => %{"sessionId" => client_session_id}
      })

      assert_push("acp:message", %{"id" => 2, "result" => %{}})

      assert {:ok, task} = FrontmanServer.Tasks.get_task(scope, client_session_id)
      assert task.framework == :vite
      assert Repo.get!(TaskSchema, client_session_id).framework == :vite
    end

    test "returns error when session/new called without sessionId", %{socket: socket} do
      version = ACP.protocol_version()

      # Initialize first
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => version,
          "clientInfo" => %{
            "name" => "test-client",
            "version" => "1.0.0",
            "_meta" => %{"framework" => "nextjs"}
          }
        }
      })

      assert_push("acp:message", %{"id" => 1, "result" => %{}})

      # Create session without sessionId - should fail
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "session/new",
        "params" => %{}
      })

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
      version = ACP.protocol_version()

      # Initialize first
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => version,
          "clientInfo" => %{
            "name" => "test-client",
            "version" => "1.0.0",
            "_meta" => %{"framework" => "nextjs"}
          }
        }
      })

      assert_push("acp:message", %{"id" => 1, "result" => %{}})

      # Create session with non-UUID string - should fail gracefully
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "session/new",
        "params" => %{"sessionId" => "not-a-valid-uuid"}
      })

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "error" => %{
          "code" => -32_602,
          "message" => "Invalid sessionId: must be a valid UUID"
        }
      })
    end

    test "returns error when session/new called with duplicate sessionId", %{
      socket: socket,
      scope: scope
    } do
      version = ACP.protocol_version()

      # Initialize first
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => version,
          "clientInfo" => %{
            "name" => "test-client",
            "version" => "1.0.0",
            "_meta" => %{"framework" => "nextjs"}
          }
        }
      })

      assert_push("acp:message", %{"id" => 1, "result" => %{}})

      # Pre-create a task with a known ID
      existing_id = task_fixture(scope).id

      # Try to create session with the same ID - should fail gracefully
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "session/new",
        "params" => %{"sessionId" => existing_id}
      })

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "error" => %{
          "code" => -32_602,
          "message" => "Failed to create session"
        }
      })
    end

    test "returns error when session/new called without clientInfo", %{socket: socket} do
      # Create session without initializing first - should fail
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "session/new",
        "params" => %{"sessionId" => Ecto.UUID.generate()}
      })

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
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "unknown/method",
        "params" => %{}
      })

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

      # Verify task exists
      assert {:ok, _task} = FrontmanServer.Tasks.get_task(scope, task_id)

      # Delete session
      ref = push(socket, "delete_session", %{"sessionId" => task_id})
      assert_reply(ref, :ok, %{})

      # Verify task is deleted
      assert {:error, :not_found} = FrontmanServer.Tasks.get_task(scope, task_id)
    end

    test "only deletes own sessions", %{socket: socket, scope: scope} do
      # Create task for current user
      _my_task_id = task_fixture(scope).id

      # Create another user and their task
      other_scope = user_scope_fixture()
      other_task_id = task_fixture(other_scope, framework: "vite").id

      # Trying to delete other user's task should fail (crashes the handler)
      # The channel will crash and the test process will receive an error
      ref = push(socket, "delete_session", %{"sessionId" => other_task_id})
      assert_reply(ref, :error, _)

      # Other user's task should still exist
      assert {:ok, _task} = FrontmanServer.Tasks.get_task(other_scope, other_task_id)
    end
  end
end
