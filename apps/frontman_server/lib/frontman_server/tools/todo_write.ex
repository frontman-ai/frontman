defmodule FrontmanServer.Tools.TodoWrite do
  @moduledoc """
  Atomic todo list replacement tool.

  Replaces incremental todo mutations (add/update/remove) with a single
  tool that writes the complete todo list every time. This eliminates
  hallucinated IDs and state drift between LLM turns.
  """

  @behaviour FrontmanServer.Tools.Backend

  alias FrontmanServer.Tasks.Todos

  @impl true
  def name, do: "todo_write"

  @impl true
  def description do
    """
    Write the complete todo list for the current task. Every call replaces the entire list.

    WHEN TO USE:
    - Use for tasks with 3+ distinct steps that benefit from tracking
    - Create the full plan upfront, then update statuses as you progress
    - Do NOT use for simple, single-step tasks

    RULES:
    - Send the COMPLETE list every time — omitted items are removed
    - Keep exactly ONE item as "in_progress" while working
    - Mark items "completed" only when fully done (tests pass, no errors)
    - Use "content" for imperative form and "active_form" for present continuous

    WORKFLOW:
    1. Analyze the task and create all planned todos (status: "pending")
    2. Before starting work on an item, rewrite the list with that item as "in_progress"
    3. After finishing, rewrite with that item as "completed" and the next as "in_progress"
    4. Add new items as subtasks are discovered

    PRIORITY LEVELS:
    - "high": Critical path items, blockers
    - "medium": Standard work items (default)
    - "low": Nice-to-have, cleanup tasks

    EXAMPLES OF GOOD USAGE:
    - Content: "Fix authentication bug", Active Form: "Fixing authentication bug"
    - Content: "Update API endpoints", Active Form: "Updating API endpoints"
    - Content: "Run tests and fix failures", Active Form: "Running tests and fixing failures"
    """
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "todos" => %{
          "type" => "array",
          "description" => "The complete todo list. Every call replaces the entire list.",
          "items" => %{
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
                "enum" => ["pending", "in_progress", "completed"],
                "description" => "Current status of this todo item"
              },
              "priority" => %{
                "type" => "string",
                "enum" => ["high", "medium", "low"],
                "description" => "Priority level. Default: 'medium'",
                "default" => "medium"
              }
            },
            "required" => ["content", "active_form", "status"]
          }
        }
      },
      "required" => ["todos"]
    }
  end

  @impl true
  def timeout_ms, do: 30_000

  @impl true
  def on_timeout, do: :error

  @impl true
  def execute(args, _context) do
    raw_todos = Map.get(args, "todos", [])

    case validate_and_build_todos(raw_todos) do
      {:ok, todos} ->
        {:ok, %{"todos" => Enum.map(todos, &serialize_todo/1)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_and_build_todos(raw_todos) when is_list(raw_todos) do
    raw_todos
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {raw, idx}, {:ok, acc} ->
      content = Map.get(raw, "content")
      active_form = Map.get(raw, "active_form")
      status = Map.get(raw, "status", "pending")
      priority = Map.get(raw, "priority", "medium")

      case Todos.Todo.make(content, active_form, status, priority) do
        {:ok, todo} ->
          {:cont, {:ok, acc ++ [todo]}}

        {:error, errors} ->
          {:halt, {:error, "Invalid todo at index #{idx}: #{inspect(errors)}"}}
      end
    end)
  end

  defp validate_and_build_todos(_), do: {:error, "todos must be an array"}

  defp serialize_todo(todo) do
    %{
      "id" => todo.id,
      "content" => todo.content,
      "active_form" => todo.active_form,
      "status" => Atom.to_string(todo.status),
      "priority" => Atom.to_string(todo.priority),
      "created_at" => DateTime.to_iso8601(todo.created_at),
      "updated_at" => DateTime.to_iso8601(todo.updated_at)
    }
  end
end
