unless Mix.env() == :test, do: raise("Hosted analytics browser fixtures require MIX_ENV=test")

import Ecto.Query

alias Ecto.Adapters.SQL.Sandbox
alias FrontmanServer.{Accounts, Analytics, Repo}
alias FrontmanServerWeb.Endpoint

suffix = System.fetch_env!("MIX_TEST_DB_SUFFIX")

unless Regex.match?(~r/\A_analytics_browser_[0-9a-f]{16}\z/, suffix),
  do: raise("Expected a generated analytics browser database suffix")

expected_database = "frontman_server_test" <> suffix

# Runtime dotenv overrides have already been applied by mix run. Check Repo.config,
# not just environment variables, before any database operation or application startup.
owned_config! = fn ->
  config = Repo.config()

  with ^expected_database <- config[:database],
       hostname when hostname in ["127.0.0.1", "localhost"] <- config[:hostname],
       5432 <- Keyword.get(config, :port, 5432),
       nil <- config[:url],
       nil <- config[:socket_dir],
       nil <- config[:socket] do
    config
  else
    _ ->
      raise(
        "Refusing analytics browser database access: effective Repo config is not owned local test storage"
      )
  end
end

owned_config = owned_config!.()
{:ok, _dependencies} = Application.ensure_all_started(:postgrex)

# Only a fresh successful create grants cleanup ownership. An existing database,
# rejected config, or failed create must never enter the cleanup block.
case Repo.__adapter__().storage_up(owned_config) do
  :ok -> :ok
  {:error, _reason} -> raise("Could not create a fresh owned analytics browser database")
end

try do
  ^owned_config = owned_config!.()
  Mix.Task.run("ecto.migrate", ["--quiet"])

  # These are local persisted fixtures, not provider responses. No jobs are drained.
  Application.put_env(:paper_tiger, :start, false)
  Application.put_env(:frontman_server, Analytics, enabled: false)

  oban = Application.fetch_env!(:frontman_server, Oban)
  Application.put_env(:frontman_server, Oban, Keyword.put(oban, :testing, :manual))
  {:ok, _applications} = Application.ensure_all_started(:frontman_server)
  Logger.configure(level: :warning)
  :ok = Sandbox.mode(Repo, :manual)
  owner = Sandbox.start_owner!(Repo, shared: true)

  try do
    password = Base.url_encode64(:crypto.strong_rand_bytes(24))

    {:ok, user} =
      Accounts.register_user(%{email: "analytics-browser@example.test", name: "Browser"})

    user = user |> Accounts.User.confirm_changeset() |> Repo.update!()
    {:ok, {_user, _tokens}} = Accounts.update_user_password(user, %{password: password})
    {:ok, {_address, port}} = Endpoint.server_info(:http)
    base = "http://127.0.0.1:#{port}"

    for enabled <- [true, false] do
      Application.put_env(:frontman_server, Analytics,
        enabled: enabled,
        anonymous_enabled: enabled,
        app_id: nil
      )

      before_count = Repo.aggregate(Oban.Job, :count)

      {output, status} =
        System.cmd("node", ["test/browser/analytics.mjs", base],
          env: [
            {"ANALYTICS_TEST_EMAIL", user.email},
            {"ANALYTICS_TEST_PASSWORD", password},
            {"ANALYTICS_TEST_ENABLED", to_string(enabled)}
          ],
          stderr_to_stdout: true
        )

      IO.write(output)
      if status != 0, do: raise("Hosted browser scenario failed")

      if enabled do
        counts =
          Repo.all(from(job in Oban.Job, select: job.args))
          |> Enum.frequencies_by(& &1["event"])

        for event <- ~w(auth_screen_viewed mcp_checkpoint_viewed billing_setup_viewed) do
          if counts[event] != 1, do: raise("Expected exactly one persisted #{event}")
        end
      else
        if Repo.aggregate(Oban.Job, :count) != before_count,
          do: raise("Disabled analytics persisted an event")
      end
    end
  after
    Sandbox.stop_owner(owner)
  end
after
  # Stop connections before dropping only the exact configuration we created.
  ^owned_config = owned_config!.()
  Application.stop(:frontman_server)
  ^owned_config = owned_config!.()

  case Repo.__adapter__().storage_down(owned_config) do
    :ok -> :ok
    {:error, _reason} -> raise("Could not remove the owned analytics browser database")
  end
end
