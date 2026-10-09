# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.CustomerFeedback do
  @moduledoc "Customer feedback issuance, rolling 30-day eligibility, and immutable answers."

  use Boundary,
    deps: [FrontmanServer, FrontmanServer.Accounts, FrontmanServer.Tasks],
    exports: [Feedback]

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.CustomerFeedback.Feedback
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks.InteractionSchema

  @doc "Whether the user has no request or answer within the rolling cooldown."
  def eligible?(%Scope{} = scope, now \\ DateTime.utc_now()) do
    cutoff = DateTime.add(now, -30, :day)

    scope
    |> Scope.user_id()
    |> Feedback.recent_for_user(cutoff)
    |> Repo.exists?()
    |> Kernel.not()
  end

  @doc "Records issuance once per persisted interaction owned by the user."
  def record_request(%Scope{} = scope, %InteractionSchema{id: id}) do
    with {:ok, _interaction} <- owned_interaction(scope, id),
         {:ok, _feedback} <-
           %Feedback{interaction_id: id}
           |> Feedback.request_changeset()
           |> Repo.insert(on_conflict: :nothing, conflict_target: :interaction_id) do
      {:ok, Repo.get_by!(Feedback, interaction_id: id)}
    end
  end

  @doc "Validates answer attributes and returns the first stored answer on replay."
  def record_answer(%Scope{} = scope, interaction_id, attrs) do
    with {:ok, _interaction} <- owned_interaction(scope, interaction_id) do
      Repo.transact(fn ->
        Feedback
        |> Repo.get_by(interaction_id: interaction_id)
        |> store_answer(attrs)
      end)
    end
  end

  defp store_answer(nil, _attrs), do: {:error, :not_found}

  defp store_answer(%Feedback{} = feedback, attrs) do
    changeset = Feedback.answer_changeset(feedback, attrs)

    with {:ok, answer} <- Ecto.Changeset.apply_action(changeset, :update) do
      feedback.id
      |> Feedback.unanswered()
      |> Repo.update_all(
        set: [score: answer.score, comment: answer.comment, answered_at: answer.answered_at]
      )

      {:ok, Repo.get!(Feedback, feedback.id)}
    end
  end

  defp owned_interaction(%Scope{} = scope, id) do
    scope
    |> Scope.user_id()
    |> Feedback.owned_interaction(id)
    |> Repo.one()
    |> case do
      %InteractionSchema{} = interaction -> {:ok, interaction}
      nil -> {:error, :not_found}
    end
  end
end
