defmodule FrontmanServer.Tools.TodoRemove do
  @moduledoc """
  Removes a todo item.
  """

  @behaviour FrontmanServer.Tools.Backend

  alias FrontmanServer.Tools.Backend.Context

  @impl true
  def name, do: "todo_remove"

  @impl true
  def description do
    """
    Remove a todo item from the current task's todo list.

    USE SPARINGLY:
    - Remove todos that became irrelevant due to scope changes
    - Remove duplicate todos created by mistake
    - Remove todos that were created in error

    IMPORTANT GUIDELINES:
    - Do NOT remove completed todos (keep them for progress tracking)
    - Only remove todos when they're truly no longer applicable
    - If a todo is blocked, keep it and create a new todo to resolve the blocker
    - Prefer marking todos as 'completed' over removing them

    WHEN TO USE:
    - User explicitly requests removal of a specific task
    - Scope changes make certain todos obsolete
    - Duplicate todos were accidentally created

    WHEN NOT TO USE:
    - Don't remove todos just because they're completed
    - Don't remove todos that might still be useful for tracking
    """
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "id" => %{
          "type" => "string",
          "description" => "The todo ID to remove from the task"
        }
      },
      "required" => ["id"]
    }
  end

  @impl true
  def execute(args, %Context{}) do
    todo_id = Map.get(args, "id")
    {:ok, todo_id}
  end
end
