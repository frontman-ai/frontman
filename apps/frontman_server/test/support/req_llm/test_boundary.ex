defmodule ReqLLM.Test do
  @moduledoc false

  use Boundary,
    top_level?: true,
    check: [in: false, out: false]
end
