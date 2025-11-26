defmodule FrontmanServerWeb.SessionsChannelTest do
  use FrontmanServerWeb.ChannelCase, async: true

  alias FrontmanServerWeb.UserSocket

  setup do
    {:ok, _, socket} =
      UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join("sessions", %{})

    {:ok, socket: socket}
  end

  describe "join sessions" do
    test "succeeds and returns status", %{socket: socket} do
      assert socket.assigns.acp_initialized == false
    end
  end

  describe "ACP initialize" do
    test "succeeds with matching protocol version", %{socket: socket} do
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => 1,
          "clientInfo" => %{"name" => "test-client", "version" => "1.0.0"}
        }
      })

      assert_push "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "result" => %{
          "protocolVersion" => 1,
          "agentInfo" => %{"name" => "frontman-server"}
        }
      }
    end

    test "fails with wrong protocol version", %{socket: socket} do
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => 999
        }
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
    test "creates new session and returns sessionId", %{socket: socket} do
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

      assert String.starts_with?(session_id, "sess_")
      assert String.length(session_id) == 29

      # Verify task was created
      {:ok, task} = FrontmanServer.Tasks.get_task(session_id)
      assert task.task_id == session_id
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
