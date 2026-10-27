defmodule FrontmanServer.ApplicationRestartRunnerTest do
  use ExUnit.Case, async: false
  alias Ecto.Adapters.Postgres
  @moduletag timeout: 120_000

  setup do
    config = Application.fetch_env!(:frontman_server, FrontmanServer.Repo)

    sentinel =
      "frontman_server_test_sentinel_" <>
        Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)

    config = Keyword.put(config, :database, sentinel)
    :ok = Postgres.storage_up(config)
    on_exit(fn -> :ok = Postgres.storage_down(config) end)

    {:ok, connection} =
      config
      |> Keyword.take([:hostname, :username, :password])
      |> Keyword.put(:database, "postgres")
      |> Postgrex.start_link()

    directory = Path.join(System.tmp_dir!(), "restart-" <> Ecto.UUID.generate())
    File.mkdir_p!(directory)
    on_exit(fn -> File.rm_rf!(directory) end)
    %{connection: connection, sentinel: sentinel, ready: Path.join(directory, "ready")}
  end

  test "real nonzero ExUnit exit cleans only owned database", context do
    port = start(context, "probe_failure", 60)
    assert 2 = await_exit(port, deadline())
    assert_cleaned(context)
  end

  test "timeout kills child BEAM before owned database cleanup", context do
    port = start(context, "probe_wait", 15)
    await_ready(context.ready, 300)
    assert 124 = await_exit(port, deadline())
    assert_cleaned(context)
  end

  for signal <- ["INT", "TERM"] do
    test "wrapper SIG#{signal} terminates owned BEAM and preserves sentinel", context do
      port = start(context, "probe_wait", 60)
      await_ready(context.ready, 300)
      {:os_pid, pid} = Port.info(port, :os_pid)
      {_, 0} = System.cmd("kill", ["-#{unquote(signal)}", to_string(pid)])
      assert 130 = await_exit(port, deadline())
      assert_cleaned(context)
    end
  end

  defp start(context, tag, timeout) do
    Port.open({:spawn_executable, System.find_executable("bash")}, [
      :binary,
      :exit_status,
      :stderr_to_stdout,
      args: [
        "test/support/application_restart.sh",
        "test/support/application_restart_probe_test.exs",
        "--only",
        tag
      ],
      env: [
        {~c"MIX_TEST_DB_SUFFIX",
         String.to_charlist(String.replace_prefix(context.sentinel, "frontman_server_test", ""))},
        {~c"MIX_TEST_PARTITION", ~c"99"},
        {~c"RESTART_TEST_READY_FILE", String.to_charlist(context.ready)},
        {~c"RESTART_TEST_TIMEOUT_SECONDS", to_charlist(timeout)}
      ]
    ])
  end

  defp deadline, do: System.monotonic_time(:millisecond) + 60_000

  defp await_exit(port, deadline) do
    receive do
      {^port, {:data, _}} -> await_exit(port, deadline)
      {^port, {:exit_status, status}} -> status
    after
      max(deadline - System.monotonic_time(:millisecond), 0) -> flunk("Runner did not exit")
    end
  end

  defp await_ready(_path, 0), do: flunk("Child BEAM did not become ready")

  defp await_ready(path, attempts) do
    unless File.exists?(path) do
      Process.sleep(100)
      await_ready(path, attempts - 1)
    end
  end

  defp assert_cleaned(context) do
    [database, child] = context.ready |> File.read!() |> String.split("\n")
    assert database != context.sentinel
    assert String.match?(database, ~r/^frontman_server_test_restart_[0-9a-f]{32}$/)
    {_, status} = System.cmd("kill", ["-0", child], stderr_to_stdout: true)
    assert status != 0

    assert %{rows: [[sentinel]]} =
             Postgrex.query!(
               context.connection,
               "SELECT datname FROM pg_database WHERE datname = ANY($1)",
               [[database, context.sentinel]],
               timeout: 5_000
             )

    assert sentinel == context.sentinel
  end
end
