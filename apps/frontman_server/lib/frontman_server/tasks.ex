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
    Interaction.TurnStarted,
    Interaction.AgentResponse,
    Interaction.AgentCompleted,
    Interaction.AgentError,
    Interaction.AgentPaused,
    Interaction.ToolCall,
    Interaction.ToolResult,
    RetryCoordinator,
    Todos.Todo
  ]

  use Boundary,
    deps: [
      FrontmanServer,
      FrontmanServer.Accounts,
      FrontmanServer.Providers,
      ModelContextProtocol
    ],
    exports: @exports

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Observability.SentryContext
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
  require Logger

  @task_scoped_interaction_types Interaction.task_scoped_types()
  @accepted_message_interaction_types [:user_message]
  @agent_run_starter_interaction_types [:turn_started, :agent_retry]
  @agent_run_terminal_interaction_types [:agent_completed, :agent_error, :agent_paused]
  @agent_run_interaction_types [:agent_response, :tool_call, :tool_result]

  # --- Authorization Helpers ---

  defp get_task_by_id(scope, task_id) do
    case task_id
         |> TaskSchema.by_id_for_user(Accounts.scope_user_id(scope))
         |> Repo.one() do
      %TaskSchema{} = task -> {:ok, task}
      nil -> {:error, :not_found}
    end
  end

  defp get_task_by_id_for_update(scope, task_id) do
    task_id
    |> TaskSchema.by_id_for_user(Accounts.scope_user_id(scope))
    |> TaskSchema.locked_for_update()
    |> Repo.one()
  end

  # --- Task Management ---

  @doc """
  Lists all tasks for a user (lightweight, no interactions loaded).

  Returns task schemas ordered by most recently updated.
  """
  @max_tasks 20

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
  Returns `{:ok, task}` on success.
  """
  def create_task(scope, task_id, framework) do
    user_id = Accounts.scope_user_id(scope)

    attrs = %{
      id: task_id,
      short_desc: TaskSchema.default_title(),
      framework: framework,
      user_id: user_id
    }

    TaskSchema.create_changeset(attrs)
    |> Repo.insert()
  end

  defp hydrate_task(%TaskSchema{} = task_schema) do
    %{task_schema | interactions: load_interactions(task_schema.id)}
  end

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
  def add_discovered_project_rule(scope, task_id, path, content) do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      interactions = load_interactions(task_id)

      if rule_loaded?(interactions, path) do
        {:ok, :already_loaded}
      else
        record_interaction(schema, Interaction.DiscoveredProjectRule.build(path, content))
      end
    end
  end

  @doc """
  Stores the discovered project structure summary for a task.
  Called during MCP initialization after `list_tree` returns.
  """
  def add_discovered_project_structure(scope, task_id, summary) do
    with {:ok, %TaskSchema{} = task} <- get_task_by_id(scope, task_id) do
      interactions = load_interactions(task.id)

      if Enum.any?(interactions, &match?(%Interaction.DiscoveredProjectStructure{}, &1)) do
        {:ok, :already_loaded}
      else
        record_interaction(task, Interaction.DiscoveredProjectStructure.build(summary))
      end
    end
  end

  defp rule_loaded?(interactions, path) do
    Enum.any?(interactions, fn
      %Interaction.DiscoveredProjectRule{path: p} -> p == path
      _ -> false
    end)
  end

  # --- Interaction Persistence Helpers ---

  defp record_interaction(%TaskSchema{} = task_schema, interaction) do
    record_interaction(task_schema, interaction, nil)
  end

  defp record_interaction(%TaskSchema{} = task_schema, interaction, turn_number) do
    Repo.transact(fn ->
      with {:ok, schema} <-
             InteractionSchema.create_changeset(task_schema, interaction, turn_number)
             |> Repo.insert(),
           {1, _} <-
             TaskSchema
             |> TaskSchema.by_id(task_schema.id)
             |> Repo.update_all(set: [updated_at: DateTime.utc_now(:second)]) do
        {:ok, schema}
      else
        {:error, reason} -> {:error, reason}
        {0, _} -> {:error, :not_found}
      end
    end)
    |> case do
      {:ok, %InteractionSchema{} = interaction_schema} ->
        interaction = InteractionSchema.to_struct(interaction_schema)

        broadcast_task(
          task_schema.id,
          {:interaction, interaction, interaction_schema.turn_number}
        )

        {:ok, interaction}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp active_agent_run_turn_number(rows) do
    rows
    |> Enum.reduce_while(nil, fn
      %InteractionSchema{type: type, turn_number: nil}, active_run_turn_number
      when type in @task_scoped_interaction_types ->
        {:cont, active_run_turn_number}

      %InteractionSchema{type: type, turn_number: nil}, active_run_turn_number
      when type in @accepted_message_interaction_types ->
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

  defp topic(task_id), do: "task:#{task_id}"

  defp broadcast_task(task_id, message) do
    Phoenix.PubSub.broadcast(FrontmanServer.PubSub, topic(task_id), message)
  end

  @doc """
  Handles a SwarmAi execution event for a task.

  Durable events are persisted first from the SwarmAi task process. Streaming
  chunks are then broadcast for live subscribers.
  """
  def handle_swarm_event(scope, task_id, turn_number, event)
      when is_binary(task_id) and is_integer(turn_number) and turn_number > 0 do
    SentryContext.set_task_scope_context(scope, task_id)

    with :ok <- persist_swarm_event(scope, task_id, turn_number, event) do
      broadcast_swarm_event(task_id, turn_number, event)
    end
  end

  # Scope may be nil for recovered processes after a monitor restart.
  # In that case we can only broadcast, not persist.
  defp persist_swarm_event(nil, _task_id, _turn_number, _event), do: :ok

  defp persist_swarm_event(%Scope{} = scope, task_id, turn_number, {:response, response}) do
    with {:ok, _interaction} <-
           agent_replied(
             scope,
             task_id,
             turn_number,
             response.content || "",
             response_metadata(response)
           ) do
      :ok
    end
  end

  defp persist_swarm_event(%Scope{} = scope, task_id, turn_number, :completed) do
    persist_agent_run_result(scope, task_id, turn_number, :completed)
  end

  defp persist_swarm_event(
         %Scope{} = scope,
         task_id,
         turn_number,
         {:failed, reason}
       ) do
    {reason_str, category, retryable} = ErrorClassifier.classify_error(reason)

    with :ok <-
           persist_agent_run_result(
             scope,
             task_id,
             turn_number,
             {:failed, reason_str, retryable, category}
           ) do
      report_agent_execution_failure(task_id, reason_str, category, retryable)
    end
  end

  defp persist_swarm_event(
         %Scope{} = scope,
         task_id,
         turn_number,
         {:crashed, %{message: message}}
       ) do
    Sentry.capture_message("Agent execution crashed",
      level: :error,
      tags: %{error_type: "agent_crash"},
      extra: %{task_id: task_id, reason: inspect(message)}
    )

    persist_agent_run_result(scope, task_id, turn_number, {:crashed, message})
  end

  defp persist_swarm_event(%Scope{} = scope, task_id, turn_number, {:cancelled, _}) do
    persist_agent_run_result(scope, task_id, turn_number, :cancelled)
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
        ModelContextProtocol.tool_result_error("Interrupted by restart"),
        true,
        turn_number: turn_number
      )
    end)

    case interactive_tool_calls do
      [] ->
        persist_agent_run_result(scope, task_id, turn_number, :terminated)

      [_ | _] ->
        :ok
    end
  end

  defp persist_swarm_event(
         %Scope{} = scope,
         task_id,
         turn_number,
         {:paused, {:timeout, tool_call_id, tool_name, timeout_ms}}
       ) do
    reason = "Tool #{tool_name} timed out after #{timeout_ms}ms (on_timeout: :pause_agent)"

    resolve_tool_request(
      scope,
      task_id,
      %{id: tool_call_id, name: tool_name},
      ModelContextProtocol.tool_result_error(reason),
      true,
      turn_number: turn_number
    )

    persist_agent_run_result(
      scope,
      task_id,
      turn_number,
      {:paused_for_tool_timeout, tool_name, timeout_ms}
    )
  end

  defp persist_swarm_event(%Scope{}, _task_id, _turn_number, {:chunk, _}), do: :ok
  defp persist_swarm_event(%Scope{}, _task_id, _turn_number, {:tool_call, _}), do: :ok

  defp persist_agent_run_result(scope, task_id, turn_number, outcome) do
    with {:ok, _interaction} <- record_agent_run_result(scope, task_id, turn_number, outcome) do
      :ok
    end
  end

  defp report_agent_execution_failure(task_id, reason_str, "overload", true) do
    Logger.warning("Execution failed for task #{task_id}, reason: #{reason_str}")
  end

  defp report_agent_execution_failure(task_id, reason_str, "rate_limit", true) do
    Logger.warning("Execution failed for task #{task_id}, reason: #{reason_str}")
  end

  defp report_agent_execution_failure(task_id, reason_str, _category, _retryable) do
    Logger.error("Execution failed for task #{task_id}, reason: #{reason_str}")

    Sentry.capture_message("Agent execution failed",
      level: :error,
      tags: %{error_type: "agent_execution_error"},
      extra: %{task_id: task_id, reason: reason_str}
    )
  end

  defp broadcast_swarm_event(task_id, turn_number, {:chunk, chunk}) do
    broadcast_task(task_id, {:execution_chunk, turn_number, chunk})
  end

  defp broadcast_swarm_event(_task_id, _turn_number, _event), do: :ok

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

    %{
      "tool_calls" => stored_tool_calls(Map.get(response, :tool_calls)),
      "reasoning_details" => non_empty(Map.get(response, :reasoning_details)),
      "response_id" => meta[:response_id],
      "phase" => meta[:phase],
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
  Accepts a user prompt into session history.

  Starting execution is handled separately by `run_next_turn/3`.
  """
  def submit_user_message(
        %Scope{} = scope,
        %{
          task_id: task_id,
          message: [_ | _] = content_blocks,
          model: model
        }
      )
      when is_binary(task_id) and is_binary(model) and model != "" do
    with {:ok, user_message_interaction} <- Interaction.UserMessage.build(content_blocks, model),
         {:ok, task_schema} <- get_task_by_id(scope, task_id),
         first_message? <- accepted_user_message_count(task_id) == 0,
         {:ok, accepted_message} <- record_interaction(task_schema, user_message_interaction) do
      if first_message? do
        GenerateTitle.new(%{
          user_id: scope.user.id,
          task_id: task_id,
          user_prompt_text: Interaction.user_prompt_text(user_message_interaction),
          model: model
        })
        |> Oban.insert!()
      end

      {:ok, accepted_message}
    end
  end

  def submit_user_message(%Scope{}, %{model: _model}) do
    {:error, :missing_model}
  end

  defp accepted_user_message_count(task_id) do
    task_id
    |> load_interaction_rows()
    |> Enum.count(&(&1.type == :user_message))
  end

  defp start_next_turn(%Scope{} = scope, task_id) when is_binary(task_id) do
    case claim_next_turn(scope, task_id) do
      {:ok, {task_schema, turn_started, turn_number, turn_model}} ->
        broadcast_task(task_id, {:interaction, turn_started, turn_number})
        {:ok, task_schema, turn_number, turn_started, turn_model}

      {:error, :already_running} ->
        :already_running

      {:error, :no_accepted_messages} ->
        :no_accepted_messages

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp claim_next_turn(scope, task_id) do
    Repo.transact(fn ->
      case get_task_by_id_for_update(scope, task_id) do
        %TaskSchema{} = task_schema -> claim_next_turn_for_task(task_schema, task_id)
        nil -> {:error, :not_found}
      end
    end)
  end

  defp claim_next_turn_for_task(task_schema, task_id) do
    rows = load_interaction_rows(task_id)

    case {active_agent_run_turn_number(rows), accepted_messages_not_in_turn(rows)} do
      {{:ok, nil}, [_ | _] = accepted_messages} ->
        turn_number = next_turn_number(rows)
        user_message_ids = Enum.map(accepted_messages, & &1.id)
        turn_started = Interaction.TurnStarted.build(user_message_ids)

        with {:ok, turn_model} <- turn_model_for_accepted_messages(accepted_messages),
             {:ok, turn_started_row} <-
               insert_turn_started(task_schema, turn_started, turn_number) do
          {:ok,
           {task_schema, InteractionSchema.to_struct(turn_started_row), turn_number, turn_model}}
        else
          {:error, reason} ->
            {:error, reason}
        end

      {{:ok, nil}, []} ->
        {:error, :no_accepted_messages}

      {{:ok, _turn_number}, _accepted_messages} ->
        {:error, :already_running}

      {{:error, reason}, _accepted_messages} ->
        {:error, reason}
    end
  end

  defp turn_model_for_accepted_messages(accepted_messages) do
    case List.last(accepted_messages) do
      %InteractionSchema{data: %Interaction.UserMessage{model: model}}
      when is_binary(model) and model != "" ->
        {:ok, model}

      _missing ->
        {:error, :missing_model}
    end
  end

  defp accepted_messages_not_in_turn(rows) do
    message_ids_already_in_turns =
      rows
      |> Enum.flat_map(fn
        %InteractionSchema{
          type: :turn_started,
          data: %Interaction.TurnStarted{user_message_ids: ids}
        } ->
          ids

        _row ->
          []
      end)
      |> MapSet.new()

    Enum.filter(rows, fn
      %InteractionSchema{type: :user_message, turn_number: nil, id: id} ->
        not MapSet.member?(message_ids_already_in_turns, id)

      _row ->
        false
    end)
  end

  defp insert_turn_started(%TaskSchema{} = task_schema, turn_started, turn_number) do
    with {:ok, schema} <-
           InteractionSchema.create_changeset(task_schema, turn_started, turn_number)
           |> Repo.insert(),
         {1, _} <-
           TaskSchema
           |> TaskSchema.by_id(task_schema.id)
           |> Repo.update_all(set: [updated_at: DateTime.utc_now(:second)]) do
      {:ok, schema}
    else
      {:error, reason} -> {:error, reason}
      {0, _} -> {:error, :not_found}
    end
  end

  def agent_replied(scope, task_id, turn_number, content, metadata \\ %{})
      when is_integer(turn_number) and turn_number > 0 do
    with {:ok, task_schema} <- get_task_by_id(scope, task_id) do
      record_interaction(
        task_schema,
        Interaction.AgentResponse.build(content, metadata),
        turn_number
      )
    end
  end

  @doc "Records how the given agent run ended."
  def record_agent_run_result(scope, task_id, turn_number, outcome)
      when is_integer(turn_number) and turn_number > 0 do
    with {:ok, task_schema} <- get_task_by_id(scope, task_id) do
      record_interaction(task_schema, build_agent_run_result(outcome), turn_number)
    end
  end

  defp build_agent_run_result(outcome) do
    case outcome do
      :completed -> Interaction.AgentCompleted.build()
      :cancelled -> turn_error("Cancelled", "cancelled")
      :terminated -> turn_error("Terminated by supervisor", "terminated")
      {:failed, error} -> turn_error(error)
      {:failed, error, retry, category} -> turn_error(error, "failed", retry, category)
      {:crashed, error} -> turn_error(error, "crashed")
      {:paused_for_tool_timeout, tool, timeout} -> Interaction.AgentPaused.build(tool, timeout)
    end
  end

  defp turn_error(error, kind \\ "failed", retryable \\ false, category \\ "unknown"),
    do: Interaction.AgentError.build(error, kind, retryable, category)

  # --- Tool Requests ---

  @doc "Records a client-handled tool request in the given turn."
  def request_client_tool(scope, task_id, turn_number, %SwarmAi.ToolCall{} = tool_call_data)
      when is_integer(turn_number) and turn_number > 0 do
    with {:ok, schema} <- get_task_by_id(scope, task_id),
         {:ok, interaction} <- Interaction.ToolCall.build(tool_call_data) do
      record_interaction(schema, interaction, turn_number)
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
  def resolve_tool_request(
        scope,
        task_id,
        %{id: tool_call_id, name: _} = tool_call_data,
        result,
        is_error \\ false,
        opts \\ []
      )
      when is_boolean(is_error) and is_list(opts) do
    Logger.debug(fn -> "resolve_tool_result(#{inspect(result)})" end)

    with {:ok, schema} <- get_task_by_id(scope, task_id),
         turn_number = tool_result_turn_number(task_id, tool_call_id, opts),
         interaction = Interaction.ToolResult.build(tool_call_data, result, is_error),
         {:ok, interaction} <- record_interaction(schema, interaction, turn_number) do
      executor_status = Execution.notify_tool_result(interaction)

      {:ok, interaction, executor_status}
    end
  end

  defp tool_result_turn_number(task_id, tool_call_id, opts) do
    case Keyword.fetch(opts, :turn_number) do
      {:ok, turn_number} when is_integer(turn_number) and turn_number > 0 ->
        turn_number

      :error ->
        InteractionSchema.for_task(task_id)
        |> InteractionSchema.of_type(Interaction.ToolCall)
        |> InteractionSchema.data_equals("tool_call_id", tool_call_id)
        |> Repo.one()
        |> case do
          %InteractionSchema{turn_number: turn_number}
          when is_integer(turn_number) and turn_number > 0 ->
            turn_number
        end
    end
  end

  @doc """
  Returns unresolved tool calls and turn number for the active agent run.

  `TurnStarted` starts a normal agent run. `AgentRetry` starts a new agent run
  in the same turn. Agent completed, error, and paused interactions close only
  the active run attempt for their turn number.
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
  def retry_execution(scope, task_id, retried_error_id, execution) do
    with {:ok, schema} <- get_task_by_id(scope, task_id),
         rows = load_interaction_rows(task_id),
         {:ok, turn_number} <- retry_turn_number(rows, retried_error_id),
         :ok <- ensure_latest_retry_turn(retried_error_id, turn_number, rows),
         {:ok, execution} <- ensure_execution_model(rows, turn_number, execution),
         retry_interaction = Interaction.AgentRetry.build(retried_error_id),
         {:ok, _retry} <- record_interaction(schema, retry_interaction, turn_number) do
      run_execution(scope, schema, turn_number, execution)
    end
  end

  @doc "Starts and runs the next accepted-message turn when work is available."
  def run_next_turn(%Scope{} = scope, task_id, execution) when is_binary(task_id) do
    case start_next_turn(scope, task_id) do
      {:ok, task, turn_number, _turn_started, turn_model} ->
        with {:ok, execution} <- put_missing_execution_model(execution, turn_model) do
          run_execution(scope, task, turn_number, execution)
        end

      stop when stop in [:already_running, :no_accepted_messages] ->
        stop

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp retry_turn_number(rows, retried_error_id) do
    rows
    |> Enum.find(fn
      %InteractionSchema{type: :agent_error, data: %Interaction.AgentError{id: ^retried_error_id}} ->
        true

      _row ->
        false
    end)
    |> case do
      %InteractionSchema{turn_number: turn_number} ->
        {:ok, turn_number}

      nil ->
        {:error, :not_found}
    end
  end

  defp ensure_latest_retry_turn(retried_error_id, turn_number, rows) do
    latest_turn_interaction =
      rows
      |> Enum.reverse()
      |> Enum.find(&(&1.turn_number == turn_number))

    case {turn_number == latest_turn_number(rows), latest_turn_interaction} do
      {true,
       %InteractionSchema{
         type: :agent_error,
         data: %Interaction.AgentError{id: ^retried_error_id}
       }} ->
        :ok

      _ ->
        {:error, :stale_turn}
    end
  end

  @doc "Resumes execution for the active agent run."
  def resume_execution(scope, task_id, execution) do
    with {:ok, task} <- get_task(scope, task_id),
         rows = load_interaction_rows(task_id),
         {:ok, turn_number} when is_integer(turn_number) <- active_agent_run_turn_number(rows),
         {:ok, execution} <- ensure_execution_model(rows, turn_number, execution) do
      run_execution(scope, task, turn_number, execution)
    else
      {:ok, nil} -> {:error, :not_running}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_execution_model(_rows, _turn_number, %{model: model} = execution)
       when is_binary(model) and model != "" do
    {:ok, execution}
  end

  defp ensure_execution_model(rows, turn_number, execution) do
    case turn_model_from_rows(rows, turn_number) do
      {:ok, model} -> {:ok, Map.put(execution, :model, model)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp put_missing_execution_model(%{model: model} = execution, _turn_model)
       when is_binary(model) and model != "" do
    {:ok, execution}
  end

  defp put_missing_execution_model(execution, turn_model)
       when is_binary(turn_model) and turn_model != "" do
    {:ok, Map.put(execution, :model, turn_model)}
  end

  defp turn_model_from_rows(rows, turn_number) do
    rows
    |> Enum.find(fn
      %InteractionSchema{type: :turn_started, turn_number: ^turn_number} -> true
      _row -> false
    end)
    |> case do
      %InteractionSchema{data: %Interaction.TurnStarted{user_message_ids: user_message_ids}} ->
        messages_by_id =
          rows
          |> Enum.filter(&(&1.type == :user_message))
          |> Map.new(fn %InteractionSchema{id: id, data: %Interaction.UserMessage{} = message} ->
            {id, message}
          end)

        case user_message_ids |> Enum.map(&Map.fetch!(messages_by_id, &1)) |> List.last() do
          %Interaction.UserMessage{model: model} when is_binary(model) and model != "" ->
            {:ok, model}

          _missing ->
            {:error, :missing_model}
        end

      _missing ->
        {:error, :missing_model}
    end
  end

  @doc """
  Cancels a running execution for the given task.

  Verifies the task exists and belongs to the user before cancelling.
  """
  def cancel_execution(scope, task_id) do
    with {:ok, _schema} <- get_task_by_id(scope, task_id) do
      SwarmAi.cancel(FrontmanServer.AgentRuntime, task_id)
    end
  end

  defp run_execution(scope, task, turn_number, execution)
       when is_integer(turn_number) and turn_number > 0 do
    case Execution.run(scope, task, turn_number, execution) do
      {:error, :already_running} ->
        {:error, :already_running}

      {:ok, _pid} ->
        :ok

      {:error, reason} ->
        record_execution_start_failure(scope, task.id, turn_number, reason)
    end
  end

  defp record_execution_start_failure(scope, task_id, turn_number, reason)
       when is_integer(turn_number) and turn_number > 0 do
    Logger.error("Execution failed to start for task #{task_id}: #{inspect(reason)}")

    {message, category, retryable} = ErrorClassifier.classify_error(reason)

    {:ok, _error} =
      record_agent_run_result(
        scope,
        task_id,
        turn_number,
        {:failed, message, retryable, category}
      )

    :ok
  end

  @doc """
  Applies a suggested title while the task still has its default title.

  Called by the `GenerateTitle` Oban worker after the LLM suggests a title.
  """
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
