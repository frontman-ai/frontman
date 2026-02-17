defmodule FrontmanServer.Tasks do
  @moduledoc """
  Public API for task management.

  Tasks are containers for interactions in a conversation with agents.
  Each task represents a conversation thread with an AI agent.

  This context provides the boundary for all task-related operations,
  delegating to the domain layer and infrastructure as appropriate.
  """
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Agents
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks.{Interaction, InteractionSchema, Task, TaskSchema}
  alias ReqLLM.ToolCall

  # --- Authorization Helpers ---

  @spec get_task_by_id(Scope.t(), String.t()) :: {:ok, TaskSchema.t()} | {:error, :not_found}
  defp get_task_by_id(%Scope{user: %{id: user_id}}, task_id) do
    query =
      TaskSchema
      |> TaskSchema.by_id(task_id)
      |> TaskSchema.for_user(user_id)

    case Repo.one(query) do
      nil -> {:error, :not_found}
      schema -> {:ok, schema}
    end
  end

  # --- Public API ---

  @doc """
  Lists all tasks for a user (lightweight, no interactions loaded).

  Returns task schemas ordered by most recently updated.
  """
  @max_tasks 20

  @spec list_tasks(Scope.t()) :: {:ok, [TaskSchema.t()]}
  def list_tasks(%Scope{user: %{id: user_id}}) do
    tasks =
      TaskSchema
      |> TaskSchema.for_user(user_id)
      |> TaskSchema.ordered_by_updated()
      |> TaskSchema.limited(@max_tasks)
      |> Repo.all()

    {:ok, tasks}
  end

  @doc """
  Checks if a task exists for the given scope.
  """
  @spec task_exists?(Scope.t(), String.t()) :: boolean()
  def task_exists?(%Scope{} = scope, task_id) do
    case get_task_by_id(scope, task_id) do
      {:ok, _schema} -> true
      {:error, :not_found} -> false
    end
  end

  @doc """
  Gets a task by ID. Returns the task with interactions loaded.

  Requires authorization - scope.user.id must match task.user_id.
  """
  @spec get_task(Scope.t(), String.t()) :: {:ok, Task.t()} | {:error, :not_found}
  def get_task(%Scope{} = scope, task_id) do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      {:ok, schema_to_task(schema)}
    end
  end

  @doc """
  Deletes a task and all its interactions.

  Requires authorization - scope.user.id must match task.user_id.
  Cascade deletes configured in migration handle interaction cleanup.
  """
  @spec delete_task(Scope.t(), String.t()) :: :ok | {:error, :not_found}
  def delete_task(%Scope{} = scope, task_id) do
    with {:ok, schema} <- get_task_by_id(scope, task_id),
         {:ok, _} <- Repo.delete(schema) do
      :ok
    end
  end

  @doc """
  Gets a task's short description (title) without loading interactions.

  Lightweight query for cases where only the title is needed (e.g., title generation check).
  """
  @spec get_short_desc(Scope.t(), String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def get_short_desc(%Scope{} = scope, task_id) do
    case get_task_by_id(scope, task_id) do
      {:ok, schema} -> {:ok, schema.short_desc}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  Updates a task's short description (title).

  Requires authorization - scope.user.id must match task.user_id.
  """
  @spec update_short_desc(Scope.t(), String.t(), String.t()) ::
          {:ok, TaskSchema.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_short_desc(%Scope{} = scope, task_id, title) do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      schema
      |> TaskSchema.update_changeset(%{short_desc: title})
      |> Repo.update()
    end
  end

  @spec schema_to_task(TaskSchema.t()) :: Task.t()
  defp schema_to_task(schema) do
    interactions = load_interactions(schema.id)

    %Task{
      task_id: schema.id,
      short_desc: schema.short_desc,
      framework: schema.framework,
      interactions: interactions
    }
  end

  @spec load_interactions(String.t()) :: [Interaction.t()]
  defp load_interactions(task_id) do
    InteractionSchema
    |> InteractionSchema.for_task(task_id)
    |> InteractionSchema.ordered_by_inserted()
    |> Repo.all()
    |> Enum.map(&InteractionSchema.to_struct/1)
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
  Requires a scope with a user.
  Returns `{:ok, task_id}` on success.
  """
  @spec create_task(Scope.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def create_task(%Scope{user: user}, task_id, framework) do
    attrs = %{
      id: task_id,
      short_desc: Task.short_description(task_id),
      framework: framework,
      user_id: user.id
    }

    case TaskSchema.create_changeset(attrs) |> Repo.insert() do
      {:ok, _schema} -> {:ok, task_id}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Gets all interactions for a task.

  Requires authorization - scope.user.id must match task.user_id.
  """
  @spec get_interactions(Scope.t(), String.t()) ::
          {:ok, [Interaction.t()]} | {:error, :not_found}
  def get_interactions(%Scope{} = scope, task_id) do
    with {:ok, _schema} <- get_task_by_id(scope, task_id) do
      {:ok, load_interactions(task_id)}
    end
  end

  @doc """
  Gets LLM-formatted messages for a task.

  Requires authorization - scope.user.id must match task.user_id.

  Note: Project rules (AGENTS.md, etc.) are now appended to the system prompt
  in Prompts.build/1 rather than prepended to user messages. This ensures they
  appear after the base prompt and before context-specific guidance.
  """
  @spec get_llm_messages(Scope.t(), String.t()) ::
          {:ok, list(map())} | {:error, :not_found}
  def get_llm_messages(%Scope{} = scope, task_id) do
    with {:ok, interactions} <- get_interactions(scope, task_id) do
      messages = Interaction.to_llm_messages(interactions)
      {:ok, messages}
    end
  end

  @doc """
  Adds a discovered project rule to the task.

  Deduplicates by path - returns `{:ok, :already_loaded}` if already present.
  """
  @spec add_discovered_project_rule(Scope.t(), String.t(), String.t(), String.t()) ::
          {:ok, Interaction.DiscoveredProjectRule.t() | :already_loaded}
          | {:error, :not_found}
  def add_discovered_project_rule(%Scope{} = scope, task_id, path, content) do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      if discovered_project_rule_loaded?(scope, task_id, path) do
        {:ok, :already_loaded}
      else
        interaction = Interaction.DiscoveredProjectRule.new(path, content)
        append_interaction(schema, interaction)
      end
    end
  end

  @doc """
  Gets all discovered project rules for a task.
  """
  @spec get_discovered_project_rules(Scope.t(), String.t()) ::
          {:ok, [Interaction.DiscoveredProjectRule.t()]} | {:error, :not_found}
  def get_discovered_project_rules(%Scope{} = scope, task_id) do
    with {:ok, interactions} <- get_interactions(scope, task_id) do
      rules = Enum.filter(interactions, &match?(%Interaction.DiscoveredProjectRule{}, &1))
      {:ok, rules}
    end
  end

  @doc """
  Checks if a project rule with the given path has already been loaded.
  """
  @spec discovered_project_rule_loaded?(Scope.t(), String.t(), String.t()) :: boolean()
  def discovered_project_rule_loaded?(%Scope{} = scope, task_id, path) do
    case get_discovered_project_rules(scope, task_id) do
      {:ok, rules} -> Enum.any?(rules, &(&1.path == path))
      {:error, _} -> false
    end
  end

  @doc """
  Checks if any user messages in the task contain a selected component.
  """
  @spec has_selected_component?(Scope.t(), String.t()) :: boolean()
  def has_selected_component?(%Scope{} = scope, task_id) do
    case get_interactions(scope, task_id) do
      {:ok, interactions} -> Interaction.has_selected_component?(interactions)
      {:error, _} -> false
    end
  end

  @doc """
  Checks if any user messages in the task contain current page context.
  """
  @spec has_current_page?(Scope.t(), String.t()) :: boolean()
  def has_current_page?(%Scope{} = scope, task_id) do
    case get_interactions(scope, task_id) do
      {:ok, interactions} -> Interaction.has_current_page?(interactions)
      {:error, _} -> false
    end
  end

  @spec append_interaction(TaskSchema.t(), Interaction.t()) ::
          {:ok, Interaction.t()} | {:error, Ecto.Changeset.t()}
  defp append_interaction(%TaskSchema{id: task_id}, interaction) do
    case InteractionSchema.create_changeset(task_id, interaction) |> Repo.insert() do
      {:ok, _schema} ->
        touch_task(task_id)
        broadcast_task(task_id, {:interaction, interaction})
        {:ok, interaction}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # Bump the task's updated_at so it sorts to the top of the sessions list
  defp touch_task(task_id) do
    import Ecto.Query

    from(t in TaskSchema, where: t.id == ^task_id)
    |> Repo.update_all(set: [updated_at: DateTime.utc_now(:second)])
  end

  @spec broadcast_task(String.t(), term()) :: :ok
  defp broadcast_task(task_id, message) do
    Phoenix.PubSub.broadcast(FrontmanServer.PubSub, topic(task_id), message)
  end

  @doc """
  Creates and appends a UserMessage interaction.

  Notifies Agents which decides whether to spawn or wake an agent.
  """
  @spec add_user_message(Scope.t(), String.t(), list(), list(), keyword()) ::
          {:ok, Interaction.UserMessage.t()} | {:error, :not_found}
  def add_user_message(%Scope{} = scope, task_id, content_blocks, tools, opts \\ []) do
    with {:ok, schema} <- get_task_by_id(scope, task_id),
         interaction = Interaction.UserMessage.new(content_blocks),
         {:ok, interaction} <- append_interaction(schema, interaction) do
      Agents.notify_user_message(scope, task_id, tools, opts)
      {:ok, interaction}
    end
  end

  @doc """
  Creates and appends an AgentResponse interaction.
  """
  @spec add_agent_response(Scope.t(), String.t(), String.t(), map()) ::
          {:ok, Interaction.AgentResponse.t()} | {:error, :not_found}
  def add_agent_response(%Scope{} = scope, task_id, content, metadata \\ %{}) do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      interaction = Interaction.AgentResponse.new(content, metadata)
      append_interaction(schema, interaction)
    end
  end

  @doc """
  Creates and appends an AgentSpawned interaction.
  """
  @spec add_agent_spawned(Scope.t(), String.t(), map()) ::
          {:ok, Interaction.AgentSpawned.t()} | {:error, :not_found}
  def add_agent_spawned(%Scope{} = scope, task_id, config \\ %{}) do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      interaction = Interaction.AgentSpawned.new(config)
      append_interaction(schema, interaction)
    end
  end

  @doc """
  Creates and appends an AgentCompleted interaction.
  """
  @spec add_agent_completed(Scope.t(), String.t(), term()) ::
          {:ok, Interaction.AgentCompleted.t()} | {:error, :not_found}
  def add_agent_completed(%Scope{} = scope, task_id, result \\ nil) do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      interaction = Interaction.AgentCompleted.new(result)
      append_interaction(schema, interaction)
    end
  end

  @doc """
  Creates and appends a ToolCall interaction.
  """
  @spec add_tool_call(Scope.t(), String.t(), ToolCall.t()) ::
          {:ok, Interaction.ToolCall.t()} | {:error, :not_found}
  def add_tool_call(%Scope{} = scope, task_id, %ToolCall{} = tool_call_data) do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      interaction = Interaction.ToolCall.new(tool_call_data)
      append_interaction(schema, interaction)
    end
  end

  @doc """
  Creates and appends a ToolResult interaction.

  Notifies Agents directly so the agent can continue its iteration.
  """
  @spec add_tool_result(Scope.t(), String.t(), map(), term(), boolean()) ::
          {:ok, Interaction.ToolResult.t()} | {:error, :not_found}
  def add_tool_result(
        %Scope{} = scope,
        task_id,
        %{id: tool_call_id, name: _} = tool_call_data,
        result,
        is_error \\ false
      ) do
    with {:ok, schema} <- get_task_by_id(scope, task_id),
         interaction = Interaction.ToolResult.new(tool_call_data, result, is_error),
         {:ok, interaction} <- append_interaction(schema, interaction) do
      Agents.notify_tool_result(task_id, tool_call_id, result, is_error)
      {:ok, interaction}
    end
  end

  # Task List Management

  alias FrontmanServer.Tasks.Todos

  @doc """
  Creates a new todo (in memory, returns for tool result).

  This is a helper for creating todo structs. The actual persistence
  happens when the todo is stored as a ToolResult interaction.
  """
  defdelegate create_todo(content, active_form, status \\ "pending"), to: Todos

  @doc """
  Updates a todo's status. Used by todo_update tool.
  """
  defdelegate update_todo_status(interactions, todo_id, status), to: Todos

  @doc """
  Projects todos from interactions. Used by todo_list tool.
  """
  defdelegate project_todos(interactions), to: Todos, as: :list_todos

  @doc """
  Lists all todos for a task.

  Todos are managed through tool calls, not direct API calls.
  This function is for reading the current state only.
  """
  @spec list_todos(Scope.t(), String.t()) ::
          {:ok, [Todos.Todo.t()]} | {:error, :not_found}
  def list_todos(%Scope{} = scope, task_id) do
    case get_task(scope, task_id) do
      {:ok, task} ->
        todos_map = Todos.list_todos(task.interactions)

        todos_list =
          todos_map
          |> Map.values()
          |> Enum.sort_by(& &1.created_at, DateTime)

        {:ok, todos_list}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
