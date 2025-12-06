defmodule FrontmanServer.Tasks.Todos.Tools.TodoUpdated do
  @moduledoc """
  TodoUpdated event and tool definition.

  Self-contained module with both the event struct and its tool definition.
  """

  use TypedStruct

  alias FrontmanServer.Tasks

  typedstruct enforce: true do
    field :todo_id, String.t()
    field :status, atom()
    field :updated_at, DateTime.t()
    field :timestamp, DateTime.t()
  end

  defimpl Event do
    def timestamp(event), do: event.timestamp
  end

  defimpl Jason.Encoder do
    def encode(event, opts) do
      %{
        "todo_id" => event.todo_id,
        "status" => Atom.to_string(event.status),
        "updated_at" => DateTime.to_iso8601(event.updated_at),
        "timestamp" => DateTime.to_iso8601(event.timestamp)
      }
      |> Jason.Encode.map(opts)
    end
  end

  @todo_statuses ["pending", "in_progress", "completed"]

  @doc """
  Returns the todo_update tool definition.
  """
  @spec tool(String.t()) :: ReqLLM.Tool.t()
  def tool(task_id) do
    ReqLLM.Tool.new!(
      name: "todo_update",
      description: """
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
      """,
      parameter_schema: %{
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
      },
      callback: fn args ->
        todo_id = Map.get(args, "id")
        status = Map.get(args, "status")

        case Tasks.get_task(task_id) do
          {:ok, task} ->
            case FrontmanServer.Tasks.Todos.update_todo_status(
                   task.interactions,
                   todo_id,
                   status
                 ) do
              {:ok, todo} ->
                event = %__MODULE__{
                  todo_id: todo.id,
                  status: todo.status,
                  updated_at: todo.updated_at,
                  timestamp: DateTime.utc_now()
                }

                {:ok, event}

              {:error, :not_found} ->
                {:error, "Todo not found"}

              {:error, reason} ->
                {:error, "Failed to update todo: #{inspect(reason)}"}
            end

          {:error, :not_found} ->
            {:error, "Task not found"}
        end
      end
    )
  end
end
