# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 - see LICENSE for details.
# Additional terms apply - see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.ToolCallExecutionReference do
  @moduledoc """
  Stable identity of one persisted tool-call interaction.
  """

  @enforce_keys [:interaction_id, :task_id, :turn_number, :tool_call_id, :tool_name]
  defstruct [:interaction_id, :task_id, :turn_number, :tool_call_id, :tool_name]

  @type t :: %__MODULE__{
          interaction_id: Ecto.UUID.t(),
          task_id: Ecto.UUID.t(),
          turn_number: pos_integer(),
          tool_call_id: String.t(),
          tool_name: String.t()
        }
end
