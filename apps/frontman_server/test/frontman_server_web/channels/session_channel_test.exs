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
end
