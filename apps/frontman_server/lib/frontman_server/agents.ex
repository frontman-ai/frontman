defmodule FrontmanServer.Agents do
  @moduledoc """
  Public API for agent management.

  Agents process user messages and generate responses using LLM.
  Each agent run gets a unique agent_id.

  This module handles:
  - Starting agents using the Swarm-based Executor
  - Routing tool result notifications to waiting executors
  - Translating agent events to Tasks operations and transport broadcasts
  """

  require Logger

  alias FrontmanServer.Agents.{Executor, RootAgent}
  alias FrontmanServer.Tasks
  alias Swarm.Message

  @doc """
  Checks if an agent is currently running for the given task.
  """
  @spec agent_running?(String.t()) :: boolean()
  def agent_running?(task_id) do
    case get_root_agent_for_task(task_id) do
      {:ok, _pid, _metadata} -> true
      {:error, :not_found} -> false
    end
  end

  @doc "Gets agent metadata by agent_id"
  @spec get_agent(String.t()) :: {:ok, pid(), map()} | {:error, :not_found}
  def get_agent(agent_id) do
    case Registry.lookup(FrontmanServer.AgentRegistry, {:agent, agent_id}) do
      [{pid, metadata}] -> {:ok, pid, metadata}
      [] -> {:error, :not_found}
    end
  end

  @doc "Gets parent_agent_id for an agent, or nil if it's the root agent"
  @spec get_parent_agent_id(String.t()) :: String.t() | nil
  def get_parent_agent_id(agent_id) do
    case get_agent(agent_id) do
      {:ok, _pid, metadata} -> Map.get(metadata, :parent_agent_id)
      {:error, :not_found} -> nil
    end
  end

  @doc "Gets spawning_tool_name for an agent (e.g., 'breakdown_figma_design'), or nil if not set"
  @spec get_spawning_tool_name(String.t()) :: String.t() | nil
  def get_spawning_tool_name(agent_id) do
    case get_agent(agent_id) do
      {:ok, _pid, metadata} -> Map.get(metadata, :spawning_tool_name)
      {:error, :not_found} -> nil
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
      [{_self, %{} = _metadata}] ->
        # New format: metadata map with caller info
        # The agent_id is not stored directly, but the executor handles routing
        {:error, :not_found}

      [{_self, agent_id}] when is_binary(agent_id) ->
        {:ok, agent_id}

      [] ->
        {:error, :not_found}
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

  Creates a unique agent_id and spawns an Executor task with RootAgent.
  The executor runs the full agent loop (LLM calls + tool execution) until completion.

  ## Options
  - `:tools` - List of tool definitions for LLM (default: [])
  - `:agent` - Custom agent struct implementing Swarm.Agent (for testing)
  """
  def start_agent(task_id, opts \\ []) do
    agent_id = Ecto.UUID.generate()
    tools = Keyword.get(opts, :tools, [])
    on_event = build_event_handler(task_id)

    agent =
      case Keyword.get(opts, :agent) do
        nil ->
          # Build context for dynamic system prompt
          has_figma = Tasks.has_figma_context?(task_id)
          has_selected_component = Tasks.has_selected_component?(task_id)
          figma_node_id = Tasks.get_figma_node_id(task_id)
          framework = get_framework(task_id)

          # Create RootAgent with context
          RootAgent.new(
            tools: tools,
            has_figma_context: has_figma,
            has_selected_component: has_selected_component,
            figma_node_id: figma_node_id,
            framework: framework
          )

        custom_agent ->
          custom_agent
      end

    # Get messages and convert to Swarm.Message format
    messages = build_messages(task_id, agent_id)

    # Track agent spawned in task
    Tasks.add_agent_spawned(%{task_id: task_id, agent_id: agent_id}, %{tools: tools})

    # Start executor - always returns {:ok, ref} since it spawns a Task
    {:ok, _ref} = Executor.run(agent, task_id, agent_id, messages, on_event: on_event)
    {:ok, agent_id}
  end

  @doc """
  Notifies the agent that a tool result has arrived.

  Called by Tasks when a tool result is added.
  Routes to the blocking caller via Registry metadata.
  """
  @spec notify_tool_result(String.t(), String.t(), term(), boolean()) :: :ok
  def notify_tool_result(_task_id, tool_call_id, result, is_error) do
    case Registry.lookup(FrontmanServer.AgentRegistry, {:tool_call, tool_call_id}) do
      [{_pid, %{executor: :tool_executor, caller_ref: ref, caller_pid: caller}}] ->
        # MCP tool - send result to waiting executor
        # Encode non-string results since Swarm.Message.ContentPart.text/1 requires strings
        encoded = encode_result_for_swarm(result)
        send(caller, {:tool_result, ref, encoded, is_error})
        :ok

      [] ->
        # No waiter - this is normal for backend tools (they execute synchronously)
        :ok
    end
  end

  @doc """
  Notifies that a user message has been added.

  Called by Tasks when a user message is added.
  Spawns a new agent if none exists.

  ## Options
  - `:tools` - List of tool definitions for LLM (default: [])
  - `:agent` - Custom agent struct implementing Swarm.Agent (for testing)
  """
  @spec notify_user_message(String.t(), list(FrontmanServer.Tools.MCP.t()), keyword()) :: :ok
  def notify_user_message(task_id, tools, opts \\ []) do
    # Check if agent is already running
    if agent_running?(task_id) do
      # Agent is running - it will pick up new messages on next iteration
      :ok
    else
      start_agent(task_id, Keyword.merge([tools: tools], opts))
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
    end
  end

  defp build_messages(task_id, agent_id) do
    task_id
    |> Tasks.get_llm_messages(agent_id)
    |> Enum.map(&to_swarm_message/1)
  end

  defp to_swarm_message(%ReqLLM.Message{} = msg) do
    content =
      case msg.content do
        text when is_binary(text) ->
          [Message.ContentPart.text(text)]

        parts when is_list(parts) ->
          Enum.map(parts, &to_swarm_content_part/1)

        nil ->
          []
      end

    %Message{
      role: msg.role,
      content: content,
      tool_calls: to_swarm_tool_calls(msg.tool_calls),
      tool_call_id: msg.tool_call_id,
      name: msg.name
    }
  end

  defp to_swarm_content_part(%ReqLLM.Message.ContentPart{type: :text, text: text}) do
    Message.ContentPart.text(text)
  end

  defp to_swarm_content_part(%ReqLLM.Message.ContentPart{type: :image, data: data, media_type: mt}) do
    Message.ContentPart.image(data, mt)
  end

  defp to_swarm_content_part(%ReqLLM.Message.ContentPart{type: :image_url, url: url}) do
    Message.ContentPart.image_url(url)
  end

  defp to_swarm_content_part(_), do: nil

  defp to_swarm_tool_calls(nil), do: []
  defp to_swarm_tool_calls([]), do: []

  defp to_swarm_tool_calls(tool_calls) do
    Enum.map(tool_calls, fn tc ->
      %Swarm.ToolCall{
        id: tc.id,
        name: ReqLLM.ToolCall.name(tc),
        arguments: tc.arguments
      }
    end)
  end

  defp get_framework(task_id) do
    case Tasks.get_task(task_id) do
      {:ok, task} -> task.framework
      {:error, :not_found} -> nil
    end
  end

  defp broadcast(task_id, message) do
    Phoenix.PubSub.broadcast(FrontmanServer.PubSub, Tasks.topic(task_id), message)
  end

  # Encode non-string results to JSON for Swarm.Message.ContentPart.text/1
  defp encode_result_for_swarm(value) when is_binary(value), do: value
  defp encode_result_for_swarm(value), do: Jason.encode!(value)
end
