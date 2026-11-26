defmodule FrontmanServer.MCPActivationTest do
  use FrontmanServer.DataCase, async: false
  use Oban.Testing, repo: FrontmanServer.Repo

  import FrontmanServer.Test.Fixtures.Accounts

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Analytics
  alias FrontmanServer.Workers.DeliverHeapEvent

  setup do
    previous = Application.get_env(:frontman_server, Analytics)
    Application.put_env(:frontman_server, Analytics, enabled: true)

    on_exit(fn ->
      case previous do
        nil -> Application.delete_env(:frontman_server, Analytics)
        config -> Application.put_env(:frontman_server, Analytics, config)
      end
    end)
  end

  test "milestones survive job pruning and distinguish user from user/client activation" do
    scope = user_scope_fixture()

    assert :ok =
             Analytics.record_mcp_activation(scope, "private-client", %{mcp_client: "unknown"})

    jobs = activation_jobs(scope)
    assert length(jobs) == 2

    assert Enum.sort(Enum.map(jobs, & &1.args["properties"]["activation_scope"])) ==
             ["user", "user_client"]

    assert Enum.all?(jobs, &(&1.args["properties"]["operation_kind"] == "unknown"))
    client_job = Enum.find(jobs, &(&1.args["properties"]["activation_scope"] == "user_client"))
    assert byte_size(client_job.args["properties"]["mcp_client_key"]) == 64
    refute inspect(jobs) =~ "private-client"
    event_ids = Enum.map(jobs, & &1.args["event_id"])
    assert length(Enum.uniq(event_ids)) == 2

    Repo.delete_all(from job in Oban.Job, where: job.id in ^Enum.map(jobs, & &1.id))
    assert :ok = Analytics.record_mcp_activation(scope, "private-client", %{})
    assert activation_jobs(scope) == []
    assert :ok = Analytics.record_mcp_activation(scope, "another-client", %{})
    assert [job] = activation_jobs(scope)
    assert job.args["properties"]["activation_scope"] == "user_client"
    assert Repo.aggregate("mcp_activations", :count) == 3
  end

  test "unknown clients only create the user milestone and disabled collection writes nothing" do
    scope = user_scope_fixture()
    Application.put_env(:frontman_server, Analytics, enabled: false)
    assert :ok = Analytics.record_mcp_activation(scope, "client", %{})
    assert Repo.aggregate("mcp_activations", :count) == 0
    Application.put_env(:frontman_server, Analytics, enabled: true)
    assert :ok = Analytics.record_mcp_activation(scope, nil, %{})
    assert :ok = Analytics.record_mcp_activation(scope, "", %{})
    assert [job] = activation_jobs(scope)
    assert job.args["properties"]["activation_scope"] == "user"
  end

  test "database rejection rolls back both milestone and outbox without raising" do
    scope = user_scope_fixture()

    # A real database constraint exercises the storage failure, not a mocked Repo.
    Repo.query!("""
    ALTER TABLE oban_jobs ADD CONSTRAINT reject_activation_test
    CHECK (args->>'event' IS DISTINCT FROM 'mcp_activated')
    """)

    assert {:error, :activation_exception} =
             Analytics.record_mcp_activation(scope, "client", %{})

    assert Repo.aggregate("mcp_activations", :count) == 0
    assert activation_jobs(scope) == []
    Repo.query!("ALTER TABLE oban_jobs DROP CONSTRAINT reject_activation_test")
    assert :ok = Analytics.record_mcp_activation(scope, "client", %{})
    assert length(activation_jobs(scope)) == 2
  end

  test "concurrent independent transactions commit exactly one milestone per scope" do
    Sandbox.unboxed_run(Repo, fn ->
      scope = user_scope_fixture()

      try do
        results =
          1..8
          |> Task.async_stream(
            fn _ ->
              Sandbox.unboxed_run(Repo, fn ->
                Analytics.record_mcp_activation(scope, "same-client", %{})
              end)
            end,
            max_concurrency: 8,
            timeout: 5_000
          )
          |> Enum.to_list()

        assert Enum.all?(results, &(&1 == {:ok, :ok}))
        assert length(activation_jobs(scope)) == 2
      after
        user_id = Scope.user_id(scope)

        Repo.delete_all(
          from job in Oban.Job,
            where: job.args["identity"] == ^user_id or job.args["user_id"] == ^user_id
        )

        Repo.delete!(scope.user)
      end
    end)
  end

  defp activation_jobs(scope) do
    all_enqueued(
      worker: DeliverHeapEvent,
      args: %{event: "mcp_activated", identity: Scope.user_id(scope)}
    )
  end
end
