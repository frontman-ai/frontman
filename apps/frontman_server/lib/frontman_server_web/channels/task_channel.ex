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
  alias FrontmanServer.Providers
  alias FrontmanServer.Providers.{Model, Registry}
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.{Execution, ExecutionEvent, RetryCoordinator, Todos}
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
      {:ok, _task} ->
        Logger.info("Client joining: #{task_id}, socket_id: #{inspect(self())}")

        # Start MCP initialization as a synchronous state machine.
        # State is stored in socket assigns — no separate GenServer process.
        # Each websocket connection needs its own MCP session because:
        # 1. MCPInitializer performs a stateful handshake with the browser-side MCP client
        # 2. Project rules loading depends on client-specific context
        # Tools are stored in socket assigns and passed through Backend.Context for agent access.
        #
        # Note: Phoenix channels prohibit push() during join/3, so we defer
        # the initial MCP request push to handle_info(:start_mcp_init).
        # All subsequent MCP responses are processed synchronously in handle_in.
        {init_state, init_actions} = MCPInitializer.start(task_id, scope)

        socket =
          socket
          |> assign(:task_id, task_id)
          |> assign(:mcp_init_state, init_state)
          |> assign(:mcp_status, :pending)
          |> assign(:mcp_init_actions, init_actions)

        send(self(), :start_mcp_init)

        {:ok, %{task_id: task_id}, socket}

      {:error, :not_found} ->
        Logger.info("Client tried to join non-existent task: #{task_id}")
        {:error, %{reason: "task_not_found"}}
    end
  end

  @impl true
  def handle_in(@acp_message, payload, socket) do
    case JsonRpc.parse(payload) do
      {:ok, {:request, id, @acp_method_session_prompt, params}} ->
        handle_prompt(id, params, socket)

      {:ok, {:notification, @acp_method_session_cancel, params}} ->
        handle_cancel(params, socket)

      {:ok, {:request, id, @acp_method_session_load, params}} ->
        # Load session history - streamed via session/update notifications
        handle_session_load(id, params, socket)

      {:ok, {:request, id, method, _params}} ->
        Logger.info("Unknown ACP method in task channel: #{method}")

        response =
          JsonRpc.error_response(
            id,
            JsonRpc.error_method_not_found(),
            "Method not found: #{method}"
          )

        {:reply, {:ok, %{@acp_message => response}}, socket}

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
    Logger.debug("Received mcp:message payload: #{inspect(payload)}")

    case JsonRpc.parse_response(payload) do
      {:ok, {:success, id, result}} ->
        handle_mcp_response(id, result, socket)

      {:ok, {:error, id, error}} ->
        handle_mcp_error(id, error, socket)

      {:error, reason} ->
        Logger.error("Invalid MCP response: #{inspect(reason)}, payload: #{inspect(payload)}")

        # Send error notification to client for better debugging
        error_notification =
          JsonRpc.notification("error", %{
            "message" => "Invalid JSON-RPC response",
            "reason" => Atom.to_string(reason)
          })

        push(socket, "mcp:message", error_notification)

        {:noreply, socket}
    end
  end

  defp handle_mcp_response(id, result, socket) do
    pending_requests = socket.assigns[:pending_requests] || %{}
    init_state = socket.assigns[:mcp_init_state]

    Logger.debug(
      "MCP response received: id=#{id}, pending_keys=#{inspect(Map.keys(pending_requests))}"
    )

    cond do
      # Tool call response - channel owns these IDs
      Map.has_key?(pending_requests, id) ->
        Logger.debug("MCP response #{id} matched pending tool call")

        case Map.pop(pending_requests, id) do
          {{:tool_call, tool_call}, remaining_requests} ->
            handle_tool_call_response(id, tool_call, result, socket, remaining_requests)

          {nil, _} ->
            Logger.warning("Received MCP response for unknown request_id: #{id}")
            {:noreply, socket}
        end

      # Initialization response - MCPInitializer state owns these IDs
      init_state && MCPInitializer.expects_response?(init_state, id) ->
        Logger.debug("MCP response #{id} matched MCPInitializer")
        {new_state, actions} = MCPInitializer.handle_response(init_state, id, result)
        socket = assign(socket, :mcp_init_state, new_state)
        socket = execute_init_actions(actions, socket)
        maybe_process_queued_prompt(socket)

      true ->
        Logger.warning("Received MCP response for unknown request_id: #{id}")
        {:noreply, socket}
    end
  end

  defp handle_tool_call_response(_id, tool_call, result, socket, remaining_requests) do
    text_result = MCP.extract_content_text(result)
    parsed_result = MCP.parse_tool_result(text_result)
    is_error = MCP.error?(result)

    # Extract _meta from the tool result (MCP spec extension point).
    # Contains env API keys + model for agent resume after server restart.
    meta = result["_meta"] || %{}

    store_tool_result(
      tool_call.tool_call_id,
      tool_call.tool_name,
      text_result,
      parsed_result,
      is_error,
      meta,
      socket
    )

    socket = assign(socket, :pending_requests, remaining_requests)
    {:noreply, socket}
  end

  # Shared logic for storing a tool result, pushing ACP notification, and
  # resuming agent execution if all pending tools are resolved.
  #
  # `meta` is the MCP _meta from the tool result — carries env API keys + model
  # so the server can resume the agent with the correct provider context.
  defp store_tool_result(
         tool_call_id,
         tool_name,
         text_result,
         parsed_result,
         is_error,
         meta,
         socket
       ) do
    task_id = socket.assigns.task_id
    scope = socket.assigns.scope

    status =
      if is_error, do: ACP.tool_call_status_failed(), else: ACP.tool_call_status_completed()

    Logger.info("Tool #{tool_name} #{status}: #{text_result}")

    # Send ACP notification with appropriate status
    content = ACP.Content.from_tool_result(text_result)
    notification = ACP.tool_call_update(task_id, tool_call_id, status, content)
    push(socket, @acp_message, notification)

    # Store result and notify agent
    case Tasks.add_tool_result(
           scope,
           task_id,
           %{id: tool_call_id, name: tool_name},
           parsed_result,
           is_error
         ) do
      {:ok, _interaction, :notified} ->
        :ok

      {:ok, _interaction, :no_executor} ->
        # No live executor (agent dead after server restart). If all pending
        # tools are now resolved, resume the agent using env_api_key + model
        # from the tool result's _meta (sent by the client per MCP spec).
        {:ok, task} = Tasks.get_task(scope, task_id)

        if Tasks.Interaction.all_pending_tools_resolved?(task.interactions) do
          Logger.info("All pending tools resolved for #{task_id}, resuming agent")
          maybe_resume_agent(socket, scope, task_id, meta)
        end

      {:error, reason} ->
        Logger.warning("Failed to store tool result for #{tool_call_id}: #{inspect(reason)}")
    end
  end

  defp maybe_resume_agent(socket, scope, task_id, meta) do
    env_api_key = Registry.extract_env_keys(meta)

    model =
      case Model.from_client_params(meta["model"]) do
        {:ok, m} -> m
        :error -> nil
      end

    mcp_tools = socket.assigns[:mcp_tools] || []
    all_tools = mcp_tools |> Tools.prepare_for_task(task_id)

    opts =
      build_execution_opts(socket,
        env_api_key: env_api_key,
        model: model,
        mcp_tool_defs: mcp_tools
      )

    Tasks.maybe_start_execution(scope, task_id, all_tools, opts)
  end

  defp handle_mcp_error(id, error, socket) do
    pending_requests = socket.assigns[:pending_requests] || %{}
    init_state = socket.assigns[:mcp_init_state]

    Logger.debug(
      "MCP error received: id=#{id}, pending_keys=#{inspect(Map.keys(pending_requests))}"
    )

    cond do
      # Tool call error - channel owns these IDs
      Map.has_key?(pending_requests, id) ->
        case Map.pop(pending_requests, id) do
          {{:tool_call, tool_call}, remaining_requests} ->
            handle_tool_call_error(id, tool_call, error, socket, remaining_requests)

          {nil, _} ->
            Logger.warning("Received MCP error for unknown request_id: #{id}")
            {:noreply, socket}
        end

      # Initialization error - MCPInitializer state owns these IDs
      init_state && MCPInitializer.expects_response?(init_state, id) ->
        {new_state, actions} = MCPInitializer.handle_error(init_state, id, error)
        socket = assign(socket, :mcp_init_state, new_state)
        socket = execute_init_actions(actions, socket)
        maybe_process_queued_prompt(socket)

      true ->
        Logger.warning("Received MCP error for unknown request_id: #{id}")
        {:noreply, socket}
    end
  end

  defp handle_tool_call_error(_id, tool_call, error, socket, remaining_requests) do
    task_id = socket.assigns.task_id
    scope = socket.assigns.scope
    error_message = error["message"] || "Unknown MCP error"
    Logger.error("MCP tool #{tool_call.tool_name} failed: #{error_message}")

    Sentry.capture_message("MCP tool execution failed",
      level: :error,
      tags: %{error_type: "mcp_tool_error"},
      extra: %{
        tool_name: tool_call.tool_name,
        tool_call_id: tool_call.tool_call_id,
        task_id: task_id,
        error_message: error_message
      }
    )

    # Send ACP notification: failed
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
    # success path in store_tool_result, we don't auto-resume here because MCP
    # error responses don't carry _meta (env API keys + model) needed to restart.
    # The error is persisted; the user can retry via a new prompt.
    case Tasks.add_tool_result(
           scope,
           task_id,
           %{id: tool_call.tool_call_id, name: tool_call.tool_name},
           error_message,
           true
         ) do
      {:ok, _interaction, _executor_status} ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Failed to store tool error result for #{tool_call.tool_call_id}: #{inspect(reason)}"
        )
    end

    socket = assign(socket, :pending_requests, remaining_requests)
    {:noreply, socket}
  end

  defp handle_prompt(id, params, socket) do
    task_id = socket.assigns.task_id

    # Check if MCP initialization is complete
    case socket.assigns[:mcp_status] do
      :ready ->
        # MCP is ready, process the prompt immediately
        process_prompt(id, params, socket)

      :failed ->
        # MCP failed, process anyway with empty tools (best effort)
        Logger.warning("Processing prompt with failed MCP initialization for task #{task_id}")
        process_prompt(id, params, socket)

      _pending ->
        # MCP still initializing, queue the prompt
        Logger.info("MCP still initializing, queueing prompt for task #{task_id}")

        socket =
          socket
          |> assign(:queued_prompt, {id, params})

        {:noreply, socket}
    end
  end

  # ACP spec: session/cancel is a NOTIFICATION (no response expected).
  # The pending session/prompt request will be resolved with stopReason: "cancelled"
  # via the :agent_cancelled handler (triggered by the death watcher).
  defp handle_cancel(_params, socket) do
    task_id = socket.assigns.task_id
    Logger.info("Cancel notification received for task #{task_id}")

    # Clear retry state up front — whether an execution is running or not,
    # the user wants to stop. Cancel the timer so :fire_retry doesn't arrive later.
    # Note: the :ok branch below does NOT call finalize_turn (the :agent_cancelled
    # handler will), so we must clear here to cover both branches.
    had_retry = socket.assigns[:retry_state] != nil
    socket = assign(socket, :retry_state, RetryCoordinator.clear(socket.assigns[:retry_state]))

    case Tasks.cancel_execution(socket.assigns.scope, task_id) do
      :ok ->
        # Execution running — cancel signal sent. The :agent_cancelled handler
        # will call finalize_turn when the execution actually stops.
        Logger.info("Agent cancel signal sent for task #{task_id}")
        {:noreply, socket}

      {:error, :not_running} ->
        Logger.info("Cancel notification for task #{task_id}: no agent running")

        if had_retry do
          # Was in retry countdown — no execution to cancel, end the turn now
          finalize_turn(socket, {:completed, ACP.stop_reason_cancelled()}, nil)
        else
          {:noreply, socket}
        end
    end
  end

  # Handle session/load - stream history via session/update notifications
  # This is called after the client has joined the session channel, allowing
  # history notifications to be received through the onUpdate callback.
  defp handle_session_load(id, params, socket) do
    task_id = socket.assigns.task_id
    scope = socket.assigns.scope
    Logger.info("ACP session/load request received on session channel for: #{task_id}")

    case Tasks.get_task(scope, task_id) do
      {:ok, task} ->
        # Stream history via session/update notifications
        stream_session_history(socket, task)

        # Return ACP-compliant LoadSessionResponse with config options.
        # Extract env API keys from _meta (forwarded from clientInfo metadata)
        # since the task channel doesn't receive the ACP initialize request.
        env_api_key = extract_env_api_key_from_params(params)

        config_options =
          Providers.model_config_data(scope, env_api_key)
          |> ACP.build_model_config_options()

        push(
          socket,
          @acp_message,
          JsonRpc.success_response(id, ACP.build_session_load_result(config_options))
        )

        # Re-dispatch unresolved tool calls so the live handle_info path
        # routes them to MCP. The success response above triggers LoadComplete
        # on the client (task → Loaded), so by the time the mcp:message arrives
        # the client can handle it via the normal live execution pipeline.
        reexecute_unresolved_tool_calls(task.interactions)

        {:noreply, socket}

      {:error, :not_found} ->
        push(
          socket,
          @acp_message,
          JsonRpc.error_response(id, JsonRpc.error_invalid_params(), "Session not found")
        )

        {:noreply, socket}
    end
  end

  # Streams session history as ACP session/update notifications
  defp stream_session_history(socket, task) do
    task.interactions
    |> Enum.flat_map(&ACPHistory.to_history_items(&1, task.task_id))
    |> Enum.each(fn notification ->
      push(socket, @acp_message, notification)
    end)
  end

  # Re-dispatch unresolved tool calls through the live handle_info path.
  # ToolCalls without a matching ToolResult are re-sent as {:interaction, ...}
  # messages to self(), which routes MCP tools to the client via tools/call.
  defp reexecute_unresolved_tool_calls(interactions) do
    alias Tasks.Interaction.{AgentCompleted, AgentError, ToolCall, ToolResult}

    resolved_ids =
      interactions
      |> Enum.filter(&match?(%ToolResult{}, &1))
      |> MapSet.new(& &1.tool_call_id)

    # Don't re-execute if the agent already completed/errored after the tool call.
    # This handles legacy data where "Client disconnected" caused the agent to
    # improvise and complete despite a missing tool result.
    last_completion_seq =
      interactions
      |> Enum.filter(&(match?(%AgentCompleted{}, &1) or match?(%AgentError{}, &1)))
      |> Enum.map(& &1.sequence)
      |> Enum.max(fn -> 0 end)

    interactions
    |> Enum.filter(&match?(%ToolCall{}, &1))
    |> Enum.reject(fn tc ->
      MapSet.member?(resolved_ids, tc.tool_call_id) or tc.sequence < last_completion_seq
    end)
    |> Enum.each(fn tc -> send(self(), {:interaction, tc}) end)
  end

  defp process_prompt(id, params, socket) do
    task_id = socket.assigns.task_id
    scope = socket.assigns.scope
    mcp_tools = socket.assigns[:mcp_tools] || []

    # Extract env API key from prompt _meta (sent with each prompt request)
    env_api_key = extract_env_api_key_from_params(params)

    # Extract model selection from prompt _meta
    model = extract_model_from_params(params)
    # model is either a %Model{} struct or nil

    # Parse ACP prompt (protocol layer)
    prompt = ACP.parse_prompt_params(params)

    # Logging
    Logger.info("Received prompt for task #{task_id}: #{prompt.text_summary}")

    if prompt.has_resources do
      Logger.info("Prompt includes embedded context")
    end

    if model do
      Logger.info("Using model: #{model}")
    end

    # Prepare tools (domain service)
    all_tools = mcp_tools |> Tools.prepare_for_task(task_id)

    opts =
      build_execution_opts(socket,
        env_api_key: env_api_key,
        model: model,
        mcp_tool_defs: mcp_tools
      )

    case Tasks.submit_user_message(scope, task_id, prompt.content, all_tools, opts) do
      {:error, :already_running} ->
        Logger.info("Rejected prompt — agent already running for task #{task_id}")
        error_response = JsonRpc.error_response(id, -32_000, "Agent already running")
        {:reply, {:ok, %{@acp_message => error_response}}, socket}

      {:ok, interaction} ->
        # Execution started — correlate this JSON-RPC request with the domain interaction
        socket =
          assign(socket, :pending_prompt, %{
            interaction_id: interaction.id,
            jsonrpc_id: id
          })

        # Store interaction_id in execution opts for retry flow
        opts = Keyword.put(opts, :interaction_id, interaction.id)
        socket = assign(socket, :last_execution_opts, opts)

        Logger.info("User message added, agent spawned for task #{task_id}")

        Tasks.enqueue_title_generation(scope, task_id, prompt.text_summary,
          env_api_key: env_api_key,
          model: model
        )

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Failed to add user message: #{inspect(reason)}")
        error_response = JsonRpc.error_response(id, -32_000, to_string(reason))
        {:reply, {:ok, %{@acp_message => error_response}}, socket}
    end
  end

  # Extract env API keys from prompt params _meta (e.g., OPENROUTER_API_KEY, ANTHROPIC_API_KEY from project env)
  defp extract_env_api_key_from_params(params) when is_map(params) do
    params |> get_in(["_meta"]) |> Registry.extract_env_keys()
  end

  defp extract_env_api_key_from_params(_), do: %{}

  # Builds execution opts, forwarding an injected agent if present in socket assigns.
  # In production, :agent_override is never set. Tests can assign it to avoid real
  # LLM calls — see FrontmanServer.Testing.BlockingAgent.
  defp build_execution_opts(socket, base_opts) do
    case socket.assigns[:agent_override] do
      nil -> base_opts
      agent -> [{:agent, agent} | base_opts]
    end
  end

  # Extract model selection from prompt params _meta.
  # Returns a %Model{} struct or nil.
  defp extract_model_from_params(params) when is_map(params) do
    case Model.from_client_params(get_in(params, ["_meta", "model"])) do
      {:ok, model} -> model
      :error -> nil
    end
  end

  defp extract_model_from_params(_), do: nil

  @impl true
  def handle_info(:start_mcp_init, socket) do
    # Deferred from join/3 because Phoenix channels prohibit push() during join.
    # The init state and actions were already created in join — we just need
    # to execute the deferred push actions now that the socket is fully joined.
    actions = socket.assigns.mcp_init_actions
    socket = assign(socket, :mcp_init_actions, nil)
    socket = execute_init_actions(actions, socket)
    {:noreply, socket}
  end

  # --- Execution events (domain events from SwarmDispatcher via PubSub) ---

  def handle_info({:execution_event, %ExecutionEvent{type: :chunk, payload: chunk}}, socket) do
    task_id = socket.assigns.task_id

    socket =
      case chunk do
        %{type: :token, text: text} when is_binary(text) and text != "" ->
          notification =
            ACP.build_agent_message_chunk_notification(task_id, text, DateTime.utc_now())

          push(socket, @acp_message, notification)
          socket

        %{type: :tool_call_start, tool_call_id: id, tool_call_name: name}
        when is_binary(id) and is_binary(name) ->
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

          announced = socket.assigns[:announced_tool_calls] || MapSet.new()
          assign(socket, :announced_tool_calls, MapSet.put(announced, id))

        _ ->
          socket
      end

    {:noreply, socket}
  end

  def handle_info({:execution_event, %ExecutionEvent{} = event}, socket) do
    case ExecutionEvent.classify(event) do
      :agent_completed ->
        finalize_turn(socket, {:completed, ACP.stop_reason_end_turn()}, event.caused_by)

      :agent_cancelled ->
        finalize_turn(socket, {:completed, ACP.stop_reason_cancelled()}, event.caused_by)

      :agent_paused ->
        finalize_turn(socket, {:completed, ACP.stop_reason_end_turn()}, event.caused_by)

      {:agent_error, %{retryable: true} = error_info} ->
        handle_transient_error(socket, error_info, event.caused_by)

      {:agent_error, %{retryable: false} = error_info} ->
        finalize_turn(socket, {:error, error_info.message, error_info.category}, event.caused_by)

      :ok ->
        {:noreply, socket}
    end
  end

  # --- Interaction events (from Tasks persistence layer via PubSub) ---

  def handle_info({:interaction, %Tasks.Interaction.ToolCall{} = tool_call}, socket) do
    task_id = socket.assigns.task_id

    # Only send tool_call_create if we haven't already announced this tool call
    # via the streaming :tool_call_start event (which fires earlier during LLM streaming).
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

    # Always send tool arguments so the UI can display them
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
        # Backend tools are executed by ToolExecutor in the agent loop.
        # The channel just notifies the UI (already done above).
        # When the tool completes, we'll receive a ToolResult notification.
        {:noreply, socket}

      :mcp ->
        # Route to MCP client for execution
        route_to_mcp(tool_call, socket)
    end
  end

  def handle_info({:interaction, %Tasks.Interaction.ToolResult{} = tool_result}, socket) do
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
      # Regular tools: send tool_call_update
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

  def handle_info({:interaction, _interaction}, socket) do
    # Other interactions don't need transport handling
    {:noreply, socket}
  end

  # Agent failed to start (e.g. no API key, usage limit). Broadcast by
  # Tasks.maybe_start_execution when Execution.run returns an error.
  def handle_info({:execution_start_error, msg}, socket) do
    finalize_turn(socket, {:error, msg, "unknown"}, nil)
  end

  def handle_info(:fire_retry, socket) do
    if socket.assigns[:retry_state] do
      scope = socket.assigns.scope
      task_id = socket.assigns.task_id
      opts = socket.assigns[:last_execution_opts] || []
      mcp_tools = socket.assigns[:mcp_tools] || []
      all_tools = mcp_tools |> Tools.prepare_for_task(task_id)
      Tasks.maybe_start_execution(scope, task_id, all_tools, opts)
    end

    {:noreply, socket}
  end

  def handle_info({:title_updated, task_id, title}, socket) do
    push(socket, @acp_title_updated, %{"sessionId" => task_id, "title" => title})
    {:noreply, socket}
  end

  def handle_info(msg, _socket) do
    raise "Unhandled message in TaskChannel: #{inspect(msg)}"
  end

  defp handle_invalid_acp_message(reason, payload, socket) do
    Logger.error(
      "Invalid ACP message in task channel: #{inspect(reason)}, payload: #{inspect(payload)}"
    )

    case payload do
      %{"id" => id} ->
        error_response =
          JsonRpc.error_response(
            id,
            JsonRpc.error_invalid_request(),
            "Invalid JSON-RPC message"
          )

        push(socket, @acp_message, error_response)
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  defp handle_retry_turn(retried_error_id, socket) do
    task_id = socket.assigns.task_id
    scope = socket.assigns.scope

    unless Execution.running?(scope, task_id) do
      Tasks.add_agent_retry(scope, task_id, retried_error_id)
      opts = socket.assigns[:last_execution_opts] || []
      mcp_tools = socket.assigns[:mcp_tools] || []
      all_tools = mcp_tools |> Tools.prepare_for_task(task_id)
      Tasks.maybe_start_execution(scope, task_id, all_tools, opts)
    end

    {:noreply, socket}
  end

  defp handle_transient_error(socket, error_info, caused_by) do
    case RetryCoordinator.handle_error(socket.assigns[:retry_state], error_info) do
      {:exhausted, error_info} ->
        finalize_turn(socket, {:error, error_info.message, error_info.category}, caused_by)

      {:retry_scheduled, state, notification} ->
        task_id = socket.assigns.task_id

        acp_notification =
          ACP.build_error_notification(task_id, notification.message, DateTime.utc_now(),
            category: notification.category,
            retry_at: notification.retry_at,
            attempt: notification.attempt,
            max_attempts: notification.max_attempts
          )

        push(socket, @acp_message, acp_notification)
        {:noreply, assign(socket, :retry_state, state)}
    end
  end

  # Unified turn finalization — every code path that ends a turn goes through here.
  # This guarantees the domain invariant: retry_state is always nil when a turn ends.
  @typep turn_outcome ::
           {:completed, stop_reason :: String.t()}
           | {:error, message :: String.t(), category :: String.t()}

  @spec finalize_turn(Phoenix.Socket.t(), turn_outcome(), String.t() | nil) ::
          {:noreply, Phoenix.Socket.t()}
  defp finalize_turn(socket, outcome, caused_by) do
    task_id = socket.assigns.task_id
    socket = assign(socket, :retry_state, RetryCoordinator.clear(socket.assigns[:retry_state]))

    case outcome do
      {:completed, stop_reason} ->
        notification = ACP.build_agent_turn_complete_notification(task_id, stop_reason)
        push(socket, @acp_message, notification)
        resolve_pending_prompt(socket, {:ok, stop_reason}, caused_by)

      {:error, message, category} ->
        notification =
          ACP.build_error_notification(task_id, message, DateTime.utc_now(), category: category)

        push(socket, @acp_message, notification)
        resolve_pending_prompt(socket, {:error, message}, caused_by)
    end
  end

  defp resolve_pending_prompt(socket, result, caused_by) do
    task_id = socket.assigns.task_id

    socket =
      case socket.assigns[:pending_prompt] do
        nil ->
          Logger.info("Turn finalized with no pending prompt for task #{task_id}")
          socket

        %{interaction_id: interaction_id, jsonrpc_id: prompt_id} ->
          if caused_by && caused_by != interaction_id do
            Logger.warning(
              "Causation mismatch resolving prompt for task #{task_id}: " <>
                "pending interaction #{interaction_id}, event caused by #{caused_by}"
            )
          end

          response =
            case result do
              {:ok, stop_reason} ->
                Logger.info(
                  "Resolving pending prompt #{prompt_id} with stop_reason=#{stop_reason}"
                )

                JsonRpc.success_response(prompt_id, ACP.build_prompt_result(stop_reason))

              {:error, message} ->
                Logger.info("Resolving pending prompt #{prompt_id} with error: #{message}")
                JsonRpc.error_response(prompt_id, -32_000, message)
            end

          push(socket, @acp_message, response)
          assign(socket, :pending_prompt, nil)
      end

    {:noreply, socket}
  end

  # Execute actions returned by the MCPInitializer state machine.
  # Each action is processed synchronously within the current callback,
  # eliminating async process hops that caused race conditions.
  defp execute_init_actions(actions, socket) do
    Enum.reduce(actions, socket, fn action, socket ->
      case action do
        {:push_mcp, msg} ->
          push(socket, "mcp:message", msg)
          socket

        {:push_acp, msg} ->
          push(socket, @acp_message, msg)
          socket

        {:initialization_complete, data} ->
          task_id = socket.assigns.task_id
          Logger.info("MCP initialization complete for task #{task_id}")

          socket
          |> assign(:mcp_status, :ready)
          |> assign(:mcp_capabilities, data.mcp_capabilities)
          |> assign(:mcp_server_info, data.mcp_server_info)
          |> assign(:mcp_tools, data.tools)

        {:initialization_failed, error} ->
          Logger.error("MCP initialization failed: #{inspect(error)}")

          socket
          |> assign(:mcp_status, :failed)
          |> assign(:mcp_error, error)
      end
    end)
  end

  # Process any queued prompt after MCP initialization completes or fails.
  # Called after execute_init_actions when handling MCP responses.
  #
  # Important: This is called from handle_in("mcp:message", ...), so we must
  # NOT return {:reply, ...} — that would send the reply on the wrong channel
  # event. Any replies from process_prompt are converted to push + {:noreply}.
  defp maybe_process_queued_prompt(socket) do
    case {socket.assigns[:mcp_status], socket.assigns[:queued_prompt]} do
      {:ready, {id, params}} ->
        task_id = socket.assigns.task_id
        Logger.info("Processing queued prompt after MCP initialization for task #{task_id}")
        socket = assign(socket, :queued_prompt, nil)
        ensure_noreply(process_prompt(id, params, socket), socket)

      {:failed, {id, params}} ->
        task_id = socket.assigns.task_id

        Logger.warning(
          "Processing queued prompt with failed MCP initialization for task #{task_id}"
        )

        socket = assign(socket, :queued_prompt, nil)
        ensure_noreply(process_prompt(id, params, socket), socket)

      _ ->
        {:noreply, socket}
    end
  end

  # Convert {:reply, ...} tuples to push + {:noreply, ...}.
  # Used when process_prompt is called from a non-ACP context (e.g. after
  # MCP initialization) where {:reply} would send on the wrong channel event.
  defp ensure_noreply({:reply, {:ok, reply_payload}, socket}, _fallback_socket) do
    Enum.each(reply_payload, fn {event, message} ->
      push(socket, event, message)
    end)

    {:noreply, socket}
  end

  defp ensure_noreply({:noreply, socket}, _fallback_socket), do: {:noreply, socket}

  defp route_to_mcp(tool_call, socket) do
    task_id = socket.assigns.task_id

    {request_id, request} =
      MCP.build_tool_execution(%MCP.ToolCallParams{
        tool_name: tool_call.tool_name,
        arguments: tool_call.arguments,
        call_id: tool_call.tool_call_id
      })

    # Send ACP notification: in_progress
    in_progress_notification =
      ACP.tool_call_update(task_id, tool_call.tool_call_id, ACP.tool_call_status_in_progress())

    push(socket, @acp_message, in_progress_notification)

    # Track pending request for response correlation
    pending_requests = socket.assigns[:pending_requests] || %{}

    socket =
      assign(
        socket,
        :pending_requests,
        Map.put(pending_requests, request_id, {:tool_call, tool_call})
      )

    push(socket, "mcp:message", request)
    {:noreply, socket}
  end

  defp to_plan_entry(%Todos.Todo{} = todo) do
    %{
      "content" => todo.content,
      "priority" => Atom.to_string(todo.priority),
      "status" => Atom.to_string(todo.status)
    }
  end

  @impl true
  def terminate(reason, socket) do
    task_id = socket.assigns[:task_id]
    Logger.info("Client disconnected from task #{task_id}: #{inspect(reason)}")

    scope = socket.assigns.scope

    # Notify any interactive tool executors waiting on this task's pending
    # tool calls. Without this, executors block until the 24h safety-net
    # timeout. On reconnect, reexecute_unresolved_tool_calls re-sends
    # tools/call to the new client, which provides a fresh tool result.
    RetryCoordinator.clear(socket.assigns[:retry_state])

    pending_requests = socket.assigns[:pending_requests] || %{}

    for {_request_id, {:tool_call, tc}} <- pending_requests do
      Execution.notify_tool_result(scope, tc.tool_call_id, "Client disconnected", true)
    end

    # Cancel any running execution. Without the channel, MCP tool results
    # can never arrive — the executor processes would hang until their
    # safety-net timeout. Cancellation is persisted by SwarmDispatcher so
    # the user sees the interrupted state on reconnect.
    case Tasks.cancel_execution(scope, task_id) do
      :ok -> Logger.info("Cancelled execution for task #{task_id} on channel termination")
      {:error, :not_running} -> :ok
    end

    :ok
  end
end
