defmodule FrontmanServer.Tasks.HistoryTest do
  use ExUnit.Case, async: true

  import FrontmanServer.InteractionCase.Helpers,
    only: [agent_resp: 1, interaction_row: 2, turn_started: 1, user_msg: 1]

  alias FrontmanServer.Tasks.History
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.InteractionSchema

  test "projects row identity, pending messages, turn model, and response ordinal once" do
    rows = [
      user_row("accepted", "model-a"),
      turn_row("turn-id", 1, ["accepted"]),
      response_row(1),
      response_row(1),
      user_row("pending", "model-b")
    ]

    assert {:ok, history} = History.new(rows)

    assert {[user, turn, first_response, second_response, pending], ["executor-id"]} =
             History.attributed_rows!(history)

    assert History.user_row(history, "accepted").id == "accepted"
    assert [%InteractionSchema{id: "pending"}] = History.pending_accepted_messages(history)
    assert {:ok, "model-a"} = History.turn_model(history, 1)
    assert 1 = History.active_run_turn_number(history)

    assert %{
             turn_started_id: "row-turn-id",
             agent_id: "executor-id",
             ordinal_offset: 2
           } = History.response_context(history, 1, "executor-id")

    assert user.agent_id == "executor-id"
    assert user.turn_row.id == "row-turn-id"
    assert turn.turn_row.id == "row-turn-id"
    assert first_response.response_ordinal == 0
    assert first_response.turn_row.id == "row-turn-id"
    assert second_response.response_ordinal == 1
    assert pending.agent_id == "executor-id"
    assert pending.turn_row == nil
  end

  test "rejects one user row assigned to conflicting turns" do
    rows = [
      user_row("accepted", "model-a"),
      turn_row("turn-one", 1, ["accepted"]),
      %{turn_row("turn-two", 2, ["accepted"]) | data: turn("turn-two", ["accepted"], "other")}
    ]

    assert {:error, {:user_message_in_multiple_turns, "accepted"}} = History.new(rows)
  end

  test "rejects turn links to missing user rows" do
    assert {:error, {:missing_user_row, "missing"}} =
             History.new([turn_row("turn-one", 1, ["missing"])])
  end

  test "rejects run rows after their turn terminated" do
    rows = [
      turn_row("turn", 1, []),
      %InteractionSchema{type: :agent_paused, turn_number: 1, data: %Interaction.AgentPaused{}},
      response_row(1)
    ]

    assert {:error, {:inactive_run, :agent_response, 1, nil}} = History.new(rows)
  end

  defp user_row(id, model) do
    interaction = %{user_msg(id) | id: "embedded-#{id}", agent_id: "executor-id", model: model}
    %{interaction_row(interaction, nil) | id: id}
  end

  defp turn_row(id, turn_number, user_message_ids) do
    interaction = %{turn_started(user_message_ids) | id: id, agent_id: "executor-id"}
    %{interaction_row(interaction, turn_number) | id: "row-#{id}"}
  end

  defp turn(id, user_message_ids, agent_id) do
    %{turn_started(user_message_ids) | id: id, agent_id: agent_id}
  end

  defp response_row(turn_number) do
    interaction_row(agent_resp(nil), turn_number)
  end
end
