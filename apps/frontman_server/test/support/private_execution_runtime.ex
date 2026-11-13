defmodule FrontmanServer.PrivateExecutionRuntime do
  @moduledoc false

  use Boundary, top_level?: true, check: [in: false, out: false]

  import ExUnit.Callbacks, only: [start_supervised!: 1]

  alias Ecto.Adapters.SQL.Sandbox

  def start!(runtime, sandbox_owner, test_owner \\ self()) do
    initialize_process = initializer(sandbox_owner, test_owner)
    # ExUnit stops later-started channels before this tree and runs on_exit afterward.
    start_supervised!({SwarmAi, name: runtime, initialize_process: initialize_process})
    runtime
  end

  defp initializer(sandbox_owner, test_owner) do
    fn ->
      :ok = Sandbox.allow(FrontmanServer.Repo, sandbox_owner, self())
      Process.put(:"$callers", [sandbox_owner, test_owner])
      :ok
    end
  end
end
