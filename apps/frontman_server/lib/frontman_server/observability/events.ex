defmodule FrontmanServer.Observability.Events do
  @moduledoc """
  Telemetry event name definitions for FrontmanServer.

  Single source of truth for event names used by TelemetryEvents (emitter)
  and OtelHandler (consumer).

  Note: Agent execution events (loop, step, llm, tool, child) are defined
  in Swarm.Telemetry.Events and handled by SwarmOtelHandler.
  """

  @prefix [:frontman]

  # Task
  def task_start, do: @prefix ++ [:task, :start]
  def task_stop, do: @prefix ++ [:task, :stop]
end
