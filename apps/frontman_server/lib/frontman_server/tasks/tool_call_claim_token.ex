# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 - see LICENSE for details.
# Additional terms apply - see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.ToolCallClaimToken do
  @moduledoc """
  Generation-fenced authority returned to the current execution owner.
  """

  alias FrontmanServer.Tasks.ToolCallExecutionReference

  @enforce_keys [
    :reference,
    :owner_connection_id,
    :generation,
    :started_at,
    :deadline_at,
    :lease_expires_at
  ]
  defstruct [
    :reference,
    :owner_connection_id,
    :generation,
    :started_at,
    :deadline_at,
    :lease_expires_at
  ]

  @type t :: %__MODULE__{
          reference: ToolCallExecutionReference.t(),
          owner_connection_id: String.t(),
          generation: pos_integer(),
          started_at: DateTime.t(),
          deadline_at: DateTime.t(),
          lease_expires_at: DateTime.t()
        }
end
