defmodule FrontmanServer.CustomerFeedbackTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.CustomerFeedback
  alias FrontmanServer.CustomerFeedback.Feedback

  @now ~U[2026-10-01 12:00:00.000000Z]
  @expired DateTime.add(@now, -31, :day)
  @recent DateTime.add(@now, -1, :day)

  setup do
    scope = user_scope_fixture()
    %{scope: scope, interaction: feedback_interaction(scope)}
  end

  test "never asked is eligible", %{scope: scope} do
    assert CustomerFeedback.eligible?(scope, @now)
  end

  test "recent unanswered request blocks eligibility", context do
    feedback = request(context)
    set_times(feedback, @recent)
    refute CustomerFeedback.eligible?(context.scope, @now)
  end

  test "recent answer restarts cooldown after an old request", context do
    feedback = request(context)

    {:ok, feedback} =
      CustomerFeedback.record_answer(context.scope, feedback.interaction_id, %{score: 8})

    set_times(feedback, @expired, @recent)
    refute CustomerFeedback.eligible?(context.scope, @now)
  end

  test "expired requests and answers no longer block eligibility", context do
    feedback = request(context)
    set_times(feedback, @expired)
    assert CustomerFeedback.eligible?(context.scope, @now)

    {:ok, feedback} =
      CustomerFeedback.record_answer(context.scope, feedback.interaction_id, %{
        score: 9,
        comment: ""
      })

    assert is_nil(feedback.comment)
    set_times(feedback, @expired, @expired)
    assert CustomerFeedback.eligible?(context.scope, @now)
  end

  test "other users are isolated", context do
    feedback = request(context)
    set_times(feedback, @now)
    other_scope = user_scope_fixture()
    assert CustomerFeedback.eligible?(other_scope, @now)

    assert {:error, :not_found} =
             CustomerFeedback.record_request(other_scope, context.interaction)

    assert {:error, :not_found} =
             CustomerFeedback.record_answer(other_scope, context.interaction.id, %{score: 10})
  end

  test "issuance replay is idempotent, not an invocation-time eligibility check", context do
    feedback = request(context)
    assert {:ok, ^feedback} = CustomerFeedback.record_request(context.scope, context.interaction)
    assert Repo.aggregate(Feedback, :count) == 1
    second_call = feedback_interaction(context.scope)
    assert {:ok, _} = CustomerFeedback.record_request(context.scope, second_call)
    assert Repo.aggregate(Feedback, :count) == 2
  end

  test "request ownership uses persisted data, not the supplied struct", context do
    assert {:error, :not_found} =
             CustomerFeedback.record_request(context.scope, %{
               context.interaction
               | id: Ecto.UUID.generate()
             })

    other = feedback_interaction(user_scope_fixture())
    forged = %{context.interaction | id: other.id}
    assert {:error, :not_found} = CustomerFeedback.record_request(context.scope, forged)

    assert Repo.aggregate(Feedback, :count) == 0
  end

  test "answer requires an issued request", context do
    assert {:error, :not_found} =
             CustomerFeedback.record_answer(context.scope, context.interaction.id, %{score: 8})
  end

  test "score and comment validation rejects invalid and malformed input", context do
    request(context)

    invalid_scores = Enum.map([-1, 11, 8.0, "invalid", nil, true], &%{score: &1})

    for attrs <- [%{} | invalid_scores] do
      assert {:error, %Ecto.Changeset{}} =
               CustomerFeedback.record_answer(context.scope, context.interaction.id, attrs)
    end

    for comment <- [
          123,
          %{},
          [],
          <<255>>,
          "nul\0byte",
          String.duplicate("a", 2001),
          String.duplicate("é", 1001)
        ] do
      assert {:error, %Ecto.Changeset{}} =
               CustomerFeedback.record_answer(context.scope, context.interaction.id, %{
                 score: 8,
                 comment: comment
               })
    end

    feedback = Repo.get_by!(Feedback, interaction_id: context.interaction.id)
    assert is_nil(feedback.score)
    assert is_nil(feedback.answered_at)
  end

  test "first answer and timestamp are immutable across replay", context do
    requested = request(context)
    comment = String.duplicate("🙂", 2000)

    before_answer = DateTime.utc_now()

    assert {:ok, first} =
             CustomerFeedback.record_answer(context.scope, context.interaction.id, %{
               "score" => "0",
               "comment" => comment,
               "answered_at" => DateTime.to_iso8601(@expired),
               "interaction_id" => Ecto.UUID.generate()
             })

    assert first.score == 0
    assert first.comment == comment
    assert first.interaction_id == context.interaction.id
    assert DateTime.compare(first.answered_at, before_answer) in [:eq, :gt]
    assert DateTime.compare(first.answered_at, DateTime.utc_now()) in [:eq, :lt]
    assert first.inserted_at == requested.inserted_at

    assert {:ok, ^first} =
             CustomerFeedback.record_answer(context.scope, context.interaction.id, %{
               score: 10,
               comment: "changed"
             })
  end

  test "feedback writes roll back with the outer transaction", context do
    assert {:error, :tool_result_failed} =
             Repo.transact(fn ->
               {:ok, _} = CustomerFeedback.record_request(context.scope, context.interaction)

               {:ok, _} =
                 CustomerFeedback.record_answer(context.scope, context.interaction.id, %{score: 8})

               {:error, :tool_result_failed}
             end)

    assert Repo.aggregate(Feedback, :count) == 0
  end

  defp feedback_interaction(scope) do
    insert_accepted_user_message!(task_fixture(scope), "Feedback checkpoint")
  end

  defp request(%{scope: scope, interaction: interaction}) do
    {:ok, feedback} = CustomerFeedback.record_request(scope, interaction)
    feedback
  end

  defp set_times(feedback, inserted_at, answered_at \\ nil) do
    feedback
    |> change(inserted_at: inserted_at, answered_at: answered_at)
    |> Repo.update!()
  end
end
