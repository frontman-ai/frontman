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
    deps: [
      FrontmanServer,
      FrontmanServer.Accounts,
      FrontmanServer.Providers,
      FrontmanServer.Frameworks
    ],
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
      Execution.LLMProvider,
      ExecutionEvent,
      RetryCoordinator,
      StreamCleanup,
      StreamStallTimeout,
      SwarmDispatcher,
      Todos,
      Todos.Todo,
      {Execution.LLMRequestPreflight, []}
    ]

  require Logger

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Frameworks
  alias FrontmanServer.Observability.TelemetryEvents
  alias FrontmanServer.Providers
  alias FrontmanServer.Repo
  import Ecto.Query, only: [from: 2]

  alias FrontmanServer.Tasks.{
    Execution,
    ExecutionEvent,
    Interaction,
    InteractionSchema,
    Task,
    TaskSchema,
    Todos
  }

  alias FrontmanServer.Workers.GenerateTitle

  # --- Authorization Helpers ---

  @spec get_task_by_id(Accounts.scope(), String.t()) ::
          {:ok, TaskSchema.t()} | {:error, :not_found}
  @spec get_task_by_id(Accounts.scope(), String.t(), keyword()) ::
          {:ok, TaskSchema.t()} | {:error, :not_found}
  defp get_task_by_id(scope, task_id, opts \\ []) do
    user_id = Accounts.scope_user_id(scope)

    query =
      TaskSchema
      |> TaskSchema.by_id(task_id)
      |> TaskSchema.for_user(user_id)

    query =
      if Keyword.get(opts, :lock, false), do: from(t in query, lock: "FOR UPDATE"), else: query

    case Repo.one(query) do
      nil -> {:error, :not_found}
      schema -> {:ok, schema}
    end
  end

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
      short_desc: Task.default_title(),
      framework: framework,
      user_id: user_id
    }

    with {:ok, _schema} <- TaskSchema.create_changeset(attrs) |> Repo.insert() do
      {:ok, task_id}
    end
  end

  @spec schema_to_task(TaskSchema.t()) :: Task.t()
  defp schema_to_task(schema) do
    interactions = load_interactions(schema.id)

    %Task{
      task_id: schema.id,
      short_desc: schema.short_desc,
      framework: Frameworks.from_string(schema.framework),
      interactions: interactions
    }
  end

  @spec load_interactions(String.t()) :: [Interaction.t()]
  defp load_interactions(task_id) do
    task_id
    |> load_interaction_rows()
    |> Enum.map(&InteractionSchema.to_struct/1)
  end

  @spec load_interaction_rows(String.t()) :: [InteractionSchema.t()]
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
          {:ok, Interaction.t()} | {:error, Ecto.Changeset.t()}
  defp record_interaction(%TaskSchema{} = task, interaction, opts \\ []) do
    with {:ok, _schema} <-
           InteractionSchema.create_changeset(task, interaction, Keyword.get(opts, :turn_number))
           |> Repo.insert() do
      mark_task_updated(task.id)
      broadcast_task(task.id, {:interaction, interaction})
      {:ok, interaction}
    end
  end

  defp record_interaction(scope, task_id, interaction, turn_number)
       when is_integer(turn_number) and turn_number > 0 do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      record_interaction(schema, interaction, turn_number: turn_number)
    end
  end

  # Bump the task's updated_at so it sorts to the top of the sessions list.
  defp mark_task_updated(task_id) do
    TaskSchema
    |> TaskSchema.by_id(task_id)
    |> Repo.update_all(set: [updated_at: DateTime.utc_now(:second)])
  end

  defp open_turn(rows) do
    rows
    |> Enum.with_index()
    |> Enum.reduce(nil, fn
      {%InteractionSchema{type: type, turn_number: nil}, _index}, active_turn
      when type in ["discovered_project_rule", "discovered_project_structure"] ->
        active_turn

      {%InteractionSchema{type: type, turn_number: nil}, _index}, _active_turn ->
        raise "Missing turn_number for turn-scoped interaction type: #{type}"

      {%InteractionSchema{type: type, turn_number: turn_number}, index}, _active_turn
      when type in ["user_message", "agent_retry"] and
             is_integer(turn_number) and turn_number > 0 ->
        {turn_number, index}

      {%InteractionSchema{type: type, turn_number: row_turn_number}, _index},
      {turn_number, _start_index}
      when type in ["agent_completed", "agent_error", "agent_paused"] and
             row_turn_number == turn_number ->
        nil

      {%InteractionSchema{type: type}, _index}, active_turn
      when type in ["agent_completed", "agent_error", "agent_paused"] ->
        active_turn

      {%InteractionSchema{type: type}, _index}, active_turn
      when type in ["agent_response", "tool_call", "tool_result"] ->
        active_turn

      {%InteractionSchema{type: type}, _index}, _active_turn ->
        raise "Unknown interaction type while finding open turn: #{type}"
    end)
  end

  defp next_turn_number(rows) do
    rows
    |> Enum.map(& &1.turn_number)
    |> Enum.reject(&is_nil/1)
    |> Enum.max(fn -> 0 end)
    |> Kernel.+(1)
  end

  defp open_turn_number!(task_id) do
    case task_id |> load_interaction_rows() |> open_turn() do
      {turn_number, _index} -> turn_number
      nil -> raise "Cannot start execution for #{task_id}: task has no open turn"
    end
  end

  @spec topic(String.t()) :: String.t()
  defp topic(task_id), do: "task:#{task_id}"

  @spec broadcast_task(String.t(), term()) :: :ok
  defp broadcast_task(task_id, message) do
    Phoenix.PubSub.broadcast(FrontmanServer.PubSub, topic(task_id), message)
  end

  @doc """
  Handles a SwarmAi execution event for a task.

  All durable events are persisted first from the SwarmAi task process, then a
  task-domain execution event is broadcast for live subscribers.
  """
  @spec handle_swarm_event(Accounts.scope() | nil, String.t(), pos_integer(), {atom(), term()}) ::
          :ok | {:error, term()}
  def handle_swarm_event(scope, task_id, turn_number, {type, payload} = event)
      when is_binary(task_id) and is_integer(turn_number) and turn_number > 0 do
    _ = persist_swarm_event(scope, task_id, turn_number, event)

    broadcast_task(
      task_id,
      {:execution_event,
       %ExecutionEvent{
         type: type,
         payload: payload,
         turn_number: turn_number
       }}
    )
  end

  # Scope may be nil for recovered processes after a monitor restart.
  # In that case we can only broadcast, not persist.
  defp persist_swarm_event(nil, _task_id, _turn_number, _event), do: :ok

  # Agent produced a response (may include tool calls in metadata).
  defp persist_swarm_event(%Scope{} = scope, task_id, turn_number, {:response, response}) do
    metadata = response_metadata(response)
    agent_replied(scope, task_id, turn_number, response.content || "", metadata)
  end

  # Agent turn completed successfully.
  defp persist_swarm_event(%Scope{} = scope, task_id, turn_number, {:completed, _}) do
    end_agent_turn(scope, task_id, turn_number, :completed)
    TelemetryEvents.task_stop(task_id)
  end

  # Agent turn failed (LLM error, tool error, etc.)
  defp persist_swarm_event(
         %Scope{} = scope,
         task_id,
         turn_number,
         {:failed, %{reason: reason, loop_id: loop_id}}
       ) do
    {reason_str, category, retryable} = ExecutionEvent.classify_error(reason)

    Logger.error(
      "Execution failed for task #{task_id}, loop_id: #{loop_id}, reason: #{reason_str}"
    )

    Sentry.capture_message("Agent execution failed",
      level: :error,
      tags: %{error_type: "agent_execution_error"},
      extra: %{task_id: task_id, loop_id: loop_id, reason: reason_str}
    )

    end_agent_turn(scope, task_id, turn_number, {:failed, reason_str, retryable, category})
    TelemetryEvents.task_stop(task_id)
  end

  # Agent process crashed unexpectedly.
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

    end_agent_turn(scope, task_id, turn_number, {:crashed, format_crash_reason(reason)})
    TelemetryEvents.task_stop(task_id)
  end

  # Agent was cancelled (user requested cancel).
  defp persist_swarm_event(%Scope{} = scope, task_id, turn_number, {:cancelled, _}) do
    end_agent_turn(scope, task_id, turn_number, :cancelled)
    TelemetryEvents.task_stop(task_id)
  end

  # Agent was terminated by supervisor (e.g. :rest_for_one restart).
  # No Sentry alert -- this is infrastructure recovery, not a bug.
  defp persist_swarm_event(%Scope{} = scope, task_id, turn_number, {:terminated, _}) do
    Logger.info("Execution terminated by supervisor for task #{task_id}")
    end_agent_turn(scope, task_id, turn_number, :terminated)
    TelemetryEvents.task_stop(task_id)
  end

  # Agent loop paused due to a tool's on_timeout: :pause_agent.
  # Persist a timeout ToolResult first, then AgentPaused.
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

    end_agent_turn(
      scope,
      task_id,
      turn_number,
      {:paused_for_tool_timeout, tool_name, timeout_ms}
    )

    TelemetryEvents.task_stop(task_id)
  end

  # Streaming chunks are ephemeral, so no persistence needed.
  defp persist_swarm_event(_scope, _task_id, _turn_number, {:chunk, _}), do: :ok

  # Tool calls are persisted by ToolExecutor directly.
  defp persist_swarm_event(_scope, _task_id, _turn_number, {:tool_call, _}), do: :ok

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

  defp format_crash_reason(reason) do
    "Execution crashed: #{format_error_reason(reason)}"
  end

  defp format_error_reason(reason) when is_exception(reason), do: Exception.message(reason)
  defp format_error_reason(reason) when is_binary(reason), do: reason
  defp format_error_reason(reason), do: inspect(reason)

  # --- Turn Lifecycle ---

  @doc """
  Submits a user prompt: persists the message and starts agent execution.

  This is the primary "user turn" use case — recording what the user said
  and kicking off the agent loop. If an execution is already running, the
  prompt is rejected entirely (nothing persisted).
  """
  @spec submit_user_message(Accounts.scope(), String.t(), list(), list(), keyword()) ::
          {:ok, Interaction.UserMessage.t(), pos_integer()}
          | {:error, :already_running | :not_found | Ecto.Changeset.t()}
  def submit_user_message(scope, task_id, content_blocks, tools, opts \\ []) do
    interaction = Interaction.UserMessage.new(content_blocks)

    case Repo.transaction(fn -> insert_user_turn(scope, task_id, interaction) end) do
      {:ok, {schema, interaction, turn_number}} ->
        mark_task_updated(schema.id)
        broadcast_task(schema.id, {:interaction, interaction})

        opts = Keyword.put(opts, :turn_number, turn_number)

        start_execution(scope, task_id, tools, opts)

        case {turn_number, interaction.messages} do
          {1, [_ | _] = messages} ->
            model = opts |> Keyword.get(:model) |> Providers.resolve_model_string()

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
    case get_task_by_id(scope, task_id, lock: true) do
      {:ok, schema} -> insert_user_turn(schema, interaction)
      {:error, :not_found} -> Repo.rollback(:not_found)
    end
  end

  defp insert_user_turn(%TaskSchema{} = schema, interaction) do
    rows = load_interaction_rows(schema.id)

    case open_turn(rows) do
      nil -> insert_user_message(schema, interaction, next_turn_number(rows))
      {_turn_number, _index} -> Repo.rollback(:already_running)
    end
  end

  defp insert_user_message(schema, interaction, turn_number) do
    case InteractionSchema.create_changeset(schema, interaction, turn_number) |> Repo.insert() do
      {:ok, _schema} -> {schema, interaction, turn_number}
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  @typep agent_turn_outcome ::
           :completed
           | :cancelled
           | :terminated
           | {:failed, String.t()}
           | {:failed, String.t(), boolean(), String.t()}
           | {:crashed, term()}
           | {:paused_for_tool_timeout, String.t(), pos_integer()}

  @doc "Records an agent reply in the given turn."
  @spec agent_replied(Accounts.scope(), String.t(), pos_integer(), String.t(), map()) ::
          {:ok, Interaction.AgentResponse.t()} | {:error, :not_found}
  def agent_replied(scope, task_id, turn_number, content, metadata \\ %{})
      when is_integer(turn_number) and turn_number > 0 do
    record_interaction(
      scope,
      task_id,
      Interaction.AgentResponse.new(content, metadata),
      turn_number
    )
  end

  @doc "Records how the given agent turn ended."
  @spec end_agent_turn(Accounts.scope(), String.t(), pos_integer(), agent_turn_outcome()) ::
          {:ok,
           Interaction.AgentCompleted.t()
           | Interaction.AgentPaused.t()
           | Interaction.AgentError.t()}
          | {:error, :not_found}
  def end_agent_turn(scope, task_id, turn_number, outcome)
      when is_integer(turn_number) and turn_number > 0 do
    record_interaction(scope, task_id, agent_turn_outcome_interaction(outcome), turn_number)
  end

  defp agent_turn_outcome_interaction(:completed), do: Interaction.AgentCompleted.new()
  defp agent_turn_outcome_interaction(:cancelled), do: turn_error("Cancelled", "cancelled")

  defp agent_turn_outcome_interaction(:terminated),
    do: turn_error("Terminated by supervisor", "terminated")

  defp agent_turn_outcome_interaction({:failed, error}), do: turn_error(error)

  defp agent_turn_outcome_interaction({:failed, error, retryable, category}),
    do: turn_error(error, "failed", retryable, category)

  defp agent_turn_outcome_interaction({:crashed, error}), do: turn_error(error, "crashed")

  defp agent_turn_outcome_interaction({:paused_for_tool_timeout, tool_name, timeout_ms}),
    do: Interaction.AgentPaused.new(tool_name, timeout_ms)

  defp turn_error(error, kind \\ "failed", retryable \\ false, category \\ "unknown"),
    do: Interaction.AgentError.new(error, kind, retryable, category)

  # --- Tool Requests ---

  @doc "Records a client-handled tool request in the given turn."
  @spec request_client_tool(Accounts.scope(), String.t(), pos_integer(), SwarmAi.ToolCall.t()) ::
          {:ok, Interaction.ToolCall.t()}
          | {:error, :not_found | {:invalid_tool_arguments, String.t()}}
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
         turn_number = tool_result_turn_number!(task_id, tool_call_id, opts),
         interaction = Interaction.ToolResult.new(tool_call_data, result, is_error),
         {:ok, interaction} <- record_interaction(schema, interaction, turn_number: turn_number) do
      executor_status = Execution.notify_tool_result(tool_call_id, result, is_error)

      {:ok, interaction, executor_status}
    end
  end

  defp tool_result_turn_number!(task_id, tool_call_id, opts) do
    case Keyword.fetch(opts, :turn_number) do
      {:ok, turn_number} when is_integer(turn_number) and turn_number > 0 ->
        turn_number

      {:ok, turn_number} ->
        raise "Invalid turn_number for tool result #{tool_call_id}: #{inspect(turn_number)}"

      :error ->
        persisted_tool_call_turn_number!(task_id, tool_call_id)
    end
  end

  defp persisted_tool_call_turn_number!(task_id, tool_call_id) do
    query =
      from(i in InteractionSchema.for_task(task_id),
        where:
          i.type == "tool_call" and
            fragment("?->>'tool_call_id'", i.data) == ^tool_call_id,
        select: i.turn_number,
        limit: 1
      )

    case Repo.one(query) do
      turn_number when is_integer(turn_number) and turn_number > 0 ->
        turn_number

      nil ->
        raise "Cannot resolve tool_result #{tool_call_id}: no persisted tool_call found"

      turn_number ->
        raise "Cannot resolve tool_result #{tool_call_id}: tool_call has invalid turn_number #{inspect(turn_number)}"
    end
  end

  @spec notify_tool_result(Accounts.scope(), String.t(), String.t(), term(), boolean()) ::
          :notified | :no_executor | {:error, :not_found}
  def notify_tool_result(scope, task_id, tool_call_id, result, is_error) do
    with {:ok, _schema} <- get_task_by_id(scope, task_id) do
      Execution.notify_tool_result(tool_call_id, result, is_error)
    end
  end

  @doc """
  Returns unresolved tool calls for the latest open turn.

  An open turn starts at `user_message` or `agent_retry` and closes at
  `agent_completed`, `agent_error`, or `agent_paused` for the same turn number.
  """
  @spec get_open_turn_unresolved_tool_calls(Accounts.scope(), String.t()) ::
          {:ok, :no_open_turn | [Interaction.ToolCall.t()]} | {:error, :not_found}
  def get_open_turn_unresolved_tool_calls(scope, task_id) do
    with {:ok, _schema} <- get_task_by_id(scope, task_id) do
      rows = load_interaction_rows(task_id)

      case open_turn(rows) do
        nil ->
          {:ok, :no_open_turn}

        {turn_number, turn_start_index} ->
          tool_calls =
            rows
            |> Enum.drop(turn_start_index)
            |> Enum.filter(&(&1.turn_number == turn_number))
            |> unresolved_tool_calls()

          {:ok, tool_calls}
      end
    end
  end

  defp unresolved_tool_calls(turn_rows) do
    unresolved_ids =
      MapSet.difference(
        tool_call_ids(turn_rows, "tool_call"),
        tool_call_ids(turn_rows, "tool_result")
      )

    turn_rows
    |> Enum.filter(&unresolved_tool_call_row?(&1, unresolved_ids))
    |> Enum.map(&InteractionSchema.to_struct/1)
  end

  defp tool_call_ids(turn_rows, type) do
    turn_rows
    |> Enum.filter(&(&1.type == type))
    |> Enum.map(&tool_call_id!/1)
    |> MapSet.new()
  end

  defp tool_call_id!(%InteractionSchema{data: %{"tool_call_id" => id}}) when is_binary(id),
    do: id

  defp tool_call_id!(%InteractionSchema{type: type}),
    do: raise("Missing tool_call_id for #{type}")

  defp unresolved_tool_call_row?(
         %InteractionSchema{type: "tool_call", data: %{"tool_call_id" => id}},
         unresolved_ids
       )
       when is_binary(id),
       do: MapSet.member?(unresolved_ids, id)

  defp unresolved_tool_call_row?(%InteractionSchema{type: "tool_call"}, _unresolved_ids),
    do: raise("Missing tool_call_id for tool_call")

  defp unresolved_tool_call_row?(_row, _unresolved_ids), do: false

  # --- Execution Management ---

  @doc "Records a retry request and starts execution."
  @spec retry_execution(Accounts.scope(), map()) ::
          :ok | :already_running | {:error, :not_found | Ecto.Changeset.t()}
  def retry_execution(
        scope,
        %{task_id: task_id, retried_error_id: retried_error_id, tools: tools} = attrs
      ) do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      rows = load_interaction_rows(task_id)

      turn_number =
        case Enum.find(rows, &(&1.type == "agent_error" and &1.data["id"] == retried_error_id)) do
          %InteractionSchema{turn_number: turn_number} when is_integer(turn_number) ->
            turn_number

          _row ->
            raise "Cannot retry #{retried_error_id}: no turn found for error"
        end

      with {:ok, _retry} <-
             record_interaction(schema, Interaction.AgentRetry.new(retried_error_id),
               turn_number: turn_number
             ) do
        opts = attrs |> Map.get(:opts, []) |> Keyword.put(:turn_number, turn_number)
        start_execution(scope, task_id, tools, opts)
      end
    end
  end

  @doc "Records an automatic retry for the latest retryable agent error."
  @spec retry_latest_agent_error(Accounts.scope(), String.t(), pos_integer()) ::
          {:ok, Interaction.AgentRetry.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def retry_latest_agent_error(scope, task_id, turn_number)
      when is_integer(turn_number) and turn_number > 0 do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      rows = load_interaction_rows(task_id)

      %InteractionSchema{data: %{"id" => retried_error_id}} =
        latest_retryable_agent_error!(rows, task_id, turn_number)

      record_interaction(schema, Interaction.AgentRetry.new(retried_error_id),
        turn_number: turn_number
      )
    end
  end

  defp latest_retryable_agent_error!(rows, task_id, turn_number) do
    Enum.find(Enum.reverse(rows), fn
      %InteractionSchema{
        type: "agent_error",
        data: %{"retryable" => true},
        turn_number: ^turn_number
      }
      when is_integer(turn_number) ->
        true

      %InteractionSchema{type: "agent_error", data: %{"retryable" => true}} ->
        raise "Cannot retry task #{task_id}: retryable agent_error has no turn_number"

      _row ->
        false
    end) ||
      raise "Cannot retry task #{task_id}: no retryable agent_error found in turn #{turn_number}"
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

  @doc """
  Starts an execution if none is already running for this task.
  Fetches the task and delegates to Execution.run.
  """
  @spec start_execution(Accounts.scope(), String.t(), list(), keyword()) ::
          :ok | :already_running | {:error, :not_found}
  def start_execution(scope, task_id, tools, opts) do
    case get_task(scope, task_id) do
      {:ok, task} ->
        turn_number = execution_turn_number!(task_id, opts)
        rows = load_interaction_rows(task_id)

        run_execution(
          scope,
          task,
          tools,
          opts
          |> Keyword.put(:turn_number, turn_number)
          |> Keyword.put(:interaction_rows, rows),
          turn_number
        )

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  defp execution_turn_number!(task_id, opts) do
    case Keyword.fetch(opts, :turn_number) do
      {:ok, turn_number} when is_integer(turn_number) and turn_number > 0 -> turn_number
      {:ok, turn_number} -> raise "Invalid execution turn_number: #{inspect(turn_number)}"
      :error -> open_turn_number!(task_id)
    end
  end

  defp run_execution(scope, task, tools, opts, turn_number) do
    case Execution.run(scope, task, tools, opts) do
      {:ok, :already_running} ->
        :already_running

      {:ok, _pid} ->
        :ok

      {:error, reason} ->
        message = Execution.error_message(scope, reason)
        {:ok, _error} = end_agent_turn(scope, task.task_id, turn_number, {:failed, message})
        broadcast_task(task.task_id, {:execution_start_error, message, turn_number})

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
    default_title = Task.default_title()

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
