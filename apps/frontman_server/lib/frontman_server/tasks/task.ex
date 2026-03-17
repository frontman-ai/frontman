defmodule FrontmanServer.Tasks.Task do
  @moduledoc """
  Read model representing a conversational task.

  Reconstituted from `TaskSchema` + interactions for use by domain services
  (e.g. `Execution.run/3`). State changes go through the `Tasks` facade
  and are persisted via `TaskSchema` / `InteractionSchema` directly.
  """

  use TypedStruct

  alias FrontmanServer.Tasks.Interaction

  typedstruct enforce: true do
    field(:task_id, String.t())
    field(:short_desc, String.t())
    field(:interactions, list(Interaction.t()), default: [])
    field(:framework, String.t() | nil, default: nil)
  end

  @doc """
  Returns the default short description for a new task.

  Titles are later generated asynchronously via `TitleGenerator`
  after the first user message.
  """
  @spec short_description(String.t()) :: String.t()
  def short_description(_task_id) do
    "New Task"
  end
end
