alias FrontmanServer.Tasks.Interaction
alias FrontmanServerWeb.ACPHistory

defimpl ACPHistory, for: Interaction.UserMessage do
  def to_history_items(
        %Interaction.UserMessage{messages: messages, timestamp: timestamp},
        session_id
      ) do
    timestamp_iso = DateTime.to_iso8601(timestamp)

    Enum.map(messages, fn text ->
      JsonRpc.notification("session/update", %{
        "sessionId" => session_id,
        "update" => %{
          "sessionUpdate" => "user_message_chunk",
          "content" => %{"type" => "text", "text" => text},
          "timestamp" => timestamp_iso
        }
      })
    end)
  end
end

defimpl ACPHistory, for: Interaction.AgentResponse do
  def to_history_items(%Interaction.AgentResponse{content: content}, session_id) do
    # Per ACP spec: only agent_message_chunk exists (no start/end markers)
    # Client's LoadComplete handler will finalize any streaming messages
    [
      JsonRpc.notification("session/update", %{
        "sessionId" => session_id,
        "update" => %{
          "sessionUpdate" => "agent_message_chunk",
          "content" => %{"type" => "text", "text" => content}
        }
      })
    ]
  end
end

defimpl ACPHistory, for: Interaction.ToolCall do
  def to_history_items(
        %Interaction.ToolCall{
          tool_call_id: tool_call_id,
          tool_name: tool_name,
          arguments: arguments
        },
        session_id
      ) do
    [
      JsonRpc.notification("session/update", %{
        "sessionId" => session_id,
        "update" => %{
          "sessionUpdate" => "tool_call",
          "toolCallId" => tool_call_id,
          "title" => tool_name,
          "kind" => "other",
          "status" => "pending"
        }
      }),
      JsonRpc.notification("session/update", %{
        "sessionId" => session_id,
        "update" => %{
          "sessionUpdate" => "tool_call_update",
          "toolCallId" => tool_call_id,
          "status" => "pending",
          "content" => [
            %{
              "type" => "content",
              "content" => %{"type" => "text", "text" => Jason.encode!(arguments)}
            }
          ]
        }
      })
    ]
  end
end

defimpl ACPHistory, for: Interaction.ToolResult do
  def to_history_items(
        %Interaction.ToolResult{tool_call_id: tool_call_id, result: result, is_error: is_error},
        session_id
      ) do
    status = if is_error, do: "failed", else: "completed"
    result_text = if is_binary(result), do: result, else: Jason.encode!(result)

    [
      JsonRpc.notification("session/update", %{
        "sessionId" => session_id,
        "update" => %{
          "sessionUpdate" => "tool_call_update",
          "toolCallId" => tool_call_id,
          "status" => status,
          "content" => [
            %{"type" => "content", "content" => %{"type" => "text", "text" => result_text}}
          ]
        }
      })
    ]
  end
end

defimpl ACPHistory, for: Interaction.AgentSpawned do
  def to_history_items(%Interaction.AgentSpawned{}, _session_id), do: []
end

defimpl ACPHistory, for: Interaction.AgentCompleted do
  def to_history_items(%Interaction.AgentCompleted{}, _session_id), do: []
end

defimpl ACPHistory, for: Interaction.DiscoveredProjectRule do
  def to_history_items(%Interaction.DiscoveredProjectRule{}, _session_id), do: []
end
