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

    test "receives streaming chunks after sending prompt", %{socket: socket, session_id: session_id} do
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "session/prompt",
        "params" => %{
          "sessionId" => session_id,
          "prompt" => [%{"type" => "text", "text" => "Hello"}]
        }
      })

      # Should receive at least one streaming chunk
      assert_push "acp:message", %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^session_id,
          "update" => %{
            "sessionUpdate" => "agent_message_chunk",
            "content" => %{"type" => "text", "text" => _text}
          }
        }
      }, 2000

      # Should eventually receive prompt response with stopReason
      assert_push "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "result" => %{"stopReason" => "end_turn"}
      }, 5000
    end

    test "returns error for unknown method", %{socket: socket} do
      ref = push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "unknown/method"
      })

      assert_reply ref, :ok, %{"acp:message" => response}
      assert response["error"]["code"] == -32601
      assert response["error"]["message"] =~ "Method not found"
    end
  end
end
