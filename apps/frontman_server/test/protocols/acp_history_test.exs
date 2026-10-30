defmodule FrontmanServer.Protocols.ACP.HistoryTest do
  use ExUnit.Case, async: true

  import FrontmanServer.InteractionCase.Helpers,
    only: [
      agent_completed: 0,
      agent_error: 1,
      agent_paused: 2,
      agent_resp: 1,
      agent_resp: 2,
      interaction_row: 2,
      tool_call: 3,
      tool_result: 3,
      tool_result: 4,
      turn_started: 1,
      user_msg: 1
    ]

  alias FrontmanServer.Agents.Agent
  alias FrontmanServer.Protocols.ACP.History
  alias FrontmanServer.Tasks.History, as: TaskHistory
  alias FrontmanServer.Tasks.Interaction

  @session_id "test-session-123"
  @timestamp ~U[2026-07-14 12:00:00.000000Z]

  test "replays canonical row IDs, complete blocks, and response ordinals" do
    rows = [
      row("turn-row", 1, turn("turn-id", ["user-row"])),
      row("user-row", nil, %{
        user_msg(["First", "Second"])
        | id: "embedded-id",
          agent_id: "executor-id",
          timestamp: @timestamp
      }),
      row("empty-response", 1, agent_resp(nil)),
      row("response", 1, agent_resp("Answer")),
      row("queued-row", nil, %{user_msg(["Follow-up"]) | agent_id: "executor-id"})
    ]

    assert [
             first,
             second,
             %{"messageId" => "queued-row"},
             %{
               "sessionUpdate" => "session_info_update",
               "_meta" => %{"frontman.dev/turnMessageIds" => ["user-row"]}
             },
             answer
           ] = updates(rows)

    assert first["messageId"] == "user-row"
    assert second["messageId"] == "user-row"
    assert first["content"] == %{"type" => "text", "text" => "First"}
    assert second["content"] == %{"type" => "text", "text" => "Second"}
    refute Map.has_key?(first, "pending")
    assert answer["messageId"] == "turn-row:1"
    assert answer["_meta"]["frontman.dev/agentId"] == "executor-id"
  end

  test "replays one tool call when response metadata also has a standalone call" do
    rows = [
      row("turn-row", 1, turn("turn-id", [])),
      row(
        "response",
        1,
        agent_resp(nil, %{
          "tool_calls" => [
            %{
              "id" => "call",
              "name" => "todo_write",
              "arguments" => ~s({"source":"embedded"})
            }
          ]
        })
      ),
      row("tool", 1, tool_call("call", "todo_write", %{"todos" => []})),
      row(
        "tool-result",
        1,
        tool_result(
          "call",
          "todo_write",
          %{"content" => [], "structuredContent" => %{"todos" => []}}
        )
      )
    ]

    assert [%{"sessionUpdate" => "session_info_update"}, tool_create, tool_result] = updates(rows)
    assert tool_create["sessionUpdate"] == "tool_call"
    assert tool_create["toolCallId"] == "call"
    assert tool_create["rawInput"] == %{"todos" => []}
    assert tool_result["sessionUpdate"] == "tool_call_update"
    assert tool_result["toolCallId"] == "call"
  end

  test "replays embedded-only calls without malformed raw input" do
    rows = [
      row("turn-row", 1, turn("turn-id", [])),
      row(
        "response",
        1,
        agent_resp(nil, %{
          "tool_calls" => [
            %{"id" => "valid-call", "name" => "todo_write", "arguments" => ~s({"todos":[]})},
            %{"id" => "call", "name" => "todo_write", "arguments" => "{invalid"}
          ]
        })
      ),
      row(
        "tool-result",
        1,
        tool_result(
          "call",
          "todo_write",
          %{
            "content" => [%{"type" => "text", "text" => "Failed to parse arguments for tool"}],
            "structuredContent" => %{}
          },
          is_error: true
        )
      )
    ]

    assert [%{"sessionUpdate" => "session_info_update"}, valid_create, tool_create, tool_update] =
             updates(rows)

    assert valid_create["rawInput"] == %{"todos" => []}
    assert tool_create["sessionUpdate"] == "tool_call"
    refute Map.has_key?(tool_create, "rawInput")
    assert tool_update["sessionUpdate"] == "tool_call_update"
    assert tool_update["status"] == "failed"
  end

  test "replays agent errors and subsequent retries in order" do
    error = %{agent_error("Failed") | id: "error-id", timestamp: @timestamp}
    retry = %Interaction.AgentRetry{retried_error_id: error.id}

    assert [
             %{
               "sessionUpdate" => "session_info_update",
               "_meta" => %{"frontman.dev/turnMessageIds" => []}
             },
             update,
             retry_update
           ] =
             updates([
               row("turn-row", 1, turn("turn-id", [])),
               row("error", 1, error),
               row("retry", 1, retry)
             ])

    assert update["_meta"]["frontman.dev/agentErrorId"] == "error-id"
    assert retry_update == %{"sessionUpdate" => "state_update", "state" => "running"}
  end

  test "crashes when history references an agent outside the global catalog" do
    rows = [
      row("turn-row", 1, %{
        turn("archived-turn", [])
        | agent_id: "archived-id"
      }),
      row("response", 1, agent_resp("Old answer"))
    ]

    assert_raise KeyError, fn -> build(rows) end
  end

  test "crashes when persisted turn has no agent ID" do
    rows = [
      row("turn-row", 1, %{turn("turn-id", []) | agent_id: nil}),
      row("response", 1, agent_resp("Answer"))
    ]

    assert_raise FunctionClauseError, fn -> build(rows) end
  end

  test "replays terminal states without historical claims" do
    for {outcome, state} <- [
          {agent_paused("question", 120_000), "requires_action"},
          {agent_completed(), "idle"}
        ] do
      rows = [row("turn-row", 1, turn("turn-id", [])), row("terminal", 1, outcome)]

      running = %{
        "sessionUpdate" => "session_info_update",
        "_meta" => %{"frontman.dev/turnMessageIds" => []}
      }

      terminal = %{"sessionUpdate" => "state_update", "state" => state}
      assert [^running, ^terminal] = updates(rows)
    end
  end

  defp row(id, turn_number, interaction),
    do: %{interaction_row(interaction, turn_number) | id: id}

  defp build(rows) do
    with {:ok, history} <- TaskHistory.new(rows),
         do: History.build(history, @session_id, [agent()])
  end

  defp turn(id, user_message_ids) do
    %{turn_started(user_message_ids) | id: id, agent_id: "executor-id", timestamp: @timestamp}
  end

  defp updates(rows) do
    {:ok, replay} = build(rows)
    Enum.map(replay.notifications, &get_in(&1, ["params", "update"]))
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
