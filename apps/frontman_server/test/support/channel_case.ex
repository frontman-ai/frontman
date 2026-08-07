defmodule FrontmanServerWeb.ChannelCase do
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers
  alias FrontmanServer.Test.Fixtures.LLMProvider

  using do
    quote do
      import Phoenix.ChannelTest
      import FrontmanServerWeb.ChannelCase

      @endpoint FrontmanServerWeb.Endpoint

      @acp_message AgentClientProtocol.event_acp_message()
    end
  end

  defmacro complete_mcp_handshake(socket, opts \\ []) do
    quote do
      socket = unquote(socket)
      tools = unquote(opts) |> Keyword.get(:tools, [])

      load_project_context = unquote(opts) |> Keyword.get(:load_project_context, true)

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

      case load_project_context do
        true ->
          assert_push("mcp:message", %{
            "id" => project_rules_request_id,
            "method" => "tools/call",
            "params" => %{"name" => "load_agent_instructions"}
          })

          push(
            socket,
            "mcp:message",
            JsonRpc.success_response(project_rules_request_id, %{
              "content" => [
                %{
                  "type" => "text",
                  "text" =>
                    Jason.encode!([
                      %{"fullPath" => "/project/AGENTS.md", "content" => "project rules"}
                    ])
                }
              ]
            })
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

        false ->
          :ok
      end

      assert_push(@acp_message, %{
        "method" => "mcp_initialization_complete"
      })
    end
  end

  defmacro join_task_channel(scope, opts \\ []) do
    quote do
      scope = unquote(scope)
      framework = unquote(opts) |> Keyword.get(:framework, "nextjs")
      task_id = Ecto.UUID.generate()

      {:ok, %FrontmanServer.Tasks.TaskSchema{id: ^task_id}} =
        FrontmanServer.Tasks.create_task(scope, task_id, framework)

      {:ok, _reply, socket} =
        FrontmanServerWeb.UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      Mox.allow(FrontmanServer.Tasks.Execution.LLMProviderMock, self(), socket.channel_pid)

      {socket, task_id}
    end
  end

  def build_acp_request(method, id, params) do
    base = %{"jsonrpc" => "2.0", "method" => method, "params" => params}

    if id, do: Map.put(base, "id", id), else: base
  end

  def build_prompt_request(opts \\ []) do
    id = Keyword.get(opts, :id, 1)
    text = Keyword.get(opts, :text, "Hello")

    meta =
      Keyword.get(opts, :_meta, %{
        "model" => %{"provider" => "openrouter", "value" => "google/gemini-3-flash-preview"},
        "agent" => "test-frontman"
      })

    params = %{"prompt" => [%{"type" => "text", "text" => text}], "_meta" => meta}

    build_acp_request("session/prompt", id, params)
  end

  def flush_mailbox do
    receive do
      _ -> flush_mailbox()
    after
      0 -> :ok
    end
  end

  setup tags do
    if tags[:shared_sandbox] && tags[:async] do
      raise "Cannot combine shared_sandbox: true with async: true - shared sandbox requires synchronous execution"
    end

    shared = tags[:shared_sandbox] || not tags[:async]

    if shared do
      Mox.set_mox_global()
    end

    LLMProvider.stub_llm_response("Test response")

    pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: shared)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    {:ok, user} =
      Accounts.register_user(%{
        email: "channel_test_#{System.unique_integer([:positive])}@test.local",
        name: "Test User",
        password: "testpassword123!"
      })

    scope = Scope.for_user(user)
    {:ok, _api_key} = Providers.upsert_api_key(scope, "openrouter", "sk-or-test")

    {:ok, scope: scope, user: user}
  end
end
