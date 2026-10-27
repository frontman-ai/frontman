defmodule FrontmanServer.Tasks.ModelHistory do
  @moduledoc "Projects task history into model messages without changing durable interactions."

  alias FrontmanServer.Tasks.{History, Interaction, InteractionSchema}
  alias SwarmAi.Message
  alias SwarmAi.Message.{ContentPart, Tool}

  def messages(%History{} = history, turn_number)
      when is_integer(turn_number) and turn_number > 0 do
    skills =
      history.rows
      |> Enum.filter(&(&1.type == :skill_used))
      |> Enum.group_by(& &1.data.user_message_id, & &1.data)

    history.rows
    |> Enum.filter(&(is_nil(&1.turn_number) or &1.turn_number <= turn_number))
    |> Enum.sort_by(&{&1.turn_number || 0, &1.sequence})
    |> Enum.map_reduce(MapSet.new(), fn row, pending ->
      messages = row_to_messages(row, history, skills, pending)
      pending = Enum.reduce(messages, pending, &track_tool_pairing(&1, row.turn_number, &2))
      {decay_historical_images(messages, row.turn_number, turn_number), pending}
    end)
    |> elem(0)
    |> List.flatten()
  end

  defp track_tool_pairing(%Message.Assistant{tool_calls: calls}, turn, pending) do
    Enum.reduce(calls, pending, &MapSet.put(&2, {turn, &1.id}))
  end

  defp track_tool_pairing(%Tool{tool_call_id: id}, turn, pending) do
    MapSet.delete(pending, {turn, id})
  end

  defp track_tool_pairing(_message, _turn, pending), do: pending

  defp row_to_messages(
         %InteractionSchema{data: %Interaction.TurnStarted{user_message_ids: ids}},
         history,
         skills,
         _pending
       ) do
    Enum.flat_map(ids, fn id ->
      Interaction.to_swarm_messages(
        Map.get(skills, id, []) ++ [History.user_row(history, id).data]
      )
    end)
  end

  defp row_to_messages(
         %InteractionSchema{turn_number: turn, data: %Interaction.AgentError{}},
         history,
         _skills,
         pending
       ) do
    history.rows
    |> History.unresolved_tool_calls(turn)
    |> Enum.filter(fn {call, _dispatch} -> MapSet.member?(pending, {turn, call.id}) end)
    |> Enum.flat_map(fn
      {call, %Interaction.ToolCall{cancel_requested: true}} ->
        [
          %Tool{
            tool_call_id: call.id,
            name: call.name,
            content: [
              ContentPart.text(
                "Outcome unknown after cancellation; do not assume failure or repeat the operation."
              )
            ]
          }
        ]

      _ ->
        []
    end)
  end

  defp row_to_messages(%InteractionSchema{turn_number: nil}, _history, _skills, _pending), do: []
  defp row_to_messages(%InteractionSchema{type: :skill_used}, _history, _skills, _pending), do: []

  defp row_to_messages(%InteractionSchema{data: data}, _history, _skills, _pending) do
    Interaction.to_swarm_messages([data])
  end

  defp decay_historical_images(messages, row_turn, turn_number)
       when is_integer(row_turn) and row_turn < turn_number,
       do: Enum.map(messages, &decay_images/1)

  defp decay_historical_images(messages, _row_turn, _turn_number), do: messages

  defp decay_images(%Tool{content: content, tool_call_id: tool_call_id} = msg)
       when is_list(content) do
    %{msg | content: Enum.map(content, &decay_image_part(&1, tool_call_id))}
  end

  defp decay_images(msg), do: msg

  defp decay_image_part(%ContentPart{type: type}, tool_call_id)
       when type in [:image, :image_url] do
    ContentPart.text("[image: omitted, tool_call_id: #{tool_call_id}]")
  end

  defp decay_image_part(part, _tool_call_id), do: part
end
