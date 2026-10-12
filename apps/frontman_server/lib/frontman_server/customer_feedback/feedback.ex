# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.CustomerFeedback.Feedback do
  @moduledoc "Read-only eligibility projection, including feedback issued before interaction wiring."

  use Ecto.Schema
  import Ecto.Query

  alias FrontmanServer.Tasks.InteractionSchema
  alias FrontmanServer.Tasks.TaskSchema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "customer_feedback" do
    belongs_to :interaction, InteractionSchema
    field :score, :integer
    field :comment, :string
    field :answered_at, :utc_datetime_usec
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def recent_for_user(user_id, cutoff) do
    legacy =
      from feedback in __MODULE__,
        join: interaction in InteractionSchema,
        on: interaction.id == feedback.interaction_id,
        join: task in TaskSchema,
        on: task.id == interaction.task_id,
        where: task.user_id == ^user_id,
        where: feedback.inserted_at > ^cutoff or feedback.answered_at > ^cutoff,
        select: 1

    from request in InteractionSchema,
      join: task in assoc(request, :task),
      left_join: answer in InteractionSchema,
      on:
        answer.task_id == request.task_id and answer.turn_number == request.turn_number and
          answer.type == :tool_result and
          fragment("?->>'tool_call_id'", answer.data) ==
            fragment("?->>'tool_call_id'", request.data) and
          fragment("?->>'tool_name'", answer.data) == "request_customer_feedback" and
          fragment("?->>'is_error'", answer.data) == "false" and
          fragment("?->'result'->'structuredContent'->>'outcome'", answer.data) == "answered",
      where: task.user_id == ^user_id,
      where: request.type == :tool_call,
      where: fragment("?->>'tool_name'", request.data) == "request_customer_feedback",
      where:
        fragment("(?->>'timestamp')::timestamptz", request.data) > ^cutoff or
          fragment("(?->>'timestamp')::timestamptz", answer.data) > ^cutoff,
      select: 1,
      union_all: ^legacy
  end
end
