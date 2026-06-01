# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.PlayGithub.GithubReference.IssuePath do
  @moduledoc """
  GitHub issue path.
  """

  use TypedStruct

  typedstruct enforce: true do
    field(:number, pos_integer())
  end
end
