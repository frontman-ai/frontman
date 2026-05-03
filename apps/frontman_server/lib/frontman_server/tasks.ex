# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks do
  @moduledoc """
  Public API for task management.

  Tasks are containers for interactions in a conversation with agents.
  Each task represents a conversation thread with an AI agent.

  This context provides the boundary for all task-related operations,
  delegating to the domain layer and infrastructure as appropriate.
  """

  use Boundary,
    deps: [FrontmanServer, FrontmanServer.Accounts, FrontmanServer.Providers],
    exports: [
      Task,
      TaskSchema,
      Interaction,
      Interaction.UserMessage,
      Interaction.AgentResponse,
      Interaction.AgentCompleted,
      Interaction.AgentError,
      Interaction.ToolCall,
      Interaction.ToolResult,
      InteractionSchema,
      Execution,
      Execution.Framework,
      ExecutionEvent,
      RetryCoordinator,
      StreamCleanup,
      StreamStallTimeout,
      SwarmDispatcher,
      Todos,
      Todos.Todo,
      {MessageOptimizer, []}
    ]

  alias FrontmanServer.Accounts
  alias FrontmanServer.Providers
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

  @spec get_task_by_id(Accounts.scope(), String.t()) ::
          {:ok, TaskSchema.t()} | {:error, :not_found}
  defp get_task_by_id(scope, task_id) do
    user_id = Accounts.scope_user_id(scope)

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

  @spec list_tasks(Accounts.scope()) :: {:ok, [TaskSchema.t()]}
  def list_tasks(scope) do
    user_id = Accounts.scope_user_id(scope)

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
  @spec get_task(Accounts.scope(), String.t()) :: {:ok, Task.t()} | {:error, :not_found}
  def get_task(scope, task_id) do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      {:ok, schema_to_task(schema)}
    end
  end

  @doc """
  Deletes a task and all its interactions.

  Requires authorization - scope.user.id must match task.user_id.
  Cascade deletes configured in migration handle interaction cleanup.
  """
  @spec delete_task(Accounts.scope(), String.t()) :: :ok | {:error, :not_found}
  def delete_task(scope, task_id) do
    with {:ok, schema} <- get_task_by_id(scope, task_id),
         {:ok, _} <- Repo.delete(schema) do
      :ok
    end
  end

  @doc """
  Gets a task's short description (title) without loading interactions.

  Lightweight query for cases where only the title is needed (e.g., title generation check).
  """
  @spec get_short_desc(Accounts.scope(), String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def get_short_desc(scope, task_id) do
    case get_task_by_id(scope, task_id) do
      {:ok, schema} -> {:ok, schema.short_desc}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  Persists a generated title and broadcasts it to subscribers on the task topic.

  Called by the `GenerateTitle` Oban worker after the LLM produces a title.
  """
  @spec set_generated_title(Accounts.scope(), String.t(), String.t()) ::
          :ok | {:error, :not_found | Ecto.Changeset.t()}
  def set_generated_title(scope, task_id, title) do
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
    |> InteractionSchema.ordered()
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
  @spec create_task(Accounts.scope(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def create_task(scope, task_id, framework) do
    user_id = Accounts.scope_user_id(scope)

    attrs = %{
      id: task_id,
      short_desc: Task.short_description(task_id),
      framework: framework,
      user_id: user_id
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
  @spec add_discovered_project_rule(Accounts.scope(), String.t(), String.t(), String.t()) ::
          {:ok, Interaction.DiscoveredProjectRule.t() | :already_loaded}
          | {:error, :not_found}
  def add_discovered_project_rule(scope, task_id, path, content) do
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
  @spec add_discovered_project_structure(Accounts.scope(), String.t(), String.t()) ::
          {:ok, Interaction.DiscoveredProjectStructure.t()}
          | {:ok, :already_loaded}
          | {:error, :not_found}
  def add_discovered_project_structure(scope, task_id, summary) do
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
  defp append_interaction(%TaskSchema{} = task, interaction) do
    case InteractionSchema.create_changeset(task, interaction) |> Repo.insert() do
      {:ok, _schema} ->
        touch_task(task.id)
        broadcast_task(task.id, {:interaction, interaction})
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
  prompt is rejected entirely (nothing persisted).
  """
  @spec submit_user_message(Accounts.scope(), String.t(), list(), list(), keyword()) ::
          {:ok, Interaction.UserMessage.t()} | {:error, :already_running} | {:error, :not_found}
  def submit_user_message(scope, task_id, content_blocks, tools, opts \\ []) do
    with :ok <- guard_not_running(scope, task_id),
         {:ok, interaction} <- add_user_message(scope, task_id, content_blocks) do
      opts = Keyword.put(opts, :interaction_id, interaction.id)
      maybe_start_execution(scope, task_id, tools, opts)
      {:ok, interaction}
    end
  end

  defp guard_not_running(scope, task_id) do
    if Execution.running?(scope, task_id), do: {:error, :already_running}, else: :ok
  end

  @doc """
  Persists a user message without starting execution.

  Use this when you need to record a user message in the conversation history
  but don't want to trigger the agent loop (e.g., populating history for tests
  or replaying messages).
  """
  @spec add_user_message(Accounts.scope(), String.t(), list()) ::
          {:ok, Interaction.UserMessage.t()} | {:error, :not_found}
  def add_user_message(scope, task_id, content_blocks) do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      interaction = Interaction.UserMessage.new(content_blocks)
      append_interaction(schema, interaction)
    end
  end

  @doc """
  Creates and appends an AgentResponse interaction.
  """
  @spec add_agent_response(Accounts.scope(), String.t(), String.t(), map()) ::
          {:ok, Interaction.AgentResponse.t()} | {:error, :not_found}
  def add_agent_response(scope, task_id, content, metadata \\ %{}) do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      interaction = Interaction.AgentResponse.new(content, metadata)
      append_interaction(schema, interaction)
    end
  end

  @doc """
  Creates and appends an AgentCompleted interaction.
  """
  @spec add_agent_completed(Accounts.scope(), String.t(), term()) ::
          {:ok, Interaction.AgentCompleted.t()} | {:error, :not_found}
  def add_agent_completed(scope, task_id, result \\ nil) do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      interaction = Interaction.AgentCompleted.new(result)
      append_interaction(schema, interaction)
    end
  end

  @doc """
  Creates and appends an AgentPaused interaction.

  Called when the agent loop is paused due to a tool timeout with `on_timeout: :pause_agent`.
  """
  @spec add_agent_paused(Accounts.scope(), String.t(), String.t(), pos_integer()) ::
          {:ok, Interaction.AgentPaused.t()} | {:error, :not_found}
  def add_agent_paused(scope, task_id, tool_name, timeout_ms) do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      interaction = Interaction.AgentPaused.new(tool_name, timeout_ms)
      append_interaction(schema, interaction)
    end
  end

  @doc """
  Creates and appends an AgentError interaction.

  `kind` is one of "failed", "crashed", "cancelled", or "terminated".
  """
  @spec add_agent_error(
          Accounts.scope(),
          String.t(),
          String.t(),
          String.t(),
          boolean(),
          String.t()
        ) ::
          {:ok, Interaction.AgentError.t()} | {:error, :not_found}
  def add_agent_error(
        scope,
        task_id,
        error,
        kind \\ "failed",
        retryable \\ false,
        category \\ "unknown"
      ) do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      interaction = Interaction.AgentError.new(error, kind, retryable, category)
      append_interaction(schema, interaction)
    end
  end

  @doc """
  Creates and appends an AgentRetry interaction.
  """
  @spec add_agent_retry(Accounts.scope(), String.t(), String.t()) ::
          {:ok, Interaction.AgentRetry.t()} | {:error, :not_found}
  def add_agent_retry(scope, task_id, retried_error_id) do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      interaction = Interaction.AgentRetry.new(retried_error_id)
      append_interaction(schema, interaction)
    end
  end

  @doc """
  Creates and appends a ToolCall interaction.
  """
  @spec add_tool_call(Accounts.scope(), String.t(), ToolCall.t()) ::
          {:ok, Interaction.ToolCall.t()} | {:error, :not_found}
  def add_tool_call(scope, task_id, %ToolCall{} = tool_call_data) do
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
  @spec add_tool_result(Accounts.scope(), String.t(), map(), term(), boolean()) ::
          {:ok, Interaction.ToolResult.t(), :notified | :no_executor}
          | {:error, :not_found | Ecto.Changeset.t()}
  def add_tool_result(
        scope,
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
  @spec cancel_execution(Accounts.scope(), String.t()) :: :ok | {:error, :not_running}
  def cancel_execution(scope, task_id) do
    Execution.cancel(scope, task_id)
  end

  # --- Title Generation ---

  @doc """
  Enqueues an Oban job to generate a title for a task from the user's prompt.
  """
  @spec enqueue_title_generation(Accounts.scope(), String.t(), String.t(), keyword()) ::
          {:ok, Oban.Job.t()} | {:error, Oban.Job.changeset()}
  def enqueue_title_generation(scope, task_id, user_prompt_text, opts \\ []) do
    model = opts |> Keyword.get(:model) |> Providers.resolve_model_string()

    GenerateTitle.new_job(scope, task_id, user_prompt_text, model)
    |> Oban.insert()
  end

  @doc """
  Starts an execution if none is already running for this task.
  Fetches the task and delegates to Execution.run.
  """
  @spec maybe_start_execution(Accounts.scope(), String.t(), list(), keyword()) ::
          :ok | :already_running
  def maybe_start_execution(scope, task_id, tools, opts) do
    if Execution.running?(scope, task_id) do
      :already_running
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

  @doc false
  @spec wrap_stream(Enumerable.t(), (-> term())) :: Enumerable.t()
  defdelegate wrap_stream(stream, cancel_fn), to: FrontmanServer.Tasks.StreamCleanup

  alias FrontmanServer.Tasks.Todos

  @doc """
  Lists all todos for a task.

  Todos are managed through tool calls, not direct API calls.
  This function is for reading the current state only.
  """
  @spec list_todos(Accounts.scope(), String.t()) ::
          {:ok, [Todos.Todo.t()]} | {:error, :not_found}
  def list_todos(scope, task_id) do
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
