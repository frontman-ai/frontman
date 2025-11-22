defmodule FrontmanServerWeb.SessionChannelDisconnectTest do
  use FrontmanServerWeb.ChannelCase, async: true

  alias FrontmanServerWeb.UserSocket
  alias FrontmanServer.Sessions

  # Helper to complete MCP initialization
  defp initialize_mcp_session(socket) do
    session_id = socket.assigns.session_id

    # Step 1: Initialize
    push(socket, "mcp:request", %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "initialize",
      "params" => %{
        "protocolVersion" => "2025-06-18",
        "capabilities" => %{},
        "clientInfo" => %{}
      }
    })

    # Step 2: Send initialized notification
    push(socket, "mcp:notification", %{
      "jsonrpc" => "2.0",
      "method" => "initialized"
    })

    # Server requests tools
    assert_push "mcp:request", %{
      "id" => request_id,
      "method" => "tools/list"
    }

    # Step 3: Respond with tools
    push(socket, "mcp:response", %{
      "jsonrpc" => "2.0",
      "id" => request_id,
      "result" => %{
        "tools" => [
          %{"name" => "test_tool", "description" => "Test", "inputSchema" => %{}}
        ]
      }
    })

    # Wait for ready event
    assert_push "session:ready", _

    # Wait for session state to actually be updated in the store
    wait_for_session_state(session_id, :ready)

    :ok
  end

  # Helper to wait for session to reach a specific state
  defp wait_for_session_state(session_id, expected_state, retries \\ 50) do
    case Sessions.get_session(session_id) do
      {:ok, %{state: ^expected_state}} ->
        :ok

      {:ok, %{state: _other_state}} when retries > 0 ->
        Process.sleep(10)
        wait_for_session_state(session_id, expected_state, retries - 1)

      {:ok, %{state: other_state}} ->
        raise "Session #{session_id} did not reach state #{expected_state}, stuck at #{other_state}"

      {:error, :not_found} when retries > 0 ->
        Process.sleep(10)
        wait_for_session_state(session_id, expected_state, retries - 1)

      {:error, :not_found} ->
        raise "Session #{session_id} not found"
    end
  end

  describe "disconnect handling" do
    test "marks session as disconnected on channel close" do
      session_id = "disconnect-test-#{:rand.uniform(1_000_000)}"

      {:ok, _, socket} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("session:#{session_id}", %{})

      # Initialize session
      initialize_mcp_session(socket)

      # Verify session is ready
      {:ok, session} = Sessions.get_session(session_id)
      assert session.state == :ready

      # Disconnect
      Process.unlink(socket.channel_pid)
      close(socket)

      # Give terminate callback time to run
      Process.sleep(10)

      # Verify session is marked as disconnected
      {:ok, session} = Sessions.get_session(session_id)
      assert session.state == :disconnected
      assert session.disconnected_at != nil
    end
  end

  describe "reconnection" do
    test "requires fresh capability announcement after reconnect" do
      session_id = "reconnect-test-#{:rand.uniform(1_000_000)}"

      # Initial connection
      {:ok, _, socket1} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("session:#{session_id}", %{})

      # Initialize session
      initialize_mcp_session(socket1)

      # Verify session is ready
      {:ok, session} = Sessions.get_session(session_id)
      assert session.state == :ready

      # Disconnect
      Process.unlink(socket1.channel_pid)
      close(socket1)

      # Give terminate callback time to run
      Process.sleep(10)

      # Verify session is disconnected
      {:ok, session} = Sessions.get_session(session_id)
      assert session.state == :disconnected

      # Reconnect
      {:ok, _, socket2} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("session:#{session_id}", %{})

      # Session should be awaiting capabilities again
      {:ok, session} = Sessions.get_session(session_id)
      assert session.state == :awaiting_caps
      assert session.disconnected_at == nil
      assert session.capabilities == %{}

      # Re-initialize MCP session
      initialize_mcp_session(socket2)

      # Session should be ready again
      {:ok, session} = Sessions.get_session(session_id)
      assert session.state == :ready
    end

    test "can create tasks after reconnection" do
      session_id = "reconnect-task-test-#{:rand.uniform(1_000_000)}"

      # Initial connection and setup
      {:ok, _, socket1} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("session:#{session_id}", %{})

      initialize_mcp_session(socket1)

      # Disconnect
      Process.unlink(socket1.channel_pid)
      close(socket1)
      Process.sleep(10)

      # Reconnect
      {:ok, _, socket2} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("session:#{session_id}", %{})

      # Re-initialize
      initialize_mcp_session(socket2)

      # Create task after reconnection
      task_id = "task-after-reconnect-#{:rand.uniform(1_000_000)}"

      ref =
        push(socket2, "task:create", %{"message" => "Hello after reconnect", "task_id" => task_id})

      assert_reply ref, :ok, %{task_id: ^task_id}

      # Verify task was created with session_id
      {:ok, task} = FrontmanServer.Tasks.get_task(task_id)
      assert task.session_id == session_id
    end
  end
end
