defmodule FrontmanServer.Tasks.Todos.Tools.TodoList do
  @moduledoc """
  TodoList tool definition.
  
  Query tool that doesn't produce events.
  """

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Todos.Todo

  @doc """
  Returns the todo_list tool definition.
  """
  @spec tool(String.t()) :: ReqLLM.Tool.t()
  def tool(task_id) do
    ReqLLM.Tool.new!(
      name: "todo_list",
      description: """
      List all todos for the current task. Use this to review progress and decide which todo to work on next.

      WHEN TO USE:
      - At the start of a complex task to see what's planned
      - Before starting new work to check current status
      - To verify all tasks are completed before finishing

      WHEN NOT TO USE:
      - Don't repeatedly call this unless the todo state has changed
      - Not needed for simple, single-step tasks
      """,
      parameter_schema: %{
        "type" => "object",
        "properties" => %{},
        "required" => []
      },
      callback: fn _args ->
        case Tasks.list_todos(task_id) do
          {:ok, todos} ->
            {:ok, %{"todos" => Enum.map(todos, &serialize_todo/1)}}

          {:error, :not_found} ->
            {:error, "Task not found"}
        end
      end
    )
  end

  defp serialize_todo(%Todo{} = todo) do
    %{
      "id" => todo.id,
      "content" => todo.content,
      "active_form" => todo.active_form,
      "status" => Atom.to_string(todo.status),
      "created_at" => DateTime.to_iso8601(todo.created_at),
      "updated_at" => DateTime.to_iso8601(todo.updated_at)
    }
  end

  defp serialize_todo(%{id: id}) do
    %{
      "id" => id
    }
  end
end
