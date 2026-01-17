defmodule FrontmanServerWeb.TasksChannelTest do
  use FrontmanServerWeb.ChannelCase, async: true

  alias AgentClientProtocol, as: ACP
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

      assert_push "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "result" => %{
          "protocolVersion" => ^version,
          "agentInfo" => %{"name" => "frontman-server"}
        }
      }
    end

    test "fails with wrong protocol version", %{socket: socket} do
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{"protocolVersion" => 999}
      })

      assert_push "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "error" => %{
          "code" => -32_600,
          "message" => "Unsupported protocol version"
        }
      }
    end

    test "fails without protocol version", %{socket: socket} do
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{}
      })

      assert_push "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "error" => %{
          "code" => -32_602,
          "message" => "Missing required field: protocolVersion"
        }
      }
    end
  end

  describe "ACP session/new" do
    test "creates task and returns sessionId", %{socket: socket, scope: scope} do
      version = ACP.protocol_version()

      # Initialize first to set clientInfo with framework
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => version,
          "clientInfo" => %{"name" => "test-client", "version" => "1.0.0"}
        }
      })

      assert_push "acp:message", %{"id" => 1, "result" => %{}}

      # Now create session
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "session/new",
        "params" => %{}
      })

      assert_push "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "result" => %{"sessionId" => session_id}
      }

      # Session ID is a UUID
      assert {:ok, _} = Ecto.UUID.cast(session_id)

      # Verify task was created in domain
      assert {:ok, task} = FrontmanServer.Tasks.get_task(scope, session_id)
      assert task.task_id == session_id
    end

    test "extracts and stores framework from clientInfo", %{socket: socket, scope: scope} do
      version = ACP.protocol_version()
      framework = "test-client-app"

      # First initialize with clientInfo
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => version,
          "clientInfo" => %{"name" => framework, "version" => "1.0.0"}
        }
      })

      assert_push "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "result" => %{
          "protocolVersion" => ^version,
          "agentInfo" => %{"name" => "frontman-server"}
        }
      }

      # Then create a session
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "session/new",
        "params" => %{}
      })

      assert_push "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "result" => %{"sessionId" => session_id}
      }

      # Verify task was created with framework
      assert {:ok, task} = FrontmanServer.Tasks.get_task(scope, session_id)
      assert task.task_id == session_id
      assert task.framework == framework
    end

    test "returns error when session/new called without clientInfo", %{socket: socket} do
      # Create session without initializing first - should fail
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "session/new",
        "params" => %{}
      })

      assert_push "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "error" => %{
          "code" => -32_602,
          "message" => "Missing framework in clientInfo"
        }
      }
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

      assert_push "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "error" => %{
          "code" => -32_601,
          "message" => "Method not found"
        }
      }
    end
  end
end
