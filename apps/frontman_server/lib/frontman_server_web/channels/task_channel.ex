# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.TaskChannel do
  @moduledoc """
  Channel for task-specific ACP events.

  Clients join this channel after creating a task via the
  tasks channel. Handles prompt messages and streams
  agent responses back to the client.
  """
  use FrontmanServerWeb, :channel
  require Logger

  alias AgentClientProtocol, as: ACP
  alias AgentClientProtocol.History, as: ACPHistory
  alias FrontmanServer.Agents
  alias FrontmanServer.Frameworks
  alias FrontmanServer.MCPConnection
  alias FrontmanServer.Observability.SentryContext
  alias FrontmanServer.Providers
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.History, as: TaskHistory
  alias FrontmanServer.Tasks.RetryCoordinator
  alias FrontmanServer.Tasks.Todos.Todo
  alias FrontmanServer.Tools

  @acp_message ACP.event_acp_message()
  @acp_title_updated ACP.event_title_updated()
  @acp_method_session_prompt ACP.method_session_prompt()
  @acp_method_session_cancel ACP.method_session_cancel()
  @acp_method_session_load ACP.method_session_load()
  @impl true
  def join("task:" <> task_id, _params, socket) do
    scope = socket.assigns.scope

    case Tasks.get_task(scope, task_id) do
      {:ok, task} ->
        {:ok, history} = TaskHistory.new(task.interaction_rows)
        active_turn = TaskHistory.active_turn_context(history)

        SentryContext.set_task_scope_context(scope, task_id)

        Logger.info("Client joining: #{task_id}, socket_id: #{inspect(self())}")

        Phoenix.PubSub.subscribe(FrontmanServer.PubSub, MCPConnection.topic(scope))

        mcp_owner = MCPConnection.owner_pid(scope)

        {mcp_status, mcp_tools} =
          case MCPConnection.catalog(scope) do
            {:ok, status, tools} -> {status, tools}
            :unavailable -> {:pending, []}
          end

        socket =
          socket
          |> assign(:task_id, task_id)
          |> assign(:framework, task.framework)
          |> assign(:mcp_tools, mcp_tools)
          |> assign(:mcp_status, mcp_status)
          |> assign(:mcp_owner, mcp_owner)
          |> assign(:mcp_owner_monitor, monitor_owner(mcp_owner))
          |> assign(:mcp_ready_owner, ready_owner(mcp_status, mcp_owner))
          |> assign(:mcp_context_ready, context_ready?(scope, task, mcp_status, mcp_owner))
          |> assign(:session_loaded, false)
          |> assign(:execution_armed, false)
          |> assign(:active_turn, active_turn)

        {:ok, %{task_id: task_id}, socket}

      {:error, :not_found} ->
        Logger.info("Client tried to join non-existent task: #{task_id}")
        {:error, %{reason: "task_not_found"}}
    end
  end

  @impl true
  def handle_in(@acp_message, payload, socket) do
    parsed = JsonRpc.parse(payload)

    Logger.info("Received ACP message")

    case parsed do
      {:ok, {:request, id, @acp_method_session_prompt, params}} ->
        handle_prompt(id, params, socket)

      {:ok, {:notification, @acp_method_session_cancel, params}} ->
        handle_cancel(params, socket)

      {:ok, {:request, id, @acp_method_session_load, params}} ->
        handle_session_load(id, params, socket)

      {:ok, {:request, id, method, _params}} ->
        reply_acp_error(
          socket,
          id,
          JsonRpc.error_method_not_found(),
          "Method not found: #{method}"
        )

      {:ok, {:notification, "session/retry_turn", %{"retriedErrorId" => retried_error_id}}} ->
        handle_retry_turn(retried_error_id, socket)

      {:ok, {:notification, _method, _params}} ->
        {:noreply, socket}

      {:error, reason} ->
        handle_invalid_acp_message(reason, payload, socket)
    end
  end

  @impl true
  def handle_info({:run_next_turn, execution}, socket) do
    case Tasks.run_next_turn(socket.assigns.scope, socket.assigns.task_id, execution) do
      result when result in [:ok, :already_running, :no_accepted_messages] ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to run next turn: #{inspect(reason)}")
    end

    {:noreply, socket}
  end

  def handle_info({:execution_chunk, turn_number, metadata, chunk}, socket) do
    {:noreply, handle_execution_chunk(socket, turn_number, metadata, chunk)}
  end

  def handle_info(
        {:interaction,
         %{
           id: turn_started_id,
           data: %Tasks.Interaction.TurnStarted{} = interaction,
           turn_number: turn_number
         }},
        socket
      ) do
    handle_turn_started(interaction, turn_started_id, turn_number, socket)
  end

  def handle_info({:interaction, %{data: interaction, turn_number: turn_number}}, socket) do
    handle_interaction(interaction, turn_number, socket)
  end

  def handle_info({:fire_retry, token}, socket) do
    case socket.assigns[:retry_state] do
      %{timer_token: ^token, retried_error_id: retried_error_id} ->
        retry_turn(socket, retried_error_id)

      _stale_or_nil ->
        :ok
    end

    {:noreply, socket}
  end

  def handle_info({:task_title_changed, task_id, title}, socket) do
    push(socket, @acp_title_updated, %{"sessionId" => task_id, "title" => title})
    {:noreply, socket}
  end

  def handle_info({:mcp_catalog_updated, owner_pid, status, tools}, socket) do
    owner_changed? = ready_owner_changed?(socket.assigns.mcp_ready_owner, status, owner_pid)

    socket =
      socket
      |> replace_mcp_owner_monitor(owner_pid)
      |> assign(:mcp_status, status)
      |> assign(:mcp_tools, tools)
      |> assign(:mcp_owner, owner_pid)
      |> assign(:mcp_context_ready, catalog_context_ready?(socket, status, owner_pid))
      |> maybe_assign_ready_owner(status, owner_pid)

    case {owner_changed?, status, socket.assigns.mcp_context_ready, context_requested?(socket)} do
      {true, _status, _context_ready?, true} ->
        MCPConnection.hydrate_task(socket.assigns.scope, socket.assigns.task_id)

      {false, :ready, false, true} ->
        MCPConnection.hydrate_task(socket.assigns.scope, socket.assigns.task_id)

      {_owner_changed?, _status, _context_ready?, _requested?} ->
        :ok
    end

    wake_runner(socket, nil)
    {:noreply, socket}
  end

  def handle_info(
        {:mcp_project_context_ready, owner_pid, task_id, _status},
        %{assigns: %{mcp_owner: owner_pid, task_id: task_id}} = socket
      ) do
    socket = assign(socket, :mcp_context_ready, true)

    case socket.assigns.active_turn do
      nil -> :ok
      _active_turn -> MCPConnection.load_task(socket.assigns.scope, task_id)
    end

    wake_runner(socket, nil)
    {:noreply, socket}
  end

  def handle_info({:mcp_project_context_ready, _owner_pid, _task_id, _status}, socket),
    do: {:noreply, socket}

  def handle_info(
        {:DOWN, monitor, :process, owner_pid, _reason},
        %{assigns: %{mcp_owner_monitor: monitor, mcp_owner: owner_pid}} = socket
      ) do
    case MCPConnection.catalog(socket.assigns.scope) do
      :unavailable ->
        cancel_execution_for_unavailable_owner(socket)
        MCPConnection.publish_unavailable(socket.assigns.scope)

        {:noreply,
         socket
         |> assign(:mcp_status, :pending)
         |> assign(:mcp_tools, [])
         |> assign(:mcp_owner, nil)
         |> assign(:mcp_owner_monitor, nil)
         |> assign(:mcp_context_ready, false)}

      {:ok, status, tools} ->
        owner_pid = MCPConnection.owner_pid(socket.assigns.scope)

        {:noreply,
         socket
         |> replace_mcp_owner_monitor(owner_pid)
         |> assign(:mcp_status, status)
         |> assign(:mcp_tools, tools)
         |> assign(:mcp_owner, owner_pid)
         |> assign(:mcp_context_ready, catalog_context_ready?(socket, status, owner_pid))}
    end
  end

  def handle_info(msg, _socket) do
    raise "Unhandled message in TaskChannel: #{inspect(msg)}"
  end

  defp cancel_execution_for_unavailable_owner(socket) do
    case Tasks.cancel_execution(socket.assigns.scope, socket.assigns.task_id) do
      result when result in [:ok, {:error, :not_running}] ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to cancel execution after MCP owner loss: #{inspect(reason)}")
    end
  end

  defp handle_turn_started(turn, turn_started_id, turn_number, socket) do
    task_id = socket.assigns.task_id
    notification = ACP.build_state_update_notification(task_id, "running")
    push(socket, @acp_message, notification)

    context = %{
      agent_id: turn.agent_id,
      turn_number: turn_number,
      turn_started_id: turn_started_id
    }

    {:noreply, assign(socket, :active_turn, context)}
  end

  defp handle_interaction(%Tasks.Interaction.ToolCall{} = tool_call, _turn_number, socket) do
    task_id = socket.assigns.task_id

    announced = socket.assigns[:announced_tool_calls] || MapSet.new()

    notification =
      case MapSet.member?(announced, tool_call.tool_call_id) do
        false ->
          ACP.tool_call_create(
            task_id,
            tool_call.tool_call_id,
            tool_call.tool_name,
            "other",
            DateTime.utc_now(),
            ACP.tool_call_status_pending(),
            tool_call.arguments
          )

        true ->
          ACP.tool_call_update(
            task_id,
            tool_call.tool_call_id,
            ACP.tool_call_status_pending(),
            nil,
            tool_call.arguments
          )
      end

    push(socket, @acp_message, notification)

    case Tools.execution_target(tool_call.tool_name) do
      :backend ->
        {:noreply, socket}

      :mcp ->
        {:noreply, socket}
    end
  end

  defp handle_interaction(%Tasks.Interaction.ToolResult{} = tool_result, _turn_number, socket) do
    task_id = socket.assigns.task_id
    scope = socket.assigns.scope

    if Tools.todo_mutation?(tool_result.tool_name) do
      case Tasks.list_todos(scope, task_id) do
        {:ok, todos} ->
          entries = Enum.map(todos, &to_plan_entry/1)
          plan_notification = ACP.plan_update(task_id, entries)
          push(socket, @acp_message, plan_notification)

        {:error, _reason} ->
          :ok
      end
    else
      notification =
        ACP.tool_call_update(
          task_id,
          tool_result.tool_call_id,
          ACP.tool_call_status(tool_result.is_error),
          ACP.Content.from_tool_result(tool_result.result),
          nil,
          Map.fetch(tool_result.result, "structuredContent")
        )

      push(socket, @acp_message, notification)
    end

    {:noreply, socket}
  end

  defp handle_interaction(%Tasks.Interaction.AgentCompleted{}, turn_number, socket) do
    finalize_turn(socket, {:completed, ACP.stop_reason_end_turn()}, turn_number)
  end

  defp handle_interaction(%Tasks.Interaction.AgentRetry{}, turn_number, socket) do
    context =
      case socket.assigns.active_turn do
        %{turn_number: ^turn_number} = context -> context
        _missing -> load_turn_context!(socket, turn_number)
      end

    {:noreply, assign(socket, :active_turn, context)}
  end

  defp handle_interaction(%Tasks.Interaction.AgentPaused{}, turn_number, socket) do
    finalize_turn(socket, :requires_action, turn_number)
  end

  defp handle_interaction(%Tasks.Interaction.AgentError{kind: "cancelled"}, turn_number, socket) do
    finalize_turn(socket, {:completed, ACP.stop_reason_cancelled()}, turn_number)
  end

  defp handle_interaction(
         %Tasks.Interaction.AgentError{retryable: true} = error,
         turn_number,
         socket
       ) do
    handle_transient_error(
      socket,
      %{
        message: error.error,
        category: error.category,
        retryable: true,
        retried_error_id: error.id
      },
      turn_number
    )
  end

  defp handle_interaction(%Tasks.Interaction.AgentError{} = error, turn_number, socket) do
    finalize_turn(socket, {:error, error.id, error.error, error.category}, turn_number)
  end

  defp handle_interaction(_interaction, _turn_number, socket) do
    {:noreply, socket}
  end

  defp load_turn_context!(socket, turn_number) do
    {:ok, task} = Tasks.get_task(socket.assigns.scope, socket.assigns.task_id)
    {:ok, history} = TaskHistory.new(task.interaction_rows)
    TaskHistory.turn_context(history, turn_number)
  end

  defp handle_prompt(id, params, socket) do
    if socket.assigns[:mcp_status] == :failed do
      Logger.warning(
        "Processing prompt with failed MCP catalog for task #{socket.assigns.task_id}"
      )
    end

    process_prompt(id, params, socket)
  end

  defp handle_cancel(_params, socket) do
    task_id = socket.assigns.task_id
    Logger.info("Cancel notification received for task #{task_id}")

    had_retry = socket.assigns[:retry_state] != nil

    socket = assign(socket, :retry_state, RetryCoordinator.clear(socket.assigns[:retry_state]))

    {:ok, _cancelled_count} =
      Tasks.cancel_claimed_tool_calls_for_task(socket.assigns.scope, task_id, "Task cancelled")

    MCPConnection.cancel_task(socket.assigns.scope, task_id, "Task cancelled")

    case Tasks.cancel_execution(socket.assigns.scope, task_id) do
      :ok ->
        Logger.info("Agent cancel signal sent for task #{task_id}")
        {:noreply, socket}

      {:error, :not_running} ->
        Logger.info("Cancel notification for task #{task_id}: no agent running")

        if had_retry do
          finalize_turn(socket, {:completed, ACP.stop_reason_cancelled()}, nil)
        else
          {:noreply, socket}
        end

      {:error, :not_found} ->
        {:noreply, socket}
    end
  end

  defp handle_session_load(id, %{"sessionId" => task_id}, socket)
       when task_id == socket.assigns.task_id do
    scope = socket.assigns.scope
    Logger.info("ACP session/load request received on session channel for: #{task_id}")

    case Tasks.get_task(scope, task_id) do
      {:ok, task} ->
        {:ok, history} = TaskHistory.new(task.interaction_rows)
        {:ok, replay} = ACPHistory.build(history, task.id, Agents.list_agents(scope))
        Enum.each(replay.notifications, &push(socket, @acp_message, &1))

        push(
          socket,
          @acp_message,
          JsonRpc.success_response(
            id,
            ACP.build_session_load_result(
              scope
              |> Providers.model_config_data()
              |> ACP.build_model_config_options()
            )
          )
        )

        socket =
          socket
          |> assign(:session_loaded, true)
          |> assign(:execution_armed, true)
          |> assign(:active_turn, TaskHistory.active_turn_context(history))

        MCPConnection.load_task(scope, task_id)

        wake_runner(socket, nil)

        {:noreply, socket}

      {:error, :not_found} ->
        push_acp_error(socket, id, JsonRpc.error_invalid_params(), "Session not found")
    end
  end

  defp handle_session_load(id, _params, socket) do
    push_acp_error(socket, id, JsonRpc.error_invalid_params(), "Session does not match channel")
  end

  defp process_prompt(id, %{"prompt" => content_blocks, "_meta" => meta}, socket)
       when is_map(meta) do
    task_id = socket.assigns.task_id
    scope = socket.assigns.scope

    case Providers.model_from_client_params(meta["model"]) do
      {:ok, model} ->
        Logger.info("process_prompt", %{task_id: task_id, model: model})

        with {:ok, agent_id} <-
               Agents.resolve_agent_id(scope, meta["agent"] || Agents.default_agent_id(scope)),
             {:ok, row} <-
               Tasks.submit_user_message(
                 scope,
                 %{
                   task_id: task_id,
                   message: content_blocks,
                   model: model,
                   agent_id: agent_id
                 }
               ) do
          push_user_message_chunks(socket, task_id, row)

          socket = assign(socket, :execution_armed, true)
          MCPConnection.hydrate_task(scope, task_id)
          socket = wake_runner(socket, meta)

          Logger.info("User message accepted for task #{task_id}")
          {:reply, {:ok, %{@acp_message => JsonRpc.success_response(id, %{})}}, socket}
        else
          {:error, :missing_agent} ->
            reply_acp_error(socket, id, JsonRpc.error_invalid_params(), "Agent is required")

          {:error, :unknown_agent} ->
            reply_acp_error(socket, id, JsonRpc.error_invalid_params(), "Unknown agent")

          {:error, {:invalid_content_block, message}} ->
            Logger.error("Failed to add user message: #{message}")
            reply_acp_error(socket, id, JsonRpc.error_invalid_params(), message)

          {:error, reason} ->
            Logger.error("Failed to add user message: #{inspect(reason)}")
            reply_acp_error(socket, id, -32_000, inspect(reason))
        end

      :error ->
        reply_acp_error(socket, id, JsonRpc.error_invalid_params(), "Model is required")
    end
  end

  defp push_user_message_chunks(socket, task_id, row) do
    %{row: row, agent_id: row.data.agent_id}
    |> ACPHistory.encode_row(task_id)
    |> Enum.each(&push(socket, @acp_message, &1))
  end

  defp reply_acp_error(socket, id, code, message) do
    {:reply, {:ok, %{@acp_message => JsonRpc.error_response(id, code, message)}}, socket}
  end

  defp push_acp_error(socket, id, code, message) do
    push(socket, @acp_message, JsonRpc.error_response(id, code, message))
    {:noreply, socket}
  end

  defp handle_execution_chunk(
         socket,
         turn_number,
         %{
           turn_started_id: turn_started_id,
           agent_id: agent_id,
           ordinal: ordinal,
           timestamp: timestamp
         },
         %{type: :content, text: text}
       )
       when is_binary(text) and text != "" do
    validate_execution_context!(socket, turn_number, turn_started_id, agent_id)
    task_id = socket.assigns.task_id
    message_id = ACP.agent_message_id(turn_started_id, ordinal)

    notification =
      ACP.build_agent_message_chunk_notification(task_id, text, timestamp, message_id, agent_id)

    push(socket, @acp_message, notification)
    socket
  end

  defp handle_execution_chunk(
         socket,
         turn_number,
         %{turn_started_id: turn_started_id, agent_id: agent_id},
         %{type: :tool_call, name: name, metadata: %{id: id}}
       )
       when is_binary(name) and is_binary(id) do
    validate_execution_context!(socket, turn_number, turn_started_id, agent_id)
    announce_stream_tool_call_once(socket, id, name)
  end

  defp handle_execution_chunk(socket, _turn_number, _metadata, %{type: :content, text: ""}),
    do: socket

  defp handle_execution_chunk(_socket, _turn_number, metadata, %{type: type})
       when type in [:content, :tool_call],
       do: raise("Invalid #{type} chunk metadata: #{inspect(metadata)}")

  defp handle_execution_chunk(socket, _turn_number, _metadata, _chunk), do: socket

  defp validate_execution_context!(
         %{assigns: %{active_turn: active_turn}},
         turn_number,
         turn_started_id,
         agent_id
       ) do
    expected = %{
      agent_id: agent_id,
      turn_number: turn_number,
      turn_started_id: turn_started_id
    }

    case active_turn do
      ^expected ->
        :ok

      _other ->
        raise "Stale execution chunk: expected #{inspect(active_turn)}, got #{inspect(expected)}"
    end
  end

  defp announce_stream_tool_call_once(socket, id, name) do
    announced = socket.assigns[:announced_tool_calls] || MapSet.new()

    case MapSet.member?(announced, id) do
      true ->
        socket

      false ->
        task_id = socket.assigns.task_id

        notification =
          ACP.tool_call_create(
            task_id,
            id,
            name,
            "other",
            DateTime.utc_now(),
            ACP.tool_call_status_pending()
          )

        push(socket, @acp_message, notification)
        assign(socket, :announced_tool_calls, MapSet.put(announced, id))
    end
  end

  defp handle_invalid_acp_message(_reason, payload, socket) do
    Logger.error("Invalid ACP message in task channel")

    case payload do
      %{"id" => id} ->
        push_acp_error(socket, id, JsonRpc.error_invalid_request(), "Invalid JSON-RPC message")

      _ ->
        {:noreply, socket}
    end
  end

  defp handle_retry_turn(retried_error_id, socket) do
    retry_turn(socket, retried_error_id)
    {:noreply, socket}
  end

  defp retry_turn(socket, retried_error_id) do
    case Tasks.retry_execution(
           socket.assigns.scope,
           socket.assigns.task_id,
           retried_error_id,
           %{
             model: nil,
             mcp_tools: socket.assigns.mcp_tools,
             project_traits: Frameworks.project_traits_from_meta(nil, socket.assigns.framework)
           }
         ) do
      :ok ->
        :ok

      {:error, reason} ->
        unless reason in [:not_found, :stale_turn] do
          Logger.warning("Retry turn failed: #{inspect(reason)}")
        end

        push_agent_error(
          socket,
          retried_error_id,
          "That response can no longer be retried. Please send a new message instead.",
          "retry_unavailable"
        )
    end
  end

  defp handle_transient_error(socket, error_info, turn_number) do
    case RetryCoordinator.handle_error(socket.assigns[:retry_state], error_info) do
      {:exhausted, error_info} ->
        finalize_turn(
          socket,
          {:error, error_info.retried_error_id, error_info.message, error_info.category},
          turn_number
        )

      {:retry_scheduled, state, notification} ->
        push_agent_error(
          socket,
          state.retried_error_id,
          notification.message,
          notification.category,
          retry_at: notification.retry_at,
          attempt: notification.attempt,
          max_attempts: notification.max_attempts
        )

        {:noreply, assign(socket, :retry_state, state)}
    end
  end

  defp finalize_turn(socket, outcome, turn_number) do
    task_id = socket.assigns.task_id

    case {turn_number, socket.assigns.active_turn} do
      {nil, _active_turn} -> :ok
      {_turn_number, nil} -> :ok
      {turn_number, %{turn_number: turn_number}} -> :ok
      {_turn_number, active_turn} -> raise "Stale turn finalization: #{inspect(active_turn)}"
    end

    socket =
      socket
      |> assign(:retry_state, RetryCoordinator.clear(socket.assigns[:retry_state]))
      |> assign(:active_turn, nil)

    case outcome do
      {:completed, stop_reason} ->
        notification = ACP.build_state_update_notification(task_id, "idle", stop_reason)
        push(socket, @acp_message, notification)
        wake_runner(assign(socket, :execution_armed, true), nil)
        {:noreply, socket}

      :requires_action ->
        notification = ACP.build_state_update_notification(task_id, "requires_action")
        push(socket, @acp_message, notification)
        {:noreply, socket}

      {:error, agent_error_id, message, category} ->
        push_agent_error(socket, agent_error_id, message, category)
        wake_runner(assign(socket, :execution_armed, true), nil)
        {:noreply, socket}
    end
  end

  defp push_agent_error(socket, agent_error_id, message, category, opts \\ []) do
    notification =
      ACP.build_error_notification(
        socket.assigns.task_id,
        message,
        DateTime.utc_now(),
        Keyword.merge(opts, category: category, agent_error_id: agent_error_id)
      )

    push(socket, @acp_message, notification)
  end

  defp wake_runner(socket, meta) do
    case {
      socket.assigns[:mcp_status],
      socket.assigns.mcp_context_ready,
      socket.assigns.execution_armed
    } do
      {status, true, true} when status in [:ready, :failed] ->
        send(self(), {:run_next_turn, execution_context(socket, meta)})
        assign(socket, :execution_armed, false)

      _pending ->
        socket
    end
  end

  defp context_ready?(scope, task, status, owner_pid) do
    case Frameworks.load_project_context?(task.framework) do
      false ->
        true

      true ->
        required_context_ready?(scope, task.id, status, owner_pid)
    end
  end

  defp required_context_ready?(_scope, _task_id, :failed, _owner_pid), do: true

  defp required_context_ready?(scope, task_id, :ready, owner_pid) do
    case MCPConnection.project_context(scope, task_id) do
      {:ok, ^owner_pid, status} when status in [:ready, :failed] -> true
      {:ok, _owner_pid, _status} -> false
      :unavailable -> false
    end
  end

  defp required_context_ready?(_scope, _task_id, _status, _owner_pid), do: false

  defp context_requested?(socket) do
    socket.assigns.execution_armed or socket.assigns.session_loaded or
      socket.assigns.active_turn != nil
  end

  defp catalog_context_ready?(socket, status, owner_pid) do
    {:ok, task} = Tasks.get_task(socket.assigns.scope, socket.assigns.task_id)
    context_ready?(socket.assigns.scope, task, status, owner_pid)
  end

  defp monitor_owner(owner_pid) when is_pid(owner_pid), do: Process.monitor(owner_pid)
  defp monitor_owner(nil), do: nil

  defp replace_mcp_owner_monitor(socket, owner_pid) do
    case socket.assigns.mcp_owner_monitor do
      nil -> :ok
      monitor -> Process.demonitor(monitor, [:flush])
    end

    assign(socket, :mcp_owner_monitor, monitor_owner(owner_pid))
  end

  defp ready_owner(:ready, owner_pid), do: owner_pid
  defp ready_owner(_status, _owner_pid), do: nil

  defp ready_owner_changed?(previous_owner, :ready, owner_pid) when is_pid(previous_owner) do
    previous_owner != owner_pid
  end

  defp ready_owner_changed?(_previous_owner, _status, _owner_pid), do: false

  defp maybe_assign_ready_owner(socket, :ready, owner_pid),
    do: assign(socket, :mcp_ready_owner, owner_pid)

  defp maybe_assign_ready_owner(socket, _status, _owner_pid), do: socket

  defp execution_context(socket, meta) do
    model =
      case Providers.model_from_client_params(meta && meta["model"]) do
        {:ok, model} -> model
        :error -> nil
      end

    %{
      model: model,
      mcp_tools: socket.assigns.mcp_tools,
      project_traits: Frameworks.project_traits_from_meta(meta, socket.assigns.framework)
    }
  end

  defp to_plan_entry(%Todo{} = todo) do
    %{
      "content" => todo.content,
      "priority" => Atom.to_string(todo.priority),
      "status" => Atom.to_string(todo.status)
    }
  end
end
