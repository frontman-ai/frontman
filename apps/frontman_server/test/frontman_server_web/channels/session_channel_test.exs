defmodule FrontmanServerWeb.SessionChannelTest do
  use FrontmanServerWeb.ChannelCase, async: true

  alias FrontmanServerWeb.UserSocket
  alias FrontmanServer.Tasks

  describe "join session:<id>" do
    test "succeeds when session exists" do
      session_id = "sess_test_#{:rand.uniform(1_000_000)}"
      {:ok, ^session_id} = Tasks.create_task(session_id, %{})

      {:ok, reply, socket} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("session:#{session_id}", %{})

      assert reply == %{session_id: session_id}
      assert socket.assigns.session_id == session_id
    end

    test "fails when session does not exist" do
      {:error, reply} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("session:nonexistent_session", %{})

      assert reply == %{reason: "session_not_found"}
    end
  end

  describe "session/prompt" do
    setup do
      session_id = "sess_test_#{:rand.uniform(1_000_000)}"
      {:ok, ^session_id} = Tasks.create_task(session_id, %{})

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("session:#{session_id}", %{})

      {:ok, socket: socket, session_id: session_id}
    end

    test "returns error for unknown method", %{socket: socket} do
      ref =
        push(socket, "acp:message", %{
          "jsonrpc" => "2.0",
          "id" => 2,
          "method" => "unknown/method"
        })

      assert_reply ref, :ok, %{"acp:message" => response}
      assert response["error"]["code"] == -32601
      assert response["error"]["message"] =~ "Method not found"
    end
  end

  describe "MCP initialization" do
    test "sends MCP initialize request on join" do
      session_id = "sess_mcp_#{:rand.uniform(1_000_000)}"
      {:ok, ^session_id} = Tasks.create_task(session_id, %{})

      {:ok, _reply, _socket} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("session:#{session_id}", %{})

      # Agent should push MCP initialize request to browser
      assert_push "mcp:message", %{
        "jsonrpc" => "2.0",
        "id" => _id,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => "DRAFT-2025-v3",
          "clientInfo" => %{"name" => "frontman-server"}
        }
      }
    end

    test "handles MCP initialize response and sends initialized notification" do
      session_id = "sess_mcp_#{:rand.uniform(1_000_000)}"
      {:ok, ^session_id} = Tasks.create_task(session_id, %{})

      {:ok, _reply, socket} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("session:#{session_id}", %{})

      # Get the initialize request to capture the id
      assert_push "mcp:message", %{"id" => request_id}

      # Browser sends response
      push(socket, "mcp:message", %{
        "jsonrpc" => "2.0",
        "id" => request_id,
        "result" => %{
          "protocolVersion" => "DRAFT-2025-v3",
          "capabilities" => %{"tools" => %{}},
          "serverInfo" => %{"name" => "browser-mcp", "version" => "1.0.0"}
        }
      })

      # Agent should send initialized notification
      assert_push "mcp:message", %{
        "jsonrpc" => "2.0",
        "method" => "notifications/initialized"
      }
    end
  end
end
