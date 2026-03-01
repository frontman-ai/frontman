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
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.TitleGenerator
  alias FrontmanServer.Tasks.Todos
  alias FrontmanServer.Tools
  alias FrontmanServerWeb.ACPHistory
  alias FrontmanServerWeb.TaskChannel.MCPInitializer
  alias ModelContextProtocol, as: MCP

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
        Logger.warning("Client tried to join non-existent task: #{task_id}")
        {:error, %{reason: "task_not_found"}}
    end
  end

  @impl true
  def handle_in("acp:message", payload, socket) do
    case JsonRpc.parse(payload) do
      {:ok, {:request, id, "session/prompt", params}} ->
        handle_prompt(id, params, socket)

      {:ok, {:notification, "session/cancel", params}} ->
        handle_cancel(params, socket)

      {:ok, {:request, id, "session/load", _params}} ->
        # Load session history - streamed via session/update notifications
        handle_session_load(id, socket)

      {:ok, {:request, id, method, _params}} ->
        Logger.warning("Unknown ACP method in task channel: #{method}")

        response =
          JsonRpc.error_response(
            id,
            JsonRpc.error_method_not_found(),
            "Method not found: #{method}"
          )

        {:reply, {:ok, %{"acp:message" => response}}, socket}

      {:ok, {:notification, _method, _params}} ->
        {:noreply, socket}

      {:error, reason} ->
        Logger.error(
          "Invalid ACP message in task channel: #{inspect(reason)}, payload: #{inspect(payload)}"
        )

        # If payload has an id, send error response
        case payload do
          %{"id" => id} ->
            error_response =
              JsonRpc.error_response(
                id,
                JsonRpc.error_invalid_request(),
                "Invalid JSON-RPC message"
              )

            push(socket, "acp:message", error_response)
            {:noreply, socket}

          _ ->
            {:noreply, socket}
        end
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
    task_id = socket.assigns.task_id
    text_result = MCP.extract_content_text(result)
    parsed_result = MCP.parse_tool_result(text_result)
    is_error = MCP.error?(result)
    status = if is_error, do: "failed", else: "completed"
    Logger.info("MCP tool #{tool_call.tool_name} #{status}: #{text_result}")

    # Send ACP notification with appropriate status
    notification =
      ACP.build_tool_call_update_notification(
        task_id,
        tool_call.tool_call_id,
        status,
        text_result
      )

    push(socket, "acp:message", notification)

    # Store result and notify agent (use parsed result to preserve structured data like screenshots)
    Tasks.add_tool_result(
      socket.assigns.scope,
      task_id,
      %{id: tool_call.tool_call_id, name: tool_call.tool_name},
      parsed_result,
      is_error
    )

    socket = assign(socket, :pending_requests, remaining_requests)
    {:noreply, socket}
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
    error_message = error["message"] || "Unknown MCP error"
    Logger.error("MCP tool #{tool_call.tool_name} failed: #{error_message}")

    # Send ACP notification: failed
    failed_notification =
      ACP.build_tool_call_update_notification(
        task_id,
        tool_call.tool_call_id,
        "failed",
        error_message
      )

    push(socket, "acp:message", failed_notification)

    # Store error result and notify agent
    Tasks.add_tool_result(
      socket.assigns.scope,
      task_id,
      %{id: tool_call.tool_call_id, name: tool_call.tool_name},
      error_message,
      true
    )

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
  # via the :agent_cancelled handler (triggered by ExecutionMonitor).
  defp handle_cancel(_params, socket) do
    task_id = socket.assigns.task_id
    Logger.info("Cancel notification received for task #{task_id}")

    case Tasks.cancel_execution(socket.assigns.scope, task_id) do
      :ok ->
        Logger.info("Agent cancel signal sent for task #{task_id}")

      {:error, :not_running} ->
        Logger.info("Cancel notification for task #{task_id}: no agent running")
    end

    {:noreply, socket}
  end

  # Handle session/load - stream history via session/update notifications
  # This is called after the client has joined the session channel, allowing
  # history notifications to be received through the onUpdate callback.
  defp handle_session_load(id, socket) do
    task_id = socket.assigns.task_id
    scope = socket.assigns.scope
    Logger.info("ACP session/load request received on session channel for: #{task_id}")

    case Tasks.get_task(scope, task_id) do
      {:ok, task} ->
        # Stream history via session/update notifications
        stream_session_history(socket, task)
        # Return ACP-compliant response
        push(socket, "acp:message", JsonRpc.success_response(id, %{}))
        {:noreply, socket}

      {:error, :not_found} ->
        push(
          socket,
          "acp:message",
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
      push(socket, "acp:message", notification)
    end)
  end

  defp process_prompt(id, params, socket) do
    task_id = socket.assigns.task_id
    scope = socket.assigns.scope
    mcp_tools = socket.assigns[:mcp_tools] || []

    # Extract env API key from prompt metadata (sent with each prompt request)
    env_api_key = extract_env_api_key_from_params(params)

    # Extract model selection from prompt metadata
    model = extract_model_from_params(params)

    # Parse ACP prompt (protocol layer)
    prompt = ACP.parse_prompt_params(params)

    # Logging
    Logger.info("Received prompt for task #{task_id}: #{prompt.text_summary}")

    if prompt.has_resources do
      Logger.info("Prompt includes embedded context")
    end

    if model do
      Logger.info("Using model: #{model.provider}:#{model.value}")
    end

    # Prepare tools (domain service)
    all_tools = mcp_tools |> Tools.prepare_for_task(task_id)

    # Track request ID (channel state)
    socket = assign(socket, :pending_prompt_id, id)

    # Pass env_api_key and model to the agent through opts
    opts = [env_api_key: env_api_key, model: model]

    case Tasks.add_user_message(scope, task_id, prompt.content, all_tools, opts) do
      {:ok, _interaction} ->
        Logger.info("User message added, agent spawned for task #{task_id}")

        # Generate title asynchronously on first user message
        socket =
          maybe_generate_title(socket, scope, task_id, prompt.text_summary, model, env_api_key)

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Failed to add user message: #{inspect(reason)}")
        error_response = JsonRpc.error_response(id, -32_000, to_string(reason))
        {:reply, {:ok, %{"acp:message" => error_response}}, socket}
    end
  end

  # Extract env API key from prompt params metadata
  defp extract_env_api_key_from_params(params) when is_map(params) do
    case get_in(params, ["metadata", "openrouterKeyValue"]) do
      key when is_binary(key) and key != "" -> %{"openrouter" => key}
      _ -> %{}
    end
  end

  defp extract_env_api_key_from_params(_), do: %{}

  # Extract model selection from prompt params metadata
  # Expected format: %{"provider" => "openrouter", "value" => "google/gemini-3-flash-preview"}
  defp extract_model_from_params(params) when is_map(params) do
    case get_in(params, ["metadata", "model"]) do
      %{"provider" => provider, "value" => value}
      when is_binary(provider) and is_binary(value) and provider != "" and value != "" ->
        %{provider: provider, value: value}

      _ ->
        nil
    end
  end

  defp extract_model_from_params(_), do: nil

  # Generate a title for a task from the first user message.
  # Only triggers once per channel — tracked via :title_generation_started assign
  # to avoid repeated attempts on every prompt (e.g., when LLM call fails and title stays "New Task").
  # Uses lightweight get_short_desc to avoid loading all interactions.
  defp maybe_generate_title(socket, scope, task_id, text_summary, model, env_api_key) do
    if socket.assigns[:title_generation_started] || text_summary == "" do
      socket
    else
      case Tasks.get_short_desc(scope, task_id) do
        {:ok, "New Task"} ->
          TitleGenerator.generate_async(scope, task_id, text_summary, model, env_api_key)
          assign(socket, :title_generation_started, true)

        _ ->
          assign(socket, :title_generation_started, true)
      end
    end
  end

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

  def handle_info({:stream_token, text}, socket) do
    # Translate domain event to ACP notification
    # ACP compliant: agent_message_chunk implicitly signals message start
    Logger.debug("Channel received stream_token: #{byte_size(text)} bytes, text=#{inspect(text)}")

    task_id = socket.assigns.task_id
    notification = ACP.build_agent_message_chunk_notification(task_id, text)
    Logger.debug("Pushing notification: #{inspect(notification)}")
    push(socket, "acp:message", notification)
    {:noreply, socket}
  end

  def handle_info({:stream_thinking, _text}, socket) do
    # Thinking tokens not forwarded to client yet - client infers thinking state from message status
    # Broadcast kept in agents.ex for future implementation of visible thinking
    {:noreply, socket}
  end

  def handle_info(:agent_completed, socket) do
    Logger.debug(
      "Channel received agent_completed, pending_prompt_id=#{inspect(socket.assigns[:pending_prompt_id])}"
    )

    # Translate domain event to ACP response
    case socket.assigns[:pending_prompt_id] do
      nil ->
        Logger.warning("agent_completed but no pending_prompt_id - response not sent!")
        {:noreply, socket}

      id ->
        response = JsonRpc.success_response(id, ACP.build_prompt_result("end_turn"))
        Logger.info("Pushing prompt response with id=#{id}")
        push(socket, "acp:message", response)

        socket = assign(socket, :pending_prompt_id, nil)

        {:noreply, socket}
    end
  end

  def handle_info(:agent_cancelled, socket) do
    Logger.info("Channel received agent_cancelled for task #{socket.assigns.task_id}")

    # Resolve the pending prompt with stopReason: "cancelled"
    case socket.assigns[:pending_prompt_id] do
      nil ->
        {:noreply, socket}

      id ->
        response = JsonRpc.success_response(id, ACP.build_prompt_result("cancelled"))
        push(socket, "acp:message", response)
        socket = assign(socket, :pending_prompt_id, nil)
        {:noreply, socket}
    end
  end

  def handle_info({:tool_call_start, tool_call_id, tool_name}, socket) do
    # Early notification: the LLM has started generating a tool call.
    # This fires as soon as the tool_call_start chunk arrives from the LLM stream,
    # BEFORE the full arguments are generated. For tools with large arguments
    # (e.g., write_file with full file content), this provides immediate UI feedback
    # instead of waiting for the entire response to be accumulated.
    task_id = socket.assigns.task_id
    notification = ACP.tool_call_create(task_id, tool_call_id, tool_name, "other", "pending")
    push(socket, "acp:message", notification)

    # Track that we already announced this tool call to avoid duplicate notifications
    announced = socket.assigns[:announced_tool_calls] || MapSet.new()
    socket = assign(socket, :announced_tool_calls, MapSet.put(announced, tool_call_id))

    {:noreply, socket}
  end

  def handle_info({:interaction, %Tasks.Interaction.ToolCall{} = tool_call}, socket) do
    task_id = socket.assigns.task_id

    # Only send tool_call_create if we haven't already announced this tool call
    # via the streaming :tool_call_start event (which fires earlier during LLM streaming).
    announced = socket.assigns[:announced_tool_calls] || MapSet.new()

    unless MapSet.member?(announced, tool_call.tool_call_id) do
      pending_notification =
        ACP.build_tool_call_notification(task_id, tool_call, "pending", [])

      push(socket, "acp:message", pending_notification)
    end

    # Always send tool arguments so the UI can display them
    args_content = ACP.Content.from_tool_result(tool_call.arguments)

    args_notification =
      ACP.tool_call_update(task_id, tool_call.tool_call_id, "pending", args_content)

    push(socket, "acp:message", args_notification)

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
          push(socket, "acp:message", plan_notification)

        {:error, _reason} ->
          :ok
      end
    else
      # Regular tools: send tool_call_update
      status = if tool_result.is_error, do: "error", else: "completed"
      content = ACP.Content.from_tool_result(tool_result.result)
      notification = ACP.tool_call_update(task_id, tool_result.tool_call_id, status, content)
      push(socket, "acp:message", notification)
    end

    {:noreply, socket}
  end

  def handle_info({:interaction, _interaction}, socket) do
    # Other interactions don't need transport handling
    {:noreply, socket}
  end

  def handle_info({:agent_error, message}, socket) do
    Logger.error("Agent error: #{message}")
    task_id = socket.assigns.task_id

    # Always send error as session/update notification so client can display it
    error_notification =
      JsonRpc.notification("session/update", %{
        "sessionId" => task_id,
        "update" => %{
          "sessionUpdate" => "error",
          "message" => message
        }
      })

    push(socket, "acp:message", error_notification)

    # Also send JSON-RPC error response if there's a pending prompt
    case socket.assigns[:pending_prompt_id] do
      nil ->
        {:noreply, socket}

      id ->
        response = JsonRpc.error_response(id, -32_000, message)
        push(socket, "acp:message", response)
        socket = assign(socket, :pending_prompt_id, nil)
        {:noreply, socket}
    end
  end

  def handle_info(msg, _socket) do
    raise "Unhandled message in TaskChannel: #{inspect(msg)}"
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
          push(socket, "acp:message", msg)
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

    # Log file operations for debugging path consistency issues
    if tool_call.tool_name in ["read_file", "write_file"] do
      Logger.info(
        "MCP file op: #{tool_call.tool_name} path=#{inspect(tool_call.arguments["path"])}"
      )
    end

    request_id = System.unique_integer([:positive])

    request =
      MCP.tools_call_request(%MCP.ToolCallParams{
        request_id: request_id,
        tool_name: tool_call.tool_name,
        arguments: tool_call.arguments,
        call_id: tool_call.tool_call_id
      })

    # Send ACP notification: in_progress
    in_progress_notification =
      ACP.build_tool_call_update_notification(task_id, tool_call.tool_call_id, "in_progress")

    push(socket, "acp:message", in_progress_notification)

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
      "priority" => "medium",
      "status" => Atom.to_string(todo.status)
    }
  end

  @impl true
  def terminate(reason, socket) do
    task_id = socket.assigns[:task_id]
    Logger.info("Client disconnected from task #{task_id}: #{inspect(reason)}")
    :ok
  end
end
