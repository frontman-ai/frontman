defmodule FrontmanServer.Tools.TodoList do
  @moduledoc """
  Lists all todos for the current task.
  """

  @behaviour FrontmanServer.Tools.Backend

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tools.Backend.Context

  @impl true
  def name, do: "todo_list"

  @impl true
  def description do
    """
    List all todos for the current task. Use this to review progress and decide which todo to work on next.

    WHEN TO USE:
    - At the start of a complex task to see what's planned
    - Before starting new work to check current status
    - To verify all tasks are completed before finishing

    WHEN NOT TO USE:
    - Don't repeatedly call this unless the todo state has changed
    - Not needed for simple, single-step tasks
    """
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{},
      "required" => []
    }
  end

  @impl true
  def execute(_args, %Context{task: %{interactions: interactions}}) do
    todos_map = Tasks.project_todos(interactions)

    todos =
      todos_map
      |> Map.values()
      |> Enum.sort_by(& &1.created_at, DateTime)

    {:ok, %{"todos" => Enum.map(todos, &serialize_todo/1)}}
  end

  defp serialize_todo(todo) do
    %{
      "id" => todo.id,
      "content" => todo.content,
      "active_form" => todo.active_form,
      "status" => Atom.to_string(todo.status),
      "created_at" => DateTime.to_iso8601(todo.created_at),
      "updated_at" => DateTime.to_iso8601(todo.updated_at)
    }
  end
end
