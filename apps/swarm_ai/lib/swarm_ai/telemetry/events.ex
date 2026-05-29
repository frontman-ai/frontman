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
      └── [:swarm_ai, :tool, :execute, :start/:stop/:exception]
  ```
  """

  @prefix [:swarm_ai]
  @type t :: [atom()]

  @doc "Event: execution run started."
  @spec run_start() :: t()
  def run_start, do: @prefix ++ [:run, :start]
  @doc "Event: execution run stopped."
  @spec run_stop() :: t()
  def run_stop, do: @prefix ++ [:run, :stop]
  @doc "Event: execution run raised an exception."
  @spec run_exception() :: t()
  def run_exception, do: @prefix ++ [:run, :exception]

  @doc "Event: execution step started."
  @spec step_start() :: t()
  def step_start, do: @prefix ++ [:step, :start]
  @doc "Event: execution step stopped."
  @spec step_stop() :: t()
  def step_stop, do: @prefix ++ [:step, :stop]
  @doc "Event: execution step raised an exception."
  @spec step_exception() :: t()
  def step_exception, do: @prefix ++ [:step, :exception]

  @doc "Event: LLM call started."
  @spec llm_call_start() :: t()
  def llm_call_start, do: @prefix ++ [:llm, :call, :start]
  @doc "Event: LLM call stopped."
  @spec llm_call_stop() :: t()
  def llm_call_stop, do: @prefix ++ [:llm, :call, :stop]
  @doc "Event: LLM call raised an exception."
  @spec llm_call_exception() :: t()
  def llm_call_exception, do: @prefix ++ [:llm, :call, :exception]

  @doc "Event: tool execution started."
  @spec tool_execute_start() :: t()
  def tool_execute_start, do: @prefix ++ [:tool, :execute, :start]
  @doc "Event: tool execution stopped."
  @spec tool_execute_stop() :: t()
  def tool_execute_stop, do: @prefix ++ [:tool, :execute, :stop]
  @doc "Event: tool execution raised an exception."
  @spec tool_execute_exception() :: t()
  def tool_execute_exception, do: @prefix ++ [:tool, :execute, :exception]

  @doc """
  Returns all event names for handler attachment.

  ## Example

      :telemetry.attach_many("my-handler", SwarmAi.Telemetry.Events.all(), &handler/4, nil)
  """
  @spec all() :: [t()]
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
      tool_execute_exception()
    ]
  end
end
