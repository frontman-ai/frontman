defmodule FrontmanServerWeb.SessionChannelTest do
  use FrontmanServerWeb.ChannelCase, async: true
  use FrontmanServer.CassetteCase

  alias FrontmanServerWeb.UserSocket

  setup do
    session_id = "test-channel-#{:rand.uniform(1_000_000)}"

    {:ok, _, socket} =
      UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join("session:#{session_id}", %{})

    {:ok, socket: socket, session_id: session_id}
  end

  # Helper to complete MCP initialization
  defp initialize_mcp_session(socket) do
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

    # Wait for ready
    assert_push "session:ready", _

    :ok
  end

  describe "join session:*" do
    test "creates session on join", %{session_id: session_id} do
      # Verify session was created
      assert {:ok, session} = FrontmanServer.Sessions.get_session(session_id)
      assert session.state == :awaiting_caps
    end

    test "returns session_id and status", %{socket: socket, session_id: session_id} do
      assert socket.assigns.session_id == session_id
      assert socket.assigns.session_state == :awaiting_caps
    end
  end

  describe "MCP protocol initialization" do
    test "handles initialize request", %{socket: socket} do
      ref =
        push(socket, "mcp:request", %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "initialize",
          "params" => %{
            "protocolVersion" => "2025-06-18",
            "capabilities" => %{"tools" => %{}},
            "clientInfo" => %{"name" => "test-browser", "version" => "1.0.0"}
          }
        })

      assert_reply ref, :ok, %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "result" => %{
          "protocolVersion" => "2025-06-18",
          "capabilities" => %{"tools" => %{}},
          "serverInfo" => %{"name" => "frontman-server", "version" => "1.0.0"}
        }
      }
    end

    test "requests tools after initialized notification", %{
      socket: socket,
      session_id: session_id
    } do
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

      # Server should request tools from browser
      assert_push "mcp:request", %{
        "jsonrpc" => "2.0",
        "id" => request_id,
        "method" => "tools/list"
      }

      # Step 3: Browser responds with tools
      tools = [
        %{
          "name" => "log_message",
          "description" => "Log a message to console",
          "inputSchema" => %{
            "type" => "object",
            "properties" => %{"message" => %{"type" => "string"}}
          }
        }
      ]

      push(socket, "mcp:response", %{
        "jsonrpc" => "2.0",
        "id" => request_id,
        "result" => %{"tools" => tools}
      })

      # Session should now be ready
      assert_push "session:ready", %{session_id: ^session_id}

      # Verify in store
      {:ok, session} = FrontmanServer.Sessions.get_session(session_id)
      assert session.state == :ready
      assert Map.has_key?(session.capabilities, "log_message")
    end
  end

  describe "task:create" do
    setup %{socket: socket} do
      # Initialize MCP session first
      initialize_mcp_session(socket)
      :ok
    end

    @tag :skip_cassette
    test "creates task with session_id", %{socket: socket, session_id: session_id} do
      task_id = "task-#{:rand.uniform(1_000_000)}"

      ref = push(socket, "task:create", %{"message" => "Hello", "task_id" => task_id})
      assert_reply ref, :ok, %{task_id: ^task_id}

      # Verify task was created with session_id
      {:ok, task} = FrontmanServer.Tasks.get_task(task_id)
      assert task.session_id == session_id
    end

    @tag :skip_cassette
    test "rejects task creation if session not ready", %{session_id: _session_id} do
      # Create new session without MCP initialization
      new_session_id = "test-not-ready-#{:rand.uniform(1_000_000)}"

      {:ok, _, socket} =
        UserSocket
        |> socket("user_id", %{})
        |> subscribe_and_join("session:#{new_session_id}", %{})

      task_id = "task-#{:rand.uniform(1_000_000)}"
      ref = push(socket, "task:create", %{"message" => "Hello", "task_id" => task_id})
      assert_reply ref, :error, %{reason: "session_not_ready"}
    end
  end
end
