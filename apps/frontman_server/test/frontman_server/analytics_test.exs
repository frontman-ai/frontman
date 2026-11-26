defmodule FrontmanServer.AnalyticsTest do
  use FrontmanServer.DataCase, async: false

  alias FrontmanServer.Analytics
  alias FrontmanServer.Workers.DeliverHeapEvent

  setup do
    previous = Application.get_env(:frontman_server, Analytics)
    Application.put_env(:frontman_server, Analytics, enabled: true, anonymous_enabled: false)

    on_exit(fn ->
      case previous do
        nil -> Application.delete_env(:frontman_server, Analytics)
        config -> Application.put_env(:frontman_server, Analytics, config)
      end
    end)

    :ok
  end

  test "persists only the safe envelope and uses the UUID as Heap identity" do
    user_id = Ecto.UUID.generate()

    assert :ok =
             Analytics.track("auth_completed", %{
               user_id: user_id,
               entry_surface: "hosted",
               auth_provider: "password",
               is_new_user: false,
               email: "private@example.com",
               url: "https://private.example/secret",
               reason_code: "raw exception with private data"
             })

    job = Repo.one!(heap_jobs())
    assert job.args["identity"] == user_id
    assert job.args["properties"]["frontman_user_id"] == user_id
    assert job.args["properties"]["is_new_user"] == false
    assert job.args["properties"]["event_source"] == "server"
    assert {:ok, _} = Ecto.UUID.cast(job.args["event_id"])
    assert {:ok, _, _} = DateTime.from_iso8601(job.args["timestamp"])
    refute Map.has_key?(job.args["properties"], "email")
    refute Map.has_key?(job.args["properties"], "url")
    refute Map.has_key?(job.args["properties"], "reason_code")
    refute Map.has_key?(job.args["properties"], "user_id")
  end

  test "stable event IDs deduplicate persisted jobs" do
    properties = %{user_id: Ecto.UUID.generate(), event_id: Ecto.UUID.generate()}
    assert :ok = Analytics.track("mcp_client_connected", properties)
    assert :ok = Analytics.track("mcp_client_connected", properties)
    assert Repo.aggregate(heap_jobs(), :count) == 1
  end

  test "anonymous collection requires a separate opt-in and a valid attempt" do
    attempt = Ecto.UUID.generate()

    assert {:error, :identity_unavailable} =
             Analytics.track("auth_started", %{onboarding_attempt_id: attempt})

    Application.put_env(:frontman_server, Analytics, enabled: true, anonymous_enabled: true)
    assert :ok = Analytics.track("auth_started", %{onboarding_attempt_id: attempt})
    assert Repo.one!(heap_jobs()).args["identity"] == "onboarding:" <> attempt
  end

  test "disabled analytics and unknown events do not persist jobs" do
    Application.put_env(:frontman_server, Analytics, enabled: false)
    assert :ok = Analytics.track("auth_completed", %{user_id: Ecto.UUID.generate()})
    Application.put_env(:frontman_server, Analytics, enabled: true)
    assert :ok = Analytics.track("private_event", %{user_id: Ecto.UUID.generate()})
    assert Repo.aggregate(heap_jobs(), :count) == 0
  end

  test "delivery honors disablement after admission without making network calls" do
    assert :ok = Analytics.track("auth_completed", %{user_id: Ecto.UUID.generate()})
    job = Repo.one!(heap_jobs())
    Application.put_env(:frontman_server, Analytics, enabled: false)
    assert {:cancel, :analytics_disabled} = DeliverHeapEvent.perform(job)
  end

  test "missing app ID cancels delivery without making network calls" do
    assert :ok = Analytics.track("auth_completed", %{user_id: Ecto.UUID.generate()})
    assert {:cancel, :heap_app_id_missing} = DeliverHeapEvent.perform(Repo.one!(heap_jobs()))
  end

  test "admission does not queue behind a saturated database pool" do
    pool =
      start_supervised!(
        {Repo, name: __MODULE__.SaturatedRepo, pool: DBConnection.ConnectionPool, pool_size: 1}
      )

    owner = self()

    holder =
      Task.async(fn ->
        Repo.put_dynamic_repo(pool)

        Repo.checkout(fn ->
          send(owner, :connection_held)

          receive do
            :release -> :ok
          after
            5_000 -> raise "Timed out waiting to release the test connection"
          end
        end)
      end)

    assert_receive :connection_held, 1_000

    admission =
      Task.async(fn ->
        Repo.put_dynamic_repo(pool)
        started = System.monotonic_time(:millisecond)
        result = Analytics.track("auth_completed", %{user_id: Ecto.UUID.generate()})
        {result, System.monotonic_time(:millisecond) - started}
      end)

    try do
      assert {:ok, {{:error, :enqueue_exception}, elapsed}} = Task.yield(admission, 1_000)
      assert elapsed < 500
    after
      Task.shutdown(admission, :brutal_kill)
      send(holder.pid, :release)
      Task.await(holder, 1_000)
    end
  end

  defp heap_jobs,
    do: from(job in Oban.Job, where: job.worker == "FrontmanServer.Workers.DeliverHeapEvent")
end
