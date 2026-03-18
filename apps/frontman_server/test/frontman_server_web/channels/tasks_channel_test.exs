defmodule FrontmanServerWeb.TasksChannelTest do
  # async: false required because "ACP session/load" describe block uses shared_sandbox: true
  # Shared sandbox mode is incompatible with async tests as it can interfere with other tests' connections
  use FrontmanServerWeb.ChannelCase, async: false

  alias AgentClientProtocol, as: ACP
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServerWeb.UserSocket

  setup %{scope: scope} do
    {:ok, _, socket} =
      UserSocket
      |> socket("user_id", %{scope: scope})
      |> subscribe_and_join("tasks", %{})

    {:ok, socket: socket, scope: scope}
  end

  describe "join tasks" do
    test "succeeds and sets acp_initialized to false", %{socket: socket} do
      assert socket.assigns.acp_initialized == false
    end
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

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "result" => %{
          "protocolVersion" => ^version,
          "agentInfo" => %{"name" => "frontman-server"}
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
        "result" => %{"sessionId" => ^client_session_id}
      })

      # Verify task was created with the client-provided ID
      assert {:ok, task} = FrontmanServer.Tasks.get_task(scope, client_session_id)
      assert task.task_id == client_session_id
      assert task.framework == "nextjs"
    end

    test "normalizes and stores framework from clientInfo", %{socket: socket, scope: scope} do
      version = ACP.protocol_version()

      # Client sends display label "Next.js" (as real middleware adapters do)
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => version,
          "clientInfo" => %{
            "name" => "frontman-client",
            "version" => "1.0.0",
            "_meta" => %{"framework" => "Next.js"}
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

      # Verify framework was normalized from "Next.js" to "nextjs"
      assert {:ok, task} = FrontmanServer.Tasks.get_task(scope, client_session_id)
      assert task.task_id == client_session_id
      assert task.framework == "nextjs"
    end

    test "normalizes vite framework from display label", %{socket: socket, scope: scope} do
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
            "_meta" => %{"framework" => "Vite"}
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
      assert task.framework == "vite"
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
      existing_id = Ecto.UUID.generate()
      {:ok, ^existing_id} = FrontmanServer.Tasks.create_task(scope, existing_id, "nextjs")

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
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = FrontmanServer.Tasks.create_task(scope, task_id, "nextjs")

      ref = push(socket, "list_sessions", %{})
      assert_reply(ref, :ok, %{"sessions" => [session]})

      assert session["sessionId"] == task_id
      assert session["title"] == "New Task"
      assert {:ok, _, _} = DateTime.from_iso8601(session["createdAt"])
      assert {:ok, _, _} = DateTime.from_iso8601(session["updatedAt"])
    end

    test "returns multiple sessions", %{socket: socket, scope: scope} do
      task1_id = Ecto.UUID.generate()
      {:ok, ^task1_id} = FrontmanServer.Tasks.create_task(scope, task1_id, "nextjs")

      task2_id = Ecto.UUID.generate()
      {:ok, ^task2_id} = FrontmanServer.Tasks.create_task(scope, task2_id, "nextjs")

      ref = push(socket, "list_sessions", %{})
      assert_reply(ref, :ok, %{"sessions" => sessions})

      assert length(sessions) == 2
      session_ids = Enum.map(sessions, & &1["sessionId"])
      assert task1_id in session_ids
      assert task2_id in session_ids
    end

    test "only returns tasks for authenticated user", %{socket: socket, scope: scope} do
      my_task_id = Ecto.UUID.generate()
      {:ok, ^my_task_id} = FrontmanServer.Tasks.create_task(scope, my_task_id, "nextjs")

      {:ok, other_user} =
        FrontmanServer.Accounts.register_user(%{
          email: "other_#{System.unique_integer([:positive])}@test.local",
          name: "Other",
          password: "testpassword123!"
        })

      other_scope = Scope.for_user(other_user)
      other_task_id = Ecto.UUID.generate()

      {:ok, ^other_task_id} =
        FrontmanServer.Tasks.create_task(other_scope, other_task_id, "vite")

      ref = push(socket, "list_sessions", %{})
      assert_reply(ref, :ok, %{"sessions" => [session]})
      assert session["sessionId"] == my_task_id
    end
  end

  describe "delete_session" do
    test "deletes session and returns empty result", %{socket: socket, scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = FrontmanServer.Tasks.create_task(scope, task_id, "nextjs")

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
      my_task_id = Ecto.UUID.generate()
      {:ok, ^my_task_id} = FrontmanServer.Tasks.create_task(scope, my_task_id, "nextjs")

      # Create another user and their task
      {:ok, other_user} =
        FrontmanServer.Accounts.register_user(%{
          email: "other_delete_#{System.unique_integer([:positive])}@test.local",
          name: "Other",
          password: "testpassword123!"
        })

      other_scope = Scope.for_user(other_user)
      other_task_id = Ecto.UUID.generate()

      {:ok, ^other_task_id} =
        FrontmanServer.Tasks.create_task(other_scope, other_task_id, "vite")

      # Trying to delete other user's task should fail (crashes the handler)
      # The channel will crash and the test process will receive an error
      ref = push(socket, "delete_session", %{"sessionId" => other_task_id})
      assert_reply(ref, :error, _)

      # Other user's task should still exist
      assert {:ok, _task} = FrontmanServer.Tasks.get_task(other_scope, other_task_id)
    end
  end

  describe "ACP session/load" do
    # Shared sandbox mode because submit_user_message can spawn agent Tasks needing DB access
    @describetag shared_sandbox: true

    setup %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = FrontmanServer.Tasks.create_task(scope, task_id, "nextjs")
      {:ok, task_id: task_id}
    end

    test "returns success for valid session", %{socket: socket, task_id: task_id} do
      push(socket, "acp:message", acp_request(1, "session/load", %{"sessionId" => task_id}))

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "result" => %{}
      })
    end

    test "streams user message history with timestamps", %{
      socket: socket,
      scope: scope,
      task_id: task_id
    } do
      FrontmanServer.Tasks.submit_user_message(
        scope,
        task_id,
        [%{"type" => "text", "text" => "Hello"}],
        []
      )

      FrontmanServer.Tasks.submit_user_message(
        scope,
        task_id,
        [%{"type" => "text", "text" => "World"}],
        []
      )

      push(socket, "acp:message", acp_request(1, "session/load", %{"sessionId" => task_id}))

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "user_message_chunk",
            "content" => %{"text" => "Hello"},
            "timestamp" => timestamp1
          }
        }
      })

      assert is_binary(timestamp1)

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "user_message_chunk",
            "content" => %{"text" => "World"},
            "timestamp" => timestamp2
          }
        }
      })

      assert is_binary(timestamp2)

      assert_push("acp:message", %{"id" => 1, "result" => %{}})
    end

    test "streams agent message history", %{
      socket: socket,
      scope: scope,
      task_id: task_id
    } do
      FrontmanServer.Tasks.add_agent_response(scope, task_id, "Response 1", %{})
      FrontmanServer.Tasks.add_agent_response(scope, task_id, "Response 2", %{})

      push(socket, "acp:message", acp_request(1, "session/load", %{"sessionId" => task_id}))

      # Per ACP spec: only agent_message_chunk exists (no start/end markers)
      # Client's LoadComplete handler finalizes any streaming messages
      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "agent_message_chunk",
            "content" => %{"text" => "Response 1"}
          }
        }
      })

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "agent_message_chunk",
            "content" => %{"text" => "Response 2"}
          }
        }
      })

      assert_push("acp:message", %{"id" => 1, "result" => %{}})
    end

    test "streams mixed history in order", %{socket: socket, scope: scope, task_id: task_id} do
      FrontmanServer.Tasks.submit_user_message(
        scope,
        task_id,
        [%{"type" => "text", "text" => "Question"}],
        []
      )

      FrontmanServer.Tasks.add_agent_response(scope, task_id, "Answer", %{})

      push(socket, "acp:message", acp_request(1, "session/load", %{"sessionId" => task_id}))

      # User message
      assert_push("acp:message", %{
        "params" => %{
          "update" => %{
            "sessionUpdate" => "user_message_chunk",
            "content" => %{"text" => "Question"}
          }
        }
      })

      # Per ACP spec: only agent_message_chunk exists (no start/end markers)
      assert_push("acp:message", %{
        "params" => %{
          "update" => %{
            "sessionUpdate" => "agent_message_chunk",
            "content" => %{"text" => "Answer"}
          }
        }
      })

      assert_push("acp:message", %{"id" => 1, "result" => %{}})
    end

    test "returns empty history for task with no messages", %{socket: socket, task_id: task_id} do
      push(socket, "acp:message", acp_request(1, "session/load", %{"sessionId" => task_id}))

      assert_push("acp:message", %{"id" => 1, "result" => %{}})
      refute_push("acp:message", %{"method" => "session/update"}, 100)
    end

    test "returns error for non-existent session", %{socket: socket} do
      push(
        socket,
        "acp:message",
        acp_request(1, "session/load", %{"sessionId" => Ecto.UUID.generate()})
      )

      assert_push("acp:message", %{
        "id" => 1,
        "error" => %{"code" => -32_602, "message" => "Session not found"}
      })
    end

    test "returns error for unauthorized session (appears as not found)", %{socket: socket} do
      # Security: Implementation returns "not found" for unauthorized access
      # to avoid revealing whether a resource exists
      {:ok, other_user} =
        FrontmanServer.Accounts.register_user(%{
          email: "other_load_#{System.unique_integer([:positive])}@test.local",
          name: "Other",
          password: "testpassword123!"
        })

      other_scope = Scope.for_user(other_user)
      other_task_id = Ecto.UUID.generate()

      {:ok, ^other_task_id} =
        FrontmanServer.Tasks.create_task(other_scope, other_task_id, "vite")

      push(socket, "acp:message", acp_request(1, "session/load", %{"sessionId" => other_task_id}))

      assert_push("acp:message", %{
        "id" => 1,
        "error" => %{"code" => -32_602, "message" => "Session not found"}
      })
    end

    test "returns error when sessionId missing", %{socket: socket} do
      push(socket, "acp:message", acp_request(1, "session/load", %{}))

      assert_push("acp:message", %{
        "id" => 1,
        "error" => %{"code" => -32_602, "message" => "Missing sessionId parameter"}
      })
    end
  end

  defp acp_request(id, method, params) do
    %{"jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params}
  end
end
