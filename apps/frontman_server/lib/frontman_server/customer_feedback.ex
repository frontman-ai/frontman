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
  alias FrontmanServer.Protocols.MCP
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.{InteractionSchema, TaskSchema}

  @tool_name "request_customer_feedback"

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

  def filter_tools(tools, %Scope{} = scope) when is_list(tools) do
    with true <- Enum.any?(tools, &(&1.name == @tool_name)),
         false <- eligible?(scope) do
      Enum.reject(tools, &(&1.name == @tool_name))
    else
      false -> tools
      true -> tools
    end
  end

  def tool_request(%Scope{} = scope, task_id, turn, %{name: @tool_name, id: id}) do
    scope
    |> Scope.user_id()
    |> Feedback.tool_request(task_id, turn, id)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      request -> record_request(scope, request)
    end
  end

  def tool_request(_scope, _task_id, _turn, _call), do: {:ok, :not_feedback}

  def tool_result(_scope, _task_id, _turn, _call, %{"isError" => true} = result),
    do: {:ok, result}

  def tool_result(
        %Scope{} = scope,
        task_id,
        turn,
        %{name: @tool_name, id: id},
        result
      ) do
    Repo.transact(fn ->
      with %TaskSchema{} <-
             task_id
             |> TaskSchema.by_id_for_user(Scope.user_id(scope))
             |> TaskSchema.locked_for_update()
             |> Repo.one(),
           {:ok, ^turn, calls} <- Tasks.get_active_turn_unresolved_tool_calls(scope, task_id),
           true <- Enum.any?(calls, &(&1.tool_call_id == id)),
           %InteractionSchema{} = request <-
             scope |> Scope.user_id() |> Feedback.tool_request(task_id, turn, id) |> Repo.one() do
        record_tool_answer(scope, request.id, result)
      else
        nil -> {:error, :not_found}
        false -> {:ok, result}
        {:ok, :no_active_turn} -> {:ok, result}
        {:ok, _other_turn, _calls} -> {:ok, result}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  def tool_result(_scope, _task_id, _turn, _call, result), do: {:ok, result}

  defp record_tool_answer(_scope, _id, %{
         "structuredContent" => %{"outcome" => "skipped"} = output
       })
       when map_size(output) == 1,
       do: {:ok, tool_reply(output)}

  defp record_tool_answer(scope, id, %{
         "structuredContent" => %{"outcome" => "answered", "score" => _score} = output
       }) do
    with true <- Map.drop(output, ["outcome", "score", "comment"]) == %{},
         {:ok, answer} <- record_answer(scope, id, Map.take(output, ["score", "comment"])) do
      data =
        case answer.comment do
          nil -> %{"outcome" => "answered", "score" => answer.score}
          comment -> %{"outcome" => "answered", "score" => answer.score, "comment" => comment}
        end

      {:ok, tool_reply(data)}
    else
      false -> {:error, :invalid_customer_feedback}
      {:error, reason} -> {:error, reason}
    end
  end

  defp record_tool_answer(_scope, _id, _result), do: {:error, :invalid_customer_feedback}

  defp tool_reply(output) do
    output
    |> Jason.encode!()
    |> MCP.tool_result_text()
    |> Map.put("structuredContent", output)
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
