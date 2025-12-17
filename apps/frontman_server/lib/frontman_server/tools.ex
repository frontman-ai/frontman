defmodule FrontmanServer.Tools do
  @moduledoc """
  Backend tool aggregator and executor.
  """

  require Logger

  alias FrontmanServer.Tools.Backend
  alias FrontmanServer.Observability.TelemetryEvents
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction.ToolCall

  @backend_tools [
    FrontmanServer.Tools.TodoList,
    FrontmanServer.Tools.TodoAdd,
    FrontmanServer.Tools.TodoUpdate,
    FrontmanServer.Tools.TodoRemove,
    FrontmanServer.Tools.BreakdownFigmaNode,
    FrontmanServer.Tools.ImplementComponent,
    FrontmanServer.Tools.FinishComponent
  ]

  @todo_mutations ["todo_add", "todo_update", "todo_remove"]

  @spec backend_tools() :: [ReqLLM.Tool.t()]
  def backend_tools do
    Enum.map(@backend_tools, &Backend.to_llm_tool/1)
  end

  @spec find_tool(String.t()) :: {:ok, module()} | :not_found
  def find_tool(tool_name) do
    case Enum.find(@backend_tools, fn mod -> mod.name() == tool_name end) do
      nil -> :not_found
      mod -> {:ok, mod}
    end
  end

  @spec todo_mutation?(String.t()) :: boolean()
  def todo_mutation?(tool_name), do: tool_name in @todo_mutations

  @spec execute_backend_tool(ToolCall.t(), String.t()) :: {:executed, term()} | :not_found
  def execute_backend_tool(%ToolCall{agent_id: agent_id} = tool_call, task_id) do
    case find_tool(tool_call.tool_name) do
      {:ok, tool_module} ->
        case Tasks.get_task(task_id) do
          {:ok, task} ->
            Logger.info("Executing backend tool: #{tool_call.tool_name}")

            TelemetryEvents.tool_start(
              tool_call.tool_call_id,
              tool_call.tool_name,
              agent_id,
              task_id,
              tool_call.arguments
            )

            context = %Backend.Context{task: task, agent_id: agent_id}
            result = tool_module.execute(tool_call.arguments, context)

            case result do
              {:ok, _} ->
                TelemetryEvents.tool_stop(tool_call.tool_call_id, status: "success")

              {:error, reason} ->
                TelemetryEvents.tool_stop(tool_call.tool_call_id, status: "error", error: reason)
            end

            Logger.debug("Backend tool #{tool_call.tool_name} result: #{inspect(result)}")

            {:executed, result}

          {:error, :not_found} ->
            {:executed, {:error, "Task not found"}}
        end

      :not_found ->
        :not_found
    end
  end
end
