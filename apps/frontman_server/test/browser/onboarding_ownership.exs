unless Mix.env() == :test, do: raise("Database ownership check requires MIX_ENV=test")

# Pin this sentinel independently of runtime dotenv settings. It is always local,
# freshly created, and never contains application or user data.
{:ok, _dependencies} = Application.ensure_all_started(:postgrex)
suffix = Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
database = "frontman_server_test_onboarding_guard_" <> suffix

config = [
  hostname: "127.0.0.1",
  port: 5432,
  username: "postgres",
  password: "postgres",
  database: database,
  timeout: 5_000
]

:ok = Ecto.Adapters.Postgres.storage_up(config)

try do
  {:ok, connection} = Postgrex.start_link(Keyword.put(config, :database, "postgres"))

  try do
    query = "SELECT oid FROM pg_database WHERE datname = $1"
    %{rows: [[original_oid]]} = Postgrex.query!(connection, query, [database], timeout: 5_000)

    {output, status} =
      System.cmd("make", ["test-onboarding-browser"],
        env: [{"DB_NAME", database}],
        stderr_to_stdout: true
      )

    unless status != 0,
      do: raise("Conflicting DB_NAME unexpectedly passed the ownership guard")

    unless String.contains?(output, "effective Repo config is not owned local test storage"),
      do: raise("Conflicting DB_NAME failed for an unexpected reason")

    %{rows: [[^original_oid]]} = Postgrex.query!(connection, query, [database], timeout: 5_000)
    {:ok, sentinel} = Postgrex.start_link(config)

    try do
      %{rows: [[0]]} =
        Postgrex.query!(
          sentinel,
          "SELECT count(*) FROM pg_tables WHERE schemaname = 'public'",
          [],
          timeout: 5_000
        )
    after
      GenServer.stop(sentinel, :normal, 5_000)
    end

    IO.puts("Conflicting DB_NAME refused; sentinel database OID unchanged and no tables created")
  after
    GenServer.stop(connection, :normal, 5_000)
  end
after
  :ok = Ecto.Adapters.Postgres.storage_down(config)
end
