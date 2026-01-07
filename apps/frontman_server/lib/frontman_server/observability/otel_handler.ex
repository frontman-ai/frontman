defmodule FrontmanServer.Observability.OtelHandler do
  @moduledoc """
  Telemetry handler that creates OpenTelemetry spans for FrontmanServer-specific events.

  Handles task-level and MCP tool spans. Agent execution spans (loop, step, llm, tool, child)
  are handled by SwarmOtelHandler which subscribes to Swarm telemetry events.

  ## Span Hierarchy (FrontmanServer portion)

  ```
  task [top-level container for session]
  └── mcp_tool [client-side tool execution]
  ```

  Agent/loop hierarchy is handled by SwarmOtelHandler.
  """

  require Logger
  require OpenTelemetry.Tracer, as: Tracer

  alias FrontmanServer.Observability.Events

  @tables [
    :frontman_spans_task,
    :frontman_spans_mcp
  ]

  @doc """
  Sets up telemetry handlers and creates ETS tables for span storage.

  Call this early in application startup.
  """
  def setup do
    create_ets_tables()
    attach_handlers()
    :ok
  end

  # No defensive checks - if tables already exist, setup/0 was called twice,
  # which is a bug in application startup. Let it crash.
  defp create_ets_tables do
    Enum.each(@tables, fn table ->
      :ets.new(table, [:named_table, :public, :set, read_concurrency: true])
    end)
  end

  defp attach_handlers do
    handlers = [
      {Events.task_start(), &__MODULE__.handle_task_start/4},
      {Events.task_stop(), &__MODULE__.handle_task_stop/4},
      {Events.mcp_tool_start(), &__MODULE__.handle_mcp_tool_start/4},
      {Events.mcp_tool_stop(), &__MODULE__.handle_mcp_tool_stop/4}
    ]

    Enum.each(handlers, fn {event, handler} ->
      handler_id = "frontman_otel_#{Enum.join(event, "_")}"
      :telemetry.attach(handler_id, event, handler, nil)
    end)
  end

  # -- Task Handlers --
  # These handlers are public for telemetry registration but are not part of the public API.

  @doc false
  def handle_task_start(_event, _measurements, %{task_id: task_id}, _config) do
    span_name = "task"

    attributes = [
      {:"frontman.task.id", task_id},
      {:"gen_ai.operation.name", "task"},
      {:"deployment.environment", deployment_environment()}
    ]

    tracer = :opentelemetry.get_tracer(:frontman_server)
    ctx = :otel_ctx.get_current()

    span_ctx = :otel_tracer.start_span(ctx, tracer, span_name, %{attributes: attributes})
    :otel_tracer.set_current_span(ctx, span_ctx)
    :ets.insert(:frontman_spans_task, {task_id, span_ctx})
  end

  @doc false
  def handle_task_stop(_event, _measurements, %{task_id: task_id}, _config) do
    case :ets.lookup(:frontman_spans_task, task_id) do
      [{^task_id, span_ctx}] ->
        Tracer.set_current_span(span_ctx)
        Tracer.end_span()
        :ets.delete(:frontman_spans_task, task_id)

      [] ->
        Logger.error(
          "Orphaned task stop event: task_id=#{task_id} has no span. Start event missing?"
        )
    end
  end

  # -- MCP Tool Handlers --

  @doc false
  def handle_mcp_tool_start(_event, _measurements, metadata, _config) do
    %{
      request_id: request_id,
      tool_call_id: tool_call_id,
      tool_name: tool_name,
      task_id: task_id,
      arguments: arguments
    } = metadata

    # Optional loop context for proper parenting under step
    loop_id = Map.get(metadata, :loop_id)
    step = Map.get(metadata, :step)

    span_name = "mcp_tool #{tool_name}"

    attributes = [
      {:"gen_ai.tool.name", tool_name},
      {:"gen_ai.tool.call.id", tool_call_id},
      {:"gen_ai.tool.type", "function"},
      {:"frontman.tool.type", "mcp"},
      {:"frontman.mcp.request_id", request_id},
      {:"frontman.task.id", task_id},
      {:"gen_ai.tool.arguments", Jason.encode!(arguments)}
    ]

    tracer = :opentelemetry.get_tracer(:frontman_server)

    # Parent MCP tool under step span if loop context is available,
    # otherwise fall back to task span
    ctx = with_parent_span(loop_id, step, task_id)

    span_ctx = :otel_tracer.start_span(ctx, tracer, span_name, %{attributes: attributes})
    :otel_span.add_event(span_ctx, "mcp.request_sent", [])

    start_time = System.monotonic_time(:millisecond)
    :ets.insert(:frontman_spans_mcp, {request_id, {span_ctx, start_time}})
  end

  @doc false
  def handle_mcp_tool_stop(_event, _measurements, metadata, _config) do
    %{request_id: request_id, status: status} = metadata

    case :ets.lookup(:frontman_spans_mcp, request_id) do
      [{^request_id, {span_ctx, start_time}}] ->
        duration = System.monotonic_time(:millisecond) - start_time

        :otel_span.add_event(span_ctx, "mcp.response_received", [])

        :otel_span.set_attributes(span_ctx, [
          {:"tool.duration_ms", duration},
          {:"tool.status", status}
        ])

        set_tool_error_status(span_ctx, metadata[:error])

        :otel_span.end_span(span_ctx)
        :ets.delete(:frontman_spans_mcp, request_id)

      [] ->
        Logger.error("Orphaned MCP tool stop event: request_id=#{request_id} has no span")
    end
  end

  # -- Helpers --

  # Look up parent span for MCP tools with fallback chain:
  # 1. If loop_id and step provided -> parent under step span
  # 2. Otherwise if task_id provided -> parent under task span
  # 3. Otherwise -> use current context (root span)
  defp with_parent_span(loop_id, step, task_id) when not is_nil(loop_id) and not is_nil(step) do
    case :ets.lookup(:frontman_spans_swarm_step, {loop_id, step}) do
      [{_key, parent_span}] ->
        ctx = :otel_ctx.new()
        :otel_tracer.set_current_span(ctx, parent_span)

      [] ->
        # Step not found, fall back to task
        with_parent_span(nil, nil, task_id)
    end
  end

  defp with_parent_span(_loop_id, _step, task_id) when not is_nil(task_id) do
    case :ets.lookup(:frontman_spans_task, task_id) do
      [{^task_id, parent_span}] ->
        ctx = :otel_ctx.new()
        :otel_tracer.set_current_span(ctx, parent_span)

      [] ->
        # Task not found, use current context
        :otel_ctx.get_current()
    end
  end

  defp with_parent_span(_loop_id, _step, _task_id) do
    :otel_ctx.get_current()
  end

  defp set_tool_error_status(_span_ctx, nil), do: :ok

  defp set_tool_error_status(span_ctx, error) do
    error_str = inspect(error)
    :otel_span.set_attributes(span_ctx, [{:"tool.error", error_str}])
    :otel_span.set_status(span_ctx, :error, error_str)
  end

  defp deployment_environment do
    case Application.get_env(:opentelemetry, :resource) do
      %{deployment: %{environment: env}} -> env
      _ -> "unknown"
    end
  end
end
