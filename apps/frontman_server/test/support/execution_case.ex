defmodule FrontmanServer.ExecutionCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      use SwarmAi.Testing, async: false
      import FrontmanServer.Test.Fixtures.LLMProvider
    end
  end
end
