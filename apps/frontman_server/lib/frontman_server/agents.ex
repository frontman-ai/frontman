defmodule FrontmanServer.Agents do
  @moduledoc """
  Public API for agent management.

  Agents process user messages and generate responses using LLM.
  Each agent run gets a unique agent_id.

  This module handles:
  - Starting agents with callback injection
  - Routing notifications to running agents
  - Translating agent events to Tasks operations and transport broadcasts
  """

  require Logger

  alias FrontmanServer.Agents.{AgentServer, Prompts}
  alias FrontmanServer.Tasks

  # Re-export role type from Prompts
  @type role :: Prompts.role()

  # Delegate role functions to Prompts module
  defdelegate roles(), to: Prompts
  defdelegate get_role(key), to: Prompts
  defdelegate parse_role(key_string), to: Prompts

  @doc """
  Returns the current state of the agent for a task.

  - `:processing` - agent is actively working
  - `:waiting_for_tools` - agent is blocked waiting for tool results
  - `:idle` - agent is waiting for new messages
  - `:not_running` - no agent exists for this task
  """
  @spec agent_state(String.t()) :: :processing | :waiting_for_tools | :idle | :not_running
  def agent_state(task_id) do
    case get_root_agent_for_task(task_id) do
      {:ok, _pid, %{state: state}} -> state
      {:error, :not_found} -> :not_running
    end
  end

  @doc """
  Checks if an agent is currently running for the given task.
  """
  @spec agent_running?(String.t()) :: boolean()
  def agent_running?(task_id) do
    agent_state(task_id) != :not_running
  end

  @doc "Gets agent metadata by agent_id"
  @spec get_agent(String.t()) :: {:ok, pid(), map()} | {:error, :not_found}
  def get_agent(agent_id) do
    case Registry.lookup(FrontmanServer.AgentRegistry, {:agent, agent_id}) do
      [{pid, metadata}] -> {:ok, pid, metadata}
      [] -> {:error, :not_found}
    end
  end

  @doc "Gets all agents for a task"
  @spec get_agents_for_task(String.t()) :: [{String.t(), pid(), map()}]
  def get_agents_for_task(task_id) do
    match_spec = [
      {{{:agent, :"$1"}, :"$2", :"$3"}, [{:==, {:map_get, :task_id, :"$3"}, task_id}],
       [{{:"$1", :"$2", :"$3"}}]}
    ]

    Registry.select(FrontmanServer.AgentRegistry, match_spec)
  end

  @doc "Gets agent that owns a tool call"
  @spec get_agent_for_tool_call(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def get_agent_for_tool_call(tool_call_id) do
    case Registry.lookup(FrontmanServer.AgentRegistry, {:tool_call, tool_call_id}) do
      [{_self, agent_id}] -> {:ok, agent_id}
      [] -> {:error, :not_found}
    end
  end

  @doc "Gets the root agent for a task"
  @spec get_root_agent_for_task(String.t()) :: {:ok, pid(), map()} | {:error, :not_found}
  def get_root_agent_for_task(task_id) do
    match_spec = [
      {{{:agent, :"$1"}, :"$2", :"$3"},
       [
         {:andalso, {:==, {:map_get, :task_id, :"$3"}, task_id},
          {:==, {:map_get, :parent_agent_id, :"$3"}, nil}}
       ], [{{:"$2", :"$3"}}]}
    ]

    case Registry.select(FrontmanServer.AgentRegistry, match_spec) do
      [{pid, metadata}] -> {:ok, pid, metadata}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Starts a new agent for the given task and begins execution.

  Creates a unique agent_id and spawns AgentServer with callback injection.
  The agent receives messages via push model - no direct Tasks access.

  ## Options
  - `:tools` - List of tool definitions for LLM (default: [])
  """
  def start_agent(task_id, opts \\ []) do
    agent_id = Ecto.UUID.generate()
    tools = Keyword.get(opts, :tools, [])
    on_event = build_event_handler(task_id)

    result =
      DynamicSupervisor.start_child(
        FrontmanServer.AgentSupervisor,
        {AgentServer, agent_id: agent_id, task_id: task_id, tools: tools, on_event: on_event}
      )

    case result do
      {:ok, _pid} ->
        Tasks.add_agent_spawned(%{task_id: task_id, agent_id: agent_id}, %{tools: tools})
        messages = Tasks.get_llm_messages(task_id, agent_id)
        system_msg = Prompts.build_system_message(nil)
        AgentServer.execute_iteration(agent_id, [system_msg | messages])
        {:ok, agent_id}

      {:error, reason} ->
        Logger.error("Failed to start agent: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Notifies the agent that a tool result has arrived.

  Called by Tasks when a tool result is added.
  Uses direct routing via Registry to deliver to the owning agent.
  Returns `{:error, :agent_not_found}` if no agent owns this tool call.
  """
  @spec notify_tool_result(String.t(), String.t(), term(), boolean()) ::
          :ok | {:error, :agent_not_found}
  def notify_tool_result(_task_id, tool_call_id, result, is_error) do
    with {:ok, agent_id} <- get_agent_for_tool_call(tool_call_id),
         {:ok, pid, _metadata} <- get_agent(agent_id) do
      send(pid, {:tool_result, tool_call_id, result, is_error})
      :ok
    else
      {:error, :not_found} -> {:error, :agent_not_found}
    end
  end

  @doc """
  Notifies that a user message has been added.

  Called by Tasks when a user message is added.
  Spawns a new agent if none exists, or wakes an idle agent.

  ## Options
  - `:tools` - List of tool definitions for LLM (default: [])
  """
  @spec notify_user_message(String.t(), keyword()) :: :ok
  def notify_user_message(task_id, opts \\ []) do
    case AgentServer.wake(task_id) do
      :ok ->
        :ok

      {:error, :not_found} ->
        start_agent(task_id, tools: Keyword.get(opts, :tools, []))
        :ok
    end
  end

  # Private Functions

  defp build_event_handler(task_id) do
    fn event -> handle_agent_event(task_id, event) end
  end

  defp handle_agent_event(task_id, event) do
    case event do
      {:token, agent_id, token} ->
        broadcast(task_id, {:agent_stream_token, agent_id, token})

      {:response, agent_id, text, metadata} ->
        Tasks.add_agent_response(task_id, agent_id, text, metadata)

      {:tool_call, agent_id, tool_call} ->
        Tasks.add_tool_call(task_id, agent_id, tool_call)

      {:completed, agent_id} ->
        Tasks.add_agent_completed(task_id, agent_id)
        broadcast(task_id, {:agent_completed, agent_id})

      {:error, agent_id, reason} ->
        broadcast(task_id, {:agent_error, agent_id, inspect(reason)})

      {:need_iteration, agent_id} ->
        push_iteration(task_id, agent_id)

      {:sub_agent_spawned, agent_id, sub_agent} ->
        Tasks.add_sub_agent_spawned(task_id, agent_id, sub_agent)
        broadcast(task_id, {:sub_agent_spawned, sub_agent.id, sub_agent.role})

      {:sub_agent_completed, agent_id, sub_agent, duration_ms} ->
        Tasks.add_sub_agent_result(task_id, agent_id, sub_agent, duration_ms)
        broadcast(task_id, {:sub_agent_completed, sub_agent.id, sub_agent.role})

      {:sub_agent_failed, agent_id, sub_agent, duration_ms} ->
        Tasks.add_sub_agent_failed(task_id, agent_id, sub_agent, duration_ms)

        broadcast(
          task_id,
          {:sub_agent_failed, sub_agent.id, sub_agent.role, sub_agent.error}
        )

      {:sub_agent_spawn_failed, agent_id, tool_call_id, role, message, reason} ->
        Tasks.add_sub_agent_spawn_failed(task_id, agent_id, tool_call_id, role, message, reason)
        broadcast(task_id, {:sub_agent_spawn_failed, tool_call_id, role, reason})
    end
  end

  defp push_iteration(task_id, agent_id) do
    messages = Tasks.get_llm_messages(task_id, agent_id)
    {:ok, _pid, %{role: role}} = get_agent(agent_id)
    role_for_prompt = if role == :root, do: nil, else: role
    system_msg = Prompts.build_system_message(role_for_prompt)
    AgentServer.execute_iteration(agent_id, [system_msg | messages])
  end

  defp broadcast(task_id, message) do
    Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), message)
  end
end
