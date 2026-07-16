defmodule FrontmanServer.Tasks.HistoryTest do
  use ExUnit.Case, async: true

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

    assert {:ok, [user, turn, first_response, second_response, pending]} =
             History.attributed_rows(history)

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
    assert History.agent_ids(history) == ["executor-id"]
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
    %InteractionSchema{
      id: id,
      type: :user_message,
      data: %Interaction.UserMessage{
        id: "embedded-#{id}",
        agent_id: "executor-id",
        model: model,
        messages: [id],
        images: []
      }
    }
  end

  defp turn_row(id, turn_number, user_message_ids) do
    %InteractionSchema{
      id: "row-#{id}",
      type: :turn_started,
      turn_number: turn_number,
      data: turn(id, user_message_ids, "executor-id")
    }
  end

  defp turn(id, user_message_ids, agent_id) do
    %Interaction.TurnStarted{
      id: id,
      agent_id: agent_id,
      user_message_ids: user_message_ids
    }
  end

  defp response_row(turn_number) do
    %InteractionSchema{
      id: Ecto.UUID.generate(),
      type: :agent_response,
      turn_number: turn_number,
      data: %Interaction.AgentResponse{id: Ecto.UUID.generate(), content: nil}
    }
  end
end
