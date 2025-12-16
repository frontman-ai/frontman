defmodule FrontmanServer.Observability.Events do
  @moduledoc """
  Telemetry event name definitions.

  Single source of truth for event names used by TelemetryEvents (emitter)
  and OtelHandler (consumer).
  """

  @prefix [:frontman]

  # Task
  def task_start, do: @prefix ++ [:task, :start]
  def task_stop, do: @prefix ++ [:task, :stop]

  # Agent
  def agent_start, do: @prefix ++ [:agent, :start]
  def agent_stop, do: @prefix ++ [:agent, :stop]

  # Iteration
  def iteration_start, do: @prefix ++ [:iteration, :start]
  def iteration_stop, do: @prefix ++ [:iteration, :stop]

  # LLM
  def llm_start, do: @prefix ++ [:llm, :start]
  def llm_stop, do: @prefix ++ [:llm, :stop]

  # Backend tool
  def tool_start, do: @prefix ++ [:tool, :start]
  def tool_stop, do: @prefix ++ [:tool, :stop]

  # MCP tool
  def mcp_tool_start, do: @prefix ++ [:mcp_tool, :start]
  def mcp_tool_stop, do: @prefix ++ [:mcp_tool, :stop]
end
