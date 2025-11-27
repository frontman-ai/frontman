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

  alias FrontmanServer.Agents.AgentServer
  alias FrontmanServer.Tasks

  @doc """
  Returns the current state of the agent for a task.

  - `:processing` - agent is actively working
  - `:idle` - agent is waiting for new messages
  - `:not_running` - no agent exists for this task
  """
  @spec agent_state(String.t()) :: :processing | :idle | :not_running
  def agent_state(task_id) do
    case Registry.lookup(FrontmanServer.AgentRegistry, task_id) do
      [{_pid, state}] -> state
      [] -> :not_running
    end
  end

  @doc """
  Checks if an agent is currently running for the given task.
  """
  @spec agent_running?(String.t()) :: boolean()
  def agent_running?(task_id) do
    agent_state(task_id) != :not_running
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
      {:ok, pid} ->
        Tasks.add_agent_spawned(%{task_id: task_id, agent_id: agent_id}, %{tools: tools})
        messages = Tasks.get_llm_messages(task_id)
        send(pid, {:execute_iteration, messages})
        {:ok, agent_id}

      {:error, reason} ->
        Logger.error("Failed to start agent: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Notifies the agent that a tool result has arrived.

  Called by Tasks when a tool result is added.
  Returns `{:error, :agent_not_found}` if no agent is running for the task.
  """
  @spec notify_tool_result(String.t(), String.t(), term(), boolean()) ::
          :ok | {:error, :agent_not_found}
  def notify_tool_result(task_id, tool_call_id, result, is_error) do
    case find_agent(task_id) do
      {:ok, pid} ->
        send(pid, {:tool_result, tool_call_id, result, is_error})
        :ok

      :not_found ->
        {:error, :agent_not_found}
    end
  end

  @doc """
  Notifies that a user message has been added.

  Called by Tasks when a user message is added.
  Spawns a new agent if none exists, or wakes an idle agent.

  ## Options
  - `:mcp_tools` - List of tool definitions for LLM (default: [])
  """
  @spec notify_user_message(String.t(), keyword()) :: :ok
  def notify_user_message(task_id, opts \\ []) do
    case find_agent(task_id) do
      {:ok, pid} ->
        send(pid, :wake_agent)
        :ok

      :not_found ->
        start_agent(task_id, tools: Keyword.get(opts, :mcp_tools, []))
        :ok
    end
  end

  # Private Functions

  defp find_agent(task_id) do
    case Registry.lookup(FrontmanServer.AgentRegistry, task_id) do
      [{pid, _state}] -> {:ok, pid}
      [] -> :not_found
    end
  end

  defp build_event_handler(task_id) do
    fn event -> handle_agent_event(task_id, event) end
  end

  defp handle_agent_event(task_id, event) do
    case event do
      {:token, agent_id, token} ->
        broadcast(task_id, {:stream_token, agent_id, token})

      {:response, agent_id, text, metadata} ->
        Tasks.add_agent_response(task_id, agent_id, text, metadata)

      {:tool_call, agent_id, tool_call} ->
        Tasks.add_tool_call(task_id, agent_id, tool_call)

      {:completed, agent_id} ->
        Tasks.add_agent_completed(task_id, agent_id)
        broadcast(task_id, {:agent_completed, agent_id})

      {:error, agent_id, reason} ->
        broadcast(task_id, {:agent_error, agent_id, inspect(reason)})

      {:need_iteration, _agent_id} ->
        push_iteration(task_id)
    end
  end

  defp push_iteration(task_id) do
    case find_agent(task_id) do
      {:ok, pid} ->
        messages = Tasks.get_llm_messages(task_id)
        send(pid, {:execute_iteration, messages})

      :not_found ->
        :ok
    end
  end

  defp broadcast(task_id, message) do
    Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), message)
  end
end
