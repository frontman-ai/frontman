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
  alias FrontmanServer.Providers
  alias FrontmanServer.Test.Fixtures.LLMProvider

  using do
    quote do
      import Phoenix.ChannelTest, except: [subscribe_and_join: 3]
      import FrontmanServerWeb.ChannelCase

      @endpoint FrontmanServerWeb.Endpoint

      @acp_message AgentClientProtocol.event_acp_message()
    end
  end

  @doc false
  def subscribe_and_join(socket, topic, payload) do
    supervisor = Process.get(:channel_case_channel_supervisor)
    socket = %{socket | transport: {Phoenix.ChannelTest, supervisor}}

    case Phoenix.ChannelTest.subscribe_and_join(socket, topic, payload) do
      {:ok, reply, joined_socket} ->
        Process.unlink(joined_socket.channel_pid)
        track_task_channel(joined_socket.channel_pid)
        {:ok, reply, joined_socket}

      error ->
        error
    end
  end

  @doc """
  Completes the MCP handshake and optional project-context loading.

  Uses `:sys.get_state/1` as a synchronization barrier after each push to ensure
  the channel process has fully processed the message before assertions.
  """
  defmacro complete_mcp_handshake(socket, opts \\ []) do
    complete_mcp_handshake_ast(socket, opts, true)
  end

  @doc "Completes the MCP handshake without requiring a task channel."
  defmacro complete_mcp_handshake_for_scope(scope, opts \\ []) do
    complete_mcp_handshake_ast(scope, opts, false)
  end

  defp complete_mcp_handshake_ast(connection, opts, synchronize_task_channel?) do
    quote do
      connection = unquote(connection)
      tools = unquote(opts) |> Keyword.get(:tools, [])

      scope =
        unquote(
          if synchronize_task_channel?,
            do: quote(do: connection.assigns.scope),
            else: quote(do: connection)
        )

      {:ok, _, mcp_socket} =
        FrontmanServerWeb.UserSocket
        |> socket("mcp-owner-#{System.unique_integer([:positive])}", %{scope: scope})
        |> subscribe_and_join("tasks", %{})

      FrontmanServerWeb.ChannelCase.track_task_channel(mcp_socket.channel_pid)

      push(mcp_socket, "mcp:ready", %{})
      :sys.get_state(mcp_socket.channel_pid)
      assert_push("mcp:message", %{"id" => init_request_id, "method" => "server/discover"})

      init_result = %{
        "resultType" => "complete",
        "supportedVersions" => [ModelContextProtocol.protocol_version()],
        "capabilities" => %{
          "tools" => %{},
          "extensions" => %{"ai.frontman/execution-context" => %{"version" => 1}}
        },
        "_meta" => %{
          "io.modelcontextprotocol/serverInfo" => %{
            "name" => "test-mcp",
            "version" => "1.0.0"
          }
        },
        "ttlMs" => 0,
        "cacheScope" => "private"
      }

      push(mcp_socket, "mcp:message", JsonRpc.success_response(init_request_id, init_result))
      :sys.get_state(mcp_socket.channel_pid)

      assert_push("mcp:message", %{"id" => tools_request_id, "method" => "tools/list"})

      push(
        mcp_socket,
        "mcp:message",
        JsonRpc.success_response(tools_request_id, %{
          "resultType" => "complete",
          "tools" => tools,
          "ttlMs" => 0,
          "cacheScope" => "private"
        })
      )

      :sys.get_state(mcp_socket.channel_pid)

      unquote(
        if synchronize_task_channel? do
          quote do
            :sys.get_state(connection.channel_pid)
            :sys.get_state(connection.channel_pid)
          end
        else
          quote do: :ok
        end
      )

      mcp_socket
    end
  end

  @doc """
  Creates a task and joins the task channel, returning `{socket, task_id}`.

  Extracts the repeated pattern of `Tasks.create_task` + `subscribe_and_join`
  that appears in virtually every channel test setup block.

  ## Options

    * `:framework` - framework name for the task (default: `"nextjs"`)

  ## Examples

      {socket, task_id} = join_task_channel(scope)
      {socket, task_id} = join_task_channel(scope, framework: "nextjs")
  """
  defmacro join_task_channel(scope, opts \\ []) do
    quote do
      scope = unquote(scope)
      framework = unquote(opts) |> Keyword.get(:framework, "nextjs")
      task_id = Ecto.UUID.generate()

      {:ok, %FrontmanServer.Tasks.TaskSchema{id: ^task_id}} =
        FrontmanServer.Tasks.create_task(scope, task_id, framework)

      track_task_execution(task_id)

      {:ok, _reply, socket} =
        FrontmanServerWeb.UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task_id}", %{})

      track_task_channel(socket.channel_pid)
      Mox.allow(FrontmanServer.Tasks.Execution.LLMProviderMock, self(), socket.channel_pid)

      {socket, task_id}
    end
  end

  @doc """
  Builds a JSON-RPC request map for ACP messages.

  ## Examples

      build_acp_request("session/prompt", 42, %{"prompt" => [%{"type" => "text", "text" => "Hello"}]})
      build_acp_request("session/cancel", nil, %{"sessionId" => "irrelevant"})
  """
  def build_acp_request(method, id, params) do
    base = %{"jsonrpc" => "2.0", "method" => method, "params" => params}

    if id, do: Map.put(base, "id", id), else: base
  end

  @doc """
  Builds a JSON-RPC `session/prompt` request for channel tests.

  Convenience wrapper around `build_acp_request/3`.

  ## Options

    * `:id` - JSON-RPC request id (default: `1`)
    * `:text` - prompt text (default: `"Hello"`)
    * `:_meta` - _meta map with selected model and agent

  ## Examples

      build_prompt_request()
      build_prompt_request(id: 42, text: "Next question")
      build_prompt_request(_meta: %{"model" => %{"provider" => "openrouter", "value" => "google/gemini-3-flash-preview"}})
  """
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

  @doc """
  Drains all messages from the test process mailbox.

  Useful after setup blocks that trigger PubSub broadcasts, ensuring
  subsequent assertions aren't polluted by leftover messages.
  """
  def flush_mailbox do
    receive do
      _ -> flush_mailbox()
    after
      0 -> :ok
    end
  end

  @doc "Waits until the supervised execution for a task has terminated."
  def await_task_execution(task_id, timeout \\ 5_000) do
    task_id
    |> execution_processes()
    |> await_processes(task_id, timeout)
  end

  @doc "Cancels a supervised task execution and waits for its worker to terminate."
  def stop_task_execution(task_id, timeout \\ 5_000) do
    registry = SwarmAi.registry_name(FrontmanServer.AgentRuntime)
    processes = Registry.lookup(registry, task_id) |> Enum.map(&elem(&1, 0))

    case processes do
      [_pid] ->
        SwarmAi.cancel(FrontmanServer.AgentRuntime, task_id)
        await_processes(processes, task_id, timeout)

      [] ->
        await_processes(processes, task_id, timeout)
    end
  end

  @doc false
  def track_task_execution(task_id) do
    case Process.get(:channel_case_task_tracker) do
      nil -> :ok
      tracker -> Agent.update(tracker, &MapSet.put(&1, task_id))
    end

    :ok
  end

  @doc false
  def track_task_channel(channel_pid) do
    case Process.get(:channel_case_channel_tracker) do
      nil -> :ok
      tracker -> Agent.update(tracker, &MapSet.put(&1, channel_pid))
    end

    :ok
  end

  defp execution_processes(task_id) do
    registry = SwarmAi.registry_name(FrontmanServer.AgentRuntime)
    Registry.lookup(registry, task_id) |> Enum.map(&elem(&1, 0))
  end

  defp await_processes([], _task_id, _timeout), do: :ok

  defp await_processes(pids, task_id, timeout) do
    case wait_for_processes(pids, timeout) do
      :ok -> :ok
      :timeout -> flunk("execution processes for task #{task_id} did not terminate")
    end
  end

  defp wait_for_processes(pids, timeout) do
    monitors = pids |> Enum.uniq() |> Map.new(&{Process.monitor(&1), &1})
    deadline = System.monotonic_time(:millisecond) + timeout
    wait_for_process_down(monitors, deadline)
  end

  defp wait_for_process_down(monitors, _deadline) when map_size(monitors) == 0, do: :ok

  defp wait_for_process_down(monitors, deadline) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {:DOWN, monitor, :process, _pid, _reason} ->
        wait_for_process_down(Map.delete(monitors, monitor), deadline)
    after
      remaining ->
        Enum.each(monitors, fn {monitor, _pid} -> Process.demonitor(monitor, [:flush]) end)
        :timeout
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

    {:ok, user} =
      Accounts.register_user(%{
        email: "channel_test_#{System.unique_integer([:positive])}@test.local",
        name: "Test User",
        password: "testpassword123!"
      })

    scope = Scope.for_user(user)
    {:ok, _api_key} = Providers.upsert_api_key(scope, "openrouter", "sk-or-test")
    {:ok, tracker} = Agent.start(fn -> MapSet.new() end)
    {:ok, channel_tracker} = Agent.start(fn -> MapSet.new() end)

    {:ok, channel_supervisor} =
      Supervisor.start_link([], strategy: :one_for_one, max_restarts: 1_000_000, max_seconds: 1)

    Process.unlink(channel_supervisor)
    Process.put(:channel_case_task_tracker, tracker)
    Process.put(:channel_case_channel_tracker, channel_tracker)
    Process.put(:channel_case_channel_supervisor, channel_supervisor)

    on_exit(fn ->
      tracker
      |> Agent.get(& &1)
      |> Enum.each(&stop_task_execution/1)

      channel_tracker
      |> Agent.get(& &1)
      |> Enum.sort_by(&channel_stop_priority/1)
      |> Enum.each(&stop_channel/1)

      Supervisor.stop(channel_supervisor, :normal, 5_000)
      Agent.stop(channel_tracker)
      Agent.stop(tracker)
      Sandbox.stop_owner(pid)
    end)

    {:ok, scope: scope, user: user}
  end

  defp channel_stop_priority(channel_pid) do
    case Process.info(channel_pid, :dictionary) do
      {:dictionary, dictionary} ->
        case Keyword.get(dictionary, :"$logger_metadata", %{}) do
          %{topic: "tasks"} -> 1
          _metadata -> 0
        end

      nil ->
        0
    end
  end

  defp stop_channel(channel_pid) do
    monitor = Process.monitor(channel_pid)

    case Process.alive?(channel_pid) do
      true ->
        try do
          GenServer.stop(channel_pid, :normal, 5_000)
        catch
          :exit, _stop_reason -> await_channel_exit(channel_pid, monitor)
        end

      false ->
        await_channel_exit(channel_pid, monitor)
    end

    Process.demonitor(monitor, [:flush])
  end

  defp await_channel_exit(channel_pid, monitor) do
    receive do
      {:DOWN, ^monitor, :process, ^channel_pid, reason} -> reason
    after
      5_000 -> flunk("channel #{inspect(channel_pid)} did not terminate")
    end
  end
end
