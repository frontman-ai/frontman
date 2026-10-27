defmodule FrontmanServer.ApplicationRestartProbe do
  use ExUnit.Case
  @moduletag :restart_runner_probe

  setup do
    database = FrontmanServer.Repo.config() |> Keyword.fetch!(:database)
    File.write!(System.fetch_env!("RESTART_TEST_READY_FILE"), database <> "\n" <> System.pid())
    :ok
  end

  @tag :probe_failure
  test "real assertion failure reports nonzero status" do
    flunk("Intentional child-VM failure for runner integration coverage")
  end

  @tag :probe_wait
  @tag timeout: :infinity
  test "live child BEAM awaits external timeout or abort" do
    Process.sleep(:infinity)
  end
end
