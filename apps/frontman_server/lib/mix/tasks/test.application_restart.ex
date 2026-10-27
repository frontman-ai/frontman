defmodule Mix.Tasks.Test.ApplicationRestart do
  @shortdoc "Run restart tests inside a fresh test BEAM"
  @moduledoc false
  use Mix.Task
  use Boundary, classify_to: FrontmanServer.Tasks

  @impl Mix.Task
  def run(args) do
    if Mix.env() != :test, do: Mix.raise("Restart tests require MIX_ENV=test")
    suffix = System.fetch_env!("MIX_TEST_DB_SUFFIX")

    unless String.match?(suffix, ~r/^_restart_[0-9a-f]{32}$/),
      do: Mix.raise("Restart tests require an owned database suffix")

    Mix.Task.run("ecto.create", ["--quiet"])
    Mix.Task.run("ecto.migrate", ["--quiet"])
    args = if args == [], do: ["--only", "application_restart", "--seed", "0"], else: args
    Mix.Task.run("test", args)
  end
end
