defmodule FrontmanServerWeb.TasksChannelTest do
  use FrontmanServerWeb.ChannelCase, async: true

  alias FrontmanServerWeb.{ACP, UserSocket}

  setup do
    {:ok, _, socket} =
      UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join("tasks", %{})

    {:ok, socket: socket}
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
          "code" => -32600,
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
          "code" => -32602,
          "message" => "Missing required field: protocolVersion"
        }
      }
    end
  end

  describe "ACP session/new" do
    test "creates task and returns sessionId", %{socket: socket} do
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "session/new",
        "params" => %{}
      })

      assert_push "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "result" => %{"sessionId" => session_id}
      }

      # Session ID format: "sess_" + 24 hex chars
      assert String.starts_with?(session_id, "sess_")
      assert byte_size(session_id) == 5 + 24

      # Verify task was created in domain
      assert {:ok, task} = FrontmanServer.Tasks.get_task(session_id)
      assert task.task_id == session_id
    end

    test "extracts and stores framework from clientInfo", %{socket: socket} do
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
      assert {:ok, task} = FrontmanServer.Tasks.get_task(session_id)
      assert task.task_id == session_id
      assert task.framework == framework
    end

    test "handles session/new without clientInfo gracefully", %{socket: socket} do
      # Create session without initializing first
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "session/new",
        "params" => %{}
      })

      assert_push "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "result" => %{"sessionId" => session_id}
      }

      # Verify task was created without framework (nil)
      assert {:ok, task} = FrontmanServer.Tasks.get_task(session_id)
      assert task.task_id == session_id
      assert task.framework == nil
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
          "code" => -32601,
          "message" => "Method not found"
        }
      }
    end
  end
end
