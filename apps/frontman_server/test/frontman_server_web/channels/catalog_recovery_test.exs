defmodule FrontmanServerWeb.CatalogRecoveryTest do
  use FrontmanServerWeb.ChannelCase, async: false

  alias FrontmanServer.Providers
  alias FrontmanServer.Providers.OAuthToken
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.{Interaction, InteractionSchema}
  alias FrontmanServerWeb.UserSocket

  setup {Req.Test, :set_req_test_from_context}
  setup {Req.Test, :verify_on_exit!}

  setup %{scope: scope} do
    %OAuthToken{user_id: scope.user.id}
    |> OAuthToken.changeset(%{
      provider: "openai_codex",
      access_token: "catalog-test-access",
      refresh_token: "catalog-test-refresh",
      expires_at: OAuthToken.calculate_expires_at(3600),
      metadata: %{"account_id" => "catalog-test-account"}
    })
    |> Repo.insert!()

    :ok
  end

  for channel <- [:tasks, :task] do
    @channel channel
    test "#{channel} recovers discovery in the same session and preserves verified config", %{
      scope: scope
    } do
      fail_discovery()
      socket = join_catalog_channel(@channel, scope)
      Req.Test.allow(:openai_oauth, self(), socket.channel_pid)

      request_catalog(@channel, socket)
      state = :sys.get_state(socket.channel_pid)
      refute codex?(state.assigns.model_catalog)
      {timer_ref, token} = state.assigns.catalog_refresh_timer

      # Repeated requests during an outage share one timer and do no network work.
      request_catalog(@channel, socket)
      state = :sys.get_state(socket.channel_pid)
      assert state.assigns.catalog_refresh_timer == {timer_ref, token}

      succeed_discovery(["gpt-6-sol"])
      send(socket.channel_pid, {:catalog_refresh, token})
      state = :sys.get_state(socket.channel_pid)
      verified = state.assigns.model_catalog.groups
      assert codex?(state.assigns.model_catalog)
      assert state.assigns.catalog_refresh_timer == nil
      assert Process.read_timer(timer_ref) == false
      assert_push("config_options_updated", %{"configOptions" => _})

      fail_discovery()
      request_catalog(@channel, socket)
      state = :sys.get_state(socket.channel_pid)
      assert state.assigns.model_catalog.groups == verified
      {_ref, next_token} = state.assigns.catalog_refresh_timer

      # Old timer messages cannot start another request or replace the active timer.
      send(socket.channel_pid, {:catalog_refresh, token})

      assert :sys.get_state(socket.channel_pid).assigns.catalog_refresh_timer ==
               state.assigns.catalog_refresh_timer

      succeed_discovery([])
      send(socket.channel_pid, {:catalog_refresh, next_token})
      state = :sys.get_state(socket.channel_pid)
      refute codex?(state.assigns.model_catalog)
      assert state.assigns.catalog_refresh_timer == nil
    end

    test "#{channel} clears retained models immediately when credentials disconnect", %{
      scope: scope
    } do
      succeed_discovery(["gpt-6-sol"])
      socket = join_catalog_channel(@channel, scope)
      Req.Test.allow(:openai_oauth, self(), socket.channel_pid)
      request_catalog(@channel, socket)
      assert codex?(:sys.get_state(socket.channel_pid).assigns.model_catalog)

      fail_discovery()
      request_catalog(@channel, socket)
      {timer_ref, token} = :sys.get_state(socket.channel_pid).assigns.catalog_refresh_timer

      assert :ok = Providers.delete_oauth_token(scope, "openai_codex")
      send(socket.channel_pid, :config_options_changed)
      state = :sys.get_state(socket.channel_pid)
      refute codex?(state.assigns.model_catalog)
      assert state.assigns.catalog_refresh_timer == nil
      assert Process.read_timer(timer_ref) == false

      send(socket.channel_pid, {:catalog_refresh, token})
      refute codex?(:sys.get_state(socket.channel_pid).assigns.model_catalog)
    end
  end

  test "a discovery outage during execution retries the queued prompt after recovery", %{
    scope: scope
  } do
    socket = join_catalog_channel(:task, scope)
    Req.Test.allow(:openai_oauth, self(), socket.channel_pid)
    complete_mcp_handshake(socket)
    succeed_discovery(["gpt-6-sol"])
    request_catalog(:task, socket)
    :sys.get_state(socket.channel_pid)
    :sys.get_state(socket.channel_pid)
    task_id = socket.assigns.task_id
    Phoenix.PubSub.subscribe(FrontmanServer.PubSub, "task:#{task_id}")

    {:ok, _message} =
      Tasks.submit_user_message(scope, %{
        task_id: task_id,
        message_id: Ecto.UUID.generate(),
        message: [%{"type" => "text", "text" => "Build the page"}],
        agent_id: "test-frontman",
        model: "openai_codex:gpt-6-sol"
      })

    fail_discovery()
    execution = FrontmanServer.Test.Fixtures.Tasks.execution_request_fixture()
    send(socket.channel_pid, {:execute_next_turn, execution})
    state = :sys.get_state(socket.channel_pid)
    {_ref, token} = state.assigns.catalog_refresh_timer
    assert {:ok, :no_active_turn} = Tasks.get_active_turn_unresolved_tool_calls(scope, task_id)

    Req.Test.stub(:openai_oauth, fn conn ->
      Req.Test.json(conn, %{"models" => [%{"slug" => "gpt-6-sol", "visibility" => "list"}]})
    end)

    send(socket.channel_pid, {:catalog_refresh, token})

    assert_receive {:interaction,
                    %InteractionSchema{data: %Interaction.AgentCompleted{}, turn_number: 1}},
                   5_000
  end

  defp join_catalog_channel(:tasks, scope) do
    {:ok, _, socket} =
      UserSocket
      |> socket("catalog-user", %{scope: scope})
      |> subscribe_and_join("tasks", %{})

    socket
  end

  defp join_catalog_channel(:task, scope) do
    {socket, _task_id} = join_task_channel(scope)
    socket
  end

  defp request_catalog(:tasks, socket) do
    push(socket, "acp:message", build_acp_request("initialize", 1, %{"protocolVersion" => 1}))
  end

  defp request_catalog(:task, socket) do
    push(
      socket,
      "acp:message",
      build_acp_request("session/load", 1, %{"sessionId" => socket.assigns.task_id})
    )
  end

  defp codex?(catalog), do: Enum.any?(catalog.groups, &(&1.id == "openai_codex"))

  defp fail_discovery do
    Req.Test.expect(:openai_oauth, fn conn ->
      conn |> Plug.Conn.put_status(503) |> Req.Test.json(%{"error" => "unavailable"})
    end)
  end

  defp succeed_discovery(ids) do
    Req.Test.expect(:openai_oauth, fn conn ->
      Req.Test.json(conn, %{"models" => Enum.map(ids, &%{"slug" => &1, "visibility" => "list"})})
    end)
  end
end
