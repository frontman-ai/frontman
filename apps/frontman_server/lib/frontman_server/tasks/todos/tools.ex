defmodule FrontmanServer.Tasks.Todos.Tools do
  @moduledoc """
  Todo tool definitions aggregator.
  
  Collects all todo tools from their individual modules.
  """

  alias FrontmanServer.Tasks.Todos.Tools.{TodoAdded, TodoUpdated, TodoRemoved, TodoList}

  @doc """
  Returns all todo-specific tools for a given task.
  """
  @spec todo_tools(String.t()) :: [ReqLLM.Tool.t()]
  def todo_tools(task_id) do
    [
      TodoList.tool(task_id),
      TodoAdded.tool(task_id),
      TodoUpdated.tool(task_id),
      TodoRemoved.tool(task_id)
    ]
  end
end
