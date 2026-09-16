# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.Execution do
  @moduledoc "Routes tool results to waiting executors."

  alias FrontmanServer.Tasks.Interaction
  alias SwarmAi.Message.ContentPart

  @doc """
  Notifies that a tool result has arrived.

  Routes the result to the blocking executor via Registry metadata.
  Returns `:notified` when the result was delivered to a live executor,
  `:no_executor` when no executor was waiting (e.g., server restarted).
  """
  def notify_tool_result(task_id, %Interaction.ToolResult{
        tool_call_id: tool_call_id,
        result: %{"content" => content},
        is_error: is_error
      })
      when is_list(content),
      do: notify_tool_result(task_id, tool_call_id, content, is_error)

  def notify_tool_result(_task_id, %Interaction.ToolResult{}), do: :no_executor

  defp notify_tool_result(task_id, tool_call_id, content, is_error) do
    case Elixir.Registry.lookup(
           FrontmanServer.ProcessRegistry,
           tool_registry_key(task_id, tool_call_id)
         ) do
      [{_pid, %{caller_pid: caller}}] ->
        content_parts =
          content
          |> Enum.map(&to_swarm_content_part/1)

        send(caller, {:tool_result, tool_call_id, content_parts, is_error})

        :notified

      [] ->
        :no_executor
    end
  end

  defp tool_registry_key(task_id, tool_call_id), do: {:tool_call, task_id, tool_call_id}

  defp to_swarm_content_part(%{"type" => "text", "text" => text}), do: ContentPart.text(text)

  defp to_swarm_content_part(%{"type" => "image", "data" => data, "mimeType" => mime_type}),
    do: ContentPart.image(Base.decode64!(data), mime_type)
end
