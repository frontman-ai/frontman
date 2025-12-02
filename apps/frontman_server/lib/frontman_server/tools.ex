defmodule FrontmanServer.Tools do
  @moduledoc """
  Backend tool definitions that execute server-side.

  These tools are passed to the LLM alongside client tools but execute
  locally without routing through the client.
  """

  require Logger

  alias FrontmanServer.Tasks.Interaction.ToolCall
  alias FrontmanServer.Tasks.Todos.Tools, as: TodoTools

  @doc """
  Returns the list of backend tools for a given task.

  All backend tools have access to the task_id via closure.
  """
  @spec backend_tools(String.t()) :: [ReqLLM.Tool.t()]
  def backend_tools(task_id) do
    TodoTools.todo_tools(task_id)
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
end
