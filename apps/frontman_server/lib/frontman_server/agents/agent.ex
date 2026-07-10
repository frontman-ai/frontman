# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Agents.Agent do
  @moduledoc """
  Backend-owned product agent definition.
  """

  @enforce_keys [:id, :name, :display_name, :description, :system]
  defstruct [
    :id,
    :name,
    :display_name,
    :description,
    :system,
    tools: :all,
    source: :static
  ]
end
