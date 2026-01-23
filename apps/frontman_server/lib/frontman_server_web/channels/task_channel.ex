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
  alias FrontmanServer.Tools
  alias FrontmanServerWeb.TaskChannel.MCPInitializer
  alias ModelContextProtocol, as: MCP

  @impl true
  def join("task:" <> task_id, _params, socket) do
    scope = socket.assigns.scope

    case Tasks.get_task(scope, task_id) do
      {:ok, _task} ->
        Logger.info("Client joining: #{task_id}, socket_id: #{inspect(self())}")

        # Start MCP initialization process.
        # Note: We always reinitialize on join because:
        # 1. MCPInitializer performs a stateful handshake with the browser-side MCP client
        # 2. Each websocket connection needs its own MCP session
        # 3. Project rules loading depends on client-specific context
        # Tools are stored in socket assigns and passed through Backend.Context for agent access.
        {:ok, initializer_pid} = MCPInitializer.start_link(self(), task_id, scope)

        socket =
          socket
          |> assign(:task_id, task_id)
          |> assign(:mcp_initializer_pid, initializer_pid)
          |> assign(:mcp_status, :pending)

        {:ok, %{task_id: task_id}, socket}

      {:error, :not_found} ->
        Logger.warning("Client tried to join non-existent task: #{task_id}")
        {:error, %{reason: "task_not_found"}}

      {:error, :unauthorized} ->
        Logger.warning("Client unauthorized to join task: #{task_id}")
        {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("acp:message", payload, socket) do
    case JsonRpc.parse(payload) do
      {:ok, {:request, id, "session/prompt", params}} ->
        handle_prompt(id, params, socket)

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
    initializer_pid = socket.assigns[:mcp_initializer_pid]

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

      # Initialization response - MCPInitializer owns these IDs
      initializer_pid && initializer_expects_response?(initializer_pid, id) ->
        Logger.debug("MCP response #{id} matched MCPInitializer")
        MCPInitializer.handle_mcp_response(initializer_pid, id, result)
        {:noreply, socket}

      true ->
        Logger.warning("Received MCP response for unknown request_id: #{id}")
        {:noreply, socket}
    end
  end

  # Safely check if MCPInitializer expects this response, with timeout protection
  defp initializer_expects_response?(pid, id) do
    MCPInitializer.expects_response?(pid, id)
  catch
    :exit, {:timeout, _} ->
      Logger.warning("MCPInitializer.expects_response? timed out for id=#{id}")
      false

    :exit, reason ->
      Logger.warning("MCPInitializer.expects_response? failed: #{inspect(reason)}")
      false
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
    initializer_pid = socket.assigns[:mcp_initializer_pid]

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

      # Initialization error - MCPInitializer owns these IDs
      initializer_pid && initializer_expects_response?(initializer_pid, id) ->
        MCPInitializer.handle_mcp_error(initializer_pid, id, error)
        {:noreply, socket}

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

  @impl true
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

  def handle_info({:interaction, %Tasks.Interaction.ToolCall{} = tool_call}, socket) do
    task_id = socket.assigns.task_id

    # Send ACP notification: pending with tool arguments in content
    pending_notification =
      ACP.build_tool_call_notification(task_id, tool_call, "pending", [])

    push(socket, "acp:message", pending_notification)

    # Send tool arguments immediately so the UI can display them
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
          entries = todos_to_plan_entries(todos)
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

  def handle_info({:mcp_initializer_request, request}, socket) do
    # Forward MCP requests from initializer to client
    push(socket, "mcp:message", request)
    {:noreply, socket}
  end

  def handle_info({:mcp_initializer_notification, notification}, socket) do
    # Forward MCP notifications from initializer to client
    push(socket, "mcp:message", notification)
    {:noreply, socket}
  end

  def handle_info({:mcp_initializer, {:initialization_complete, data}}, socket) do
    task_id = socket.assigns.task_id
    Logger.info("MCP initialization complete for task #{task_id}")

    # Notify client that project rules are initialized
    notification =
      JsonRpc.notification("project_rules_initialized", %{
        "count" => length(data.tools),
        "taskId" => task_id
      })

    push(socket, "acp:message", notification)

    socket =
      socket
      |> assign(:mcp_status, :ready)
      |> assign(:mcp_capabilities, data.mcp_capabilities)
      |> assign(:mcp_server_info, data.mcp_server_info)
      |> assign(:mcp_tools, data.tools)

    # Process any queued prompt that was waiting for MCP initialization
    case socket.assigns[:queued_prompt] do
      {id, params} ->
        Logger.info("Processing queued prompt after MCP initialization for task #{task_id}")
        socket = assign(socket, :queued_prompt, nil)
        process_prompt(id, params, socket)

      nil ->
        {:noreply, socket}
    end
  end

  def handle_info({:mcp_initializer, {:initialization_failed, error}}, socket) do
    Logger.error("MCP initialization failed: #{inspect(error)}")
    task_id = socket.assigns.task_id

    socket =
      socket
      |> assign(:mcp_status, :failed)
      |> assign(:mcp_error, error)

    # Process any queued prompt with empty tools (best effort)
    case socket.assigns[:queued_prompt] do
      {id, params} ->
        Logger.warning(
          "Processing queued prompt with failed MCP initialization for task #{task_id}"
        )

        socket = assign(socket, :queued_prompt, nil)
        process_prompt(id, params, socket)

      nil ->
        {:noreply, socket}
    end
  end

  def handle_info(msg, _socket) do
    raise "Unhandled message in TaskChannel: #{inspect(msg)}"
  end

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

  # Convert todos to ACP plan entries
  defp todos_to_plan_entries(todos) when is_list(todos) do
    todos
    |> Enum.sort_by(& &1.created_at, DateTime)
    |> Enum.map(&todo_to_plan_entry/1)
  end

  defp todo_to_plan_entry(todo) do
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
