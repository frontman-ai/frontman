defmodule SwarmAi.Telemetry do
  @moduledoc """
  Telemetry instrumentation for Swarm agent execution.

  Swarm emits `:telemetry` events following Erlang/Elixir ecosystem conventions.
  All events use the `[:swarm_ai, ...]` prefix and follow the start/stop/exception pattern.

  ## Metadata Propagation

  All events include a `metadata` field that is passed from the caller through `SwarmAi.run_streaming/3`
  or `SwarmAi.run/3`. This allows callers to attach arbitrary context (like `task_id`) that flows
  through all telemetry events, enabling correlation without requiring process-based hacks.

  ## Events

  ### Run Lifecycle (`[:swarm_ai, :run, ...]`)

  Emitted around the full agent execution lifecycle.

  | Event | Measurements | Metadata |
  |-------|--------------|----------|
  | `[:swarm_ai, :run, :start]` | `system_time` | `loop_id`, `agent_module`, `metadata` |
  | `[:swarm_ai, :run, :stop]` | `duration` | `loop_id`, `status`, `step_count`, `result`, `error`, `metadata` |
  | `[:swarm_ai, :run, :exception]` | `duration` | `loop_id`, `kind`, `reason`, `stacktrace`, `metadata` |

  ### Step Lifecycle (`[:swarm_ai, :step, ...]`)

  Emitted around each step (iteration) of the agent loop.

  | Event | Measurements | Metadata |
  |-------|--------------|----------|
  | `[:swarm_ai, :step, :start]` | `system_time` | `loop_id`, `step`, `metadata` |
  | `[:swarm_ai, :step, :stop]` | `duration` | `loop_id`, `step`, `metadata` |
  | `[:swarm_ai, :step, :exception]` | `duration` | `loop_id`, `step`, `kind`, `reason`, `stacktrace`, `metadata` |

  ### LLM Calls (`[:swarm_ai, :llm, :call, ...]`)

  Emitted around each LLM API call within a run.

  | Event | Measurements | Metadata |
  |-------|--------------|----------|
  | `[:swarm_ai, :llm, :call, :start]` | `system_time` | `loop_id`, `step`, `model`, `metadata` |
  | `[:swarm_ai, :llm, :call, :stop]` | `duration` | `loop_id`, `step`, `input_tokens`, `output_tokens`, `tool_call_count`, `metadata` |
  | `[:swarm_ai, :llm, :call, :exception]` | `duration` | `loop_id`, `step`, `kind`, `reason`, `stacktrace`, `metadata` |

  ### Tool Execution (`[:swarm_ai, :tool, :execute, ...]`)

  Emitted around each tool execution.

  | Event | Measurements | Metadata |
  |-------|--------------|----------|
  | `[:swarm_ai, :tool, :execute, :start]` | `system_time` | `loop_id`, `step`, `tool_id`, `tool_name`, `metadata` |
  | `[:swarm_ai, :tool, :execute, :stop]` | `duration` | `loop_id`, `step`, `tool_id`, `tool_name`, `is_error`, `metadata` |
  | `[:swarm_ai, :tool, :execute, :exception]` | `duration` | `loop_id`, `step`, `tool_id`, `tool_name`, `kind`, `reason`, `stacktrace`, `metadata` |

  ### Child Agent Spawning (`[:swarm_ai, :child, :spawn, ...]`)

  Emitted when a parent agent spawns a child agent.

  | Event | Measurements | Metadata |
  |-------|--------------|----------|
  | `[:swarm_ai, :child, :spawn, :start]` | `system_time` | `parent_loop_id`, `parent_step`, `tool_call_id`, `child_agent_module`, `task`, `metadata` |
  | `[:swarm_ai, :child, :spawn, :stop]` | `duration` | `parent_loop_id`, `child_loop_id`, `child_status`, `child_step_count`, `child_total_tokens`, `metadata` |
  | `[:swarm_ai, :child, :spawn, :exception]` | `duration` | `parent_loop_id`, `tool_call_id`, `kind`, `reason`, `stacktrace`, `metadata` |

  ## Usage

  ### Attaching Handlers

      :telemetry.attach_many(
        "my-swarm-handler",
        SwarmAi.Telemetry.Events.all(),
        &MyHandler.handle_event/4,
        nil
      )

  ### Default Logger

  Swarm provides a default logger for development:

      SwarmAi.Telemetry.attach_default_logger()
      SwarmAi.Telemetry.attach_default_logger(level: :debug)

  ### OpenTelemetry Integration

      OpentelemetryTelemetry.attach_telemetry_handlers("swarm", SwarmAi.Telemetry.Events.all())
  """

  require Logger
  alias SwarmAi.Telemetry.Events

  # =============================================================================
  # Run Lifecycle
  # =============================================================================

  @doc "Emit run start event."
  @spec run_start(String.t(), module(), map()) :: :ok
  def run_start(loop_id, agent_module, metadata \\ %{}) do
    emit(Events.run_start(), %{
      loop_id: loop_id,
      agent_module: agent_module,
      metadata: metadata
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
      step_count: Keyword.get(opts, :step_count, 0),
      metadata: Keyword.get(opts, :metadata, %{})
    })
  end

  @doc "Emit run exception event."
  @spec run_exception(String.t(), atom(), term(), list(), map()) :: :ok
  def run_exception(loop_id, kind, reason, stacktrace, metadata \\ %{}) do
    emit(Events.run_exception(), %{
      loop_id: loop_id,
      kind: kind,
      reason: reason,
      stacktrace: stacktrace,
      metadata: metadata
    })
  end

  # =============================================================================
  # Step Lifecycle
  # =============================================================================

  @doc "Emit step start event."
  @spec step_start(String.t(), pos_integer(), map()) :: :ok
  def step_start(loop_id, step, metadata \\ %{}) do
    emit(Events.step_start(), %{
      loop_id: loop_id,
      step: step,
      metadata: metadata
    })
  end

  @doc "Emit step stop event."
  @spec step_stop(String.t(), pos_integer(), map()) :: :ok
  def step_stop(loop_id, step, metadata \\ %{}) do
    emit(Events.step_stop(), %{
      loop_id: loop_id,
      step: step,
      metadata: metadata
    })
  end

  @doc "Emit step exception event."
  @spec step_exception(String.t(), pos_integer(), atom(), term(), list(), map()) :: :ok
  def step_exception(loop_id, step, kind, reason, stacktrace, metadata \\ %{}) do
    emit(Events.step_exception(), %{
      loop_id: loop_id,
      step: step,
      kind: kind,
      reason: reason,
      stacktrace: stacktrace,
      metadata: metadata
    })
  end

  # =============================================================================
  # LLM Call
  # =============================================================================

  @doc "Emit LLM call start event."
  @spec llm_call_start(String.t(), pos_integer(), String.t() | nil, map()) :: :ok
  def llm_call_start(loop_id, step, model, metadata \\ %{}) do
    emit(Events.llm_call_start(), %{
      loop_id: loop_id,
      step: step,
      model: model,
      metadata: metadata
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
      reasoning_tokens: Keyword.get(opts, :reasoning_tokens, 0),
      cached_tokens: Keyword.get(opts, :cached_tokens, 0),
      tool_call_count: Keyword.get(opts, :tool_call_count, 0),
      metadata: Keyword.get(opts, :metadata, %{})
    })
  end

  @doc "Emit LLM call exception event."
  @spec llm_call_exception(String.t(), pos_integer(), atom(), term(), list(), map()) :: :ok
  def llm_call_exception(loop_id, step, kind, reason, stacktrace, metadata \\ %{}) do
    emit(Events.llm_call_exception(), %{
      loop_id: loop_id,
      step: step,
      kind: kind,
      reason: reason,
      stacktrace: stacktrace,
      metadata: metadata
    })
  end

  # =============================================================================
  # Tool Execution
  # =============================================================================

  @doc "Emit tool execution start event."
  @spec tool_execute_start(String.t(), pos_integer(), String.t(), String.t(), map()) :: :ok
  def tool_execute_start(loop_id, step, tool_id, tool_name, metadata \\ %{}) do
    emit(Events.tool_execute_start(), %{
      loop_id: loop_id,
      step: step,
      tool_id: tool_id,
      tool_name: tool_name,
      metadata: metadata
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
      is_error: Keyword.get(opts, :is_error, false),
      metadata: Keyword.get(opts, :metadata, %{})
    })
  end

  @doc "Emit tool execution exception event."
  @spec tool_execute_exception(
          String.t(),
          pos_integer(),
          String.t(),
          String.t(),
          atom(),
          term(),
          list(),
          map()
        ) ::
          :ok
  def tool_execute_exception(
        loop_id,
        step,
        tool_id,
        tool_name,
        kind,
        reason,
        stacktrace,
        metadata \\ %{}
      ) do
    emit(Events.tool_execute_exception(), %{
      loop_id: loop_id,
      step: step,
      tool_id: tool_id,
      tool_name: tool_name,
      kind: kind,
      reason: reason,
      stacktrace: stacktrace,
      metadata: metadata
    })
  end

  # =============================================================================
  # Child Spawn
  # =============================================================================

  @doc "Emit child spawn start event."
  @spec child_spawn_start(
          String.t(),
          pos_integer(),
          String.t(),
          SwarmAi.SpawnChildAgent.t(),
          map()
        ) ::
          :ok
  def child_spawn_start(
        parent_loop_id,
        parent_step,
        tool_call_id,
        %SwarmAi.SpawnChildAgent{} = request,
        metadata \\ %{}
      ) do
    emit(Events.child_spawn_start(), %{
      parent_loop_id: parent_loop_id,
      parent_step: parent_step,
      tool_call_id: tool_call_id,
      child_agent_module: request.agent.__struct__,
      task: request.task,
      metadata: metadata
    })
  end

  @doc "Emit child spawn stop event."
  @spec child_spawn_stop(String.t(), SwarmAi.ChildResult.t(), map()) :: :ok
  def child_spawn_stop(parent_loop_id, %SwarmAi.ChildResult{} = result, metadata \\ %{}) do
    emit(Events.child_spawn_stop(), %{
      parent_loop_id: parent_loop_id,
      child_loop_id: result.child_loop_id,
      child_status: result.status,
      child_step_count: result.step_count,
      child_total_tokens: result.total_tokens,
      duration_ms: result.duration_ms,
      metadata: metadata
    })
  end

  @doc "Emit child spawn exception event."
  @spec child_spawn_exception(String.t(), String.t(), atom(), term(), list(), map()) :: :ok
  def child_spawn_exception(
        parent_loop_id,
        tool_call_id,
        kind,
        reason,
        stacktrace,
        metadata \\ %{}
      ) do
    emit(Events.child_spawn_exception(), %{
      parent_loop_id: parent_loop_id,
      tool_call_id: tool_call_id,
      kind: kind,
      reason: reason,
      stacktrace: stacktrace,
      metadata: metadata
    })
  end

  # =============================================================================
  # Span Helpers
  # =============================================================================

  @doc """
  Execute a function within a run telemetry span.

  Automatically emits `[:swarm_ai, :run, :start/:stop/:exception]` events with timing.

  ## Example

      SwarmAi.Telemetry.run_span(%{loop_id: id, agent_module: MyAgent}, fn ->
        result = do_run()
        {result, %{status: :completed, step_count: 3}}
      end)
  """
  @spec run_span(map(), (-> {term(), map()})) :: term()
  def run_span(metadata, fun) when is_function(fun, 0) do
    :telemetry.span([:swarm_ai, :run], metadata, fun)
  end

  @doc """
  Execute a function within a step telemetry span.

  Automatically emits `[:swarm_ai, :step, :start/:stop/:exception]` events with timing.

  ## Example

      SwarmAi.Telemetry.step_span(%{loop_id: id, step: 1, metadata: %{}}, fn ->
        result = do_step_work()
        {result, %{}}
      end)
  """
  @spec step_span(map(), (-> {term(), map()})) :: term()
  def step_span(metadata, fun) when is_function(fun, 0) do
    :telemetry.span([:swarm_ai, :step], metadata, fun)
  end

  @doc """
  Execute a function within an LLM call telemetry span.

  Automatically emits `[:swarm_ai, :llm, :call, :start/:stop/:exception]` events.

  ## Example

      SwarmAi.Telemetry.llm_span(%{loop_id: id, step: 1, model: "claude"}, fn ->
        response = call_llm()
        {response, %{input_tokens: 100, output_tokens: 50, tool_call_count: 2}}
      end)
  """
  @spec llm_span(map(), (-> {term(), map()})) :: term()
  def llm_span(metadata, fun) when is_function(fun, 0) do
    :telemetry.span([:swarm_ai, :llm, :call], metadata, fun)
  end

  @doc """
  Execute a function within a tool execution telemetry span.

  Automatically emits `[:swarm_ai, :tool, :execute, :start/:stop/:exception]` events.

  ## Example

      SwarmAi.Telemetry.tool_span(%{loop_id: id, step: 1, tool_id: tc.id, tool_name: "search"}, fn ->
        result = execute_tool(tc)
        {result, %{is_error: false}}
      end)
  """
  @spec tool_span(map(), (-> {term(), map()})) :: term()
  def tool_span(metadata, fun) when is_function(fun, 0) do
    :telemetry.span([:swarm_ai, :tool, :execute], metadata, fun)
  end

  @doc """
  Execute a function within a child spawn telemetry span.

  Automatically emits `[:swarm_ai, :child, :spawn, :start/:stop/:exception]` events.

  ## Example

      SwarmAi.Telemetry.child_span(%{parent_loop_id: id, tool_call_id: tc_id, ...}, fn ->
        result = run_child()
        {result, %{child_loop_id: child.id, child_status: :completed, ...}}
      end)
  """
  @spec child_span(map(), (-> {term(), map()})) :: term()
  def child_span(metadata, fun) when is_function(fun, 0) do
    :telemetry.span([:swarm_ai, :child, :spawn], metadata, fun)
  end

  # =============================================================================
  # Default Logger
  # =============================================================================

  @doc """
  Attaches a default logger that logs all Swarm telemetry events.

  Useful for development and debugging. Uses Elixir's Logger.

  ## Options

  - `:level` - Log level (default: `:info`)

  ## Example

      SwarmAi.Telemetry.attach_default_logger()
      SwarmAi.Telemetry.attach_default_logger(level: :debug)
  """
  @spec attach_default_logger(keyword()) :: :ok | {:error, :already_exists}
  def attach_default_logger(opts \\ []) do
    level = Keyword.get(opts, :level, :info)

    :telemetry.attach_many(
      "swarm-default-logger",
      Events.all(),
      &__MODULE__.handle_event/4,
      %{level: level}
    )
  end

  @doc """
  Detaches the default logger.
  """
  @spec detach_default_logger() :: :ok | {:error, :not_found}
  def detach_default_logger do
    :telemetry.detach("swarm-default-logger")
  end

  @doc false
  def handle_event(event, measurements, metadata, config) do
    level = Map.get(config, :level, :info)
    message = format_event(event, measurements, metadata)
    Logger.log(level, message)
  end

  defp format_event([:swarm_ai, :run, :start], _measurements, metadata) do
    "[swarm_ai] run:start loop=#{short_id(metadata.loop_id)} agent=#{inspect(metadata.agent_module)}"
  end

  defp format_event([:swarm_ai, :run, :stop], measurements, metadata) do
    duration = Map.get(measurements, :duration, 0) |> native_to_ms()
    status = format_status(metadata.status)

    "[swarm_ai] run:stop  loop=#{short_id(metadata.loop_id)} #{status} " <>
      "steps=#{metadata.step_count} (#{duration}ms)"
  end

  defp format_event([:swarm_ai, :run, :exception], measurements, metadata) do
    duration = Map.get(measurements, :duration, 0) |> native_to_ms()

    "[swarm_ai] run:exception loop=#{short_id(metadata.loop_id)} " <>
      "#{metadata.kind}: #{inspect(metadata.reason)} (#{duration}ms)"
  end

  defp format_event([:swarm_ai, :step, :start], _measurements, metadata) do
    "[swarm_ai] step:start loop=#{short_id(metadata.loop_id)} step=#{metadata.step}"
  end

  defp format_event([:swarm_ai, :step, :stop], measurements, metadata) do
    duration = Map.get(measurements, :duration, 0) |> native_to_ms()

    "[swarm_ai] step:stop  loop=#{short_id(metadata.loop_id)} step=#{metadata.step} (#{duration}ms)"
  end

  defp format_event([:swarm_ai, :step, :exception], measurements, metadata) do
    duration = Map.get(measurements, :duration, 0) |> native_to_ms()

    "[swarm_ai] step:exception loop=#{short_id(metadata.loop_id)} step=#{metadata.step} " <>
      "#{metadata.kind}: #{inspect(metadata.reason)} (#{duration}ms)"
  end

  defp format_event([:swarm_ai, :llm, :call, :start], _measurements, metadata) do
    "[swarm_ai] llm:start  loop=#{short_id(metadata.loop_id)} step=#{metadata.step} " <>
      "model=#{format_model(metadata.model)}"
  end

  defp format_event([:swarm_ai, :llm, :call, :stop], measurements, metadata) do
    duration = Map.get(measurements, :duration, 0) |> native_to_ms()
    input = Map.get(metadata, :input_tokens, 0)
    output = Map.get(metadata, :output_tokens, 0)
    tools = Map.get(metadata, :tool_call_count, 0)

    "[swarm_ai] llm:stop   loop=#{short_id(metadata.loop_id)} step=#{metadata.step} " <>
      "(#{duration}ms) [#{input} in / #{output} out] tools=#{tools}"
  end

  defp format_event([:swarm_ai, :llm, :call, :exception], measurements, metadata) do
    duration = Map.get(measurements, :duration, 0) |> native_to_ms()

    "[swarm_ai] llm:exception loop=#{short_id(metadata.loop_id)} step=#{metadata.step} " <>
      "#{metadata.kind}: #{inspect(metadata.reason)} (#{duration}ms)"
  end

  defp format_event([:swarm_ai, :tool, :execute, :start], _measurements, metadata) do
    "[swarm_ai] tool:start loop=#{short_id(metadata.loop_id)} step=#{metadata.step} #{metadata.tool_name}"
  end

  defp format_event([:swarm_ai, :tool, :execute, :stop], measurements, metadata) do
    duration = Map.get(measurements, :duration, 0) |> native_to_ms()
    status = if metadata.is_error, do: "✗", else: "✓"

    "[swarm_ai] tool:stop  loop=#{short_id(metadata.loop_id)} #{metadata.tool_name} #{status} (#{duration}ms)"
  end

  defp format_event([:swarm_ai, :tool, :execute, :exception], measurements, metadata) do
    duration = Map.get(measurements, :duration, 0) |> native_to_ms()

    "[swarm_ai] tool:exception loop=#{short_id(metadata.loop_id)} #{metadata.tool_name} " <>
      "#{metadata.kind}: #{inspect(metadata.reason)} (#{duration}ms)"
  end

  defp format_event([:swarm_ai, :child, :spawn, :start], _measurements, metadata) do
    task_preview = String.slice(metadata.task || "", 0, 50)

    "[swarm_ai] child:start parent=#{short_id(metadata.parent_loop_id)} " <>
      "agent=#{inspect(metadata.child_agent_module)} task=\"#{task_preview}...\""
  end

  defp format_event([:swarm_ai, :child, :spawn, :stop], measurements, metadata) do
    duration = Map.get(measurements, :duration, 0) |> native_to_ms()
    status = format_status(metadata.child_status)

    "[swarm_ai] child:stop  parent=#{short_id(metadata.parent_loop_id)} " <>
      "child=#{short_id(metadata.child_loop_id)} #{status} " <>
      "steps=#{metadata.child_step_count} tokens=#{metadata.child_total_tokens} (#{duration}ms)"
  end

  defp format_event([:swarm_ai, :child, :spawn, :exception], measurements, metadata) do
    duration = Map.get(measurements, :duration, 0) |> native_to_ms()

    "[swarm_ai] child:exception parent=#{short_id(metadata.parent_loop_id)} " <>
      "#{metadata.kind}: #{inspect(metadata.reason)} (#{duration}ms)"
  end

  defp format_event(event, _measurements, _metadata) do
    "[swarm_ai] #{inspect(event)}"
  end

  # =============================================================================
  # Private Helpers
  # =============================================================================

  defp emit(event, metadata) do
    :telemetry.execute(event, %{system_time: System.system_time()}, metadata)
  end

  defp short_id(id) when is_binary(id), do: String.slice(id, 0, 8)
  defp short_id(id), do: inspect(id)

  # Format model for telemetry logging - handles both string models and LLMDB.Model structs
  defp format_model(nil), do: "unknown"
  defp format_model(model) when is_binary(model), do: model
  defp format_model(%{id: id}) when is_binary(id), do: id
  defp format_model(model), do: inspect(model)

  defp format_status(:ok), do: "✓"
  defp format_status(:completed), do: "✓"
  defp format_status(:error), do: "✗"
  defp format_status(:failed), do: "✗"
  defp format_status(status), do: "#{status}"

  defp native_to_ms(native) when is_integer(native) do
    System.convert_time_unit(native, :native, :millisecond)
  end

  defp native_to_ms(_), do: 0
end
