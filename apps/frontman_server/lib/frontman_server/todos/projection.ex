defmodule FrontmanServer.Tasks.Todos.Projection do
  @moduledoc """
  Projects todo state from tool results.
  """

  alias FrontmanServer.Tasks.Interaction.ToolResult
  alias FrontmanServer.Tasks.Todos.Todo

  @spec project(list()) :: %{String.t() => Todo.t()}
  def project(interactions) do
    interactions
    |> Enum.filter(&todo_tool_result?/1)
    |> Enum.reduce(%{}, &apply_result/2)
  end

  defp todo_tool_result?(%ToolResult{tool_name: name}) do
    name in ["todo_add", "todo_update", "todo_remove"]
  end

  defp todo_tool_result?(_), do: false

  defp apply_result(%ToolResult{tool_name: "todo_add", result: %Todo{} = todo}, state) do
    Map.put(state, todo.id, todo)
  end

  defp apply_result(%ToolResult{tool_name: "todo_update", result: %Todo{} = todo}, state) do
    Map.put(state, todo.id, todo)
  end

  defp apply_result(%ToolResult{tool_name: "todo_remove", result: todo_id}, state) do
    Map.delete(state, todo_id)
  end

  defp apply_result(_, state), do: state
end
