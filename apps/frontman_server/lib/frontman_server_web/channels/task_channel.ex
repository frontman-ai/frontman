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
  alias FrontmanServer.Frameworks
  alias FrontmanServer.Observability.SentryContext
  alias FrontmanServer.Providers
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.RetryCoordinator
  alias FrontmanServer.Tasks.Todos.Todo
  alias FrontmanServer.Tools
  alias FrontmanServerWeb.ACPHistory
  alias FrontmanServerWeb.TaskChannel.MCPInitializer
  alias ModelContextProtocol, as: MCP

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
        SentryContext.set_task_scope_context(scope, task_id)

        Logger.info("Client joining: #{task_id}, socket_id: #{inspect(self())}")

        # Start MCP initialization as a synchronous state machine.
        # State is stored in socket assigns — no separate GenServer process.
        # Each websocket connection needs its own MCP session because:
        # 1. MCPInitializer performs a stateful handshake with the browser-side MCP client
        # 2. Project rules loading depends on client-specific context
        # Tools are stored in socket assigns for LLM availability and browser routing.
        #
        # Note: Phoenix channels prohibit push() during join/3, so we defer
        # the initial MCP request push to handle_info(:start_mcp_init).
        # All subsequent MCP responses are processed synchronously in handle_in.
        {init_state, init_actions} = MCPInitializer.start(task_id, scope, task.framework)

        socket =
          socket
          |> assign(:task_id, task_id)
          |> assign(:framework, task.framework)
          |> assign(:mcp_init_state, init_state)
          |> assign(:mcp_tools, [])
          |> assign(:mcp_status, :pending)
          |> assign(:session_loaded, false)
          |> assign(:pending_mcp_tool_requests, %{})

        send(self(), {:start_mcp_init, init_actions})

        {:ok, %{task_id: task_id}, socket}

      {:error, :not_found} ->
        Logger.info("Client tried to join non-existent task: #{task_id}")
        {:error, %{reason: "task_not_found"}}
    end
  end

  @impl true
  def handle_in(@acp_message, payload, socket) do
    parsed = JsonRpc.parse(payload)

    Logger.info(fn -> "Got ACP message #{inspect(parsed)}" end)

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
  def handle_in("mcp:message", payload, socket) do
    case JsonRpc.parse_response(payload) do
      {:ok, {:success, id, result}} ->
        handle_mcp_response(id, result, socket)

      {:ok, {:error, id, error}} ->
        handle_mcp_error(id, error, socket)

      {:error, reason} ->
        Logger.error("Invalid MCP response: #{inspect(reason)}, payload: #{inspect(payload)}")

        error_notification =
          JsonRpc.notification("error", %{
            "message" => "Invalid JSON-RPC response",
            "reason" => Atom.to_string(reason)
          })

        push(socket, "mcp:message", error_notification)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:start_mcp_init, actions}, socket) do
    # Deferred from join/3 because Phoenix channels prohibit push() during join.
    # The init state and actions were already created in join — we just need
    # to execute the deferred push actions now that the socket is fully joined.
    socket = execute_init_actions(actions, socket)
    {:noreply, socket}
  end

  def handle_info({:run_next_turn, execution}, socket) do
    case Tasks.run_next_turn(socket.assigns.scope, socket.assigns.task_id, execution) do
      result when result in [:ok, :already_running, :no_accepted_messages] ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to run next turn: #{inspect(reason)}")
    end

    {:noreply, socket}
  end

  # --- Execution events (live transport from Tasks via PubSub) ---

  def handle_info({:execution_chunk, _turn_number, chunk}, socket) do
    {:noreply, handle_execution_chunk(socket, chunk)}
  end

  # --- Interaction events (from Tasks persistence layer via PubSub) ---

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

  def handle_info(msg, _socket) do
    raise "Unhandled message in TaskChannel: #{inspect(msg)}"
  end

  defp handle_interaction(%Tasks.Interaction.ToolCall{} = tool_call, _turn_number, socket) do
    task_id = socket.assigns.task_id

    announced = socket.assigns[:announced_tool_calls] || MapSet.new()

    unless MapSet.member?(announced, tool_call.tool_call_id) do
      pending_notification =
        ACP.tool_call_create(
          task_id,
          tool_call.tool_call_id,
          tool_call.tool_name,
          "other",
          DateTime.utc_now()
        )

      push(socket, @acp_message, pending_notification)
    end

    args_content = ACP.Content.from_tool_result(tool_call.arguments)

    args_notification =
      ACP.tool_call_update(
        task_id,
        tool_call.tool_call_id,
        ACP.tool_call_status_pending(),
        args_content
      )

    push(socket, @acp_message, args_notification)

    case Tools.execution_target(tool_call.tool_name) do
      :backend ->
        {:noreply, socket}

      :mcp ->
        route_to_mcp(tool_call, socket)
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
      status =
        if tool_result.is_error,
          do: ACP.tool_call_status_failed(),
          else: ACP.tool_call_status_completed()

      content = ACP.Content.from_tool_result(tool_result.result)
      notification = ACP.tool_call_update(task_id, tool_result.tool_call_id, status, content)
      push(socket, @acp_message, notification)
    end

    {:noreply, socket}
  end

  defp handle_interaction(%Tasks.Interaction.AgentCompleted{}, turn_number, socket) do
    finalize_turn(socket, {:completed, ACP.stop_reason_end_turn()}, turn_number)
  end

  defp handle_interaction(%Tasks.Interaction.TurnStarted{}, _turn_number, socket) do
    task_id = socket.assigns.task_id
    notification = ACP.build_state_update_notification(task_id, "running")
    push(socket, @acp_message, notification)
    {:noreply, socket}
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

  defp handle_mcp_response(id, result, socket) do
    init_state = socket.assigns[:mcp_init_state]

    if mcp_initialization_request?(init_state, id) do
      {new_state, actions} = MCPInitializer.handle_response(init_state, id, result)
      socket = assign(socket, :mcp_init_state, new_state)
      {:noreply, execute_init_actions(actions, socket)}
    else
      handle_tool_call_response_by_id(id, result, socket)
    end
  end

  defp handle_tool_call_response_by_id(id, result, socket) when is_integer(id) do
    case pop_mcp_tool_request(socket, id) do
      {:ok, tool_call_id, socket} ->
        case open_tool_call(socket, tool_call_id) do
          {:ok, tool_call} ->
            handle_tool_call_response(tool_call, result, socket)

          :error ->
            Logger.warning(
              "Received MCP response for unknown tool_call_id: #{inspect(tool_call_id)}"
            )

            {:noreply, socket}
        end

      :error ->
        unknown_mcp_response(id, socket)
    end
  end

  defp handle_tool_call_response_by_id(id, _result, socket), do: unknown_mcp_response(id, socket)

  defp pop_mcp_tool_request(socket, request_id) do
    case Map.pop(socket.assigns.pending_mcp_tool_requests, request_id) do
      {nil, _pending} ->
        :error

      {tool_call_id, pending} ->
        {:ok, tool_call_id, assign(socket, :pending_mcp_tool_requests, pending)}
    end
  end

  defp open_tool_call(socket, tool_call_id) do
    with {:ok, _turn_number, tool_calls} when is_list(tool_calls) <-
           Tasks.get_active_run_unresolved_tool_calls(
             socket.assigns.scope,
             socket.assigns.task_id
           ),
         %Tasks.Interaction.ToolCall{} = tool_call <-
           Enum.find(tool_calls, &(&1.tool_call_id == tool_call_id)) do
      {:ok, tool_call}
    else
      _ -> :error
    end
  end

  defp unknown_mcp_response(id, socket) do
    Logger.warning("Received MCP response for unknown request_id: #{inspect(id)}")
    {:noreply, socket}
  end

  defp handle_tool_call_response(tool_call, result, socket) do
    task_id = socket.assigns.task_id
    scope = socket.assigns.scope
    is_error = MCP.error?(result)
    meta = result["_meta"] || %{}

    status =
      if is_error, do: ACP.tool_call_status_failed(), else: ACP.tool_call_status_completed()

    Logger.info("Tool #{tool_call.tool_name} #{status}")

    content = ACP.Content.from_tool_result(result)
    notification = ACP.tool_call_update(task_id, tool_call.tool_call_id, status, content)
    push(socket, @acp_message, notification)

    socket =
      case Tasks.resolve_tool_request(
             scope,
             task_id,
             %{id: tool_call.tool_call_id, name: tool_call.tool_name},
             result,
             is_error
           ) do
        {:ok, _interaction, :notified} ->
          socket

        {:ok, _interaction, :no_executor} ->
          # No live executor (agent dead after server restart). If all active-run
          # tool calls have results, resume the agent using model from the tool
          # result's _meta (sent by the client per MCP spec).
          case Tasks.get_active_run_unresolved_tool_calls(scope, task_id) do
            {:ok, _turn_number, []} ->
              Logger.info(
                "Active agent run has no unresolved tool calls for #{task_id}, resuming agent"
              )

              resume_agent(socket, scope, task_id, meta)

            {:ok, _turn_number, [_ | _]} ->
              socket

            {:ok, :no_active_run} ->
              socket
          end

        {:error, reason} ->
          Logger.warning(
            "Failed to store tool result for #{tool_call.tool_call_id}: #{inspect(reason)}"
          )

          socket
      end

    {:noreply, socket}
  end

  defp resume_agent(socket, scope, task_id, meta) do
    model =
      case Providers.model_from_client_params(meta["model"]) do
        {:ok, m} -> m
        :error -> nil
      end

    Tasks.resume_execution(scope, task_id, %{
      model: model,
      mcp_tools: socket.assigns.mcp_tools,
      project_traits: Frameworks.project_traits_from_meta(meta, socket.assigns.framework)
    })

    socket
  end

  defp handle_mcp_error(id, error, socket) do
    init_state = socket.assigns[:mcp_init_state]

    if mcp_initialization_request?(init_state, id) do
      {new_state, actions} = MCPInitializer.handle_error(init_state, id, error)
      socket = assign(socket, :mcp_init_state, new_state)
      {:noreply, execute_init_actions(actions, socket)}
    else
      handle_tool_call_error_by_id(id, error, socket)
    end
  end

  defp mcp_initialization_request?(%{} = init_state, id) when is_integer(id) do
    id in [
      init_state.mcp_init_request_id,
      init_state.tools_request_id,
      init_state.project_rules_request_id,
      init_state.project_structure_request_id
    ]
  end

  defp mcp_initialization_request?(_init_state, _id), do: false

  defp handle_tool_call_error_by_id(id, error, socket) when is_integer(id) do
    case pop_mcp_tool_request(socket, id) do
      {:ok, tool_call_id, socket} ->
        case open_tool_call(socket, tool_call_id) do
          {:ok, tool_call} ->
            handle_tool_call_error(tool_call, error, socket)

          :error ->
            Logger.warning(
              "Received MCP error for unknown tool_call_id: #{inspect(tool_call_id)}"
            )

            {:noreply, socket}
        end

      :error ->
        unknown_mcp_error(id, socket)
    end
  end

  defp handle_tool_call_error_by_id(id, _error, socket), do: unknown_mcp_error(id, socket)

  defp unknown_mcp_error(id, socket) do
    Logger.warning("Received MCP error for unknown request_id: #{inspect(id)}")
    {:noreply, socket}
  end

  defp handle_tool_call_error(tool_call, error, socket) do
    task_id = socket.assigns.task_id
    scope = socket.assigns.scope
    error_message = error["message"] || "Unknown MCP error"

    metadata = [
      error_type: "mcp_tool_error",
      tool_name: tool_call.tool_name,
      tool_call_id: tool_call.tool_call_id,
      task_id: task_id,
      error_message: error_message
    ]

    Logger.error("MCP tool execution failed", metadata)

    failed_content = ACP.Content.from_tool_result(error_message)

    failed_notification =
      ACP.tool_call_update(
        task_id,
        tool_call.tool_call_id,
        ACP.tool_call_status_failed(),
        failed_content
      )

    push(socket, @acp_message, failed_notification)

    # Store error result and notify agent.
    # :no_executor means the agent is dead (e.g. server restart). Unlike the
    # success path in handle_tool_call_response/4, we don't auto-resume here because MCP
    # error responses don't carry _meta with the model needed to restart.
    # The error is persisted; the user can retry via a new prompt.
    case Tasks.resolve_tool_request(
           scope,
           task_id,
           %{id: tool_call.tool_call_id, name: tool_call.tool_name},
           ModelContextProtocol.tool_result_error(error_message),
           true
         ) do
      {:ok, _interaction, _executor_status} ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Failed to store tool error result for #{tool_call.tool_call_id}: #{inspect(reason)}"
        )
    end

    {:noreply, socket}
  end

  defp handle_prompt(id, params, socket) do
    if socket.assigns[:mcp_status] == :failed do
      Logger.warning(
        "Processing prompt with failed MCP initialization for task #{socket.assigns.task_id}"
      )
    end

    process_prompt(id, params, socket)
  end

  defp handle_cancel(_params, socket) do
    task_id = socket.assigns.task_id
    Logger.info("Cancel notification received for task #{task_id}")

    had_retry = socket.assigns[:retry_state] != nil
    socket = assign(socket, :retry_state, RetryCoordinator.clear(socket.assigns[:retry_state]))

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

  # This is called after the client has joined the session channel, allowing
  # history notifications to be received through the onUpdate callback.
  defp handle_session_load(id, _params, socket) do
    task_id = socket.assigns.task_id
    scope = socket.assigns.scope
    Logger.info("ACP session/load request received on session channel for: #{task_id}")

    case Tasks.get_task(scope, task_id) do
      {:ok, task} ->
        stream_session_history(socket, task)

        # Return ACP-compliant LoadSessionResponse with config options.
        config_options =
          scope
          |> Providers.model_config_data()
          |> ACP.build_model_config_options()

        push(
          socket,
          @acp_message,
          JsonRpc.success_response(id, ACP.build_session_load_result(config_options))
        )

        socket =
          socket
          |> assign(:session_loaded, true)
          |> redispatch_unresolved_tool_calls()

        wake_runner(socket, nil)

        {:noreply, socket}

      {:error, :not_found} ->
        push_acp_error(socket, id, JsonRpc.error_invalid_params(), "Session not found")
    end
  end

  defp stream_session_history(socket, task) do
    task.interactions
    |> Enum.flat_map(&ACPHistory.to_history_items(&1, task.id))
    |> Enum.each(fn notification ->
      push(socket, @acp_message, notification)
    end)
  end

  defp process_prompt(id, %{"prompt" => content_blocks, "_meta" => meta}, socket)
       when is_map(meta) do
    task_id = socket.assigns.task_id
    scope = socket.assigns.scope

    case Providers.model_from_client_params(meta["model"]) do
      {:ok, model} ->
        Logger.info("process_prompt", %{task_id: task_id, model: model})

        case Tasks.submit_user_message(
               scope,
               %{
                 task_id: task_id,
                 message: content_blocks,
                 model: model
               }
             ) do
          {:ok, interaction} ->
            push(
              socket,
              @acp_message,
              ACP.build_user_message_notification(task_id, interaction.id, content_blocks)
            )

            wake_runner(socket, meta)

            Logger.info("User message accepted for task #{task_id}")
            {:reply, {:ok, %{@acp_message => JsonRpc.success_response(id, %{})}}, socket}

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

  defp reply_acp_error(socket, id, code, message) do
    {:reply, {:ok, %{@acp_message => JsonRpc.error_response(id, code, message)}}, socket}
  end

  defp push_acp_error(socket, id, code, message) do
    push(socket, @acp_message, JsonRpc.error_response(id, code, message))
    {:noreply, socket}
  end

  defp handle_execution_chunk(socket, %{type: :content, text: text})
       when is_binary(text) and text != "" do
    task_id = socket.assigns.task_id
    notification = ACP.build_agent_message_chunk_notification(task_id, text, DateTime.utc_now())
    push(socket, @acp_message, notification)
    socket
  end

  defp handle_execution_chunk(socket, %{type: :tool_call, name: name, metadata: %{id: id}})
       when is_binary(name) and is_binary(id) do
    announce_stream_tool_call_once(socket, id, name)
  end

  defp handle_execution_chunk(socket, _chunk), do: socket

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

  defp handle_invalid_acp_message(reason, payload, socket) do
    Logger.error(
      "Invalid ACP message in task channel: #{inspect(reason)}, payload: #{inspect(payload)}"
    )

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

  # Unified turn finalization — every code path that ends a turn goes through here.
  # This guarantees the domain invariant: retry_state is always nil when a turn ends.

  defp finalize_turn(socket, outcome, _turn_number) do
    task_id = socket.assigns.task_id
    socket = assign(socket, :retry_state, RetryCoordinator.clear(socket.assigns[:retry_state]))

    case outcome do
      {:completed, stop_reason} ->
        notification = ACP.build_state_update_notification(task_id, "idle", stop_reason)
        push(socket, @acp_message, notification)
        wake_runner(socket, nil)
        {:noreply, socket}

      :requires_action ->
        notification = ACP.build_state_update_notification(task_id, "requires_action")
        push(socket, @acp_message, notification)
        {:noreply, socket}

      {:error, agent_error_id, message, category} ->
        push_agent_error(socket, agent_error_id, message, category)
        wake_runner(socket, nil)
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
    case socket.assigns[:mcp_status] do
      status when status in [:ready, :failed] ->
        send(self(), {:run_next_turn, execution_context(socket, meta)})

      _pending ->
        :ok
    end
  end

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

  # Execute actions returned by the MCPInitializer state machine.
  # Each action is processed synchronously within the current callback,
  # eliminating async process hops that caused race conditions.
  defp execute_init_actions(actions, socket) do
    apply_init_actions(actions, socket)
  end

  defp apply_init_actions([], socket), do: socket

  defp apply_init_actions([action | rest], socket) do
    socket = apply_init_action(socket, action)
    apply_init_actions(rest, socket)
  end

  defp apply_init_action(socket, {:push_mcp, msg}) do
    push(socket, "mcp:message", msg)
    socket
  end

  defp apply_init_action(socket, {:push_acp, msg}) do
    push(socket, @acp_message, msg)
    socket
  end

  defp apply_init_action(socket, {:initialization_complete, data}) do
    task_id = socket.assigns.task_id
    Logger.info("MCP initialization complete for task #{task_id}")

    socket
    |> assign(:mcp_status, :ready)
    |> assign(:mcp_capabilities, data.mcp_capabilities)
    |> assign(:mcp_server_info, data.mcp_server_info)
    |> assign(:mcp_tools, data.tools)
    |> redispatch_unresolved_tool_calls()
    |> tap(&wake_runner(&1, nil))
  end

  defp apply_init_action(socket, {:initialization_failed, error}) do
    Logger.error("MCP initialization failed: #{inspect(error)}")

    socket
    |> assign(:mcp_status, :failed)
    |> assign(:mcp_error, error)
    |> redispatch_unresolved_tool_calls()
    |> tap(&wake_runner(&1, nil))
  end

  defp redispatch_unresolved_tool_calls(
         %{assigns: %{session_loaded: true, mcp_status: status}} = socket
       )
       when status in [:ready, :failed] do
    case Tasks.get_active_run_unresolved_tool_calls(socket.assigns.scope, socket.assigns.task_id) do
      {:ok, turn_number, tool_calls} when is_list(tool_calls) ->
        Enum.reduce(tool_calls, socket, &redispatch_unresolved_tool_call(&2, &1, turn_number))

      {:ok, :no_active_run} ->
        socket
    end
  end

  defp redispatch_unresolved_tool_calls(socket), do: socket

  defp redispatch_unresolved_tool_call(socket, tool_call, turn_number) do
    case mcp_tool_request_pending?(socket, tool_call.tool_call_id) do
      true ->
        socket

      false ->
        {:noreply, socket} = handle_interaction(tool_call, turn_number, socket)
        socket
    end
  end

  defp mcp_tool_request_pending?(socket, tool_call_id) do
    socket.assigns.pending_mcp_tool_requests
    |> Map.values()
    |> Enum.member?(tool_call_id)
  end

  defp route_to_mcp(tool_call, socket) do
    task_id = socket.assigns.task_id
    request_id = System.unique_integer([:positive])

    request =
      MCP.build_tool_execution(%MCP.ToolCallParams{
        request_id: request_id,
        tool_name: tool_call.tool_name,
        arguments: tool_call.arguments,
        call_id: tool_call.tool_call_id
      })

    in_progress_notification =
      ACP.tool_call_update(task_id, tool_call.tool_call_id, ACP.tool_call_status_in_progress())

    push(socket, @acp_message, in_progress_notification)

    socket = remember_mcp_tool_request(socket, request_id, tool_call.tool_call_id)

    push(socket, "mcp:message", request)
    {:noreply, socket}
  end

  defp remember_mcp_tool_request(socket, request_id, tool_call_id) do
    pending = Map.put(socket.assigns.pending_mcp_tool_requests, request_id, tool_call_id)
    assign(socket, :pending_mcp_tool_requests, pending)
  end

  defp to_plan_entry(%Todo{} = todo) do
    %{
      "content" => todo.content,
      "priority" => Atom.to_string(todo.priority),
      "status" => Atom.to_string(todo.status)
    }
  end
end
