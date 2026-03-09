defmodule FrontmanServerWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests.

  Such tests rely on `Phoenix.ChannelTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use FrontmanServerWeb.ChannelCase, async: true`,
  although this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import FrontmanServerWeb.ChannelCase

      # The default endpoint for testing
      @endpoint FrontmanServerWeb.Endpoint
    end
  end

  @doc """
  Completes the MCP handshake (initialize → tools/list → load_agent_instructions → list_tree).

  Uses `:sys.get_state/1` as a synchronization barrier after each push to ensure
  the channel process has fully processed the message before we assert the
  response. Without these barriers, under CI load (especially coverage runs),
  the channel process may not be scheduled in time and assert_push times out.

  ## Options

    * `:tools` - list of MCP tool definitions to return from `tools/list`
      (default: `[]`, which returns an empty tool set)

  ## Examples

      complete_mcp_handshake(socket)
      complete_mcp_handshake(socket, tools: [%{"name" => "get_logs", ...}])
  """
  defmacro complete_mcp_handshake(socket, opts \\ []) do
    quote do
      socket = unquote(socket)
      tools = unquote(opts) |> Keyword.get(:tools, [])

      :sys.get_state(socket.channel_pid)
      assert_push("mcp:message", %{"id" => init_request_id, "method" => "initialize"})

      init_result = %{
        "protocolVersion" => ModelContextProtocol.protocol_version(),
        "capabilities" => %{"tools" => %{}},
        "serverInfo" => %{"name" => "test-mcp", "version" => "1.0.0"}
      }

      push(socket, "mcp:message", JsonRpc.success_response(init_request_id, init_result))
      :sys.get_state(socket.channel_pid)

      assert_push("mcp:message", %{"method" => "notifications/initialized"})
      assert_push("mcp:message", %{"id" => tools_request_id, "method" => "tools/list"})

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(tools_request_id, %{"tools" => tools})
      )

      :sys.get_state(socket.channel_pid)

      assert_push("mcp:message", %{
        "id" => project_rules_request_id,
        "method" => "tools/call",
        "params" => %{"name" => "load_agent_instructions"}
      })

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(project_rules_request_id, %{"content" => []})
      )

      :sys.get_state(socket.channel_pid)

      assert_push("mcp:message", %{
        "id" => project_structure_request_id,
        "method" => "tools/call",
        "params" => %{"name" => "list_tree"}
      })

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(project_structure_request_id, %{"content" => []})
      )

      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "method" => "mcp_initialization_complete"
      })
    end
  end

  setup tags do
    if tags[:shared_sandbox] && tags[:async] do
      raise "Cannot combine shared_sandbox: true with async: true - shared sandbox requires synchronous execution"
    end

    shared = tags[:shared_sandbox] || not tags[:async]
    pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: shared)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    # Create a test user for scope
    {:ok, user} =
      Accounts.register_user(%{
        email: "channel_test_#{System.unique_integer([:positive])}@test.local",
        name: "Test User",
        password: "testpassword123!"
      })

    scope = Scope.for_user(user)
    {:ok, scope: scope, user: user}
  end
end
