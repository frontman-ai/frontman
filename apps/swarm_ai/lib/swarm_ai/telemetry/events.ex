defmodule SwarmAi.Telemetry.Events do
  @moduledoc """
  Telemetry event name definitions for Swarm.

  Single source of truth for event names used by `SwarmAi.Telemetry` (emitter)
  and any handlers that consume these events.

  ## Event Hierarchy

  ```
  [:swarm_ai, :run, :start/:stop/:exception]
  └── [:swarm_ai, :step, :start/:stop/:exception]
      ├── [:swarm_ai, :llm, :call, :start/:stop/:exception]
      ├── [:swarm_ai, :tool, :execute, :start/:stop/:exception]
      └── [:swarm_ai, :child, :spawn, :start/:stop/:exception]
  ```
  """

  @prefix [:swarm_ai]

  # Run lifecycle
  def run_start, do: @prefix ++ [:run, :start]
  def run_stop, do: @prefix ++ [:run, :stop]
  def run_exception, do: @prefix ++ [:run, :exception]

  # Step lifecycle
  def step_start, do: @prefix ++ [:step, :start]
  def step_stop, do: @prefix ++ [:step, :stop]
  def step_exception, do: @prefix ++ [:step, :exception]

  # LLM call
  def llm_call_start, do: @prefix ++ [:llm, :call, :start]
  def llm_call_stop, do: @prefix ++ [:llm, :call, :stop]
  def llm_call_exception, do: @prefix ++ [:llm, :call, :exception]

  # Tool execution
  def tool_execute_start, do: @prefix ++ [:tool, :execute, :start]
  def tool_execute_stop, do: @prefix ++ [:tool, :execute, :stop]
  def tool_execute_exception, do: @prefix ++ [:tool, :execute, :exception]

  # Child spawn lifecycle
  def child_spawn_start, do: @prefix ++ [:child, :spawn, :start]
  def child_spawn_stop, do: @prefix ++ [:child, :spawn, :stop]
  def child_spawn_exception, do: @prefix ++ [:child, :spawn, :exception]

  @doc """
  Returns all event names for handler attachment.

  ## Example

      :telemetry.attach_many("my-handler", SwarmAi.Telemetry.Events.all(), &handler/4, nil)
  """
  def all do
    [
      run_start(),
      run_stop(),
      run_exception(),
      step_start(),
      step_stop(),
      step_exception(),
      llm_call_start(),
      llm_call_stop(),
      llm_call_exception(),
      tool_execute_start(),
      tool_execute_stop(),
      tool_execute_exception(),
      child_spawn_start(),
      child_spawn_stop(),
      child_spawn_exception()
    ]
  end
end
