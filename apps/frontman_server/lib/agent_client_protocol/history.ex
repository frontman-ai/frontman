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

  @spec build([InteractionSchema.t()], String.t(), [FrontmanServer.Agents.Agent.t()]) ::
          {:ok, %{catalog: [map()], notifications: [map()]}} | {:error, term()}
  def build(rows, session_id, active_agents)
      when is_list(rows) and is_binary(session_id) and is_list(active_agents) do
    with {:ok, history} <- TaskHistory.new(rows),
         {:ok, rows} <- TaskHistory.attributed_rows(history),
         {:ok, agents} <-
           Agents.resolve_catalog(
             active_agents,
             TaskHistory.turns(history),
             TaskHistory.agent_ids(history)
           ) do
      notifications = Enum.flat_map(rows, &encode_row(&1, session_id))
      {:ok, active_turn_number} = TaskHistory.active_run_turn_number(history)
      active_turn = TaskHistory.turn_context(history, active_turn_number)
      latest_turn = TaskHistory.turn_context(history, TaskHistory.latest_turn_number(history))

      {:ok,
       %{
         active_turn: active_turn,
         catalog: ACP.build_agent_catalog(agents),
         latest_turn: latest_turn,
         notifications: notifications
       }}
    end
  end

  defp encode_row(
         %{
           row: %InteractionSchema{id: id, data: %Interaction.UserMessage{} = message},
           agent_id: agent_id
         },
         session_id
       ) do
    message
    |> ACP.Content.from_user_message()
    |> Enum.map(fn content ->
      ACP.build_user_message_chunk_notification(
        session_id,
        id,
        content,
        agent_id,
        message.timestamp
      )
    end)
  end

  defp encode_row(
         %{
           row: %InteractionSchema{data: %Interaction.AgentResponse{} = response},
           turn_row: turn_row,
           agent_id: agent_id,
           response_ordinal: ordinal
         },
         session_id
       ) do
    encode_response(response, session_id, turn_row.id, agent_id, ordinal)
  end

  defp encode_row(%{row: %InteractionSchema{data: %Interaction.ToolCall{} = call}}, session_id) do
    [
      ACP.tool_call_create(
        session_id,
        call.tool_call_id,
        call.tool_name,
        "other",
        call.timestamp
      ),
      ACP.tool_call_update(
        session_id,
        call.tool_call_id,
        ACP.tool_call_status_pending(),
        ACP.Content.from_tool_result(call.arguments)
      )
    ]
  end

  defp encode_row(
         %{row: %InteractionSchema{data: %Interaction.ToolResult{} = result}},
         session_id
       ) do
    status =
      case result.is_error do
        true -> ACP.tool_call_status_failed()
        false -> ACP.tool_call_status_completed()
      end

    [
      ACP.tool_call_update(
        session_id,
        result.tool_call_id,
        status,
        ACP.Content.from_tool_result(result.result)
      )
    ]
  end

  defp encode_row(%{row: %InteractionSchema{data: %Interaction.AgentError{} = error}}, session_id) do
    [
      ACP.build_error_notification(session_id, error.error, error.timestamp,
        category: error.category,
        agent_error_id: error.id
      )
    ]
  end

  defp encode_row(%{row: %InteractionSchema{data: %Interaction.AgentPaused{}}}, session_id) do
    [ACP.build_state_update_notification(session_id, "requires_action")]
  end

  defp encode_row(%{row: %InteractionSchema{type: type}}, _session_id)
       when type in [
              :turn_started,
              :agent_completed,
              :agent_retry,
              :discovered_project_rule,
              :discovered_project_structure
            ],
       do: []

  defp encode_response(
         %Interaction.AgentResponse{content: content} = response,
         session_id,
         turn_started_id,
         agent_id,
         ordinal
       )
       when is_binary(content) and content != "" do
    [
      ACP.build_agent_message_chunk_notification(
        session_id,
        content,
        response.timestamp,
        ACP.agent_message_id(turn_started_id, ordinal),
        agent_id
      )
    ]
  end

  defp encode_response(
         %Interaction.AgentResponse{content: content},
         _session_id,
         _turn_started_id,
         _agent_id,
         _ordinal
       )
       when content in [nil, ""],
       do: []
end
