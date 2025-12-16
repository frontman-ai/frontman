defmodule FrontmanServer.Observability.TelemetryEvents do
  @moduledoc """
  Clean API for domain code to emit observability events.

  Domain modules call these functions to emit semantic events.
  The OtelHandler (or other handlers) translates these to spans/metrics.

  No OpenTelemetry imports here - this is pure domain event emission.

  ## Span Hierarchy

  Events are organized to match the span hierarchy:

  ```
  task
  └── agent
      └── iteration
          ├── llm (chat)
          ├── tool (backend)
          ├── mcp_tool (client)
          └── spawn_sub_agent
              └── agent [sub-agent lifecycle]
  ```
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
  # Agent
  # ============================================================================

  @doc "Emits agent start."
  @spec agent_start(String.t(), String.t()) :: :ok
  def agent_start(agent_id, task_id) do
    emit(Events.agent_start(), %{
      agent_id: agent_id,
      task_id: task_id
    })
  end

  @doc "Emits agent stop. Called when agent terminates."
  @spec agent_stop(String.t()) :: :ok
  def agent_stop(agent_id) do
    emit(Events.agent_stop(), %{agent_id: agent_id})
  end

  # ============================================================================
  # Iteration
  # ============================================================================

  @doc "Emits iteration start. Called when agent begins a new iteration."
  @spec iteration_start(String.t(), pos_integer()) :: :ok
  def iteration_start(agent_id, iteration_number) do
    # End previous iteration if any (handles :wait_for_tools case where iteration wasn't closed)
    if iteration_number > 1 do
      iteration_stop(agent_id, iteration_number - 1)
    end

    emit(Events.iteration_start(), %{
      agent_id: agent_id,
      iteration_number: iteration_number
    })
  end

  @doc """
  Emits iteration stop.

  Options: `:status` (:stop | :wait_for_tools | :error), `:error`
  """
  @spec iteration_stop(String.t(), pos_integer(), keyword()) :: :ok
  def iteration_stop(agent_id, iteration_number, opts \\ []) do
    emit(Events.iteration_stop(), %{
      agent_id: agent_id,
      iteration_number: iteration_number,
      status: Keyword.get(opts, :status, :stop),
      error: Keyword.get(opts, :error)
    })
  end

  # ============================================================================
  # LLM Call
  # ============================================================================

  @doc "Emits LLM call start. Called before streaming begins."
  @spec llm_start(String.t(), String.t(), String.t(), list()) :: :ok
  def llm_start(agent_id, task_id, model, messages) do
    emit(Events.llm_start(), %{
      agent_id: agent_id,
      task_id: task_id,
      model: model,
      messages: messages
    })
  end

  @doc """
  Emits LLM call stop.

  Options: `:response_id`, `:output_text`, `:tool_calls`, `:usage`, `:error`
  """
  @spec llm_stop(String.t(), keyword()) :: :ok
  def llm_stop(agent_id, opts \\ []) do
    emit(Events.llm_stop(), %{
      agent_id: agent_id,
      response_id: Keyword.get(opts, :response_id),
      output_text: Keyword.get(opts, :output_text),
      tool_calls: Keyword.get(opts, :tool_calls, []),
      usage: Keyword.get(opts, :usage),
      error: Keyword.get(opts, :error)
    })
  end

  # ============================================================================
  # Tool Execution (Backend)
  # ============================================================================

  @doc "Emits backend tool start. Called before executing a server-side tool."
  @spec tool_start(String.t(), String.t(), String.t(), String.t(), map()) :: :ok
  def tool_start(tool_call_id, tool_name, agent_id, task_id, arguments) do
    emit(Events.tool_start(), %{
      tool_call_id: tool_call_id,
      tool_name: tool_name,
      agent_id: agent_id,
      task_id: task_id,
      arguments: arguments
    })
  end

  @doc """
  Emits backend tool stop.

  Options: `:status` ("success" | "error"), `:error`
  """
  @spec tool_stop(String.t(), keyword()) :: :ok
  def tool_stop(tool_call_id, opts \\ []) do
    emit(Events.tool_stop(), %{
      tool_call_id: tool_call_id,
      status: Keyword.get(opts, :status, "success"),
      error: Keyword.get(opts, :error)
    })
  end

  # ============================================================================
  # Tool Execution (MCP/Client)
  # ============================================================================

  @doc "Emits MCP tool start. Called when routing a tool call to the client."
  @spec mcp_tool_start(integer(), String.t(), String.t(), String.t(), String.t(), map()) :: :ok
  def mcp_tool_start(request_id, tool_call_id, tool_name, agent_id, task_id, arguments) do
    emit(Events.mcp_tool_start(), %{
      request_id: request_id,
      tool_call_id: tool_call_id,
      tool_name: tool_name,
      agent_id: agent_id,
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
  # Sub-Agent Spawn
  # ============================================================================

  @doc "Emits sub-agent spawn start."
  @spec spawn_sub_agent_start(String.t(), String.t(), String.t()) :: :ok
  def spawn_sub_agent_start(agent_id, task_id, role) do
    emit(Events.spawn_sub_agent_start(), %{
      agent_id: agent_id,
      task_id: task_id,
      role: role
    })
  end

  @doc """
  Emits sub-agent spawn stop.

  Options: `:status` ("success" | "error"), `:error`
  """
  @spec spawn_sub_agent_stop(String.t(), keyword()) :: :ok
  def spawn_sub_agent_stop(agent_id, opts \\ []) do
    emit(Events.spawn_sub_agent_stop(), %{
      agent_id: agent_id,
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
