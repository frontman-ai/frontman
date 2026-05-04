# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.Task do
  @moduledoc """
  Read model representing a conversational task.

  Reconstituted from `TaskSchema` + interactions for use by domain services
  (e.g. `Execution.run/3`). State changes go through the `Tasks` facade
  and are persisted via `TaskSchema` / `InteractionSchema` directly.
  """

  use TypedStruct

  alias FrontmanServer.Tasks.Execution.Framework
  alias FrontmanServer.Tasks.Interaction

  typedstruct enforce: true do
    field(:task_id, String.t())
    field(:short_desc, String.t())
    field(:interactions, list(Interaction.t()), default: [])
    field(:framework, Framework.t())
  end

  @doc """
  Returns the default short description for a new task.

  Titles are later generated asynchronously via the `GenerateTitle`
  Oban worker after the first user message.
  """
  @spec short_description(String.t()) :: String.t()
  def short_description(_task_id) do
    "New Task"
  end
end
