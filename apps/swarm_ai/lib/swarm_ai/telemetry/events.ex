defmodule SwarmAi.Telemetry.Events do
  @prefix [:swarm_ai]
  @type t :: [atom()]

  @spec run_start() :: t()
  def run_start, do: @prefix ++ [:run, :start]
  @spec run_stop() :: t()
  def run_stop, do: @prefix ++ [:run, :stop]
  @spec run_exception() :: t()
  def run_exception, do: @prefix ++ [:run, :exception]

  @spec step_start() :: t()
  def step_start, do: @prefix ++ [:step, :start]
  @spec step_stop() :: t()
  def step_stop, do: @prefix ++ [:step, :stop]
  @spec step_exception() :: t()
  def step_exception, do: @prefix ++ [:step, :exception]

  @spec llm_call_start() :: t()
  def llm_call_start, do: @prefix ++ [:llm, :call, :start]
  @spec llm_call_stop() :: t()
  def llm_call_stop, do: @prefix ++ [:llm, :call, :stop]
  @spec llm_call_exception() :: t()
  def llm_call_exception, do: @prefix ++ [:llm, :call, :exception]

  @spec tool_execute_start() :: t()
  def tool_execute_start, do: @prefix ++ [:tool, :execute, :start]
  @spec tool_execute_stop() :: t()
  def tool_execute_stop, do: @prefix ++ [:tool, :execute, :stop]
  @spec tool_execute_exception() :: t()
  def tool_execute_exception, do: @prefix ++ [:tool, :execute, :exception]

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
