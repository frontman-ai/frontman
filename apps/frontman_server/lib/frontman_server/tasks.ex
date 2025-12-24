defmodule FrontmanServer.Tasks do
  @moduledoc """
  Public API for task management.

  Tasks are containers for interactions in a conversation with agents.
  Each task represents a conversation thread with an AI agent.

  This context provides the boundary for all task-related operations,
  delegating to the domain layer and infrastructure as appropriate.
  """

  alias FrontmanServer.Tasks.{Interaction, Task, TaskStore}
  alias FrontmanServer.Tools.MCP
  alias FrontmanServer.Agents
  alias ReqLLM.ToolCall

  defdelegate task_exists?(task_id), to: TaskStore, as: :exists?
  defdelegate get_task(task_id), to: TaskStore, as: :get

  @doc """
  Sets the MCP tools for a task.

  MCP tools are stored as structured `MCP.t()` structs.
  Returns :ok on success, {:error, :not_found} if task doesn't exist.
  """
  @spec set_mcp_tools(String.t(), [MCP.t()]) :: :ok | {:error, :not_found}
  def set_mcp_tools(task_id, mcp_tools) do
    case TaskStore.update(task_id, &Task.set_mcp_tools(&1, mcp_tools)) do
      {:ok, _} -> :ok
      {:error, :not_found} = error -> error
    end
  end

  @doc """
  Gets the MCP tools for a task.

  Returns the MCP tool structs (not LLM-formatted).
  Returns [] if task not found or no tools set.
  """
  @spec get_mcp_tools(String.t()) :: [MCP.t()]
  def get_mcp_tools(task_id) do
    case get_task(task_id) do
      {:ok, task} -> task.mcp_tools || []
      {:error, :not_found} -> []
    end
  end

  @doc """
  Returns the PubSub topic for a task.
  """
  @spec topic(String.t()) :: String.t()
  def topic(task_id), do: "task:#{task_id}"

  @doc """
  Subscribes the calling process to task events.
  """
  @spec subscribe(atom(), String.t()) :: :ok | {:error, term()}
  def subscribe(pubsub, task_id) do
    Phoenix.PubSub.subscribe(pubsub, topic(task_id))
  end

  @doc """
  Creates a new task and stores it.

  The task_id must be provided by the client.
  Returns `{:ok, task_id}` on success.
  """
  @spec create_task(String.t(), String.t() | nil) :: {:ok, String.t()} | {:error, term()}
  def create_task(task_id, framework \\ nil) do
    task = Task.new(task_id, framework)
    :ok = TaskStore.insert(task)
    {:ok, task_id}
  end

  @doc """
  Gets all interactions for a task.
  """
  @spec get_interactions(String.t()) :: list(Interaction.t())
  def get_interactions(task_id) do
    case TaskStore.get(task_id) do
      {:ok, task} -> task.interactions
      {:error, :not_found} -> []
    end
  end

  @spec get_llm_messages(String.t(), String.t()) :: list(map())
  def get_llm_messages(task_id, agent_id) do
    interactions = get_interactions(task_id)
    discovered_rules = get_discovered_project_rules(task_id)
    messages = Interaction.to_llm_messages(interactions, agent_id)

    prepend_rules_to_first_user_message(messages, discovered_rules)
  end

  @spec add_discovered_project_rule(String.t(), String.t(), String.t()) ::
          {:ok, Interaction.DiscoveredProjectRule.t()} | {:ok, :already_loaded} | {:error, term()}
  def add_discovered_project_rule(task_id, path, content) do
    if discovered_project_rule_loaded?(task_id, path) do
      {:ok, :already_loaded}
    else
      interaction = Interaction.DiscoveredProjectRule.new(path, content)
      append_interaction(task_id, interaction)
    end
  end

  @spec get_discovered_project_rules(String.t()) :: list(Interaction.DiscoveredProjectRule.t())
  def get_discovered_project_rules(task_id) do
    task_id
    |> get_interactions()
    |> Enum.filter(&match?(%Interaction.DiscoveredProjectRule{}, &1))
  end

  @spec discovered_project_rule_loaded?(String.t(), String.t()) :: boolean()
  def discovered_project_rule_loaded?(task_id, path) do
    task_id
    |> get_discovered_project_rules()
    |> Enum.any?(&(&1.path == path))
  end

  defp prepend_rules_to_first_user_message(messages, []), do: messages

  defp prepend_rules_to_first_user_message(messages, rules) do
    reminder = build_rules_reminder(rules)
    do_prepend_to_first_user_message(messages, reminder)
  end

  defp do_prepend_to_first_user_message([], _reminder), do: []

  defp do_prepend_to_first_user_message([%{role: :user} = msg | rest], reminder) do
    content_parts =
      case msg.content do
        content when is_binary(content) -> [ReqLLM.Message.ContentPart.text(content)]
        content when is_list(content) -> content
      end

    updated_content = [ReqLLM.Message.ContentPart.text(reminder) | content_parts]

    [%{msg | content: updated_content} | rest]
  end

  defp do_prepend_to_first_user_message([msg | rest], reminder) do
    [msg | do_prepend_to_first_user_message(rest, reminder)]
  end

  defp build_rules_reminder(rules) do
    sections =
      rules
      |> Enum.sort_by(& &1.timestamp, DateTime)
      |> Enum.map(fn rule -> "Contents of #{rule.path}:\n\n#{rule.content}" end)

    """
    <system-reminder>
    As you answer the user's questions, you can use the following context:
    # Project Rules

    #{Enum.join(sections, "\n\n---\n\n")}

    IMPORTANT: this context may or may not be relevant to your tasks.
    </system-reminder>
    """
  end

  @doc """
  Checks if an interaction is a user message.
  """
  defdelegate user_message?(interaction), to: Interaction

  @doc """
  Checks if any user messages in the task contain Figma context.
  Returns true if there's a content block with figma_image or figma_node metadata.
  """
  @spec has_figma_context?(String.t()) :: boolean()
  def has_figma_context?(task_id) do
    task_id
    |> get_interactions()
    |> Interaction.has_figma_context?()
  end

  @doc """
  Checks if any user messages in the task contain a selected component.
  Returns true if there's a resource_link content block with a file:// URI.
  """
  @spec has_selected_component?(String.t()) :: boolean()
  def has_selected_component?(task_id) do
    task_id
    |> get_interactions()
    |> Interaction.has_selected_component?()
  end

  @spec append_interaction(String.t(), Interaction.t()) ::
          {:ok, Interaction.t()} | {:error, :task_not_found}
  defp append_interaction(task_id, interaction) do
    case TaskStore.update(task_id, &Task.append_interaction(&1, interaction)) do
      {:ok, _updated_task} ->
        # Broadcast the new interaction to all subscribers
        Phoenix.PubSub.broadcast(
          FrontmanServer.PubSub,
          "task:#{task_id}",
          {:interaction, interaction}
        )

        {:ok, interaction}

      {:error, :not_found} ->
        {:error, :task_not_found}
    end
  end

  @doc """
  Creates and appends a UserMessage interaction.

  Notifies Agents which decides whether to spawn or wake an agent.

  Arguments:
    - `task_id` - The ID of the task
    - `content_blocks` - Array of content blocks (text, resource_link, resource)

  Options:
    - `:tools` - List of tool definitions to pass to the agent
    - `:metadata` - Additional metadata for the message
  """
  @spec add_user_message(String.t(), list(), list(FrontmanServer.Tools.MCP.t())) ::
          {:ok, Interaction.t()} | {:error, :task_not_found}
  def add_user_message(task_id, content_blocks, tools) do
    interaction = Interaction.UserMessage.new(content_blocks)

    case append_interaction(task_id, interaction) do
      {:ok, interaction} ->
        Agents.notify_user_message(task_id, tools)
        {:ok, interaction}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Creates and appends an AgentResponse interaction.
  """
  @spec add_agent_response(String.t(), String.t(), String.t(), map()) ::
          {:ok, Interaction.t()} | {:error, :task_not_found}
  def add_agent_response(task_id, agent_id, content, metadata \\ %{}) do
    interaction = Interaction.AgentResponse.new(agent_id, content, metadata)
    append_interaction(task_id, interaction)
  end

  @doc """
  Creates and appends an AgentSpawned interaction.
  """
  @spec add_agent_spawned(%{task_id: String.t(), agent_id: String.t()}, map()) ::
          {:ok, Interaction.t()} | {:error, :task_not_found}
  def add_agent_spawned(%{task_id: task_id, agent_id: agent_id}, config \\ %{}) do
    interaction = Interaction.AgentSpawned.new(agent_id, config)
    append_interaction(task_id, interaction)
  end

  @doc """
  Creates and appends an AgentCompleted interaction.
  """
  @spec add_agent_completed(String.t(), String.t(), term()) ::
          {:ok, Interaction.t()} | {:error, :task_not_found}
  def add_agent_completed(task_id, agent_id, result \\ nil) do
    interaction = Interaction.AgentCompleted.new(agent_id, result)
    append_interaction(task_id, interaction)
  end

  @doc """
  Creates and appends a ToolCall interaction.
  """
  @spec add_tool_call(String.t(), String.t(), ToolCall.t()) ::
          {:ok, Interaction.t()} | {:error, :task_not_found}
  def add_tool_call(task_id, agent_id, %ToolCall{} = tool_call_data) do
    interaction = Interaction.ToolCall.new(agent_id, tool_call_data)
    append_interaction(task_id, interaction)
  end

  @doc """
  Creates and appends a ToolResult interaction.

  The agent_id identifies which agent (root or sub-agent) owns this tool result.
  Notifies Agents directly so the agent can continue its iteration.
  """
  @spec add_tool_result(
          String.t(),
          String.t(),
          %{id: String.t(), name: String.t()},
          term(),
          boolean()
        ) ::
          {:ok, Interaction.t()} | {:error, :task_not_found}
  def add_tool_result(
        task_id,
        agent_id,
        %{id: tool_call_id, name: _} = tool_call_data,
        result,
        is_error \\ false
      ) do
    interaction = Interaction.ToolResult.new(agent_id, tool_call_data, result, is_error)

    case append_interaction(task_id, interaction) do
      {:ok, interaction} ->
        Agents.notify_tool_result(task_id, tool_call_id, result, is_error)
        {:ok, interaction}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Todo Management

  alias FrontmanServer.Tasks.Todos

  @doc """
  Creates a new todo (in memory, returns for tool result).

  This is a helper for creating todo structs. The actual persistence
  happens when the todo is stored as a ToolResult interaction.
  """
  defdelegate create_todo(content, active_form, status \\ "pending"), to: Todos

  @doc """
  Lists all todos for a task.

  Todos are managed through tool calls, not direct API calls.
  This function is for reading the current state only.
  """
  @spec list_todos(String.t()) :: {:ok, [Todos.Todo.t()]} | {:error, :not_found}
  def list_todos(task_id) do
    case get_task(task_id) do
      {:ok, task} ->
        todos_map = Todos.list_todos(task.interactions)

        todos_list =
          todos_map
          |> Map.values()
          |> Enum.sort_by(& &1.created_at, DateTime)

        {:ok, todos_list}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end
end
