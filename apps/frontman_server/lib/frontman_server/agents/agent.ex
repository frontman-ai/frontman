defmodule FrontmanServer.Agents.Agent do
  @moduledoc """
  Domain entity representing an AI agent.

  An agent processes tasks by iterating with an LLM and executing tools.
  This struct holds the domain state - process lifecycle is managed by AgentServer.
  """

  use TypedStruct

  alias ReqLLM.ToolCall

  typedstruct enforce: true do
    field :id, String.t()
    field :task_id, String.t()
    field :pending_tools, %{String.t() => ToolCall.t()}, default: %{}
    field :started_at, integer(), default: 0
    field :iteration_count, non_neg_integer(), default: 0
  end

  @doc "Creates a new root agent"
  @spec new_root(String.t(), String.t()) :: t()
  def new_root(agent_id, task_id) do
    %__MODULE__{
      id: agent_id,
      task_id: task_id,
      started_at: System.monotonic_time(:millisecond)
    }
  end

  @doc "Does the agent have pending work (tools)?"
  @spec has_pending_work?(t()) :: boolean()
  def has_pending_work?(%__MODULE__{} = agent) do
    map_size(agent.pending_tools) > 0
  end

  @doc "Track a new tool call"
  @spec track_tool(t(), ToolCall.t()) :: t()
  def track_tool(%__MODULE__{} = agent, %ToolCall{id: id} = tool_call) do
    %{agent | pending_tools: Map.put(agent.pending_tools, id, tool_call)}
  end

  @doc "Complete a tool call"
  @spec complete_tool(t(), String.t()) :: {ToolCall.t() | nil, t()}
  def complete_tool(%__MODULE__{pending_tools: pending} = agent, tool_call_id) do
    case Map.pop(pending, tool_call_id) do
      {nil, _} -> {nil, agent}
      {tool_call, remaining} -> {tool_call, %{agent | pending_tools: remaining}}
    end
  end

  @doc "Increment iteration count"
  @spec increment_iteration(t()) :: t()
  def increment_iteration(%__MODULE__{} = agent) do
    %{agent | iteration_count: agent.iteration_count + 1}
  end
end
