defmodule FrontmanServer.PrivateExecutionRuntime do
  @moduledoc false

  use Boundary, top_level?: true, check: [in: false, out: false]

  import ExUnit.Callbacks, only: [start_supervised!: 1]

  alias Ecto.Adapters.SQL.Sandbox

  def start!(runtime, sandbox_owner) do
    test_owner = self()

    initialize_process = fn ->
      :ok = Sandbox.allow(FrontmanServer.Repo, sandbox_owner, self())
      Process.put(:"$callers", [sandbox_owner, test_owner])
      :ok
    end

    start_supervised!({SwarmAi, name: runtime, initialize_process: initialize_process})
    runtime
  end
end
