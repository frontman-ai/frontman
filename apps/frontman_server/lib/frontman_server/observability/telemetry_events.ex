defmodule FrontmanServer.Observability.TelemetryEvents do
  @moduledoc """
  Clean API for domain code to emit observability events.

  Domain modules call these functions to emit semantic events.
  The OtelHandler (or other handlers) translates these to spans/metrics.

  No OpenTelemetry imports here - this is pure domain event emission.

  ## Span Hierarchy

  FrontmanServer emits only task and MCP tool events:

  ```
  task
  └── mcp_tool (client-side tools)
  ```

  Agent execution events (loop, step, llm, tool, child) are emitted by Swarm
  and handled by SwarmOtelHandler.
  """

  alias FrontmanServer.Observability.Events

  # ============================================================================
  # Task
  # ============================================================================

  @doc "Emits task start. Called when a new prompt begins processing."
  @spec task_start(String.t()) :: :ok
  def task_start(task_id) do
    emit(Events.task_start(), %{task_id: task_id})
  end

  @doc "Emits task stop. Called when prompt completes or session terminates."
  @spec task_stop(String.t()) :: :ok
  def task_stop(task_id) do
    emit(Events.task_stop(), %{task_id: task_id})
  end

  # ============================================================================
  # Tool Execution (MCP/Client)
  # ============================================================================

  @doc "Emits MCP tool start. Called when routing a tool call to the client."
  @spec mcp_tool_start(integer(), String.t(), String.t(), String.t(), map()) :: :ok
  def mcp_tool_start(request_id, tool_call_id, tool_name, task_id, arguments) do
    emit(Events.mcp_tool_start(), %{
      request_id: request_id,
      tool_call_id: tool_call_id,
      tool_name: tool_name,
      task_id: task_id,
      arguments: arguments
    })
  end

  @doc """
  Emits MCP tool stop. Called when MCP response arrives.

  Options: `:status` ("success" | "error"), `:error`
  """
  @spec mcp_tool_stop(integer(), keyword()) :: :ok
  def mcp_tool_stop(request_id, opts \\ []) do
    emit(Events.mcp_tool_stop(), %{
      request_id: request_id,
      status: Keyword.get(opts, :status, "success"),
      error: Keyword.get(opts, :error)
    })
  end

  # ============================================================================
  # Private
  # ============================================================================

  defp emit(event, metadata) do
    :telemetry.execute(event, %{system_time: System.system_time()}, metadata)
  end
end
