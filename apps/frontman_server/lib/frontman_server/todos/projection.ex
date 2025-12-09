defmodule Todos.Projection do
  @moduledoc """
  Projects todo events into current state.

  Filters for known event types, then pattern matches to apply them.
  """

  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.Interaction.ToolResult
  alias FrontmanServer.Tasks.Todos.Todo
  alias FrontmanServer.Tasks.Todos.Tools.{TodoAdded, TodoUpdated, TodoRemoved}
  alias FrontmanServer.ToolRegistry, as: ToolRegistry

  @spec project(list(Interaction.t())) :: %{String.t() => Todo.t()}
  def project(interactions) do
    interactions
    |> extract_events()
    |> Enum.reduce(%{}, &apply_event/2)
  end

  defp extract_events(interactions) do
    interactions
    |> Enum.filter(&is_event_tool_result?/1)
    |> Enum.map(&extract_event/1)
    |> Enum.filter(&is_known_event?/1)
  end

  defp is_event_tool_result?(%ToolResult{tool_name: name}) do
    ToolRegistry.produces_events?(name)
  end

  defp is_event_tool_result?(_), do: false

  defp extract_event(%ToolResult{result: event}) when is_struct(event) do
    event
  end

  defp extract_event(%ToolResult{result: _}), do: nil

  @event_types [TodoAdded, TodoUpdated, TodoRemoved]

  defp is_known_event?(%{__struct__: struct}) when struct in @event_types, do: true
  defp is_known_event?(_), do: false

  defp apply_event(%TodoAdded{} = event, state) do
    todo = %Todo{
      id: event.todo_id,
      content: event.content,
      active_form: event.active_form,
      status: event.status,
      created_at: event.created_at,
      updated_at: event.created_at
    }

    Map.put(state, todo.id, todo)
  end

  defp apply_event(%TodoUpdated{} = event, state) do
    case Map.get(state, event.todo_id) do
      nil ->
        state

      todo ->
        Map.put(state, event.todo_id, %{todo | status: event.status, updated_at: event.updated_at})
    end
  end

  defp apply_event(%TodoRemoved{} = event, state) do
    Map.delete(state, event.todo_id)
  end
end
