defmodule FrontmanServer.Tasks.Todos.Tools.TodoAdded do
  @moduledoc """
  TodoAdded event and tool definition.
  
  Self-contained module with both the event struct and its tool definition.
  """

  use TypedStruct

  alias FrontmanServer.Tasks.Todos.Todo

  typedstruct enforce: true do
    field :todo_id, String.t()
    field :content, String.t()
    field :active_form, String.t()
    field :status, atom()
    field :created_at, DateTime.t()
    field :timestamp, DateTime.t()
  end

  defimpl Event do
    def timestamp(event), do: event.timestamp
  end

  defimpl Jason.Encoder do
    def encode(event, opts) do
      %{
        "todo_id" => event.todo_id,
        "content" => event.content,
        "active_form" => event.active_form,
        "status" => Atom.to_string(event.status),
        "created_at" => DateTime.to_iso8601(event.created_at),
        "timestamp" => DateTime.to_iso8601(event.timestamp)
      }
      |> Jason.Encode.map(opts)
    end
  end

  def from_todo(%Todo{} = todo) do
    %__MODULE__{
      todo_id: todo.id,
      content: todo.content,
      active_form: todo.active_form,
      status: todo.status,
      created_at: todo.created_at,
      timestamp: DateTime.utc_now()
    }
  end

  @todo_statuses ["pending", "in_progress", "completed"]

  @doc """
  Returns the todo_add tool definition.
  """
  @spec tool(String.t()) :: ReqLLM.Tool.t()
  def tool(_task_id) do
    ReqLLM.Tool.new!(
      name: "todo_add",
      description: """
      Add a new todo item for tracking work on the current task.

      USAGE GUIDELINES:
      - Use ONLY for complex tasks with 3+ distinct steps
      - Do NOT use for simple, straightforward tasks
      - Create all planned todos upfront when starting a complex task
      - Each todo must have both imperative form (content) and present continuous form (active_form)
      - Add new todos as subtasks are discovered during implementation

      WHEN TO USE:
      - Breaking down complex, multi-step tasks
      - User provides multiple tasks (numbered or comma-separated)
      - Non-trivial tasks requiring careful planning or multiple operations
      - After receiving new instructions with multiple requirements

      WHEN NOT TO USE:
      - Single, straightforward tasks
      - Trivial tasks completable in less than 3 steps
      - Purely conversational or informational requests
      - Tasks that provide no organizational benefit to track

      EXAMPLES OF GOOD USAGE:
      ✓ Content: "Fix authentication bug", Active Form: "Fixing authentication bug"
      ✓ Content: "Update API endpoints", Active Form: "Updating API endpoints"
      ✓ Content: "Run tests and fix failures", Active Form: "Running tests and fixing failures"

      EXAMPLES OF BAD USAGE (too simple):
      ✗ "Read README file"
      ✗ "Add a comment to function"
      ✗ "Run npm install"
      """,
      parameter_schema: %{
        "type" => "object",
        "properties" => %{
          "content" => %{
            "type" => "string",
            "description" =>
              "The todo description in imperative form (e.g., 'Fix bug in login')"
          },
          "active_form" => %{
            "type" => "string",
            "description" =>
              "The present continuous form shown during execution (e.g., 'Fixing bug in login')"
          },
          "status" => %{
            "type" => "string",
            "enum" => @todo_statuses,
            "description" => "Initial status (defaults to 'pending')",
            "default" => "pending"
          }
        },
        "required" => ["content", "active_form"]
      },
      callback: fn args ->
        content = Map.get(args, "content")
        active_form = Map.get(args, "active_form")
        status = Map.get(args, "status", "pending")

        case FrontmanServer.Tasks.Todos.create_todo(content, active_form, status) do
          {:ok, todo} ->
            event = from_todo(todo)
            {:ok, event}

          {:error, reason} ->
            {:error, "Failed to add todo: #{inspect(reason)}"}
        end
      end
    )
  end
end
