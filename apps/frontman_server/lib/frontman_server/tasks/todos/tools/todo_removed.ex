defmodule FrontmanServer.Tasks.Todos.Tools.TodoRemoved do
  @moduledoc """
  TodoRemoved event and tool definition.
  
  Self-contained module with both the event struct and its tool definition.
  """

  use TypedStruct

  alias FrontmanServer.Tasks

  typedstruct enforce: true do
    field :todo_id, String.t()
    field :timestamp, DateTime.t()
  end

  defimpl Event do
    def timestamp(event), do: event.timestamp
  end

  defimpl Jason.Encoder do
    def encode(event, opts) do
      %{
        "todo_id" => event.todo_id,
        "timestamp" => DateTime.to_iso8601(event.timestamp)
      }
      |> Jason.Encode.map(opts)
    end
  end

  @doc """
  Returns the todo_remove tool definition.
  """
  @spec tool(String.t()) :: ReqLLM.Tool.t()
  def tool(task_id) do
    ReqLLM.Tool.new!(
      name: "todo_remove",
      description: """
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
      """,
      parameter_schema: %{
        "type" => "object",
        "properties" => %{
          "id" => %{
            "type" => "string",
            "description" => "The todo ID to remove from the task"
          }
        },
        "required" => ["id"]
      },
      callback: fn args ->
        todo_id = Map.get(args, "id")

        case Tasks.get_task(task_id) do
          {:ok, task} ->
            case FrontmanServer.Tasks.Todos.validate_todo_exists(task.interactions, todo_id) do
              :ok ->
                event = %__MODULE__{
                  todo_id: todo_id,
                  timestamp: DateTime.utc_now()
                }
                {:ok, event}

              {:error, :not_found} ->
                {:error, "Todo not found"}
            end

          {:error, :not_found} ->
            {:error, "Task not found"}
        end
      end
    )
  end
end
