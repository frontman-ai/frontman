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

  @exports [
    TaskSchema,
    Interaction,
    Interaction.UserMessage,
    Interaction.AgentResponse,
    Interaction.AgentCompleted,
    Interaction.AgentError,
    Interaction.AgentPaused,
    Interaction.ToolCall,
    Interaction.ToolResult,
    RetryCoordinator,
    StreamCleanup,
    SwarmDispatcher,
    Todos.Todo
  ]

  use Boundary,
    deps: [
      FrontmanServer,
      FrontmanServer.Accounts,
      FrontmanServer.Providers
    ],
    exports: @exports

  require Logger

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Observability.TelemetryEvents
  alias FrontmanServer.Providers
  alias FrontmanServer.Repo

  alias FrontmanServer.Tasks.{
    Execution,
    Execution.ErrorClassifier,
    Interaction,
    InteractionSchema,
    TaskSchema,
    Todos
  }

  alias FrontmanServer.Workers.GenerateTitle

  @task_scoped_interaction_types Interaction.task_scoped_types()
  @agent_run_starter_interaction_types [:user_message, :agent_retry]
  @agent_run_terminal_interaction_types [:agent_completed, :agent_error, :agent_paused]
  @agent_run_interaction_types [:agent_response, :tool_call, :tool_result]

  @typep active_agent_run_error ::
           {:missing_turn_number, atom()} | {:unknown_interaction_type, atom()}

  # --- Authorization Helpers ---

  @spec get_task_by_id(Accounts.scope(), String.t()) ::
          {:ok, TaskSchema.t()} | {:error, :not_found}
  defp get_task_by_id(scope, task_id) do
    task_id
    |> TaskSchema.by_id_for_user(Accounts.scope_user_id(scope))
    |> Repo.one()
    |> task_lookup_result()
  end

  @spec get_task_by_id_for_update(Accounts.scope(), String.t()) ::
          {:ok, TaskSchema.t()} | {:error, :not_found}
  defp get_task_by_id_for_update(scope, task_id) do
    task_id
    |> TaskSchema.by_id_for_user(Accounts.scope_user_id(scope))
    |> TaskSchema.locked_for_update()
    |> Repo.one()
    |> task_lookup_result()
  end

  defp task_lookup_result(nil), do: {:error, :not_found}
  defp task_lookup_result(%TaskSchema{} = schema), do: {:ok, schema}

  # --- Task Management ---

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
  @spec get_task(Accounts.scope(), String.t()) :: {:ok, TaskSchema.t()} | {:error, :not_found}
  def get_task(scope, task_id) do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      {:ok, hydrate_task(schema)}
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
      short_desc: TaskSchema.default_title(),
      framework: framework,
      user_id: user_id
    }

    with {:ok, _schema} <- TaskSchema.create_changeset(attrs) |> Repo.insert() do
      {:ok, task_id}
    end
  end

  @spec hydrate_task(TaskSchema.t()) :: TaskSchema.t()
  defp hydrate_task(%TaskSchema{} = schema) do
    %{schema | interactions: load_interactions(schema.id)}
  end

  @spec load_interactions(String.t()) :: [Interaction.t()]
  defp load_interactions(task_id) do
    task_id
    |> load_interaction_rows()
    |> Enum.map(&InteractionSchema.to_struct/1)
  end

  defp load_interaction_rows(task_id) do
    InteractionSchema.for_task(task_id)
    |> InteractionSchema.ordered()
    |> Repo.all()
  end

  # --- Project Discovery ---

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
        record_interaction(schema, interaction)
      end
    end
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
        record_interaction(schema, interaction)
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

  # --- Interaction Persistence Helpers ---

  @spec record_interaction(TaskSchema.t(), Interaction.t(), keyword()) ::
          {:ok, Interaction.t()} | {:error, :not_found | Ecto.Changeset.t()}
  defp record_interaction(%TaskSchema{} = task, interaction, opts \\ []) do
    turn_number = Keyword.get(opts, :turn_number)

    with {:ok, interaction} <- append_interaction(task, interaction, turn_number) do
      broadcast_task(task.id, {:interaction, interaction, turn_number})
      {:ok, interaction}
    end
  end

  defp record_interaction(scope, task_id, interaction, turn_number)
       when is_integer(turn_number) and turn_number > 0 do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      record_interaction(schema, interaction, turn_number: turn_number)
    end
  end

  defp append_interaction(%TaskSchema{} = task, interaction, turn_number) do
    Repo.transact(fn ->
      with {:ok, _schema} <-
             InteractionSchema.create_changeset(task, interaction, turn_number)
             |> Repo.insert(),
           {1, _} <-
             TaskSchema
             |> TaskSchema.by_id(task.id)
             |> Repo.update_all(set: [updated_at: DateTime.utc_now(:second)]) do
        {:ok, interaction}
      else
        {:error, reason} -> {:error, reason}
        {0, _} -> {:error, :not_found}
      end
    end)
  end

  defp active_agent_run_turn_number(rows) do
    rows
    |> Enum.reduce_while(nil, fn
      %InteractionSchema{type: type, turn_number: nil}, active_run_turn_number
      when type in @task_scoped_interaction_types ->
        {:cont, active_run_turn_number}

      %InteractionSchema{type: type, turn_number: nil}, _active_run_turn_number ->
        {:halt, {:error, {:missing_turn_number, type}}}

      %InteractionSchema{type: type, turn_number: turn_number}, _active_run_turn_number
      when type in @agent_run_starter_interaction_types and
             is_integer(turn_number) and turn_number > 0 ->
        {:cont, turn_number}

      %InteractionSchema{type: type, turn_number: turn_number}, active_run_turn_number
      when type in @agent_run_terminal_interaction_types and
             turn_number == active_run_turn_number ->
        {:cont, nil}

      %InteractionSchema{type: type}, active_run_turn_number
      when type in @agent_run_terminal_interaction_types ->
        {:cont, active_run_turn_number}

      %InteractionSchema{type: type}, active_run_turn_number
      when type in @agent_run_interaction_types ->
        {:cont, active_run_turn_number}

      %InteractionSchema{type: type}, _active_run_turn_number ->
        {:halt, {:error, {:unknown_interaction_type, type}}}
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      active_run_turn_number -> {:ok, active_run_turn_number}
    end
  end

  defp next_turn_number(rows) do
    rows
    |> Enum.map(& &1.turn_number)
    |> Enum.reject(&is_nil/1)
    |> Enum.max(fn -> 0 end)
    |> Kernel.+(1)
  end

  defp latest_turn_number(rows), do: next_turn_number(rows) - 1

  @spec topic(String.t()) :: String.t()
  defp topic(task_id), do: "task:#{task_id}"

  @spec broadcast_task(String.t(), term()) :: :ok
  defp broadcast_task(task_id, message) do
    Phoenix.PubSub.broadcast(FrontmanServer.PubSub, topic(task_id), message)
  end

  @doc """
  Handles a SwarmAi execution event for a task.

  Durable events are persisted first from the SwarmAi task process. Streaming
  chunks are then broadcast for live subscribers.
  """
  def handle_swarm_event(scope, task_id, %{turn_number: turn_number, event: event} = context)
      when is_binary(task_id) and is_integer(turn_number) and turn_number > 0 do
    persist_swarm_event(scope, task_id, turn_number, event)

    broadcast_swarm_event(task_id, context)
  end

  # Scope may be nil for recovered processes after a monitor restart.
  # In that case we can only broadcast, not persist.
  defp persist_swarm_event(nil, _task_id, _turn_number, _event), do: :ok

  defp persist_swarm_event(%Scope{} = scope, task_id, turn_number, {:response, response}) do
    agent_replied(
      scope,
      task_id,
      turn_number,
      response.content || "",
      response_metadata(response)
    )
  end

  defp persist_swarm_event(%Scope{} = scope, task_id, turn_number, {:completed, _}) do
    {:ok, interaction} = record_agent_run_result(scope, task_id, turn_number, :completed)
    TelemetryEvents.task_stop(task_id)
    {:ok, interaction}
  end

  defp persist_swarm_event(
         %Scope{} = scope,
         task_id,
         turn_number,
         {:failed, %{reason: reason, loop_id: loop_id}}
       ) do
    {reason_str, category, retryable} = ErrorClassifier.classify_error(reason)

    Logger.error(
      "Execution failed for task #{task_id}, loop_id: #{loop_id}, reason: #{reason_str}"
    )

    Sentry.capture_message("Agent execution failed",
      level: :error,
      tags: %{error_type: "agent_execution_error"},
      extra: %{task_id: task_id, loop_id: loop_id, reason: reason_str}
    )

    {:ok, interaction} =
      record_agent_run_result(
        scope,
        task_id,
        turn_number,
        {:failed, reason_str, retryable, category}
      )

    TelemetryEvents.task_stop(task_id)
    {:ok, interaction}
  end

  defp persist_swarm_event(
         %Scope{} = scope,
         task_id,
         turn_number,
         {:crashed, %{reason: reason, stacktrace: stacktrace}}
       ) do
    Logger.error("Execution crashed for task #{task_id}, reason: #{inspect(reason)}")

    if is_exception(reason) do
      Sentry.capture_exception(reason,
        stacktrace: stacktrace,
        tags: %{error_type: "agent_crash"},
        extra: %{task_id: task_id}
      )
    else
      Sentry.capture_message("Agent execution crashed",
        level: :error,
        tags: %{error_type: "agent_crash"},
        extra: %{task_id: task_id, reason: inspect(reason)}
      )
    end

    {reason_str, _category, _retryable} = ErrorClassifier.classify_error(reason)

    {:ok, interaction} =
      record_agent_run_result(scope, task_id, turn_number, {:crashed, reason_str})

    TelemetryEvents.task_stop(task_id)
    {:ok, interaction}
  end

  defp persist_swarm_event(%Scope{} = scope, task_id, turn_number, {:cancelled, _}) do
    {:ok, interaction} = record_agent_run_result(scope, task_id, turn_number, :cancelled)
    TelemetryEvents.task_stop(task_id)
    {:ok, interaction}
  end

  defp persist_swarm_event(%Scope{} = scope, task_id, turn_number, {:terminated, _}) do
    Logger.info("Execution terminated by supervisor for task #{task_id}")

    unresolved_tool_calls = unresolved_tool_calls_for_turn(task_id, turn_number)

    {interactive_tool_calls, interrupted_tool_calls} =
      Enum.split_with(unresolved_tool_calls, &keeps_turn_open_after_restart?/1)

    Enum.each(interrupted_tool_calls, fn tool_call ->
      resolve_tool_request(
        scope,
        task_id,
        %{id: tool_call.tool_call_id, name: tool_call.tool_name},
        "Interrupted by restart",
        true,
        turn_number: turn_number
      )
    end)

    result =
      case interactive_tool_calls do
        [] -> record_agent_run_result(scope, task_id, turn_number, :terminated)
        [_ | _] -> :ok
      end

    TelemetryEvents.task_stop(task_id)
    result
  end

  defp persist_swarm_event(
         %Scope{} = scope,
         task_id,
         turn_number,
         {:paused, {:timeout, tool_call_id, tool_name, timeout_ms}}
       ) do
    reason = "Tool #{tool_name} timed out after #{timeout_ms}ms (on_timeout: :pause_agent)"

    resolve_tool_request(scope, task_id, %{id: tool_call_id, name: tool_name}, reason, true,
      turn_number: turn_number
    )

    {:ok, interaction} =
      record_agent_run_result(
        scope,
        task_id,
        turn_number,
        {:paused_for_tool_timeout, tool_name, timeout_ms}
      )

    TelemetryEvents.task_stop(task_id)
    {:ok, interaction}
  end

  defp persist_swarm_event(%Scope{}, _task_id, _turn_number, {:chunk, _}), do: :ok
  defp persist_swarm_event(%Scope{}, _task_id, _turn_number, {:tool_call, _}), do: :ok

  defp broadcast_swarm_event(task_id, %{turn_number: turn_number, event: {:chunk, chunk}}) do
    broadcast_task(task_id, {:execution_chunk, turn_number, chunk})
  end

  defp broadcast_swarm_event(_task_id, _context), do: :ok

  defp unresolved_tool_calls_for_turn(task_id, turn_number) do
    InteractionSchema.for_task(task_id)
    |> InteractionSchema.for_turn(turn_number)
    |> InteractionSchema.unresolved_tool_calls()
    |> InteractionSchema.ordered()
    |> Repo.all()
    |> Enum.map(&InteractionSchema.to_struct/1)
  end

  defp keeps_turn_open_after_restart?(%Interaction.ToolCall{tool_name: "question"}), do: true
  defp keeps_turn_open_after_restart?(%Interaction.ToolCall{}), do: false

  defp response_metadata(response) do
    meta = Map.get(response, :metadata) || %{}
    response_id = meta[:response_id]
    phase = meta[:phase]

    %{
      "tool_calls" => stored_tool_calls(Map.get(response, :tool_calls)),
      "reasoning_details" => non_empty(Map.get(response, :reasoning_details)),
      "response_id" => if(is_binary(response_id), do: response_id),
      "phase" => if(is_binary(phase), do: phase),
      "phase_items" => non_empty(meta[:phase_items])
    }
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp stored_tool_calls(tool_calls) when is_list(tool_calls) and tool_calls != [] do
    Enum.map(tool_calls, fn %SwarmAi.ToolCall{id: id, name: name, arguments: arguments} ->
      %{"id" => id, "name" => name, "arguments" => arguments}
    end)
  end

  defp stored_tool_calls(_tool_calls), do: nil

  defp non_empty(list) when is_list(list) and list != [], do: list
  defp non_empty(_list), do: nil

  # --- Conversation Lifecycle ---

  @doc """
  Submits a user prompt: persists the message and starts agent execution.

  This is the primary "user turn" use case — recording what the user said
  and kicking off the agent loop. If an execution is already running, the
  prompt is rejected entirely (nothing persisted).
  """
  @spec submit_user_message(Accounts.scope(), String.t(), list(), map()) ::
          {:ok, Interaction.UserMessage.t(), pos_integer()}
          | {:error,
             :already_running | :not_found | active_agent_run_error() | Ecto.Changeset.t()}
  def submit_user_message(scope, task_id, content_blocks, execution) do
    interaction = Interaction.UserMessage.new(content_blocks)

    case Repo.transact(fn -> insert_user_turn(scope, task_id, interaction) end) do
      {:ok, {schema, interaction, turn_number}} ->
        broadcast_task(schema.id, {:interaction, interaction, turn_number})

        run_task_execution(scope, task_id, execution, turn_number)

        case {turn_number, interaction.messages} do
          {1, [_ | _] = messages} ->
            model = execution.model |> Providers.resolve_model_string()

            GenerateTitle.new_job(scope, task_id, Enum.join(messages, "\n"), model)
            |> Oban.insert()

          _ ->
            :ok
        end

        {:ok, interaction, turn_number}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp insert_user_turn(scope, task_id, interaction) do
    # Lock task row so concurrent submissions serialize before calculating next turn number.
    case get_task_by_id_for_update(scope, task_id) do
      {:ok, schema} -> insert_user_turn(schema, interaction)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  defp insert_user_turn(%TaskSchema{} = schema, interaction) do
    rows = load_interaction_rows(schema.id)

    case active_agent_run_turn_number(rows) do
      {:ok, nil} -> insert_user_message(schema, interaction, next_turn_number(rows))
      {:ok, _turn_number} -> {:error, :already_running}
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert_user_message(schema, interaction, turn_number) do
    with {:ok, interaction} <- append_interaction(schema, interaction, turn_number) do
      {:ok, {schema, interaction, turn_number}}
    end
  end

  def agent_replied(scope, task_id, turn_number, content, metadata \\ %{})
      when is_integer(turn_number) and turn_number > 0 do
    record_interaction(
      scope,
      task_id,
      Interaction.AgentResponse.new(content, metadata),
      turn_number
    )
  end

  @doc "Records how the given agent run ended."
  def record_agent_run_result(scope, task_id, turn_number, outcome)
      when is_integer(turn_number) and turn_number > 0 do
    interaction =
      case outcome do
        :completed -> Interaction.AgentCompleted.new()
        :cancelled -> turn_error("Cancelled", "cancelled")
        :terminated -> turn_error("Terminated by supervisor", "terminated")
        {:failed, error} -> turn_error(error)
        {:failed, error, retry, category} -> turn_error(error, "failed", retry, category)
        {:crashed, error} -> turn_error(error, "crashed")
        {:paused_for_tool_timeout, tool, timeout} -> Interaction.AgentPaused.new(tool, timeout)
      end

    record_interaction(scope, task_id, interaction, turn_number)
  end

  defp turn_error(error, kind \\ "failed", retryable \\ false, category \\ "unknown"),
    do: Interaction.AgentError.new(error, kind, retryable, category)

  # --- Tool Requests ---

  @doc "Records a client-handled tool request in the given turn."
  def request_client_tool(scope, task_id, turn_number, %SwarmAi.ToolCall{} = tool_call_data)
      when is_integer(turn_number) and turn_number > 0 do
    with {:ok, schema} <- get_task_by_id(scope, task_id),
         {:ok, interaction} <- Interaction.ToolCall.new(tool_call_data) do
      record_interaction(schema, interaction, turn_number: turn_number)
    end
  end

  @doc """
  Resolves a tool request.

  Routes the result to the waiting executor so the agent can continue.
  Duplicate tool results for the same tool_call_id are prevented by a
  unique partial index on the interactions table.

  Returns `{:ok, interaction, :notified}` when a live executor received the result,
  `{:ok, interaction, :no_executor}` when no executor was waiting (e.g., server restart).
  """
  @spec resolve_tool_request(Accounts.scope(), String.t(), map(), term(), boolean(), keyword()) ::
          {:ok, Interaction.ToolResult.t(), :notified | :no_executor}
          | {:error, :not_found | Ecto.Changeset.t()}
  def resolve_tool_request(
        scope,
        task_id,
        %{id: tool_call_id, name: _} = tool_call_data,
        result,
        is_error \\ false,
        opts \\ []
      )
      when is_boolean(is_error) and is_list(opts) do
    with {:ok, schema} <- get_task_by_id(scope, task_id),
         turn_number = tool_result_turn_number(task_id, tool_call_id, opts),
         interaction = Interaction.ToolResult.new(tool_call_data, result, is_error),
         {:ok, interaction} <- record_interaction(schema, interaction, turn_number: turn_number) do
      executor_status = Execution.notify_tool_result(tool_call_id, result, is_error)

      {:ok, interaction, executor_status}
    end
  end

  defp tool_result_turn_number(task_id, tool_call_id, opts) do
    case Keyword.fetch(opts, :turn_number) do
      {:ok, turn_number} when is_integer(turn_number) and turn_number > 0 ->
        turn_number

      :error ->
        persisted_tool_call_turn_number(task_id, tool_call_id)
    end
  end

  defp persisted_tool_call_turn_number(task_id, tool_call_id) do
    row =
      InteractionSchema.for_task(task_id)
      |> InteractionSchema.of_type(Interaction.ToolCall)
      |> InteractionSchema.data_equals("tool_call_id", tool_call_id)
      |> Repo.one()

    case row do
      %InteractionSchema{turn_number: turn_number}
      when is_integer(turn_number) and turn_number > 0 ->
        turn_number
    end
  end

  @doc """
  Returns unresolved tool calls and turn number for the active agent run.

  A user message starts a turn and its first agent run. Agent retry starts a new
  agent run in the same turn. Agent completed, error, and paused interactions
  close only the active run attempt for their turn number.
  """
  def get_active_run_unresolved_tool_calls(scope, task_id) do
    with {:ok, _schema} <- get_task_by_id(scope, task_id) do
      rows = load_interaction_rows(task_id)

      case active_agent_run_turn_number(rows) do
        {:ok, nil} ->
          {:ok, :no_active_run}

        {:ok, turn_number} ->
          tool_calls =
            InteractionSchema.for_task(task_id)
            |> InteractionSchema.for_turn(turn_number)
            |> InteractionSchema.unresolved_tool_calls()
            |> InteractionSchema.ordered()
            |> Repo.all()
            |> Enum.map(&InteractionSchema.to_struct/1)

          {:ok, turn_number, tool_calls}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # --- Execution Management ---

  @doc "Records a retry request and starts execution."
  @spec retry_execution(Accounts.scope(), String.t(), String.t(), map()) ::
          :ok | :already_running | {:error, :not_found | :stale_turn | Ecto.Changeset.t()}
  def retry_execution(scope, task_id, retried_error_id, execution) do
    with {:ok, schema} <- get_task_by_id(scope, task_id),
         rows = load_interaction_rows(task_id),
         {:ok, turn_number} <- retry_turn_number(task_id, retried_error_id),
         :ok <- ensure_latest_retry_turn(turn_number, rows),
         {:ok, _retry} <-
           record_interaction(schema, Interaction.AgentRetry.new(retried_error_id),
             turn_number: turn_number
           ) do
      run_task_execution(scope, task_id, execution, turn_number)
    end
  end

  defp retry_turn_number(task_id, retried_error_id) do
    %InteractionSchema{turn_number: turn_number} =
      InteractionSchema.for_task(task_id)
      |> InteractionSchema.of_type(Interaction.AgentError)
      |> InteractionSchema.data_equals("id", retried_error_id)
      |> Repo.one()

    {:ok, turn_number}
  end

  defp ensure_latest_retry_turn(turn_number, rows) do
    if turn_number == latest_turn_number(rows), do: :ok, else: {:error, :stale_turn}
  end

  @doc "Resumes execution for the active agent run."
  @spec resume_execution(Accounts.scope(), String.t(), map()) ::
          :ok | :already_running | {:error, :not_found | :not_running | active_agent_run_error()}
  def resume_execution(scope, task_id, execution) do
    case get_task(scope, task_id) do
      {:ok, task} ->
        rows = load_interaction_rows(task_id)

        case active_agent_run_turn_number(rows) do
          {:ok, turn_number} when is_integer(turn_number) ->
            rows =
              InteractionSchema.for_task(task_id)
              |> InteractionSchema.up_to_turn(turn_number)
              |> InteractionSchema.ordered()
              |> Repo.all()

            run_execution(scope, task, execution_params(execution, rows, turn_number))

          {:ok, nil} ->
            {:error, :not_running}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Cancels a running execution for the given task.

  Verifies the task exists and belongs to the user before cancelling.
  """
  @spec cancel_execution(Accounts.scope(), String.t()) ::
          :ok | {:error, :not_found | :not_running}
  def cancel_execution(scope, task_id) do
    with {:ok, _schema} <- get_task_by_id(scope, task_id) do
      SwarmAi.cancel(FrontmanServer.AgentRuntime, task_id)
    end
  end

  defp run_task_execution(scope, task_id, execution, turn_number)
       when is_integer(turn_number) and turn_number > 0 do
    case get_task(scope, task_id) do
      {:ok, task} ->
        rows =
          InteractionSchema.for_task(task_id)
          |> InteractionSchema.up_to_turn(turn_number)
          |> InteractionSchema.ordered()
          |> Repo.all()

        run_execution(scope, task, execution_params(execution, rows, turn_number))

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  defp execution_params(
         %{
           tools: tools,
           model: model,
           project_traits: project_traits,
           backend_tool_modules: backend_tool_modules,
           mcp_tool_defs: mcp_tool_defs
         },
         rows,
         turn_number
       )
       when is_integer(turn_number) and turn_number > 0 do
    %{
      tools: tools,
      model: model,
      turn_number: turn_number,
      interaction_rows: rows,
      project_traits: project_traits,
      backend_tool_modules: backend_tool_modules,
      mcp_tool_defs: mcp_tool_defs
    }
  end

  defp run_execution(scope, task, %{turn_number: turn_number} = execution) do
    case Execution.run(scope, task, execution) do
      {:ok, :already_running} ->
        :already_running

      {:ok, _pid} ->
        :ok

      {:error, reason} ->
        message = Execution.error_message(scope, reason)
        {:ok, _error} = record_agent_run_result(scope, task.id, turn_number, {:failed, message})
        broadcast_task(task.id, {:execution_start_error, message, turn_number})

        :ok
    end
  end

  @doc """
  Applies a suggested title while the task still has its default title.

  Called by the `GenerateTitle` Oban worker after the LLM suggests a title.
  """
  @spec apply_title_suggestion(Accounts.scope(), String.t(), String.t()) ::
          :ok | {:error, :not_found | Ecto.Changeset.t()}
  def apply_title_suggestion(scope, task_id, title) do
    default_title = TaskSchema.default_title()

    with {:ok, %TaskSchema{short_desc: ^default_title} = schema} <- get_task_by_id(scope, task_id),
         {:ok, _updated} <-
           schema
           |> TaskSchema.update_changeset(%{short_desc: title})
           |> Repo.update() do
      broadcast_task(task_id, {:task_title_changed, task_id, title})
    else
      {:ok, %TaskSchema{}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # --- Todos ---

  @doc """
  Lists all todos for a task.

  Todos are managed through tool calls, not direct API calls.
  This function is for reading the current todos only.
  """
  @spec list_todos(Accounts.scope(), String.t()) ::
          {:ok, [Todos.Todo.t()]} | {:error, :not_found}
  def list_todos(scope, task_id) do
    with {:ok, task} <- get_task(scope, task_id) do
      todos =
        task.interactions
        |> Todos.list_todos()
        |> Map.values()
        |> Enum.sort_by(& &1.created_at, DateTime)

      {:ok, todos}
    end
  end
end
