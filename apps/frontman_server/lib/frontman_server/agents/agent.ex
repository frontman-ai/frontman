defmodule FrontmanServer.Agents.Agent do
  @moduledoc """
  Domain entity representing an AI agent.

  An agent processes tasks by iterating with an LLM, executing tools,
  and optionally delegating work to sub-agents. This struct holds
  the domain state - process lifecycle is managed by AgentServer.

  ## Root vs Sub-agents

  - Root agents have `parent_id: nil` and `role: nil`
  - Sub-agents have a parent_id and a role from the Agents configuration
  """

  use TypedStruct

  alias FrontmanServer.Agents.SubAgent

  typedstruct enforce: true do
    field :id, String.t()
    field :task_id, String.t()
    field :role, atom() | nil, enforce: false
    field :task, String.t() | nil, enforce: false
    field :parent_id, String.t() | nil, enforce: false
    field :pending_tools, %{String.t() => map()}, default: %{}
    field :sub_agents, %{String.t() => SubAgent.t()}, default: %{}
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

  @doc "Creates a new sub-agent"
  @spec new_sub_agent(String.t(), String.t(), String.t(), atom(), String.t()) :: t()
  def new_sub_agent(agent_id, task_id, parent_id, role, task) do
    %__MODULE__{
      id: agent_id,
      task_id: task_id,
      role: role,
      task: task,
      parent_id: parent_id,
      started_at: System.monotonic_time(:millisecond)
    }
  end

  @doc "Is this a root agent (no parent)?"
  @spec root?(t()) :: boolean()
  def root?(%__MODULE__{parent_id: nil}), do: true
  def root?(_), do: false

  @doc "Does the agent have pending work (tools or sub-agents)?"
  @spec has_pending_work?(t()) :: boolean()
  def has_pending_work?(%__MODULE__{} = agent) do
    map_size(agent.pending_tools) > 0 or map_size(agent.sub_agents) > 0
  end

  @doc "Does the agent have pending sub-agents?"
  @spec has_pending_sub_agents?(t()) :: boolean()
  def has_pending_sub_agents?(%__MODULE__{} = agent) do
    map_size(agent.sub_agents) > 0
  end

  @doc "Track a new tool call"
  @spec track_tool(t(), map()) :: t()
  def track_tool(%__MODULE__{} = agent, tool_call) do
    %{agent | pending_tools: Map.put(agent.pending_tools, tool_call.id, tool_call)}
  end

  @doc "Complete a tool call"
  @spec complete_tool(t(), String.t()) :: {map() | nil, t()}
  def complete_tool(%__MODULE__{} = agent, tool_call_id) do
    tool_call = Map.get(agent.pending_tools, tool_call_id)
    updated = %{agent | pending_tools: Map.delete(agent.pending_tools, tool_call_id)}
    {tool_call, updated}
  end

  @doc "Track a spawned sub-agent"
  @spec track_sub_agent(t(), SubAgent.t()) :: t()
  def track_sub_agent(%__MODULE__{} = agent, sub_agent) do
    %{agent | sub_agents: Map.put(agent.sub_agents, sub_agent.id, sub_agent)}
  end

  @doc "Remove a sub-agent (completed or failed)"
  @spec remove_sub_agent(t(), String.t()) :: {SubAgent.t() | nil, t()}
  def remove_sub_agent(%__MODULE__{} = agent, sub_agent_id) do
    sub_agent = Map.get(agent.sub_agents, sub_agent_id)
    updated = %{agent | sub_agents: Map.delete(agent.sub_agents, sub_agent_id)}
    {sub_agent, updated}
  end

  @doc "Find a sub-agent by its pid"
  @spec find_sub_agent_by_pid(t(), pid()) :: {String.t(), SubAgent.t()} | nil
  def find_sub_agent_by_pid(%__MODULE__{} = agent, pid) do
    Enum.find(agent.sub_agents, fn {_id, sa} -> sa.pid == pid end)
  end

  @doc "Increment iteration count"
  @spec increment_iteration(t()) :: t()
  def increment_iteration(%__MODULE__{} = agent) do
    %{agent | iteration_count: agent.iteration_count + 1}
  end
end
