defmodule AgentClientProtocol.HistoryTest do
  use ExUnit.Case, async: true

  alias AgentClientProtocol.History
  alias FrontmanServer.Agents.Agent
  alias FrontmanServer.Tasks.History, as: TaskHistory
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.InteractionSchema

  @session_id "test-session-123"
  @timestamp ~U[2026-07-14 12:00:00.000000Z]

  test "replays canonical row IDs, complete blocks, tools, errors, and response ordinals" do
    rows = [
      row("user-row", :user_message, nil, %Interaction.UserMessage{
        id: "embedded-id",
        agent_id: "executor-id",
        messages: ["First", "Second"],
        images: [],
        timestamp: @timestamp
      }),
      row("turn-row", :turn_started, 1, turn("turn-id", ["user-row"])),
      row("empty-response", :agent_response, 1, response(nil)),
      row("response", :agent_response, 1, response("Answer")),
      row("tool", :tool_call, 1, %Interaction.ToolCall{
        id: "tool",
        tool_call_id: "call",
        tool_name: "read_file",
        arguments: %{"path" => "file"},
        timestamp: @timestamp
      }),
      row("error", :agent_error, 1, %Interaction.AgentError{
        id: "error-id",
        error: "Failed",
        category: "unknown",
        timestamp: @timestamp
      })
    ]

    assert {:ok, replay} = build(rows)
    updates = Enum.map(replay.notifications, &get_in(&1, ["params", "update"]))

    assert [%{"id" => "executor-id"}] = replay.catalog
    assert [first, second, answer, _tool_create, _tool_update, error] = updates
    assert first["messageId"] == "user-row"
    assert second["messageId"] == "user-row"
    assert answer["messageId"] == "turn-row:1"
    assert answer["_meta"]["frontman.dev/agentId"] == "executor-id"
    assert error["_meta"]["frontman.dev/agentErrorId"] == "error-id"
  end

  test "resolves removed agents from persisted turn metadata" do
    rows = [
      row("turn-row", :turn_started, 1, %{
        turn("archived-turn", [])
        | agent_id: "archived-id",
          agent_name: "archived",
          agent_display_name: "Archived",
          agent_color: "#123456"
      }),
      row("response", :agent_response, 1, response("Old answer"))
    ]

    assert {:ok, replay} = build(rows)
    assert Enum.any?(replay.catalog, &(&1["id"] == "archived-id"))
  end

  test "replays paused terminal state as requires_action" do
    rows = [
      row("turn-row", :turn_started, 1, turn("turn-id", [])),
      row("paused", :agent_paused, 1, %Interaction.AgentPaused{timestamp: @timestamp})
    ]

    assert {:ok, replay} = build(rows)

    assert [%{"params" => %{"update" => update}}] = replay.notifications
    assert update == %{"sessionUpdate" => "state_update", "state" => "requires_action"}
  end

  defp row(id, type, turn_number, data) do
    %InteractionSchema{id: id, type: type, turn_number: turn_number, data: data}
  end

  defp build(rows) do
    with {:ok, history} <- TaskHistory.new(rows),
         do: History.build(history, @session_id, [agent()])
  end

  defp turn(id, user_message_ids) do
    %Interaction.TurnStarted{
      id: id,
      agent_id: "executor-id",
      agent_name: "executor",
      agent_display_name: "Executor",
      agent_description: "Executes changes",
      agent_color: "#22C55E",
      user_message_ids: user_message_ids,
      timestamp: @timestamp
    }
  end

  defp response(content) do
    %Interaction.AgentResponse{id: Ecto.UUID.generate(), content: content, timestamp: @timestamp}
  end

  defp agent do
    %Agent{
      id: "executor-id",
      name: "executor",
      display_name: "Executor",
      description: "Executes changes",
      color: "#22C55E",
      system: "Execute"
    }
  end
end
