defmodule FrontmanServer.Tasks do
  @moduledoc """
  Public API for task management.

  Tasks are containers for interactions in a conversation with agents.
  Each task represents a conversation thread with an AI agent.

  This context provides the boundary for all task-related operations,
  delegating to the domain layer and infrastructure as appropriate.
  """

  alias FrontmanServer.Tasks.{Interaction, Task, TaskStore}
  alias FrontmanServer.Agents
  alias ReqLLM.ToolCall

  defdelegate task_exists?(task_id), to: TaskStore, as: :exists?
  defdelegate get_task(task_id), to: TaskStore, as: :get

  @doc """
  Sets the MCP tools for a task.

  MCP tools are stored in raw format (as received from client).
  Returns :ok on success, {:error, :not_found} if task doesn't exist.
  """
  @spec set_mcp_tools(String.t(), list()) :: :ok | {:error, :not_found}
  def set_mcp_tools(task_id, mcp_tools) do
    case TaskStore.update(task_id, &Task.set_mcp_tools(&1, mcp_tools)) do
      {:ok, _} -> :ok
      {:error, :not_found} = error -> error
    end
  end

  @doc """
  Gets the MCP tools for a task.

  Returns the raw MCP tool definitions (not LLM-formatted).
  Returns [] if task not found or no tools set.
  """
  @spec get_mcp_tools(String.t()) :: list()
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
  @spec create_task(String.t()) :: {:ok, String.t()} | {:error, term()}
  def create_task(task_id) do
    task = Task.new(task_id)
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

  @doc """
  Gets interactions formatted as LLM messages for a specific agent.

  Transforms task interactions into the format expected by LLM APIs.
  Filters to only include interactions belonging to the specified agent.
  UserMessages are always included as shared context.
  """
  @spec get_llm_messages(String.t(), String.t()) :: list(map())
  def get_llm_messages(task_id, agent_id) do
    task_id
    |> get_interactions()
    |> Interaction.to_llm_messages(agent_id)
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
  @spec add_user_message(String.t(), list(), keyword()) ::
          {:ok, Interaction.t()} | {:error, :task_not_found}
  def add_user_message(task_id, content_blocks, opts \\ []) do
    metadata = Keyword.get(opts, :metadata, %{})

    interaction = Interaction.UserMessage.new(content_blocks, metadata)

    case append_interaction(task_id, interaction) do
      {:ok, interaction} ->
        Agents.notify_user_message(task_id, opts)
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
