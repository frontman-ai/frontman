alias AgentClientProtocol, as: ACP
alias FrontmanServer.Tasks.Interaction
alias FrontmanServerWeb.ACPHistory

defimpl ACPHistory, for: Interaction.UserMessage do
  def to_history_items(
        %Interaction.UserMessage{messages: messages, timestamp: timestamp},
        session_id
      ) do
    Enum.map(messages, fn text ->
      ACP.build_user_message_chunk_notification(session_id, text, timestamp)
    end)
  end
end

defimpl ACPHistory, for: Interaction.AgentResponse do
  def to_history_items(
        %Interaction.AgentResponse{content: content, timestamp: timestamp},
        session_id
      ) do
    # Per ACP spec: only agent_message_chunk exists (no start/end markers)
    # Client's LoadComplete handler will finalize any streaming messages
    [ACP.build_agent_message_chunk_notification(session_id, content, timestamp)]
  end
end

defimpl ACPHistory, for: Interaction.ToolCall do
  def to_history_items(
        %Interaction.ToolCall{
          tool_call_id: tool_call_id,
          tool_name: tool_name,
          arguments: arguments,
          timestamp: timestamp
        },
        session_id
      ) do
    args_content = ACP.Content.from_tool_result(arguments)

    [
      ACP.tool_call_create(session_id, tool_call_id, tool_name, "other", timestamp),
      ACP.tool_call_update(session_id, tool_call_id, ACP.tool_call_status_pending(), args_content)
    ]
  end
end

defimpl ACPHistory, for: Interaction.ToolResult do
  def to_history_items(
        %Interaction.ToolResult{tool_call_id: tool_call_id, result: result, is_error: is_error},
        session_id
      ) do
    status =
      if is_error, do: ACP.tool_call_status_failed(), else: ACP.tool_call_status_completed()

    result_content = ACP.Content.from_tool_result(result)

    [ACP.tool_call_update(session_id, tool_call_id, status, result_content)]
  end
end

defimpl ACPHistory, for: Interaction.AgentSpawned do
  def to_history_items(%Interaction.AgentSpawned{}, _session_id), do: []
end

defimpl ACPHistory, for: Interaction.AgentCompleted do
  def to_history_items(%Interaction.AgentCompleted{}, _session_id), do: []
end

defimpl ACPHistory, for: Interaction.AgentError do
  def to_history_items(
        %Interaction.AgentError{error: error},
        session_id
      ) do
    # Replay errors as sessionUpdate: "error" notifications so the client
    # renders them the same as live agent errors.
    [ACP.build_error_notification(session_id, error)]
  end
end

defimpl ACPHistory, for: Interaction.DiscoveredProjectRule do
  def to_history_items(%Interaction.DiscoveredProjectRule{}, _session_id), do: []
end

defimpl ACPHistory, for: Interaction.DiscoveredProjectStructure do
  def to_history_items(%Interaction.DiscoveredProjectStructure{}, _session_id), do: []
end
