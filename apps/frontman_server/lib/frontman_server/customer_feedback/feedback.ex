# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.CustomerFeedback.Feedback do
  @moduledoc "Persistence for an issued customer feedback request and its optional answer."

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias FrontmanServer.Tasks.InteractionSchema
  alias FrontmanServer.Tasks.TaskSchema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @type t :: %__MODULE__{}

  schema "customer_feedback" do
    belongs_to :interaction, InteractionSchema
    field :score, :integer
    field :comment, :string
    field :answered_at, :utc_datetime_usec
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def recent_for_user(user_id, cutoff) do
    from feedback in __MODULE__,
      join: interaction in assoc(feedback, :interaction),
      join: task in assoc(interaction, :task),
      where: task.user_id == ^user_id,
      where: feedback.inserted_at > ^cutoff or feedback.answered_at > ^cutoff
  end

  def owned_interaction(user_id, interaction_id) do
    from interaction in InteractionSchema,
      join: task in TaskSchema,
      on: task.id == interaction.task_id,
      where: interaction.id == ^interaction_id and task.user_id == ^user_id
  end

  def unanswered(id), do: from(f in __MODULE__, where: f.id == ^id and is_nil(f.answered_at))

  def request_changeset(%__MODULE__{} = feedback) do
    feedback
    |> change()
    |> validate_required([:interaction_id])
    |> foreign_key_constraint(:interaction_id)
    |> unique_constraint(:interaction_id)
  end

  def answer_changeset(%__MODULE__{} = feedback, attrs) do
    feedback
    |> cast(attrs, [:score, :comment])
    |> validate_required([:score])
    |> validate_number(:score, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
    |> validate_change(:comment, fn :comment, comment ->
      with true <- String.valid?(comment),
           false <- String.contains?(comment, "\0") do
        []
      else
        false -> [comment: "must be valid UTF-8"]
        true -> [comment: "must not contain NUL characters"]
      end
    end)
    |> validate_length(:comment, max: 2000, count: :codepoints)
    |> put_change(:answered_at, DateTime.utc_now())
  end
end
