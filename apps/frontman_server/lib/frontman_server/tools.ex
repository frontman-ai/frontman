defmodule FrontmanServer.Tools do
  @moduledoc """
  Backend tool definitions that execute server-side.

  These tools are passed to the LLM alongside client tools but execute
  locally without routing through the client.
  """

  require Logger

  alias FrontmanServer.Agents.FigmaTools
  alias FrontmanServer.Observability.TelemetryEvents
  alias FrontmanServer.Tasks.Interaction.ToolCall
  alias FrontmanServer.Tasks.Todos.Tools, as: TodoTools

  @doc """
  Returns the list of backend tools for a given task.

  All backend tools have access to the task_id via closure.
  MCP tools are stored on the Task and retrieved when tools execute.
  """
  @spec backend_tools(String.t()) :: [ReqLLM.Tool.t()]
  def backend_tools(task_id) do
    TodoTools.todo_tools(task_id) ++ FigmaTools.figma_tools(task_id)
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
  def execute_backend_tool(%ToolCall{agent_id: agent_id} = tool_call, task_id) do
    case find_backend_tool(tool_call.tool_name, task_id) do
      {:ok, tool} ->
        Logger.info("Executing backend tool: #{tool_call.tool_name}")

        # Emit tool start telemetry event
        TelemetryEvents.tool_start(
          tool_call.tool_call_id,
          tool_call.tool_name,
          agent_id,
          task_id,
          tool_call.arguments
        )

        # Context passed to tools that support it (arity 2)
        context = %{agent_id: agent_id, task_id: task_id}
        result = execute_tool(tool, tool_call.arguments, context)

        # Emit tool stop telemetry event
        case result do
          {:ok, _} ->
            TelemetryEvents.tool_stop(tool_call.tool_call_id, status: "success")

          {:error, reason} ->
            TelemetryEvents.tool_stop(tool_call.tool_call_id, status: "error", error: reason)
        end

        Logger.debug("Backend tool #{tool_call.tool_name} result: #{inspect(result)}")

        {:executed, result}

      :not_found ->
        :not_found
    end
  end

  defp execute_tool(tool, arguments, context) do
    try do
      # Store context in process dictionary for tools that need it
      Process.put(:backend_tool_context, context)
      result = tool.callback.(arguments)
      Process.delete(:backend_tool_context)
      result
    rescue
      error ->
        Process.delete(:backend_tool_context)
        Logger.error("Backend tool execution failed: #{inspect(error)}")
        {:error, "Tool execution failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Gets the current tool execution context (agent_id, task_id).
  Used by tools that spawn sub-agents and need to know their parent.
  """
  @spec get_tool_context() :: map()
  def get_tool_context do
    Process.get(:backend_tool_context, %{})
  end
end
