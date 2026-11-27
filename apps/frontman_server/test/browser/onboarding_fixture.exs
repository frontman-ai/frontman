unless Mix.env() == :test, do: raise("Onboarding fixtures require MIX_ENV=test")

alias FrontmanServer.Repo
alias FrontmanServer.Test.Fixtures.Onboarding
alias FrontmanServerWeb.Endpoint

suffix = System.fetch_env!("MIX_TEST_DB_SUFFIX")

unless Regex.match?(~r/\A_onboarding_browser_[0-9a-f]{16}\z/, suffix),
  do: raise("Expected a generated onboarding browser database suffix")

expected_database = "frontman_server_test" <> suffix

# Real browser requests need independent connections, not a single-connection sandbox.
Application.put_env(
  :frontman_server,
  Repo,
  Application.fetch_env!(:frontman_server, Repo)
  |> Keyword.put(:pool, DBConnection.ConnectionPool)
)

# Runtime dotenv settings are already loaded. Verify effective configuration before
# creating, migrating, or dropping anything; only this fresh local database is owned.
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
        "Refusing onboarding database access: effective Repo config is not owned local test storage"
      )
  end
end

owned_config = owned_config!.()
{:ok, _dependencies} = Application.ensure_all_started(:postgrex)

case Repo.__adapter__().storage_up(owned_config) do
  :ok -> :ok
  {:error, _reason} -> raise("Could not create a fresh owned onboarding browser database")
end

try do
  ^owned_config = owned_config!.()
  Mix.Task.run("ecto.migrate", ["--quiet"])
  Application.put_env(:paper_tiger, :start, true)
  oban = Application.fetch_env!(:frontman_server, Oban)
  Application.put_env(:frontman_server, Oban, Keyword.put(oban, :testing, :manual))
  {:ok, _applications} = Application.ensure_all_started(:frontman_server)
  stripe = Application.fetch_env!(:frontman_server, :stripe)

  Application.put_env(
    :frontman_server,
    :stripe,
    stripe
    |> Keyword.put(:api_base_url, "http://localhost:#{PaperTiger.get_port()}/v1")
    |> Keyword.put(:extra_headers, [])
  )

  {:ok, _seeded} = PaperTiger.Initializer.load()
  Logger.configure(level: :warning)
  password = Base.url_encode64(:crypto.strong_rand_bytes(24))
  cases = Onboarding.cases(password)
  {:ok, {_address, port}} = Endpoint.server_info(:http)
  base = "http://127.0.0.1:#{port}"

  if System.get_env("ONBOARDING_PREVIEW") == "1" do
    {_output, status} =
      System.cmd("node", ["test/browser/onboarding-preview.mjs", base],
        env: [
          {"ONBOARDING_PREVIEW_CASES", JSON.encode!(cases)},
          {"ONBOARDING_TEST_PASSWORD", password}
        ],
        into: IO.stream(:stdio, :line),
        stderr_to_stdout: true
      )

    if status != 0, do: raise("Interactive onboarding preview failed")
  else
    for scenario <- cases do
      {output, status} =
        System.cmd("node", ["test/browser/onboarding.mjs", base],
          env: [
            {"ONBOARDING_TEST_EMAIL", scenario.email},
            {"ONBOARDING_TEST_PASSWORD", password},
            {"ONBOARDING_CASE", scenario.name},
            {"ONBOARDING_USER_ID", scenario.user_id},
            {"ONBOARDING_WEBHOOK_SECRET", Keyword.fetch!(stripe, :webhook_secret)},
            {"ONBOARDING_SITE_IDS", JSON.encode!(scenario.site_ids)}
          ],
          stderr_to_stdout: true
        )

      IO.write(output)
      if status != 0, do: raise("Hosted onboarding browser scenario failed: #{scenario.name}")
    end
  end
after
  ^owned_config = owned_config!.()
  Application.stop(:frontman_server)
  ^owned_config = owned_config!.()

  case Repo.__adapter__().storage_down(owned_config) do
    :ok -> :ok
    {:error, _reason} -> raise("Could not remove the owned onboarding browser database")
  end
end
