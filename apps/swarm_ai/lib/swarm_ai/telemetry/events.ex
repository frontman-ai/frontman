defmodule SwarmAi.Telemetry.Events do
  @moduledoc """
  Telemetry event name definitions for SwarmAi.

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

  @doc "Event: agent run started."
  def run_start, do: @prefix ++ [:run, :start]
  @doc "Event: agent run stopped."
  def run_stop, do: @prefix ++ [:run, :stop]
  @doc "Event: agent run raised an exception."
  def run_exception, do: @prefix ++ [:run, :exception]

  @doc "Event: execution step started."
  def step_start, do: @prefix ++ [:step, :start]
  @doc "Event: execution step stopped."
  def step_stop, do: @prefix ++ [:step, :stop]
  @doc "Event: execution step raised an exception."
  def step_exception, do: @prefix ++ [:step, :exception]

  @doc "Event: LLM call started."
  def llm_call_start, do: @prefix ++ [:llm, :call, :start]
  @doc "Event: LLM call stopped."
  def llm_call_stop, do: @prefix ++ [:llm, :call, :stop]
  @doc "Event: LLM call raised an exception."
  def llm_call_exception, do: @prefix ++ [:llm, :call, :exception]

  @doc "Event: tool execution started."
  def tool_execute_start, do: @prefix ++ [:tool, :execute, :start]
  @doc "Event: tool execution stopped."
  def tool_execute_stop, do: @prefix ++ [:tool, :execute, :stop]
  @doc "Event: tool execution raised an exception."
  def tool_execute_exception, do: @prefix ++ [:tool, :execute, :exception]

  @doc "Event: child agent spawn started."
  def child_spawn_start, do: @prefix ++ [:child, :spawn, :start]
  @doc "Event: child agent spawn stopped."
  def child_spawn_stop, do: @prefix ++ [:child, :spawn, :stop]
  @doc "Event: child agent spawn raised an exception."
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
