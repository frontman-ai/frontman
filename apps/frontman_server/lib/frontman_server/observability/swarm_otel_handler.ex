defmodule FrontmanServer.Observability.SwarmOtelHandler do
  @moduledoc """
  Creates OpenTelemetry spans from Swarm telemetry events.

  Swarm emits telemetry events for agent execution (loop, step, llm, tool, child).
  This handler translates those into OTEL spans with proper parent-child relationships.

  The `task_id` comes from `loop.metadata` which is passed by FrontmanServer when
  starting agent execution. This allows correlation back to the task span.

  ## Span Hierarchy

  ```
  task [created by OtelHandler]
  └── loop [swarm:run]
      └── step 1 [swarm:step]
          ├── llm call [swarm:llm:call]
          ├── tool execution [swarm:tool:execute]
          └── child spawn [swarm:child:spawn]
              └── child loop [nested swarm:run]
      └── step 2
          └── llm call
  ```

  ## ETS Tables

  Uses same tables as OtelHandler for task span lookup:
  - `:frontman_spans_task` - task spans keyed by task_id

  Creates additional tables for Swarm spans:
  - `:frontman_spans_loop` - loop spans keyed by loop_id
  - `:frontman_spans_swarm_step` - step spans keyed by {loop_id, step}
  """

  require Logger

  @tables [
    :frontman_spans_loop,
    :frontman_spans_swarm_step,
    :frontman_spans_llm,
    :frontman_spans_tool,
    :frontman_spans_spawn
  ]

  @doc """
  Sets up telemetry handlers and creates ETS tables.
  Call this after OtelHandler.setup/0 in application startup.
  """
  def setup do
    create_ets_tables()
    attach_handlers()
    :ok
  end

  defp create_ets_tables do
    Enum.each(@tables, fn table ->
      :ets.new(table, [:named_table, :public, :set, read_concurrency: true])
    end)
  end

  defp attach_handlers do
    handlers = [
      # Run (loop) events
      {[:swarm, :run, :start], &__MODULE__.handle_run_start/4},
      {[:swarm, :run, :stop], &__MODULE__.handle_run_stop/4},
      {[:swarm, :run, :exception], &__MODULE__.handle_run_exception/4},
      # Step events
      {[:swarm, :step, :start], &__MODULE__.handle_step_start/4},
      {[:swarm, :step, :stop], &__MODULE__.handle_step_stop/4},
      {[:swarm, :step, :exception], &__MODULE__.handle_step_exception/4},
      # LLM events
      {[:swarm, :llm, :call, :start], &__MODULE__.handle_llm_start/4},
      {[:swarm, :llm, :call, :stop], &__MODULE__.handle_llm_stop/4},
      {[:swarm, :llm, :call, :exception], &__MODULE__.handle_llm_exception/4},
      # Tool events
      {[:swarm, :tool, :execute, :start], &__MODULE__.handle_tool_start/4},
      {[:swarm, :tool, :execute, :stop], &__MODULE__.handle_tool_stop/4},
      {[:swarm, :tool, :execute, :exception], &__MODULE__.handle_tool_exception/4},
      # Child spawn events
      {[:swarm, :child, :spawn, :start], &__MODULE__.handle_child_start/4},
      {[:swarm, :child, :spawn, :stop], &__MODULE__.handle_child_stop/4},
      {[:swarm, :child, :spawn, :exception], &__MODULE__.handle_child_exception/4}
    ]

    Enum.each(handlers, fn {event, handler} ->
      handler_id = "swarm_otel_#{Enum.join(event, "_")}"
      :telemetry.attach(handler_id, event, handler, nil)
    end)
  end

  # =============================================================================
  # Run (Loop) Handlers
  # =============================================================================

  @doc false
  def handle_run_start(_event, _measurements, metadata, _config) do
    loop_id = metadata.loop_id
    agent_module = metadata.agent_module
    loop_meta = Map.get(metadata, :metadata, %{})
    task_id = Map.get(loop_meta, :task_id)
    input_messages = Map.get(metadata, :input_messages, [])

    span_name = "loop"

    attributes = [
      {:"gen_ai.operation.name", "loop"},
      {:"swarm.loop.id", loop_id},
      {:"swarm.agent.module", inspect(agent_module)},
      {:"frontman.task.id", task_id},
      {:"gen_ai.prompt", format_messages_for_span(input_messages)}
    ]

    tracer = :opentelemetry.get_tracer(:frontman_server)
    # Parent loop span under task span (looked up from ETS)
    ctx = with_parent_span(:frontman_spans_task, task_id)

    span_ctx = :otel_tracer.start_span(ctx, tracer, span_name, %{attributes: attributes})
    :otel_tracer.set_current_span(ctx, span_ctx)
    store_span(:frontman_spans_loop, loop_id, span_ctx)
  end

  @doc false
  def handle_run_stop(_event, measurements, metadata, _config) do
    loop_id = metadata.loop_id
    status = Map.get(metadata, :status, :unknown)
    step_count = Map.get(metadata, :step_count, 0)
    output = Map.get(metadata, :output)

    case lookup_span(:frontman_spans_loop, loop_id) do
      {:ok, span_ctx} ->
        attributes = [
          {:"swarm.loop.status", to_string(status)},
          {:"swarm.loop.step_count", step_count}
        ]

        # Add output if present
        attributes =
          if output do
            [{:"gen_ai.completion", truncate(to_string(output), 10_000)} | attributes]
          else
            attributes
          end

        :otel_span.set_attributes(span_ctx, attributes)

        add_duration_event(span_ctx, measurements)
        :otel_span.end_span(span_ctx)
        delete_span(:frontman_spans_loop, loop_id)

      :not_found ->
        Logger.warning("Orphaned loop stop event: loop_id=#{loop_id} has no span")
    end
  end

  @doc false
  def handle_run_exception(_event, _measurements, metadata, _config) do
    loop_id = metadata.loop_id

    case lookup_span(:frontman_spans_loop, loop_id) do
      {:ok, span_ctx} ->
        reason = inspect(metadata[:reason] || "unknown")
        :otel_span.set_status(span_ctx, :error, "Exception: #{reason}")
        :otel_span.end_span(span_ctx)
        delete_span(:frontman_spans_loop, loop_id)

      :not_found ->
        :ok
    end
  end

  # =============================================================================
  # Step Handlers
  # =============================================================================

  @doc false
  def handle_step_start(_event, _measurements, metadata, _config) do
    %{loop_id: loop_id, step: step} = metadata
    loop_meta = Map.get(metadata, :metadata, %{})
    task_id = Map.get(loop_meta, :task_id)

    span_name = "step #{step}"

    attributes = [
      {:"gen_ai.operation.name", "step"},
      {:"swarm.loop.id", loop_id},
      {:"swarm.step.number", step},
      {:"frontman.task.id", task_id}
    ]

    tracer = :opentelemetry.get_tracer(:frontman_server)
    # Parent step span under loop span
    ctx = with_parent_span(:frontman_spans_loop, loop_id)

    span_ctx = :otel_tracer.start_span(ctx, tracer, span_name, %{attributes: attributes})
    :otel_tracer.set_current_span(ctx, span_ctx)
    store_span(:frontman_spans_swarm_step, {loop_id, step}, span_ctx)
  end

  @doc false
  def handle_step_stop(_event, measurements, metadata, _config) do
    %{loop_id: loop_id, step: step} = metadata
    key = {loop_id, step}

    case lookup_span(:frontman_spans_swarm_step, key) do
      {:ok, span_ctx} ->
        add_duration_event(span_ctx, measurements)
        :otel_span.end_span(span_ctx)
        delete_span(:frontman_spans_swarm_step, key)

      :not_found ->
        Logger.warning("Orphaned step stop event: loop_id=#{loop_id} step=#{step} has no span")
    end
  end

  @doc false
  def handle_step_exception(_event, _measurements, metadata, _config) do
    loop_id = metadata.loop_id
    step = metadata.step
    key = {loop_id, step}

    case lookup_span(:frontman_spans_swarm_step, key) do
      {:ok, span_ctx} ->
        reason = inspect(metadata[:reason] || "unknown")
        :otel_span.set_status(span_ctx, :error, "Exception: #{reason}")
        :otel_span.end_span(span_ctx)
        delete_span(:frontman_spans_swarm_step, key)

      :not_found ->
        :ok
    end
  end

  # =============================================================================
  # LLM Handlers
  # =============================================================================

  @doc false
  def handle_llm_start(_event, _measurements, metadata, _config) do
    %{loop_id: loop_id, step: step, model: model} = metadata
    loop_meta = Map.get(metadata, :metadata, %{})
    task_id = Map.get(loop_meta, :task_id)

    span_name = "chat #{model}"

    attributes = [
      {:"gen_ai.operation.name", "chat"},
      {:"gen_ai.request.model", model},
      {:"gen_ai.system", llm_system_from_model(model)},
      {:"swarm.loop.id", loop_id},
      {:"swarm.step.number", step},
      {:"frontman.task.id", task_id}
    ]

    tracer = :opentelemetry.get_tracer(:frontman_server)
    # Parent LLM span under step span
    ctx = with_parent_span(:frontman_spans_swarm_step, {loop_id, step})

    span_ctx = :otel_tracer.start_span(ctx, tracer, span_name, %{attributes: attributes})
    :otel_tracer.set_current_span(ctx, span_ctx)
    store_span(:frontman_spans_llm, {loop_id, step}, span_ctx)
  end

  @doc false
  def handle_llm_stop(_event, measurements, metadata, _config) do
    %{loop_id: loop_id, step: step} = metadata
    key = {loop_id, step}

    case lookup_span(:frontman_spans_llm, key) do
      {:ok, span_ctx} ->
        # Add usage metrics
        if usage = metadata[:usage] do
          :otel_span.set_attributes(span_ctx, [
            {:"gen_ai.usage.input_tokens", Map.get(usage, :input_tokens, 0)},
            {:"gen_ai.usage.output_tokens", Map.get(usage, :output_tokens, 0)}
          ])
        end

        if tool_call_count = metadata[:tool_call_count] do
          :otel_span.set_attributes(span_ctx, [{:"gen_ai.tool_call_count", tool_call_count}])
        end

        add_duration_event(span_ctx, measurements)
        :otel_span.end_span(span_ctx)
        delete_span(:frontman_spans_llm, key)

      :not_found ->
        Logger.warning("Orphaned LLM stop event: loop_id=#{loop_id} step=#{step} has no span")
    end
  end

  @doc false
  def handle_llm_exception(_event, _measurements, metadata, _config) do
    loop_id = metadata.loop_id
    step = metadata.step
    key = {loop_id, step}

    case lookup_span(:frontman_spans_llm, key) do
      {:ok, span_ctx} ->
        reason = inspect(metadata[:reason] || "unknown")
        :otel_span.set_status(span_ctx, :error, "LLM exception: #{reason}")
        :otel_span.end_span(span_ctx)
        delete_span(:frontman_spans_llm, key)

      :not_found ->
        :ok
    end
  end

  # =============================================================================
  # Tool Handlers
  # =============================================================================

  @doc false
  def handle_tool_start(_event, _measurements, metadata, _config) do
    %{loop_id: loop_id, step: step, tool_id: tool_id, tool_name: tool_name} = metadata
    loop_meta = Map.get(metadata, :metadata, %{})
    task_id = Map.get(loop_meta, :task_id)

    span_name = "tool #{tool_name}"

    attributes = [
      {:"gen_ai.operation.name", "tool"},
      {:"gen_ai.tool.name", tool_name},
      {:"gen_ai.tool.call.id", tool_id},
      {:"swarm.loop.id", loop_id},
      {:"swarm.step.number", step},
      {:"frontman.task.id", task_id}
    ]

    tracer = :opentelemetry.get_tracer(:frontman_server)
    # Parent tool span under step span
    ctx = with_parent_span(:frontman_spans_swarm_step, {loop_id, step})

    span_ctx = :otel_tracer.start_span(ctx, tracer, span_name, %{attributes: attributes})
    :otel_tracer.set_current_span(ctx, span_ctx)
    store_span(:frontman_spans_tool, tool_id, span_ctx)
  end

  @doc false
  def handle_tool_stop(_event, measurements, metadata, _config) do
    tool_id = metadata.tool_id
    is_error = Map.get(metadata, :is_error, false)

    case lookup_span(:frontman_spans_tool, tool_id) do
      {:ok, span_ctx} ->
        if is_error do
          :otel_span.set_status(span_ctx, :error, "Tool returned error")
        end

        add_duration_event(span_ctx, measurements)
        :otel_span.end_span(span_ctx)
        delete_span(:frontman_spans_tool, tool_id)

      :not_found ->
        Logger.warning("Orphaned tool stop event: tool_id=#{tool_id} has no span")
    end
  end

  @doc false
  def handle_tool_exception(_event, _measurements, metadata, _config) do
    tool_id = metadata.tool_id

    case lookup_span(:frontman_spans_tool, tool_id) do
      {:ok, span_ctx} ->
        reason = inspect(metadata[:reason] || "unknown")
        :otel_span.set_status(span_ctx, :error, "Tool exception: #{reason}")
        :otel_span.end_span(span_ctx)
        delete_span(:frontman_spans_tool, tool_id)

      :not_found ->
        :ok
    end
  end

  # =============================================================================
  # Child Spawn Handlers
  # =============================================================================

  @doc false
  def handle_child_start(_event, _measurements, metadata, _config) do
    %{
      parent_loop_id: parent_loop_id,
      parent_step: parent_step,
      tool_call_id: tool_call_id,
      task: task
    } = metadata

    loop_meta = Map.get(metadata, :metadata, %{})
    task_id = Map.get(loop_meta, :task_id)

    span_name = "spawn_child"

    attributes = [
      {:"gen_ai.operation.name", "spawn_child"},
      {:"swarm.parent.loop_id", parent_loop_id},
      {:"swarm.parent.step", parent_step},
      {:"swarm.tool_call_id", tool_call_id},
      {:"swarm.child.task", truncate(task, 200)},
      {:"frontman.task.id", task_id}
    ]

    tracer = :opentelemetry.get_tracer(:frontman_server)
    # Parent child spawn under step span of the parent loop
    ctx = with_parent_span(:frontman_spans_swarm_step, {parent_loop_id, parent_step})

    span_ctx = :otel_tracer.start_span(ctx, tracer, span_name, %{attributes: attributes})
    :otel_tracer.set_current_span(ctx, span_ctx)
    store_span(:frontman_spans_spawn, tool_call_id, span_ctx)
  end

  @doc false
  def handle_child_stop(_event, measurements, metadata, _config) do
    tool_call_id = metadata.tool_call_id
    child_status = Map.get(metadata, :child_status, :unknown)
    child_step_count = Map.get(metadata, :child_step_count, 0)

    case lookup_span(:frontman_spans_spawn, tool_call_id) do
      {:ok, span_ctx} ->
        :otel_span.set_attributes(span_ctx, [
          {:"swarm.child.status", to_string(child_status)},
          {:"swarm.child.step_count", child_step_count}
        ])

        if child_loop_id = metadata[:child_loop_id] do
          :otel_span.set_attributes(span_ctx, [{:"swarm.child.loop_id", child_loop_id}])
        end

        add_duration_event(span_ctx, measurements)
        :otel_span.end_span(span_ctx)
        delete_span(:frontman_spans_spawn, tool_call_id)

      :not_found ->
        Logger.warning("Orphaned child stop event: tool_call_id=#{tool_call_id} has no span")
    end
  end

  @doc false
  def handle_child_exception(_event, _measurements, metadata, _config) do
    tool_call_id = metadata.tool_call_id

    case lookup_span(:frontman_spans_spawn, tool_call_id) do
      {:ok, span_ctx} ->
        reason = inspect(metadata[:reason] || "unknown")
        :otel_span.set_status(span_ctx, :error, "Child exception: #{reason}")
        :otel_span.end_span(span_ctx)
        delete_span(:frontman_spans_spawn, tool_call_id)

      :not_found ->
        :ok
    end
  end

  # =============================================================================
  # Helpers
  # =============================================================================

  # Look up parent span from ETS and create context with it as current span.
  # This enables proper parent-child relationships across processes.
  defp with_parent_span(table, key) do
    case :ets.lookup(table, key) do
      [{^key, parent_span}] ->
        # Create a fresh context and set the parent span as current
        ctx = :otel_ctx.new()
        :otel_tracer.set_current_span(ctx, parent_span)

      [] ->
        # No parent found, use current context (will be root span)
        :otel_ctx.get_current()
    end
  end

  defp store_span(table, key, span_ctx) do
    :ets.insert(table, {key, span_ctx})
  end

  defp lookup_span(table, key) do
    case :ets.lookup(table, key) do
      [{^key, span_ctx}] -> {:ok, span_ctx}
      [] -> :not_found
    end
  end

  defp delete_span(table, key) do
    :ets.delete(table, key)
  end

  defp add_duration_event(span_ctx, measurements) do
    if duration = measurements[:duration] do
      duration_ms = System.convert_time_unit(duration, :native, :millisecond)
      :otel_span.add_event(span_ctx, "completed", [{:duration_ms, duration_ms}])
    end
  end

  defp llm_system_from_model(model) when is_binary(model) do
    cond do
      String.contains?(model, "claude") -> "anthropic"
      String.contains?(model, "gpt") -> "openai"
      String.contains?(model, "gemini") -> "google"
      true -> "unknown"
    end
  end

  defp llm_system_from_model(_), do: "unknown"

  defp truncate(string, max_length) when is_binary(string) do
    if String.length(string) > max_length do
      String.slice(string, 0, max_length) <> "..."
    else
      string
    end
  end

  defp truncate(other, _), do: inspect(other)

  # Format messages for span attribute - extract user content for readability
  defp format_messages_for_span(messages) when is_list(messages) do
    messages
    |> Enum.filter(&match?(%{role: :user}, &1))
    |> Enum.flat_map(fn msg -> msg.content end)
    |> Enum.filter(&match?(%{type: :text}, &1))
    |> Enum.map_join("\n", & &1.text)
    |> truncate(10_000)
  end

  defp format_messages_for_span(_), do: ""
end
