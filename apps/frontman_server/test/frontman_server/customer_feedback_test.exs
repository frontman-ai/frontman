defmodule FrontmanServer.CustomerFeedbackTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.CustomerFeedback
  alias FrontmanServer.CustomerFeedback.Feedback

  @now ~U[2026-10-01 12:00:00.000000Z]
  @cutoff DateTime.add(@now, -30, :day)

  setup do
    scope = user_scope_fixture()
    %{scope: scope, interaction: feedback_interaction(scope)}
  end

  test "never asked is eligible", %{scope: scope} do
    assert CustomerFeedback.eligible?(scope, @now)
  end

  test "recent issuance across tasks starts cooldown even unanswered", context do
    feedback = request(context)
    set_times(feedback, DateTime.add(@now, -1, :day))
    feedback_interaction(context.scope)
    refute CustomerFeedback.eligible?(context.scope, @now)
  end

  test "recent answer restarts cooldown after an old request", context do
    feedback = request(context)

    {:ok, feedback} =
      CustomerFeedback.record_answer(context.scope, feedback.interaction_id, %{score: 8})

    set_times(feedback, DateTime.add(@cutoff, -1, :second), DateTime.add(@now, -1, :second))
    refute CustomerFeedback.eligible?(context.scope, @now)
  end

  test "exactly 30 days after issuance is eligible; one microsecond before is not", context do
    feedback = request(context)
    set_times(feedback, @cutoff)
    assert CustomerFeedback.eligible?(context.scope, @now)
    refute CustomerFeedback.eligible?(context.scope, DateTime.add(@now, -1, :microsecond))
    set_times(feedback, DateTime.add(@cutoff, -1, :day))
    assert CustomerFeedback.eligible?(context.scope, @now)
  end

  test "exactly 30 days after answer is eligible; old answers and requests are eligible",
       context do
    feedback = request(context)

    {:ok, feedback} =
      CustomerFeedback.record_answer(context.scope, feedback.interaction_id, %{score: 9})

    set_times(feedback, DateTime.add(@cutoff, -1, :day), @cutoff)
    assert CustomerFeedback.eligible?(context.scope, @now)
    refute CustomerFeedback.eligible?(context.scope, DateTime.add(@now, -1, :microsecond))
    set_times(feedback, DateTime.add(@cutoff, -2, :day), DateTime.add(@cutoff, -1, :day))
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
    refute CustomerFeedback.eligible?(context.scope)
    second_call = feedback_interaction(context.scope)
    assert {:ok, _} = CustomerFeedback.record_request(context.scope, second_call)
    assert Repo.aggregate(Feedback, :count) == 2
  end

  test "requires a persisted owned interaction, never trusts supplied struct data", context do
    assert {:error, :not_found} =
             CustomerFeedback.record_request(context.scope, %{
               context.interaction
               | id: Ecto.UUID.generate()
             })

    other = feedback_interaction(user_scope_fixture())
    forged = %{context.interaction | id: other.id}
    assert {:error, :not_found} = CustomerFeedback.record_request(context.scope, forged)

    assert {:error, :not_found} =
             CustomerFeedback.record_answer(context.scope, other.id, %{score: 8})

    assert {:error, :not_found} =
             CustomerFeedback.record_answer(context.scope, context.interaction.id, %{score: 8})

    assert Repo.aggregate(Feedback, :count) == 0
  end

  test "score and comment validation rejects invalid and malformed input", context do
    request(context)

    for score <- [-1, 11, 8.0, "invalid", nil, true] do
      assert {:error, %Ecto.Changeset{}} =
               CustomerFeedback.record_answer(context.scope, context.interaction.id, %{
                 score: score
               })
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

    assert {:ok, first} =
             CustomerFeedback.record_answer(context.scope, context.interaction.id, %{
               "score" => "0",
               "comment" => comment
             })

    assert first.score == 0
    assert first.comment == comment
    assert first.answered_at
    assert first.inserted_at == requested.inserted_at

    assert {:ok, ^first} =
             CustomerFeedback.record_answer(context.scope, context.interaction.id, %{
               score: 10,
               comment: "changed"
             })
  end

  test "writes compose with outer tool-result transactions and roll back", context do
    assert {:error, :tool_result_failed} =
             Repo.transact(fn ->
               {:ok, _} = CustomerFeedback.record_request(context.scope, context.interaction)

               {:ok, _} =
                 CustomerFeedback.record_answer(context.scope, context.interaction.id, %{score: 8})

               {:error, :tool_result_failed}
             end)

    assert Repo.aggregate(Feedback, :count) == 0
  end

  test "changeset casts only answer attributes and generates its own timestamp" do
    attrs = %{score: "8", comment: "", answered_at: nil, interaction_id: "forged"}

    for params <- [attrs, Map.new(attrs, fn {key, value} -> {Atom.to_string(key), value} end)] do
      changeset = Feedback.answer_changeset(%Feedback{}, params)
      assert {:ok, answer} = Ecto.Changeset.apply_action(changeset, :update)
      assert answer.score == 8
      assert answer.comment == nil
      assert answer.interaction_id == nil
      assert DateTime.diff(DateTime.utc_now(), answer.answered_at, :second) in 0..1
    end

    assert {:error, %Ecto.Changeset{errors: [score: _]}} =
             %Feedback{}
             |> Feedback.answer_changeset(%{})
             |> Ecto.Changeset.apply_action(:update)
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
