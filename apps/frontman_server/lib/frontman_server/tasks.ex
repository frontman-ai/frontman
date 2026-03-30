defmodule FrontmanServer.Tasks do
  @moduledoc """
  Public API for task management.

  Tasks are containers for interactions in a conversation with agents.
  Each task represents a conversation thread with an AI agent.

  This context provides the boundary for all task-related operations,
  delegating to the domain layer and infrastructure as appropriate.
  """
  require Logger

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers.Model
  alias FrontmanServer.Repo

  alias FrontmanServer.Tasks.{
    Execution,
    Interaction,
    InteractionSchema,
    Task,
    TaskSchema
  }

  alias FrontmanServer.Workers.GenerateTitle
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
  Persists a generated title and broadcasts it to subscribers on the task topic.

  Called by the `GenerateTitle` Oban worker after the LLM produces a title.
  """
  @spec set_generated_title(Scope.t(), String.t(), String.t()) ::
          :ok | {:error, :not_found | Ecto.Changeset.t()}
  def set_generated_title(%Scope{} = scope, task_id, title) do
    with {:ok, schema} <- get_task_by_id(scope, task_id),
         {:ok, _updated} <-
           schema
           |> TaskSchema.update_changeset(%{short_desc: title})
           |> Repo.update() do
      broadcast_task(task_id, {:title_updated, task_id, title})
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
  Adds a discovered project rule to the task.

  Deduplicates by path - returns `{:ok, :already_loaded}` if already present.
  """
  @spec add_discovered_project_rule(Scope.t(), String.t(), String.t(), String.t()) ::
          {:ok, Interaction.DiscoveredProjectRule.t() | :already_loaded}
          | {:error, :not_found}
  def add_discovered_project_rule(%Scope{} = scope, task_id, path, content) do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      interactions = load_interactions(task_id)

      if rule_loaded?(interactions, path) do
        {:ok, :already_loaded}
      else
        interaction = Interaction.DiscoveredProjectRule.new(path, content)
        append_interaction(schema, interaction)
      end
    end
  end

  @spec rule_loaded?([Interaction.t()], String.t()) :: boolean()
  defp rule_loaded?(interactions, path) do
    Enum.any?(interactions, fn
      %Interaction.DiscoveredProjectRule{path: p} -> p == path
      _ -> false
    end)
  end

  @doc """
  Stores the discovered project structure summary for a task.
  Called during MCP initialization after `list_tree` returns.
  """
  @spec add_discovered_project_structure(Scope.t(), String.t(), String.t()) ::
          {:ok, Interaction.DiscoveredProjectStructure.t()}
          | {:ok, :already_loaded}
          | {:error, :not_found}
  def add_discovered_project_structure(%Scope{} = scope, task_id, summary) do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      interactions = load_interactions(task_id)

      if Enum.any?(interactions, &match?(%Interaction.DiscoveredProjectStructure{}, &1)) do
        {:ok, :already_loaded}
      else
        interaction = Interaction.DiscoveredProjectStructure.new(summary)
        append_interaction(schema, interaction)
      end
    end
  end

  @spec append_interaction(TaskSchema.t(), Interaction.t()) ::
          {:ok, Interaction.t()} | {:error, Ecto.Changeset.t()}
  defp append_interaction(%TaskSchema{id: task_id}, interaction) do
    case InteractionSchema.create_changeset(task_id, interaction) |> Repo.insert() do
      {:ok, schema} ->
        interaction = %{interaction | sequence: schema.sequence}
        touch_task(task_id)
        broadcast_task(task_id, {:interaction, interaction})
        {:ok, interaction}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # Bump the task's updated_at so it sorts to the top of the sessions list
  defp touch_task(task_id) do
    TaskSchema
    |> TaskSchema.by_id(task_id)
    |> Repo.update_all(set: [updated_at: DateTime.utc_now(:second)])
  end

  @spec broadcast_task(String.t(), term()) :: :ok
  defp broadcast_task(task_id, message) do
    Phoenix.PubSub.broadcast(FrontmanServer.PubSub, topic(task_id), message)
  end

  @doc """
  Submits a user prompt: persists the message and starts agent execution.

  This is the primary "user turn" use case — recording what the user said
  and kicking off the agent loop. If an execution is already running, the
  message is persisted but no new run is started.
  """
  @spec submit_user_message(Scope.t(), String.t(), list(), list(), keyword()) ::
          {:ok, Interaction.UserMessage.t()} | {:error, :not_found}
  def submit_user_message(%Scope{} = scope, task_id, content_blocks, tools, opts \\ []) do
    with {:ok, schema} <- get_task_by_id(scope, task_id),
         interaction = Interaction.UserMessage.new(content_blocks),
         {:ok, interaction} <- append_interaction(schema, interaction) do
      maybe_start_execution(scope, task_id, tools, opts)
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
  Creates and appends an AgentError interaction.

  `kind` is one of "failed", "crashed", or "cancelled".
  """
  @spec add_agent_error(Scope.t(), String.t(), String.t(), String.t()) ::
          {:ok, Interaction.AgentError.t()} | {:error, :not_found}
  def add_agent_error(%Scope{} = scope, task_id, error, kind \\ "failed") do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      interaction = Interaction.AgentError.new(error, kind)
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

  Routes the result to the waiting executor so the agent can continue.
  Duplicate tool results for the same tool_call_id are prevented by a
  unique partial index on the interactions table.

  Returns `{:ok, interaction, :notified}` when a live executor received the result,
  `{:ok, interaction, :no_executor}` when no executor was waiting (e.g., server restart).
  """
  @spec add_tool_result(Scope.t(), String.t(), map(), term(), boolean()) ::
          {:ok, Interaction.ToolResult.t(), :notified | :no_executor}
          | {:error, :not_found | Ecto.Changeset.t()}
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
      executor_status = Execution.notify_tool_result(scope, tool_call_id, result, is_error)
      {:ok, interaction, executor_status}
    end
  end

  # --- Execution Management ---

  @doc """
  Cancels a running execution for the given task.

  Verifies the task exists and belongs to the user before cancelling.
  """
  @spec cancel_execution(Scope.t(), String.t()) :: :ok | {:error, :not_running}
  def cancel_execution(%Scope{} = scope, task_id) do
    Execution.cancel(scope, task_id)
  end

  # --- Title Generation ---

  @doc """
  Enqueues an Oban job to generate a title for a task from the user's prompt.
  """
  @spec enqueue_title_generation(Scope.t(), String.t(), String.t(), keyword()) ::
          {:ok, Oban.Job.t()} | {:error, Oban.Job.changeset()}
  def enqueue_title_generation(%Scope{} = scope, task_id, user_prompt_text, opts \\ []) do
    env_api_key = Keyword.get(opts, :env_api_key, %{})
    model = opts |> Keyword.get(:model) |> Model.resolve_string()

    GenerateTitle.new_job(scope.user.id, task_id, user_prompt_text, model, env_api_key)
    |> Oban.insert()
  end

  @doc """
  Starts an execution if none is already running for this task.
  Fetches the task and delegates to Execution.run.
  """
  @spec maybe_start_execution(Scope.t(), String.t(), list(), keyword()) :: :ok
  def maybe_start_execution(scope, task_id, tools, opts) do
    if Execution.running?(scope, task_id) do
      :ok
    else
      {:ok, task} = get_task(scope, task_id)

      case Execution.run(scope, task, Keyword.merge([tools: tools], opts)) do
        {:ok, _pid_or_already_running} ->
          :ok

        {:error, reason} ->
          # Broadcast as :execution_start_error so TaskChannel can handle it.
          # This is NOT a swarm_event (the agent never started), so we use a
          # separate message shape to avoid double-wrapping.
          Phoenix.PubSub.broadcast(
            FrontmanServer.PubSub,
            topic(task_id),
            {:execution_start_error, Execution.error_message(scope, reason)}
          )

          :ok
      end
    end
  end

  alias FrontmanServer.Tasks.Todos

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
