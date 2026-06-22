# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.PlayGithub.GithubReference.IssuePath do
  @moduledoc """
  GitHub issue path.
  """

  @schema Zoi.struct(__MODULE__, %{number: Zoi.integer() |> Zoi.positive()})

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)
end
