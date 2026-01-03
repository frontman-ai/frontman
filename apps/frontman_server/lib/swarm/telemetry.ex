defmodule Swarm.Telemetry do
  @moduledoc """
  Telemetry instrumentation for Swarm agent execution.

  Emits `:telemetry` events that can be consumed by handlers to create
  OpenTelemetry spans, metrics, or logs.

  ## Events

  All events follow the `[:swarm, operation, phase]` naming convention.

  ### Run Lifecycle

  - `[:swarm, :run, :start]` - Agent execution started
    - Measurements: `%{system_time: integer()}`
    - Metadata: `%{loop_id: String.t(), agent_module: atom()}`

  - `[:swarm, :run, :stop]` - Agent execution completed
    - Measurements: `%{duration: integer()}`
    - Metadata: `%{loop_id: String.t(), status: atom(), result: term(), error: term(), step_count: integer()}`

  - `[:swarm, :run, :exception]` - Agent execution raised
    - Measurements: `%{duration: integer()}`
    - Metadata: `%{loop_id: String.t(), kind: atom(), reason: term(), stacktrace: list()}`

  ### LLM Calls

  - `[:swarm, :llm, :call, :start]` - LLM call started
    - Measurements: `%{system_time: integer()}`
    - Metadata: `%{loop_id: String.t(), step: integer(), model: String.t() | nil}`

  - `[:swarm, :llm, :call, :stop]` - LLM call completed
    - Measurements: `%{duration: integer()}`
    - Metadata: `%{loop_id: String.t(), step: integer(), input_tokens: integer(), output_tokens: integer(), tool_call_count: integer()}`

  - `[:swarm, :llm, :call, :exception]` - LLM call raised
    - Measurements: `%{duration: integer()}`
    - Metadata: `%{loop_id: String.t(), step: integer(), kind: atom(), reason: term(), stacktrace: list()}`

  ### Tool Execution

  - `[:swarm, :tool, :execute, :start]` - Tool execution started
    - Measurements: `%{system_time: integer()}`
    - Metadata: `%{loop_id: String.t(), step: integer(), tool_id: String.t(), tool_name: String.t()}`

  - `[:swarm, :tool, :execute, :stop]` - Tool execution completed
    - Measurements: `%{duration: integer()}`
    - Metadata: `%{loop_id: String.t(), step: integer(), tool_id: String.t(), tool_name: String.t(), is_error: boolean()}`

  - `[:swarm, :tool, :execute, :exception]` - Tool execution raised
    - Measurements: `%{duration: integer()}`
    - Metadata: `%{loop_id: String.t(), step: integer(), tool_id: String.t(), tool_name: String.t(), kind: atom(), reason: term(), stacktrace: list()}`

  ## Handler Setup

      :telemetry.attach_many(
        "my-swarm-handler",
        Swarm.Telemetry.Events.all(),
        &MyHandler.handle_event/4,
        nil
      )

  ## OpenTelemetry Integration

  Use the `opentelemetry_telemetry` library to convert these events to OTel spans:

      # In your application startup
      OpentelemetryTelemetry.attach_telemetry_handlers("swarm", Swarm.Telemetry.Events.all())
  """

  alias Swarm.Telemetry.Events

  # =============================================================================
  # Run Lifecycle
  # =============================================================================

  @doc "Emit run start event."
  @spec run_start(String.t(), module()) :: :ok
  def run_start(loop_id, agent_module) do
    emit(Events.run_start(), %{
      loop_id: loop_id,
      agent_module: agent_module
    })
  end

  @doc "Emit run stop event."
  @spec run_stop(String.t(), keyword()) :: :ok
  def run_stop(loop_id, opts \\ []) do
    emit(Events.run_stop(), %{
      loop_id: loop_id,
      status: Keyword.get(opts, :status),
      result: Keyword.get(opts, :result),
      error: Keyword.get(opts, :error),
      step_count: Keyword.get(opts, :step_count, 0)
    })
  end

  @doc "Emit run exception event."
  @spec run_exception(String.t(), atom(), term(), list()) :: :ok
  def run_exception(loop_id, kind, reason, stacktrace) do
    emit(Events.run_exception(), %{
      loop_id: loop_id,
      kind: kind,
      reason: reason,
      stacktrace: stacktrace
    })
  end

  # =============================================================================
  # LLM Call
  # =============================================================================

  @doc "Emit LLM call start event."
  @spec llm_call_start(String.t(), pos_integer(), String.t() | nil) :: :ok
  def llm_call_start(loop_id, step, model) do
    emit(Events.llm_call_start(), %{
      loop_id: loop_id,
      step: step,
      model: model
    })
  end

  @doc "Emit LLM call stop event."
  @spec llm_call_stop(String.t(), pos_integer(), keyword()) :: :ok
  def llm_call_stop(loop_id, step, opts \\ []) do
    emit(Events.llm_call_stop(), %{
      loop_id: loop_id,
      step: step,
      input_tokens: Keyword.get(opts, :input_tokens, 0),
      output_tokens: Keyword.get(opts, :output_tokens, 0),
      tool_call_count: Keyword.get(opts, :tool_call_count, 0)
    })
  end

  @doc "Emit LLM call exception event."
  @spec llm_call_exception(String.t(), pos_integer(), atom(), term(), list()) :: :ok
  def llm_call_exception(loop_id, step, kind, reason, stacktrace) do
    emit(Events.llm_call_exception(), %{
      loop_id: loop_id,
      step: step,
      kind: kind,
      reason: reason,
      stacktrace: stacktrace
    })
  end

  # =============================================================================
  # Tool Execution
  # =============================================================================

  @doc "Emit tool execution start event."
  @spec tool_execute_start(String.t(), pos_integer(), String.t(), String.t()) :: :ok
  def tool_execute_start(loop_id, step, tool_id, tool_name) do
    emit(Events.tool_execute_start(), %{
      loop_id: loop_id,
      step: step,
      tool_id: tool_id,
      tool_name: tool_name
    })
  end

  @doc "Emit tool execution stop event."
  @spec tool_execute_stop(String.t(), pos_integer(), String.t(), String.t(), keyword()) :: :ok
  def tool_execute_stop(loop_id, step, tool_id, tool_name, opts \\ []) do
    emit(Events.tool_execute_stop(), %{
      loop_id: loop_id,
      step: step,
      tool_id: tool_id,
      tool_name: tool_name,
      is_error: Keyword.get(opts, :is_error, false)
    })
  end

  @doc "Emit tool execution exception event."
  @spec tool_execute_exception(String.t(), pos_integer(), String.t(), String.t(), atom(), term(), list()) ::
          :ok
  def tool_execute_exception(loop_id, step, tool_id, tool_name, kind, reason, stacktrace) do
    emit(Events.tool_execute_exception(), %{
      loop_id: loop_id,
      step: step,
      tool_id: tool_id,
      tool_name: tool_name,
      kind: kind,
      reason: reason,
      stacktrace: stacktrace
    })
  end

  # =============================================================================
  # Span Helpers
  # =============================================================================

  @doc """
  Execute a function within a telemetry span.

  Automatically emits start/stop/exception events with timing.

  ## Example

      Swarm.Telemetry.span(:llm_call, %{loop_id: id, step: 1, model: "claude"}, fn ->
        result = do_llm_call()
        {result, %{input_tokens: 100, output_tokens: 50}}
      end)
  """
  @spec span(atom(), map(), (-> {term(), map()})) :: term()
  def span(operation, start_metadata, fun) when is_function(fun, 0) do
    {start_event, stop_event, exception_event} = events_for_operation(operation)

    :telemetry.span([start_event, stop_event, exception_event], start_metadata, fn ->
      {result, extra_metadata} = fun.()
      {result, extra_metadata}
    end)
  end

  defp events_for_operation(:run), do: {Events.run_start(), Events.run_stop(), Events.run_exception()}

  defp events_for_operation(:llm_call),
    do: {Events.llm_call_start(), Events.llm_call_stop(), Events.llm_call_exception()}

  defp events_for_operation(:tool_execute),
    do: {Events.tool_execute_start(), Events.tool_execute_stop(), Events.tool_execute_exception()}

  # =============================================================================
  # Private
  # =============================================================================

  defp emit(event, metadata) do
    :telemetry.execute(event, %{system_time: System.system_time()}, metadata)
  end
end
