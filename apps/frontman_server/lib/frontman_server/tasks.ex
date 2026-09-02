# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks do
  @moduledoc """
  Public API for tasks.

  A task is a durable conversation between a user and one or more agents.
  It owns user messages, turn history, project context, and execution state.
  """

  @exports [
    TaskSchema,
    History,
    InteractionSchema,
    Interaction,
    Interaction.UserMessage,
    Interaction.TurnStarted,
    Interaction.AgentResponse,
    Interaction.AgentCompleted,
    Interaction.AgentError,
    Interaction.AgentPaused,
    Interaction.AgentRetry,
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
  alias FrontmanServer.Agents
  alias FrontmanServer.Observability.SentryContext
  alias FrontmanServer.Repo

  alias FrontmanServer.Tasks.{
    Execution,
    Execution.ErrorClassifier,
    History,
    Interaction,
    InteractionSchema,
    TaskSchema,
    Todos
  }

  alias FrontmanServer.Workers.GenerateTitle
  require Logger

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

  @doc "Projects canonical interaction rows into their domain payloads."
  def interactions(%TaskSchema{interaction_rows: rows}) when is_list(rows) do
    {:ok, history} = History.new(rows)
    Enum.map(history.rows, & &1.data)
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
  Drops a user message and every interaction recorded after it.

  Called when the user edits an already-sent message. The edit is submitted as a
  fresh interaction, so the original and everything it produced must go —
  otherwise the agent would answer both the old prompt and the new one. Refused
  while a turn is running, because the runner would write into rows we are about
  to delete.

  Requires authorization - scope.user.id must match task.user_id.
  """
  @spec truncate_from_message(Scope.t(), String.t(), String.t()) ::
          {:ok, non_neg_integer()} | {:error, atom()}
  def truncate_from_message(%Scope{} = scope, task_id, message_id)
      when is_binary(task_id) and is_binary(message_id) do
    Repo.transact(fn ->
      with {:ok, task_schema} <- lock_task_by_id(scope, task_id),
           {:ok, history} <- History.new(load_interaction_rows(task_id)),
           :idle <- run_state(history),
           {:ok, sequence} <- user_message_sequence(history, message_id) do
        delete_interactions_from_sequence(task_schema.id, sequence)
      else
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  @doc """
  Atomically replaces a user message with a fresh accepted message.

  The replacement content is validated before rows are deleted. The delete and
  insert happen in one transaction, so a rejected replacement cannot leave the
  task rewound without the new message.
  """
  @spec replace_user_message(Scope.t(), String.t(), map()) ::
          {:ok, InteractionSchema.t()} | {:error, term()}
  def replace_user_message(%Scope{} = scope, replaced_message_id, attrs)
      when is_binary(replaced_message_id) and is_map(attrs) do
    Repo.transact(fn ->
      with {:ok, user_message_attrs} <-
             Interaction.UserMessage.attrs(attrs.message, attrs.model, attrs.agent_id),
           {:ok, task_schema} <- lock_task_by_id(scope, attrs.task_id),
           {:ok, history} <- History.new(load_interaction_rows(attrs.task_id)),
           :idle <- run_state(history),
           {:ok, sequence} <- user_message_sequence(history, replaced_message_id),
           {:ok, _deleted_count} <- delete_interactions_from_sequence(task_schema.id, sequence),
           {:ok, accepted_row} <-
             insert_interaction_row(task_schema, %{
               id: attrs.message_id,
               type: :user_message,
               data: Map.put(user_message_attrs, :id, attrs.message_id),
               turn_number: nil
             }) do
        {:ok, accepted_row}
      else
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  defp lock_task_by_id(scope, task_id) do
    case get_task_by_id_for_update(scope, task_id) do
      %TaskSchema{} = task_schema -> {:ok, task_schema}
      nil -> {:error, :not_found}
    end
  end

  defp delete_interactions_from_sequence(task_id, sequence) do
    {deleted_count, _returned} =
      task_id
      |> InteractionSchema.for_task()
      |> InteractionSchema.from_sequence(sequence)
      |> Repo.delete_all()

    {:ok, deleted_count}
  end

  defp run_state(%History{} = history) do
    case History.active_turn_number(history) do
      nil -> :idle
      turn_number when is_integer(turn_number) -> {:error, :turn_running}
    end
  end

  defp user_message_sequence(%History{rows: rows}, message_id) do
    case Enum.find(rows, &match?(%InteractionSchema{id: ^message_id, type: :user_message}, &1)) do
      %InteractionSchema{sequence: sequence} -> {:ok, sequence}
      nil -> {:error, :message_not_found}
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
    %{task_schema | interaction_rows: load_interaction_rows(task_schema.id)}
  end

  defp load_interaction_rows(task_id) do
    InteractionSchema.for_task(task_id)
    |> InteractionSchema.ordered()
    |> Repo.all()
  end

  @max_project_rules 32

  @doc "Adds discovered project rules to the task, deduplicated by path."
  def add_discovered_project_rules(scope, task_id, rules) when is_list(rules) do
    enforce_project_rule_limit!(length(rules), task_id)

    Repo.transact(fn ->
      case get_task_by_id_for_update(scope, task_id) do
        %TaskSchema{} = task -> insert_project_rules(task, rules)
        nil -> {:error, :not_found}
      end
    end)
    |> case do
      {:ok, {task, rows}} ->
        Enum.each(rows, &broadcast_task(task.id, {:interaction, &1}))
        {:ok, rows}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp insert_project_rules(task, rules) do
    loaded_paths =
      task.id
      |> InteractionSchema.for_task()
      |> InteractionSchema.of_type(:discovered_project_rule)
      |> InteractionSchema.limited_data_values("path", @max_project_rules + 1)
      |> Repo.all()

    attrs =
      rules
      |> Enum.uniq_by(&elem(&1, 0))
      |> Enum.reject(fn {path, _content} -> path in loaded_paths end)
      |> Enum.map(fn {path, content} ->
        %{
          id: Ecto.UUID.generate(),
          type: :discovered_project_rule,
          data: %{path: path, content: content},
          turn_number: nil
        }
      end)

    enforce_project_rule_limit!(length(loaded_paths) + length(attrs), task.id)

    case attrs do
      [] ->
        {:ok, {task, []}}

      [_ | _] ->
        rows =
          Enum.map(attrs, fn attrs ->
            task
            |> Ecto.build_assoc(:interaction_rows)
            |> InteractionSchema.changeset(attrs)
            |> Repo.insert!()
          end)

        {1, _} =
          TaskSchema
          |> TaskSchema.by_id(task.id)
          |> Repo.update_all(set: [updated_at: DateTime.utc_now(:second)])

        {:ok, {task, rows}}
    end
  end

  defp enforce_project_rule_limit!(count, _task_id) when count <= @max_project_rules, do: :ok

  defp enforce_project_rule_limit!(count, task_id),
    do:
      raise(
        "project rule count #{count} exceeded limit #{@max_project_rules} for task #{task_id}"
      )

  @doc "Stores the discovered project structure summary for a task."
  def add_discovered_project_structure(scope, task_id, summary) do
    with {:ok, %TaskSchema{} = task} <- get_task_by_id(scope, task_id),
         false <-
           task.id
           |> InteractionSchema.for_task()
           |> InteractionSchema.of_type(:discovered_project_structure)
           |> Repo.exists?() do
      record_interaction(task, :discovered_project_structure, %{summary: summary}, nil)
    else
      true -> {:ok, :already_loaded}
      {:error, reason} -> {:error, reason}
    end
  end

  defp record_interaction(%TaskSchema{} = task_schema, type, data, turn_number) do
    attrs = %{
      id: Ecto.UUID.generate(),
      type: type,
      data: data,
      turn_number: turn_number
    }

    with {:ok, row} <- record_interaction_row(task_schema, attrs) do
      {:ok, row.data}
    end
  end

  defp record_interaction_row(%TaskSchema{} = task, attrs) do
    Repo.transact(fn -> insert_interaction_row(task, attrs) end)
    |> case do
      {:ok, %InteractionSchema{} = interaction_schema} ->
        broadcast_task(task.id, {:interaction, interaction_schema})
        {:ok, interaction_schema}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp insert_interaction_row(%TaskSchema{} = task, attrs) do
    with {:ok, schema} <-
           task
           |> Ecto.build_assoc(:interaction_rows)
           |> InteractionSchema.changeset(attrs)
           |> Repo.insert(),
         {1, _} <-
           TaskSchema
           |> TaskSchema.by_id(task.id)
           |> Repo.update_all(set: [updated_at: DateTime.utc_now(:second)]) do
      {:ok, schema}
    else
      {:error, reason} -> {:error, reason}
      {0, _} -> {:error, :not_found}
    end
  end

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

  defp persist_swarm_event(nil, _task_id, _turn_number, _event), do: :ok

  defp persist_swarm_event(
         %Scope{} = scope,
         task_id,
         turn_number,
         {:response, metadata, response}
       ) do
    attrs =
      response
      |> Interaction.AgentResponse.attrs_from_llm_response()
      |> Map.put(:timestamp, metadata.timestamp)

    with {:ok, task_schema} <- get_task_by_id(scope, task_id),
         {:ok, _interaction} <-
           record_interaction(task_schema, :agent_response, attrs, turn_number) do
      :ok
    end
  end

  defp persist_swarm_event(%Scope{} = scope, task_id, turn_number, :completed) do
    persist_execution_outcome(scope, task_id, turn_number, :completed)
  end

  defp persist_swarm_event(
         %Scope{} = scope,
         task_id,
         turn_number,
         {:failed, reason}
       ) do
    {reason_str, category, retryable} = ErrorClassifier.classify_error(reason)

    with :ok <-
           persist_execution_outcome(
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

    persist_execution_outcome(scope, task_id, turn_number, {:crashed, message})
  end

  defp persist_swarm_event(%Scope{} = scope, task_id, turn_number, {:cancelled, _}) do
    persist_execution_outcome(scope, task_id, turn_number, :cancelled)
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
        turn_number: turn_number
      )
    end)

    case interactive_tool_calls do
      [] ->
        persist_execution_outcome(scope, task_id, turn_number, :terminated)

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
      turn_number: turn_number
    )

    persist_execution_outcome(
      scope,
      task_id,
      turn_number,
      {:paused_for_tool_timeout, tool_name, timeout_ms}
    )
  end

  defp persist_swarm_event(%Scope{}, _task_id, _turn_number, {:chunk, _, _}), do: :ok
  defp persist_swarm_event(%Scope{}, _task_id, _turn_number, {:tool_call, _}), do: :ok

  defp persist_execution_outcome(scope, task_id, turn_number, outcome) do
    with {:ok, _interaction} <- record_execution_outcome(scope, task_id, turn_number, outcome) do
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

  defp broadcast_swarm_event(task_id, turn_number, {:chunk, metadata, chunk}) do
    broadcast_task(task_id, {:execution_chunk, turn_number, metadata, chunk})
  end

  defp broadcast_swarm_event(_task_id, _turn_number, _event), do: :ok

  defp unresolved_tool_calls_for_turn(task_id, turn_number) do
    InteractionSchema.for_task(task_id)
    |> InteractionSchema.for_turn(turn_number)
    |> InteractionSchema.unresolved_tool_calls()
    |> InteractionSchema.ordered()
    |> Repo.all()
    |> Enum.map(& &1.data)
  end

  defp keeps_turn_open_after_restart?(%Interaction.ToolCall{tool_name: "question"}), do: true
  defp keeps_turn_open_after_restart?(%Interaction.ToolCall{}), do: false

  @doc """
  Accepts a user prompt into session history.

  Starting execution is handled separately by `execute_next_turn/3`.
  """
  def submit_user_message(
        %Scope{} = scope,
        %{
          task_id: task_id,
          message_id: message_id,
          message: [_ | _] = content_blocks,
          model: model,
          agent_id: agent_id
        }
      )
      when is_binary(task_id) and is_binary(model) and model != "" and is_binary(agent_id) and
             agent_id != "" do
    with {:ok, user_message_attrs} <-
           Interaction.UserMessage.attrs(content_blocks, model, agent_id),
         {:ok, task_schema} <- get_task_by_id(scope, task_id),
         first_message? <- accepted_user_message_count(task_id) == 0,
         {:ok, accepted_row} <-
           record_interaction_row(
             task_schema,
             %{
               id: message_id,
               type: :user_message,
               data: Map.put(user_message_attrs, :id, message_id),
               turn_number: nil
             }
           ) do
      if first_message? do
        GenerateTitle.new(%{
          user_id: scope.user.id,
          task_id: task_id,
          user_prompt_text: Interaction.user_prompt_text(accepted_row.data),
          model: model
        })
        |> Oban.insert!()
      end

      {:ok, accepted_row}
    end
  end

  def submit_user_message(%Scope{}, %{agent_id: agent_id})
      when is_binary(agent_id) and agent_id != "" do
    {:error, :missing_model}
  end

  def submit_user_message(%Scope{}, %{model: _model}) do
    {:error, :missing_agent}
  end

  defp accepted_user_message_count(task_id) do
    task_id
    |> load_interaction_rows()
    |> Enum.count(&(&1.type == :user_message))
  end

  defp start_next_turn(%Scope{} = scope, task_id) when is_binary(task_id) do
    case claim_next_turn(scope, task_id) do
      {:ok, {task_schema, turn_started_row, turn_number, turn_model, agent}} ->
        broadcast_task(task_id, {:interaction, turn_started_row})
        {:ok, task_schema, turn_number, turn_model, agent}

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
        %TaskSchema{} = task_schema -> claim_next_turn_for_task(scope, task_schema, task_id)
        nil -> {:error, :not_found}
      end
    end)
  end

  defp claim_next_turn_for_task(scope, task_schema, task_id) do
    rows = load_interaction_rows(task_id)

    with {:ok, history} <- History.new(rows),
         {nil, [_ | _] = accepted_messages} <-
           {History.active_turn_number(history), History.pending_accepted_messages(history)},
         turn_number = History.next_turn_number(history),
         default_agent_id = Agents.default_agent_id(scope),
         first_accepted_message = List.first(accepted_messages),
         agent_id = accepted_message_agent_id(first_accepted_message, default_agent_id),
         {:ok, turn_model} <- accepted_message_model(first_accepted_message),
         accepted_messages =
           Enum.take_while(accepted_messages, fn row ->
             accepted_message_agent_id(row, default_agent_id) == agent_id and
               accepted_message_model(row) == {:ok, turn_model}
           end),
         user_message_ids = Enum.map(accepted_messages, & &1.id),
         {:ok, agent} <- Agents.get_agent(scope, agent_id),
         turn_started_attrs = %{
           agent_id: agent.id,
           user_message_ids: user_message_ids
         },
         {:ok, turn_started_row} <-
           insert_turn_started(task_schema, turn_started_attrs, turn_number) do
      {:ok, {task_schema, turn_started_row, turn_number, turn_model, agent}}
    else
      {:error, reason} -> {:error, reason}
      {nil, []} -> {:error, :no_accepted_messages}
      {_turn_number, _accepted_messages} -> {:error, :already_running}
    end
  end

  defp accepted_message_model(%InteractionSchema{data: %Interaction.UserMessage{model: model}})
       when is_binary(model) and model != "",
       do: {:ok, model}

  defp accepted_message_model(_missing), do: {:error, :missing_model}

  defp accepted_message_agent_id(
         %InteractionSchema{data: %Interaction.UserMessage{agent_id: agent_id}},
         _default_agent_id
       )
       when is_binary(agent_id) and agent_id != "" do
    agent_id
  end

  defp accepted_message_agent_id(
         %InteractionSchema{data: %Interaction.UserMessage{}},
         default_agent_id
       ) do
    default_agent_id
  end

  defp insert_turn_started(%TaskSchema{} = task_schema, turn_started_attrs, turn_number) do
    attrs = %{
      id: Ecto.UUID.generate(),
      type: :turn_started,
      data: turn_started_attrs,
      turn_number: turn_number
    }

    with {:ok, schema} <-
           task_schema
           |> Ecto.build_assoc(:interaction_rows)
           |> InteractionSchema.changeset(attrs)
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

  def agent_replied(scope, task_id, turn_number, content, metadata \\ %{}, usage \\ nil)
      when is_integer(turn_number) and turn_number > 0 do
    with {:ok, task_schema} <- get_task_by_id(scope, task_id) do
      record_interaction(
        task_schema,
        :agent_response,
        Interaction.AgentResponse.attrs(content, metadata, usage),
        turn_number
      )
    end
  end

  @doc "Records how the given execution ended."
  def record_execution_outcome(scope, task_id, turn_number, outcome)
      when is_integer(turn_number) and turn_number > 0 do
    with {:ok, task_schema} <- get_task_by_id(scope, task_id) do
      {type, attrs} = build_execution_outcome(outcome)

      record_interaction(task_schema, type, attrs, turn_number)
    end
  end

  defp build_execution_outcome(outcome) do
    case outcome do
      :completed ->
        {:agent_completed, %{result: nil}}

      :cancelled ->
        turn_error("Cancelled", "cancelled")

      :terminated ->
        turn_error("Terminated by supervisor", "terminated")

      {:failed, error} ->
        turn_error(error)

      {:failed, error, retry, category} ->
        turn_error(error, "failed", retry, category)

      {:crashed, error} ->
        turn_error(error, "crashed")

      {:paused_for_tool_timeout, tool, timeout} ->
        {:agent_paused,
         %{
           reason: "Tool #{tool} timed out after #{timeout}ms (on_timeout: :pause_agent)",
           tool_name: tool,
           timeout_ms: timeout
         }}
    end
  end

  defp turn_error(error, kind \\ "failed", retryable \\ false, category \\ "unknown") do
    {:agent_error,
     %{
       error: error,
       kind: kind,
       retryable: retryable,
       category: category
     }}
  end

  @doc "Records a client-handled tool request in the given turn."
  def request_client_tool(scope, task_id, turn_number, %SwarmAi.ToolCall{} = tool_call_data)
      when is_integer(turn_number) and turn_number > 0 do
    with {:ok, schema} <- get_task_by_id(scope, task_id),
         {:ok, attrs} <- Interaction.ToolCall.attrs(tool_call_data) do
      record_interaction(schema, :tool_call, attrs, turn_number)
    end
  end

  @doc """
  Resolves a tool request.

  Routes the result to the waiting executor so the agent can continue.
  Duplicate tool results for the same tool_call_id are prevented by a
  unique partial index on the interactions table.

  Returns `{:ok, interaction, :notified}` when a live executor received the result,
  and `{:ok, interaction, :no_executor}` when no executor was waiting (e.g., server restart).
  """
  def resolve_tool_request(
        scope,
        task_id,
        %{id: tool_call_id, name: _} = tool_call_data,
        result,
        opts \\ []
      )
      when is_list(opts) do
    with {:ok, schema} <- get_task_by_id(scope, task_id) do
      turn_number = tool_result_turn_number(task_id, tool_call_id, opts)
      attrs = Interaction.ToolResult.attrs(tool_call_data, result)

      schema
      |> record_interaction(:tool_result, attrs, turn_number)
      |> resolve_recorded_tool_result(task_id, turn_number, tool_call_id)
    end
  end

  defp resolve_recorded_tool_result({:ok, interaction}, task_id, _turn_number, _tool_call_id) do
    notify_recorded_tool_result(interaction, task_id)
  end

  defp resolve_recorded_tool_result(
         {:error, %Ecto.Changeset{} = changeset},
         task_id,
         turn_number,
         tool_call_id
       ) do
    case InteractionSchema.duplicate_tool_result?(changeset) do
      true ->
        interaction =
          InteractionSchema
          |> InteractionSchema.for_task(task_id)
          |> InteractionSchema.for_turn(turn_number)
          |> InteractionSchema.of_type(:tool_result)
          |> InteractionSchema.data_equals("tool_call_id", tool_call_id)
          |> Repo.one!()
          |> Map.fetch!(:data)

        notify_recorded_tool_result(interaction, task_id)

      false ->
        {:error, changeset}
    end
  end

  defp notify_recorded_tool_result(interaction, task_id) do
    {:ok, interaction, Execution.notify_tool_result(task_id, interaction)}
  end

  defp tool_result_turn_number(task_id, tool_call_id, opts) do
    case Keyword.fetch(opts, :turn_number) do
      {:ok, turn_number} when is_integer(turn_number) and turn_number > 0 ->
        turn_number

      :error ->
        InteractionSchema.for_task(task_id)
        |> InteractionSchema.of_type(:tool_call)
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
  Returns unresolved tool calls and the turn number for the active execution.

  `TurnStarted` starts execution for a new turn. `AgentRetry` restarts execution
  in the same turn. Completion, error, and pause records stop execution.
  """
  def get_active_turn_unresolved_tool_calls(scope, task_id) do
    with {:ok, _schema} <- get_task_by_id(scope, task_id),
         rows = load_interaction_rows(task_id),
         {:ok, history} <- History.new(rows) do
      case History.active_turn_number(history) do
        nil ->
          {:ok, :no_active_turn}

        turn_number ->
          tool_calls =
            InteractionSchema.for_task(task_id)
            |> InteractionSchema.for_turn(turn_number)
            |> InteractionSchema.unresolved_tool_calls()
            |> InteractionSchema.ordered()
            |> Repo.all()
            |> Enum.map(& &1.data)

          {:ok, turn_number, tool_calls}
      end
    end
  end

  @doc "Records a retry request and starts execution."
  def retry_execution(scope, task_id, retried_error_id, execution) do
    with {:ok, schema} <- get_task_by_id(scope, task_id),
         rows = load_interaction_rows(task_id),
         {:ok, history} = History.new(rows),
         {:ok, turn_number} <- retry_turn_number(rows, retried_error_id),
         :ok <- ensure_latest_retry_turn(retried_error_id, turn_number, history),
         {:ok, execution} <- ensure_execution_model(history, turn_number, execution),
         {:ok, agent} <- turn_agent(scope, history, turn_number),
         retry_attrs = %{retried_error_id: retried_error_id},
         {:ok, _retry} <- record_interaction(schema, :agent_retry, retry_attrs, turn_number) do
      start_execution(scope, schema, turn_number, agent, execution)
    end
  end

  @doc "Executes the next accepted-message turn when work is available."
  def execute_next_turn(%Scope{} = scope, task_id, execution) when is_binary(task_id) do
    case start_next_turn(scope, task_id) do
      {:ok, task, turn_number, turn_model, agent} ->
        execution = Map.put(execution, :model, turn_model)
        start_execution(scope, task, turn_number, agent, execution)

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

  defp ensure_latest_retry_turn(retried_error_id, turn_number, history) do
    latest_turn_interaction =
      history.rows
      |> Enum.reverse()
      |> Enum.find(&(&1.turn_number == turn_number))

    case {turn_number == History.latest_turn_number(history), latest_turn_interaction} do
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

  @doc "Resumes execution for the active turn."
  def resume_execution(scope, task_id, execution) do
    with {:ok, task} <- get_task(scope, task_id),
         {:ok, history} <- History.new(task.interaction_rows),
         turn_number when is_integer(turn_number) <- History.active_turn_number(history),
         {:ok, agent} <- turn_agent(scope, history, turn_number),
         {:ok, execution} <- ensure_execution_model(history, turn_number, execution) do
      start_execution(scope, task, turn_number, agent, execution)
    else
      nil -> {:error, :not_running}
      {:error, reason} -> {:error, reason}
    end
  end

  defp turn_agent(%Scope{} = scope, history, turn_number) do
    with {:ok, agent_id} <- History.turn_agent_id(history, turn_number) do
      Agents.get_agent(scope, agent_id || Agents.default_agent_id(scope))
    end
  end

  defp ensure_execution_model(history, turn_number, execution) do
    with {:ok, model} <- History.turn_model(history, turn_number) do
      {:ok, Map.put(execution, :model, model)}
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

  defp start_execution(scope, task, turn_number, agent, execution)
       when is_integer(turn_number) and turn_number > 0 do
    rows = load_interaction_rows(task.id)
    {:ok, history} = History.new(rows)
    context = prompt_context(task, rows, execution)
    system_prompt = Agents.system_prompt(agent, context)
    tool_policy = Agents.tool_policy(agent)
    response_context = History.response_context(history, turn_number, agent.id)

    case Execution.start(
           scope,
           task,
           turn_number,
           system_prompt,
           rows,
           tool_policy,
           response_context,
           execution
         ) do
      {:error, :already_running} ->
        {:error, :already_running}

      {:ok, _pid} ->
        :ok

      {:error, reason} ->
        record_execution_start_failure(scope, task.id, turn_number, reason)
    end
  end

  defp prompt_context(%TaskSchema{} = task, rows, execution) do
    interactions = Enum.map(rows, &Map.fetch!(&1, :data))

    %{
      framework: task.framework,
      project_traits: Map.get(execution, :project_traits, []),
      project_rules:
        Enum.flat_map(interactions, fn
          %Interaction.DiscoveredProjectRule{} = rule ->
            [%{path: rule.path, content: rule.content, timestamp: rule.timestamp}]

          _interaction ->
            []
        end),
      project_structure:
        Enum.find_value(interactions, fn
          %Interaction.DiscoveredProjectStructure{summary: summary} -> summary
          _interaction -> nil
        end),
      has_annotations:
        Enum.any?(interactions, &match?(%Interaction.UserMessage{annotations: [_ | _]}, &1))
    }
  end

  defp record_execution_start_failure(scope, task_id, turn_number, reason)
       when is_integer(turn_number) and turn_number > 0 do
    Logger.error("Execution failed to start for task #{task_id}: #{inspect(reason)}")

    {message, category, retryable} = ErrorClassifier.classify_error(reason)

    {:ok, _error} =
      record_execution_outcome(
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

  @doc """
  Lists all todos from an already-loaded task.

  Todos are managed through tool calls, not direct API calls.
  This function is for reading the current todos only.
  """
  @spec list_todos(TaskSchema.t()) :: [Todos.Todo.t()]
  def list_todos(%TaskSchema{interaction_rows: rows}) when is_list(rows) do
    rows
    |> Todos.list_todos()
    |> Map.values()
    |> Enum.sort_by(& &1.created_at, DateTime)
  end

  @doc "Lists all todos for a task."
  def list_todos(scope, task_id) do
    with {:ok, task} <- get_task(scope, task_id) do
      {:ok, list_todos(task)}
    end
  end
end
