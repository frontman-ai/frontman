defmodule SwarmAi.Telemetry do
  @moduledoc """
  Telemetry instrumentation for SwarmAi executions.

  Events use the `[:swarm_ai, ...]` prefix and the start/stop/exception shape.
  Run metadata identifies the run by `loop_id`, `task_id`, and `turn_number`.
  Dispatcher context is not copied into telemetry.

      :telemetry.attach_many(
        "my-swarm-handler",
        SwarmAi.Telemetry.Events.all(),
        &MyHandler.handle_event/4,
        nil
      )

  Run events carry `loop_id`, `task_id`, `turn_number`, `status`,
  `step_count`, `result`, `error`, and `output` as applicable.
  Step, LLM, and tool events carry `loop_id`, `step`, and their local fields.
  """

  require Logger
  alias SwarmAi.Telemetry.Events

  @doc "Emit run start event."
  @spec run_start(String.t(), String.t(), pos_integer()) :: :ok
  def run_start(loop_id, task_id, turn_number) do
    emit(Events.run_start(), %{
      loop_id: loop_id,
      task_id: task_id,
      turn_number: turn_number
    })
  end

  @doc "Emit run stop event."
  @spec run_stop(String.t(), keyword()) :: :ok
  def run_stop(loop_id, opts \\ []) do
    emit(Events.run_stop(), %{
      loop_id: loop_id,
      task_id: Keyword.get(opts, :task_id),
      turn_number: Keyword.get(opts, :turn_number),
      status: Keyword.get(opts, :status),
      result: Keyword.get(opts, :result),
      error: Keyword.get(opts, :error),
      step_count: Keyword.get(opts, :step_count, 0)
    })
  end

  @doc "Emit run exception event."
  @spec run_exception(String.t(), atom(), term(), list(), keyword()) :: :ok
  def run_exception(loop_id, kind, reason, stacktrace, opts \\ []) do
    emit(Events.run_exception(), %{
      loop_id: loop_id,
      task_id: Keyword.get(opts, :task_id),
      turn_number: Keyword.get(opts, :turn_number),
      kind: kind,
      reason: reason,
      stacktrace: stacktrace
    })
  end

  @doc "Emit step start event."
  def step_start(loop_id, step) do
    emit(Events.step_start(), %{
      loop_id: loop_id,
      step: step
    })
  end

  @doc "Emit step stop event."
  def step_stop(loop_id, step) do
    emit(Events.step_stop(), %{
      loop_id: loop_id,
      step: step
    })
  end

  @doc "Emit step exception event."
  def step_exception(loop_id, step, kind, reason, stacktrace) do
    emit(Events.step_exception(), %{
      loop_id: loop_id,
      step: step,
      kind: kind,
      reason: reason,
      stacktrace: stacktrace
    })
  end

  @doc "Emit LLM call start event."
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
      reasoning_tokens: Keyword.get(opts, :reasoning_tokens, 0),
      cached_tokens: Keyword.get(opts, :cached_tokens, 0),
      tool_call_count: Keyword.get(opts, :tool_call_count, 0)
    })
  end

  @doc "Emit LLM call exception event."
  def llm_call_exception(loop_id, step, kind, reason, stacktrace) do
    emit(Events.llm_call_exception(), %{
      loop_id: loop_id,
      step: step,
      kind: kind,
      reason: reason,
      stacktrace: stacktrace
    })
  end

  @doc "Emit tool execution start event."
  def tool_execute_start(loop_id, step, tool_id, tool_name) do
    emit(Events.tool_execute_start(), %{
      loop_id: loop_id,
      step: step,
      tool_id: tool_id,
      tool_name: tool_name
    })
  end

  @doc "Emit tool execution stop event."
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
  def tool_execute_exception(
        loop_id,
        step,
        tool_id,
        tool_name,
        kind,
        reason,
        stacktrace
      ) do
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

  @doc """
  Execute a function within a run telemetry span.

  Automatically emits `[:swarm_ai, :run, :start/:stop/:exception]` events with timing.

  ## Example

        SwarmAi.Telemetry.run_span(%{loop_id: id, task_id: task_id, turn_number: 1}, fn ->
          result = do_run()
          {result, %{loop_id: id, task_id: task_id, turn_number: 1, status: :completed, step_count: 3}}
        end)
  """
  def run_span(%{} = metadata, fun) when is_function(fun, 0) do
    :telemetry.span([:swarm_ai, :run], metadata, fun)
  end

  @doc """
  Execute a function within a step telemetry span.

  Automatically emits `[:swarm_ai, :step, :start/:stop/:exception]` events with timing.

  ## Example

      SwarmAi.Telemetry.step_span(%{loop_id: id, step: 1}, fn ->
        result = do_step_work()
        {result, %{}}
      end)
  """
  def step_span(%{} = metadata, fun) when is_function(fun, 0) do
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
  def llm_span(%{} = metadata, fun) when is_function(fun, 0) do
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
  def tool_span(metadata, fun) when is_function(fun, 0) do
    :telemetry.span([:swarm_ai, :tool, :execute], metadata, fun)
  end

  @doc """
  Attaches a default logger that logs all Swarm telemetry events.

  Useful for development and debugging. Uses Elixir's Logger.

  ## Options

  - `:level` - Log level (default: `:info`)

  ## Example

      SwarmAi.Telemetry.attach_default_logger()
      SwarmAi.Telemetry.attach_default_logger(level: :debug)
  """
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
    "[swarm_ai] run:start loop=#{short_id(metadata.loop_id)} task=#{short_id(metadata.task_id)} turn=#{metadata.turn_number}"
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

  defp format_event(event, _measurements, _metadata) do
    "[swarm_ai] #{inspect(event)}"
  end

  defp emit(event, metadata) do
    :telemetry.execute(event, %{system_time: System.system_time()}, metadata)
  end

  defp short_id(id) when is_binary(id), do: String.slice(id, 0, 8)
  defp short_id(id), do: inspect(id)

  # Handles both string models and LLMDB.Model structs.
  defp format_model(nil), do: "unknown"
  defp format_model(model) when is_binary(model), do: model
  defp format_model(%{id: id}) when is_binary(id), do: id
  defp format_model(model), do: inspect(model)

  defp format_status(:ok), do: "✓"
  defp format_status(:completed), do: "✓"
  defp format_status({:failed, _reason}), do: "✗"
  defp format_status({:paused, _reason}), do: "⏸"
  defp format_status(:error), do: "✗"
  defp format_status(:failed), do: "✗"
  defp format_status(status), do: inspect(status)

  defp native_to_ms(native) when is_integer(native) do
    System.convert_time_unit(native, :native, :millisecond)
  end

  defp native_to_ms(_), do: 0
end
