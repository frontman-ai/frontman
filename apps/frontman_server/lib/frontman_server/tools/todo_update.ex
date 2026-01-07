defmodule FrontmanServer.Tools.TodoUpdate do
  @moduledoc """
  Updates a todo's status.
  """

  @behaviour FrontmanServer.Tools.Backend

  alias FrontmanServer.Tasks.Todos
  alias FrontmanServer.Tools.Backend.Context

  @todo_statuses ["pending", "in_progress", "completed"]

  @impl true
  def name, do: "todo_update"

  @impl true
  def description do
    """
    Update a todo's status to track progress through your task list.

    WORKFLOW:
    1. Mark ONE todo as 'in_progress' BEFORE starting work on it
    2. Mark as 'completed' IMMEDIATELY after finishing (don't batch completions)
    3. Only ONE todo should be 'in_progress' at a time (not less, not more)
    4. Move todos back to 'pending' if blocked or deprioritized

    CRITICAL COMPLETION RULES:
    - ONLY mark as 'completed' when you have FULLY accomplished the task
    - NEVER mark as completed if:
      * Tests are failing
      * Implementation is partial or incomplete
      * You encountered unresolved errors or blockers
      * You couldn't find necessary files or dependencies
    - If blocked, keep as 'in_progress' and create a new todo describing what needs resolution
    - Complete current todo before starting the next one

    TASK STATE MANAGEMENT:
    - 'pending': Task not yet started, waiting in queue
    - 'in_progress': Currently working on this task (limit to ONE)
    - 'completed': Task finished successfully with all requirements met
    """
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "id" => %{
          "type" => "string",
          "description" => "The todo ID to update"
        },
        "status" => %{
          "type" => "string",
          "enum" => @todo_statuses,
          "description" => "New status for the todo"
        }
      },
      "required" => ["id", "status"]
    }
  end

  @impl true
  def execute(args, %Context{task: %{interactions: interactions}}) do
    todo_id = Map.get(args, "id")
    status = Map.get(args, "status")

    case Todos.update_todo_status(interactions, todo_id, status) do
      {:ok, todo} ->
        {:ok, todo}

      {:error, :not_found} ->
        {:error, "Todo not found"}

      {:error, reason} ->
        {:error, "Failed to update todo: #{inspect(reason)}"}
    end
  end
end
