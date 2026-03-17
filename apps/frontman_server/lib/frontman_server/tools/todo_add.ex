defmodule FrontmanServer.Tools.TodoAdd do
  @moduledoc """
  Adds a new todo item.
  """

  @behaviour FrontmanServer.Tools.Backend

  alias FrontmanServer.Tasks.Todos

  @todo_statuses ["pending", "in_progress", "completed"]

  @impl true
  def name, do: "todo_add"

  @impl true
  def description do
    """
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
    - Content: "Fix authentication bug", Active Form: "Fixing authentication bug"
    - Content: "Update API endpoints", Active Form: "Updating API endpoints"
    - Content: "Run tests and fix failures", Active Form: "Running tests and fixing failures"

    EXAMPLES OF BAD USAGE (too simple):
    - "Read README file"
    - "Add a comment to function"
    - "Run npm install"
    """
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "content" => %{
          "type" => "string",
          "description" => "The todo description in imperative form (e.g., 'Fix bug in login')"
        },
        "active_form" => %{
          "type" => "string",
          "description" =>
            "The present continuous form shown during execution (e.g., 'Fixing bug in login')"
        },
        "status" => %{
          "type" => "string",
          "enum" => @todo_statuses,
          "description" => "(Optional) Initial status. Default: 'pending'",
          "default" => "pending"
        }
      },
      "required" => ["content", "active_form"]
    }
  end

  @impl true
  def execute(args, _context) do
    content = Map.get(args, "content")
    active_form = Map.get(args, "active_form")
    status = Map.get(args, "status", "pending")

    case Todos.create_todo(content, active_form, status) do
      {:ok, todo} ->
        {:ok, todo}

      {:error, reason} ->
        {:error, "Failed to add todo: #{inspect(reason)}"}
    end
  end
end
