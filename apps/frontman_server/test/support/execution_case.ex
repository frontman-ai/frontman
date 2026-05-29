defmodule FrontmanServer.ExecutionCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      use SwarmAi.Testing, async: false
      import FrontmanServer.Test.Fixtures.LLMProvider
    end
  end

  setup do
    Mox.set_mox_global()

    Req.Test.set_req_test_to_shared()

    on_exit(fn ->
      Req.Test.set_req_test_to_private()
    end)

    :ok
  end
end
