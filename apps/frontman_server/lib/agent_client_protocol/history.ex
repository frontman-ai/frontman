# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 - see LICENSE for details.
# Additional terms apply - see AI-SUPPLEMENTARY-TERMS.md

defmodule AgentClientProtocol.History do
  @moduledoc "Encodes projected task row contexts as ACP notifications."

  alias AgentClientProtocol, as: ACP
  alias FrontmanServer.Agents
  alias FrontmanServer.Tasks.History, as: TaskHistory
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.InteractionSchema

  @ignored_types [
    :turn_started,
    :agent_completed,
    :agent_retry,
    :discovered_project_rule,
    :discovered_project_structure
  ]

  def build(%TaskHistory{} = history, session_id, active_agents)
      when is_binary(session_id) and is_list(active_agents) do
    {rows, agent_ids} = TaskHistory.attributed_rows!(history)
    Agents.resolve_catalog!(active_agents, agent_ids)
    notifications = Enum.flat_map(rows, &encode_row(&1, session_id))
    {:ok, %{notifications: notifications}}
  end

  def encode_row(
        %{
          row: %InteractionSchema{data: %Interaction.AgentResponse{} = response},
          turn_row: turn_row,
          agent_id: agent_id,
          response_ordinal: ordinal
        },
        session_id
      ) do
    case response.content do
      content when content in [nil, ""] ->
        []

      content when is_binary(content) ->
        [
          ACP.build_agent_message_chunk_notification(
            session_id,
            content,
            response.timestamp,
            ACP.agent_message_id(turn_row.id, ordinal),
            agent_id
          )
        ]
    end
  end

  def encode_row(
        %{row: %InteractionSchema{data: data, type: type} = row} = context,
        session_id
      ) do
    case data do
      %Interaction.UserMessage{} = message ->
        message
        |> ACP.Content.from_user_message()
        |> Enum.map(fn content ->
          ACP.build_user_message_chunk_notification(
            session_id,
            row.id,
            content,
            context.agent_id,
            message.timestamp
          )
        end)

      %Interaction.ToolCall{} = call ->
        [
          ACP.tool_call_create(
            session_id,
            call.tool_call_id,
            call.tool_name,
            "other",
            call.timestamp,
            ACP.tool_call_status_pending(),
            call.arguments
          )
        ]

      %Interaction.ToolResult{} = result ->
        [
          ACP.tool_call_update(
            session_id,
            result.tool_call_id,
            ACP.tool_call_status(result.is_error),
            ACP.Content.from_tool_result(result.result),
            nil,
            result.result["structuredContent"]
          )
        ]

      %Interaction.AgentError{} = error ->
        [
          ACP.build_error_notification(session_id, error.error, error.timestamp,
            category: error.category,
            agent_error_id: error.id
          )
        ]

      %Interaction.AgentPaused{} ->
        [ACP.build_state_update_notification(session_id, "requires_action")]

      _ignored when type in @ignored_types ->
        []

      _unsupported ->
        raise FunctionClauseError, module: __MODULE__, function: :encode_row, arity: 2
    end
  end
end
