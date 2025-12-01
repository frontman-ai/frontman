defmodule FrontmanServer.Tools do
  @moduledoc """
  Backend tool definitions that execute server-side.

  These tools are passed to the LLM alongside MCP tools but execute
  locally without routing through the client.
  """

  require Logger

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Todos.Todo
  alias FrontmanServer.Tasks.Interaction.ToolCall

  @doc """
  Returns the list of backend tools for a given task.

  All backend tools have access to the task_id via closure.
  """
  @spec backend_tools(String.t()) :: [ReqLLM.Tool.t()]
  def backend_tools(task_id) do
    [
      todo_list_tool(task_id),
      todo_add_tool(task_id),
      todo_update_tool(task_id),
      todo_remove_tool(task_id)
    ]
  end

  @doc """
  Finds a backend tool by name.

  Returns {:ok, tool} if found, :not_found otherwise.
  """
  @spec find_backend_tool(String.t(), String.t()) :: {:ok, ReqLLM.Tool.t()} | :not_found
  def find_backend_tool(tool_name, task_id) do
    backend_tools(task_id)
    |> Enum.find(fn tool -> tool.name == tool_name end)
    |> case do
      nil -> :not_found
      tool -> {:ok, tool}
    end
  end

  @doc """
  Executes a backend tool if found.

  Returns {:executed, result} if the tool was found and executed.
  Returns :not_found if the tool is not a backend tool.
  """
  @spec execute_backend_tool(ToolCall.t(), String.t()) :: {:executed, term()} | :not_found
  def execute_backend_tool(%ToolCall{} = tool_call, task_id) do
    case find_backend_tool(tool_call.tool_name, task_id) do
      {:ok, tool} ->
        Logger.info("Executing backend tool: #{tool_call.tool_name}")

        result = execute_tool(tool, tool_call.arguments)

        Logger.debug("Backend tool #{tool_call.tool_name} result: #{inspect(result)}")

        {:executed, result}

      :not_found ->
        :not_found
    end
  end

  defp execute_tool(tool, arguments) do
    try do
      tool.callback.(arguments)
    rescue
      error ->
        Logger.error("Backend tool execution failed: #{inspect(error)}")
        {:error, "Tool execution failed: #{Exception.message(error)}"}
    end
  end

  # Tool Definitions

  defp todo_list_tool(task_id) do
    ReqLLM.Tool.new!(
      name: "todo_list",
      description: "List all todos for the current task",
      parameter_schema: %{
        "type" => "object",
        "properties" => %{},
        "required" => []
      },
      callback: fn _args ->
        case Tasks.list_todos(task_id) do
          {:ok, todos} ->
            {:ok, format_todo_list_result(todos)}

          {:error, :not_found} ->
            {:error, "Task not found"}
        end
      end
    )
  end

  defp todo_add_tool(_task_id) do
    ReqLLM.Tool.new!(
      name: "todo_add",
      description: "Add a new todo item",
      parameter_schema: %{
        "type" => "object",
        "properties" => %{
          "content" => %{
            "type" => "string",
            "description" => "The todo description (imperative form, e.g., 'Fix bug in login')"
          },
          "active_form" => %{
            "type" => "string",
            "description" => "Present continuous form (e.g., 'Fixing bug in login')"
          },
          "status" => %{
            "type" => "string",
            "enum" => ["pending", "in_progress", "completed"],
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

        case Tasks.create_todo(content, active_form, status) do
          {:ok, todo} ->
            {:ok, format_todo_result("todo_add", todo)}

          {:error, reason} ->
            {:error, "Failed to add todo: #{inspect(reason)}"}
        end
      end
    )
  end

  defp todo_update_tool(task_id) do
    ReqLLM.Tool.new!(
      name: "todo_update",
      description: "Update a todo's status",
      parameter_schema: %{
        "type" => "object",
        "properties" => %{
          "id" => %{
            "type" => "string",
            "description" => "The todo ID to update"
          },
          "status" => %{
            "type" => "string",
            "enum" => ["pending", "in_progress", "completed"],
            "description" => "New status"
          }
        },
        "required" => ["id", "status"]
      },
      callback: fn args ->
        todo_id = Map.get(args, "id")
        status = Map.get(args, "status")

        case Tasks.update_todo_status(task_id, todo_id, status) do
          {:ok, todo} ->
            {:ok, format_todo_result("todo_update", todo)}

          {:error, :task_not_found} ->
            {:error, "Task not found"}

          {:error, :todo_not_found} ->
            {:error, "Todo not found"}

          {:error, reason} ->
            {:error, "Failed to update todo: #{inspect(reason)}"}
        end
      end
    )
  end

  defp todo_remove_tool(task_id) do
    ReqLLM.Tool.new!(
      name: "todo_remove",
      description: "Remove a todo item",
      parameter_schema: %{
        "type" => "object",
        "properties" => %{
          "id" => %{
            "type" => "string",
            "description" => "The todo ID to remove"
          }
        },
        "required" => ["id"]
      },
      callback: fn args ->
        todo_id = Map.get(args, "id")

        case Tasks.validate_todo_exists(task_id, todo_id) do
          :ok ->
            {:ok, format_todo_result("todo_remove", %{id: todo_id})}

          {:error, :task_not_found} ->
            {:error, "Task not found"}

          {:error, :todo_not_found} ->
            {:error, "Todo not found"}
        end
      end
    )
  end

  # Result Formatting

  defp format_todo_list_result(todos) do
    %{
      "type" => "todo_list",
      "todos" => Enum.map(todos, &serialize_todo/1)
    }
  end

  defp format_todo_result(operation_type, todo) do
    %{
      "type" => operation_type,
      "todo" => serialize_todo(todo)
    }
  end

  defp serialize_todo(%Todo{} = todo) do
    %{
      "id" => todo.id,
      "content" => todo.content,
      "active_form" => todo.active_form,
      "status" => todo.status,
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
