defmodule FrontmanServer.Observability.TelemetryEvents do
  @moduledoc """
  Clean API for domain code to emit observability events.

  Domain modules call these functions to emit semantic events.
  The OtelHandler (or other handlers) translates these to spans/metrics.

  No OpenTelemetry imports here - this is pure domain event emission.

  ## Span Hierarchy

  FrontmanServer emits task events. Agent execution events (loop, step, llm, tool, child)
  are emitted by Swarm and handled by SwarmOtelHandler.
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
  # Private
  # ============================================================================

  defp emit(event, metadata) do
    :telemetry.execute(event, %{system_time: System.system_time()}, metadata)
  end
end
