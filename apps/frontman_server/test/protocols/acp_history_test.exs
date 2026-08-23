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
      row("tool-result", :tool_result, 1, %Interaction.ToolResult{
        tool_call_id: "call",
        tool_name: "read_file",
        result: %{
          "content" => [%{"type" => "text", "text" => "{\"path\":\"file\"}"}],
          "structuredContent" => %{"path" => "file"}
        },
        is_error: false,
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

    assert [first, second, answer, tool_create, tool_result, error] = updates
    assert first["messageId"] == "user-row"
    assert second["messageId"] == "user-row"
    assert answer["messageId"] == "turn-row:1"
    assert answer["_meta"]["frontman.dev/agentId"] == "executor-id"
    assert tool_create["rawInput"] == %{"path" => "file"}
    refute Map.has_key?(tool_create, "content")
    assert tool_result["rawOutput"] == %{"path" => "file"}
    assert [%{"content" => %{"text" => "{\"path\":\"file\"}"}}] = tool_result["content"]
    assert error["_meta"]["frontman.dev/agentErrorId"] == "error-id"
  end

  test "replays tool calls embedded in an empty agent response before their results" do
    rows = [
      row("turn-row", :turn_started, 1, turn("turn-id", [])),
      row("response", :agent_response, 1, %Interaction.AgentResponse{
        id: Ecto.UUID.generate(),
        content: nil,
        metadata: %{
          "tool_calls" => [
            %{
              "id" => "call",
              "name" => "todo_write",
              "arguments" => ~s({"todos":[]})
            }
          ]
        },
        timestamp: @timestamp
      }),
      row("tool-result", :tool_result, 1, %Interaction.ToolResult{
        tool_call_id: "call",
        tool_name: "todo_write",
        result: %{"content" => [], "structuredContent" => %{"todos" => []}},
        is_error: false,
        timestamp: @timestamp
      })
    ]

    assert {:ok, replay} = build(rows)
    updates = Enum.map(replay.notifications, &get_in(&1, ["params", "update"]))

    assert [tool_create, tool_result] = updates
    assert tool_create["sessionUpdate"] == "tool_call"
    assert tool_create["toolCallId"] == "call"
    assert tool_create["rawInput"] == %{"todos" => []}
    assert tool_result["sessionUpdate"] == "tool_call_update"
    assert tool_result["toolCallId"] == "call"
  end

  test "replays provider-shaped embedded tool calls" do
    [tool_create] =
      replay_embedded_tool_calls([
        %{
          "id" => "call",
          "function" => %{
            "name" => "todo_write",
            "arguments" => ~s({"todos":[]})
          }
        }
      ])

    assert tool_create["toolCallId"] == "call"
    assert tool_create["title"] == "todo_write"
    assert tool_create["rawInput"] == %{"todos" => []}
  end

  test "replays embedded tool calls with decoded arguments" do
    [tool_create] =
      replay_embedded_tool_calls([
        %{"id" => "call", "name" => "todo_write", "arguments" => %{"todos" => []}}
      ])

    assert tool_create["rawInput"] == %{"todos" => []}
  end

  test "treats nil embedded tool calls as empty" do
    assert replay_embedded_tool_calls(nil) == []
  end

  test "replays failed tool calls with malformed arguments without raw input" do
    tool_result = %Interaction.ToolResult{
      tool_call_id: "call",
      tool_name: "todo_write",
      result: %{
        "content" => [%{"type" => "text", "text" => "Failed to parse arguments for tool"}],
        "structuredContent" => %{}
      },
      is_error: true,
      timestamp: @timestamp
    }

    assert [tool_create, tool_update] =
             replay_embedded_tool_calls(
               [%{"id" => "call", "name" => "todo_write", "arguments" => "{invalid"}],
               tool_result
             )

    assert tool_create["sessionUpdate"] == "tool_call"
    refute Map.has_key?(tool_create, "rawInput")
    assert tool_update["sessionUpdate"] == "tool_call_update"
    assert tool_update["status"] == "failed"
  end

  test "crashes when history references an agent outside the global catalog" do
    rows = [
      row("turn-row", :turn_started, 1, %{
        turn("archived-turn", [])
        | agent_id: "archived-id"
      }),
      row("response", :agent_response, 1, response("Old answer"))
    ]

    assert_raise KeyError, fn -> build(rows) end
  end

  test "crashes when persisted turn has no agent ID" do
    rows = [
      row("turn-row", :turn_started, 1, %{turn("turn-id", []) | agent_id: nil}),
      row("response", :agent_response, 1, response("Answer"))
    ]

    assert_raise FunctionClauseError, fn -> build(rows) end
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
      user_message_ids: user_message_ids,
      timestamp: @timestamp
    }
  end

  defp response(content) do
    %Interaction.AgentResponse{id: Ecto.UUID.generate(), content: content, timestamp: @timestamp}
  end

  defp replay_embedded_tool_calls(tool_calls, tool_result \\ nil) do
    rows = [
      row("turn-row", :turn_started, 1, turn("turn-id", [])),
      row("response", :agent_response, 1, %Interaction.AgentResponse{
        id: Ecto.UUID.generate(),
        content: nil,
        metadata: %{"tool_calls" => tool_calls},
        timestamp: @timestamp
      })
    ]

    rows =
      case tool_result do
        nil -> rows
        tool_result -> rows ++ [row("tool-result", :tool_result, 1, tool_result)]
      end

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
