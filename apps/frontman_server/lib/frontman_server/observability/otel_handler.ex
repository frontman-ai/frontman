defmodule FrontmanServer.Observability.OtelHandler do
  @moduledoc """
  Telemetry handler that creates OpenTelemetry spans for FrontmanServer-specific events.

  Handles task-level spans. Agent execution spans (loop, step, llm, tool, child)
  are handled by SwarmOtelHandler which subscribes to Swarm telemetry events.
  """

  require Logger
  require OpenTelemetry.Tracer, as: Tracer

  alias FrontmanServer.Observability.Events

  @tables [
    :frontman_spans_task
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
      {Events.task_stop(), &__MODULE__.handle_task_stop/4}
    ]

    Enum.each(handlers, fn {event, handler} ->
      handler_id = "frontman_otel_#{Enum.join(event, "_")}"
      :telemetry.attach(handler_id, event, handler, nil)
    end)
  end

  # -- Task Handlers --
  # These handlers are public for telemetry registration but are not part of the public API.

  @doc false
  def handle_task_start(
        _event,
        _measurements,
        %{task_id: task_id},
        _config
      ) do
    span_name = "task"

    attributes = [
      {:"openinference.span.kind", "CHAIN"},
      {:"session.id", task_id},
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
        Logger.warning(
          "Orphaned task stop event: task_id=#{task_id} has no span. Start event missing?"
        )
    end
  end

  # -- Helpers --

  defp deployment_environment do
    case Application.get_env(:opentelemetry, :resource) do
      %{deployment: %{environment: env}} -> env
      _ -> "unknown"
    end
  end
end
