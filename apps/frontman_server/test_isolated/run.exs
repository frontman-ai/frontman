defmodule FrontmanServer.IsolatedSuite do
  @moduledoc false

  def run([]) do
    Process.flag(:trap_exit, true)
    {:ok, _} = Application.ensure_all_started(:postgrex)
    database = "frontman_server_test_isolated_" <> Base.encode16(:crypto.strong_rand_bytes(12))
    owner = self()

    for signal <- [:sigterm, :sighup] do
      {:ok, _} =
        System.trap_signal(signal, fn ->
          send(owner, {:shutdown, self()})

          receive do
            :cleaned -> :ok
          after
            30_000 -> IO.puts(:stderr, "Isolated suite signal cleanup timed out")
          end
        end)
    end

    repo_config = FrontmanServer.Repo.config()

    config =
      repo_config
      |> Keyword.take([:hostname, :port, :username, :password, :socket_dir, :ssl])
      |> Keyword.merge(
        database: Keyword.get(repo_config, :maintenance_database, "postgres"),
        backoff_type: :stop,
        connect_timeout: 5_000,
        timeout: 10_000
      )

    with_connection(config, database, :create, fn connection ->
      Postgrex.query!(connection, ~s(CREATE DATABASE "#{database}"), [], timeout: 10_000)
    end)

    {status, handler} =
      try do
        IO.puts("Created isolated database #{database}")
        run_child(database)
      after
        with_connection(config, database, :cleanup, fn connection ->
          Postgrex.query!(connection, ~s|DROP DATABASE "#{database}" WITH (FORCE)|, [],
            timeout: 10_000
          )

          %{rows: [[false]]} =
            Postgrex.query!(
              connection,
              "SELECT EXISTS (SELECT 1 FROM pg_database WHERE datname = $1)",
              [database],
              timeout: 10_000
            )
        end)

        IO.puts("Dropped isolated database #{database}")
      end

    if handler, do: send(handler, :cleaned)
    System.halt(status)
  end

  def run(["--child", database]) do
    ^database = FrontmanServer.Repo.config()[:database]
    true = String.starts_with?(database, "frontman_server_test_isolated_")
    System.put_env("PAPER_TIGER_START", "false")
    ExUnit.start(autorun: false, timeout: 30_000)

    coverage_dir = System.get_env("ISOLATED_COVERAGE_DIR")

    if coverage_dir do
      Mix.Project.compile_path()
      |> ExCoveralls.Cover.compile()
      |> Enum.each(fn {:ok, _module} -> :ok end)
    end

    Mox.defmock(
      FrontmanServer.Tasks.Execution.LLMProviderMock,
      for: FrontmanServer.Tasks.Execution.LLMProvider
    )

    {:ok, _, _} =
      Ecto.Migrator.with_repo(FrontmanServer.Repo, fn repo ->
        Ecto.Migrator.run(repo, :up, all: true, log: false)
      end)

    {:ok, _} = Application.ensure_all_started(:frontman_server)
    Logger.configure(level: :warning)
    Code.require_file("application_restart_test.exs", __DIR__)
    %{failures: failures} = ExUnit.run()
    :ok = Application.stop(:frontman_server)

    if coverage_dir do
      :ok = ExCoveralls.Cover.export(Path.join(coverage_dir, "application_restart.coverdata"))
    end

    System.halt(if failures == 0, do: 0, else: 1)
  end

  defp with_connection(config, database, operation, callback) do
    config = Keyword.put(config, :parameters, application_name: "#{database}:#{operation}")

    case Postgrex.start_link(config) do
      {:ok, connection} ->
        Process.unlink(connection)
        monitor = Process.monitor(connection)

        try do
          callback.(connection)
        rescue
          error ->
            reraise RuntimeError,
                    [
                      message:
                        "Isolated database #{operation} failed for #{database}: #{Exception.message(error)}"
                    ],
                    __STACKTRACE__
        catch
          :exit, reason ->
            raise "Isolated database #{operation} failed for #{database}: #{inspect(reason)}"
        after
          Process.exit(connection, :kill)

          receive do
            {:DOWN, ^monitor, :process, ^connection, _reason} -> :ok
          after
            5_000 -> raise "Isolated database #{operation} connection did not exit"
          end
        end

      {:error, reason} ->
        raise "Isolated database #{operation} connection failed for #{database}: #{inspect(reason)}"
    end
  end

  defp run_child(database) do
    port =
      Port.open({:spawn_executable, System.find_executable("mix")}, [
        :binary,
        :exit_status,
        :use_stdio,
        :stderr_to_stdout,
        args: ["run", "--no-start", __ENV__.file, "--child", database],
        env: [
          {~c"DB_NAME", String.to_charlist(database)},
          {~c"MIX_TEST_DB_SUFFIX",
           String.to_charlist(String.replace_prefix(database, "frontman_server_test", ""))},
          {~c"MIX_TEST_PARTITION", false}
        ]
      ])

    deadline = System.monotonic_time(:millisecond) + 120_000

    try do
      await_child(port, deadline)
    after
      case Port.info(port, :os_pid) do
        nil -> :ok
        {:os_pid, _pid} -> stop_child(port)
      end
    end
  end

  defp await_child(port, deadline) do
    remaining_ms = deadline - System.monotonic_time(:millisecond)
    await_child(port, deadline, remaining_ms)
  end

  defp await_child(port, _deadline, remaining_ms) when remaining_ms <= 0 do
    IO.puts(:stderr, "Isolated suite exceeded 120 seconds")
    stop_child(port)
    {1, nil}
  end

  defp await_child(port, deadline, remaining_ms) do
    receive do
      {^port, {:data, data}} ->
        IO.binwrite(data)
        await_child(port, deadline)

      {^port, {:exit_status, status}} ->
        {status, nil}

      {:shutdown, handler} ->
        stop_child(port)
        {143, handler}
    after
      remaining_ms -> await_child(port, deadline, 0)
    end
  end

  defp stop_child(port) do
    {:os_pid, pid} = Port.info(port, :os_pid)
    {_, 0} = System.cmd("kill", ["-KILL", Integer.to_string(pid)])

    receive do
      {^port, {:exit_status, _status}} -> :ok
    after
      5_000 -> raise "Isolated suite process did not exit"
    end
  end
end

FrontmanServer.IsolatedSuite.run(System.argv())
