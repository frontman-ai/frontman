defmodule FrontmanServerWeb.TaskChannel do
  @moduledoc """
  Channel for task-specific ACP events.

  Clients join this channel after creating a task via the
  tasks channel. Handles prompt messages and streams
  agent responses back to the client.
  """
  use FrontmanServerWeb, :channel
  require Logger

  alias FrontmanServer.Agents
  alias FrontmanServer.Observability.TelemetryEvents
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tools
  alias FrontmanServerWeb.{ACP, JsonRpc}
  alias FrontmanServerWeb.MCPProtocol
  alias FrontmanServerWeb.TaskChannel.MCPInitializer

  @impl true
  def join("task:" <> task_id, _params, socket) do
    case Tasks.get_task(task_id) do
      {:ok, _task} ->
        Logger.info("Client joining: #{task_id}, socket_id: #{inspect(self())}")

        # Start MCP initialization process
        {:ok, initializer_pid} = MCPInitializer.start_link(self(), task_id)

        socket =
          socket
          |> assign(:task_id, task_id)
          |> assign(:mcp_initializer_pid, initializer_pid)
          |> assign(:mcp_status, :pending)

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

    cond do
      # During initialization, forward all responses to MCPInitializer
      socket.assigns[:mcp_status] != :ready and socket.assigns[:mcp_initializer_pid] ->
        MCPInitializer.handle_mcp_response(socket.assigns.mcp_initializer_pid, id, result)
        {:noreply, socket}

      # After initialization, handle tool call responses
      Map.has_key?(pending_requests, id) ->
        case Map.pop(pending_requests, id) do
          {{:tool_call, tool_call}, remaining_requests} ->
            handle_tool_call_response(id, tool_call, result, socket, remaining_requests)

          {nil, _} ->
            Logger.warning("Received MCP response for unknown request_id: #{id}")
            {:noreply, socket}
        end

      true ->
        Logger.warning("Received MCP response for unknown request_id: #{id}")
        {:noreply, socket}
    end
  end

  defp handle_tool_call_response(id, tool_call, result, socket, remaining_requests) do
    task_id = socket.assigns.task_id

    # Extract text from MCP content array
    text_result = MCPProtocol.extract_content_text(result)

    # Try to parse the result as JSON to preserve structured data (e.g., screenshots)
    parsed_result = MCPProtocol.parse_tool_result(text_result)

    # Check if the tool call resulted in an error
    is_error = MCPProtocol.is_error?(result)

    # Emit MCP tool stop telemetry event
    if is_error do
      TelemetryEvents.mcp_tool_stop(id, status: "error", error: text_result)
    else
      TelemetryEvents.mcp_tool_stop(id, status: "success")
    end

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
      task_id,
      tool_call.agent_id,
      %{id: tool_call.tool_call_id, name: tool_call.tool_name},
      parsed_result,
      is_error
    )

    socket = assign(socket, :pending_requests, remaining_requests)
    {:noreply, socket}
  end

  defp handle_mcp_error(id, error, socket) do
    pending_requests = socket.assigns[:pending_requests] || %{}

    cond do
      # During initialization, forward all errors to MCPInitializer
      socket.assigns[:mcp_status] != :ready and socket.assigns[:mcp_initializer_pid] ->
        MCPInitializer.handle_mcp_error(socket.assigns.mcp_initializer_pid, id, error)
        {:noreply, socket}

      # After initialization, handle tool call errors
      Map.has_key?(pending_requests, id) ->
        case Map.pop(pending_requests, id) do
          {{:tool_call, tool_call}, remaining_requests} ->
            handle_tool_call_error(id, tool_call, error, socket, remaining_requests)

          {nil, _} ->
            Logger.warning("Received MCP error for unknown request_id: #{id}")
            {:noreply, socket}
        end

      true ->
        Logger.warning("Received MCP error for unknown request_id: #{id}")
        {:noreply, socket}
    end
  end

  defp handle_tool_call_error(id, tool_call, error, socket, remaining_requests) do
    task_id = socket.assigns.task_id
    error_message = error["message"] || "Unknown MCP error"

    # Emit MCP tool stop telemetry event with error
    TelemetryEvents.mcp_tool_stop(id, status: "error", error: error_message)

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
      task_id,
      tool_call.agent_id,
      %{id: tool_call.tool_call_id, name: tool_call.tool_name},
      error_message,
      true
    )

    socket = assign(socket, :pending_requests, remaining_requests)
    {:noreply, socket}
  end

  defp handle_prompt(id, params, socket) do
    task_id = socket.assigns.task_id
    mcp_tools = socket.assigns[:mcp_tools] || []

    # Parse ACP prompt (protocol layer)
    prompt = ACP.parse_prompt_params(params)

    # Logging
    Logger.info("Received prompt for task #{task_id}: #{prompt.text_summary}")

    if prompt.has_resources do
      Logger.info("Prompt includes embedded context")
    end

    # Prepare tools (domain service)
    all_tools = mcp_tools |> Tools.prepare_for_task(task_id)

    # Track request ID (channel state)
    socket = assign(socket, :pending_prompt_id, id)

    # Execute domain command with telemetry
    TelemetryEvents.task_start(task_id)

    case Tasks.add_user_message(task_id, prompt.content, all_tools) do
      {:ok, _interaction} ->
        Logger.info("User message added, agent spawned for task #{task_id}")
        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Failed to add user message: #{inspect(reason)}")
        error_response = JsonRpc.error_response(id, -32000, to_string(reason))
        {:reply, {:ok, %{"acp:message" => error_response}}, socket}
    end
  end

  @impl true
  def handle_info({:agent_stream_token, _agent_id, text}, socket) do
    # Translate domain event to ACP notification
    # ACP compliant: agent_message_chunk implicitly signals message start
    Logger.debug(
      "Channel received agent_stream_token: #{byte_size(text)} bytes, text=#{inspect(text)}"
    )

    task_id = socket.assigns.task_id
    notification = ACP.build_agent_message_chunk_notification(task_id, text)
    Logger.debug("Pushing notification: #{inspect(notification)}")
    push(socket, "acp:message", notification)
    {:noreply, socket}
  end

  def handle_info({:agent_completed, _agent_id}, socket) do
    Logger.debug(
      "Channel received agent_completed, pending_prompt_id=#{inspect(socket.assigns[:pending_prompt_id])}"
    )

    task_id = socket.assigns.task_id

    # Emit task stop telemetry event
    TelemetryEvents.task_stop(task_id)

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

  def handle_info({:interaction, %Interaction.ToolCall{} = tool_call}, socket) do
    task_id = socket.assigns.task_id

    # Check if this tool call is from a sub-agent and get spawning tool name
    parent_agent_id = Agents.get_parent_agent_id(tool_call.agent_id)
    spawning_tool_name = Agents.get_spawning_tool_name(tool_call.agent_id)

    acp_opts =
      []
      |> then(fn opts ->
        if parent_agent_id, do: [{:parent_agent_id, parent_agent_id} | opts], else: opts
      end)
      |> then(fn opts ->
        if spawning_tool_name, do: [{:spawning_tool_name, spawning_tool_name} | opts], else: opts
      end)

    # Send ACP notification: pending with tool arguments in content
    pending_notification =
      ACP.build_tool_call_notification(task_id, tool_call, "pending", acp_opts)

    push(socket, "acp:message", pending_notification)

    # Send tool arguments immediately so the UI can display them
    args_content = [
      %{
        "type" => "content",
        "content" => %{"type" => "text", "text" => Jason.encode!(tool_call.arguments)}
      }
    ]

    args_notification =
      ACP.tool_call_update(task_id, tool_call.tool_call_id, "pending", args_content)

    push(socket, "acp:message", args_notification)

    # Check if it's a backend tool
    case Tools.find_tool(tool_call.tool_name) do
      {:ok, _tool_module} ->
        # Execute backend tool ASYNC to avoid blocking the channel
        channel_pid = self()

        Task.start(fn ->
          result = Tools.execute_backend_tool(tool_call, task_id)
          send(channel_pid, {:backend_tool_completed, tool_call, result})
        end)

        {:noreply, socket}

      :not_found ->
        # Not a backend tool, route to MCP
        route_to_mcp(tool_call, socket)
    end
  end

  def handle_info({:backend_tool_completed, tool_call, {:executed, result}}, socket) do
    handle_backend_tool_result(tool_call, result, socket)
  end

  def handle_info({:backend_tool_completed, tool_call, :not_found}, socket) do
    # This shouldn't happen since we checked find_backend_tool first,
    # but handle it gracefully by routing to MCP
    Logger.warning("Backend tool #{tool_call.tool_name} not found after async execution")
    route_to_mcp(tool_call, socket)
  end

  def handle_info({:interaction, %Interaction.ToolResult{} = tool_result}, socket) do
    task_id = socket.assigns.task_id

    if Tools.todo_mutation?(tool_result.tool_name) do
      # Send plan_update as before
      case Tasks.list_todos(task_id) do
        {:ok, todos} ->
          entries = todos_to_plan_entries(todos)
          notification = ACP.plan_update(task_id, entries)
          push(socket, "acp:message", notification)

        {:error, _reason} ->
          :ok
      end

      # Send additional todo-specific notifications for UX
      emit_todo_event_notification(socket, tool_result)
    end

    {:noreply, socket}
  end

  def handle_info({:interaction, _interaction}, socket) do
    # Other interactions don't need transport handling
    {:noreply, socket}
  end

  def handle_info({:agent_error, _agent_id, message}, socket) do
    Logger.error("Agent error: #{message}")

    case socket.assigns[:pending_prompt_id] do
      nil ->
        {:noreply, socket}

      id ->
        response = JsonRpc.error_response(id, -32000, message)
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
    Logger.info("MCP initialization complete for task #{socket.assigns.task_id}")

    # Notify client that project rules are initialized
    task_id = socket.assigns.task_id

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

    {:noreply, socket}
  end

  def handle_info({:mcp_initializer, {:initialization_failed, error}}, socket) do
    Logger.error("MCP initialization failed: #{inspect(error)}")

    socket =
      socket
      |> assign(:mcp_status, :failed)
      |> assign(:mcp_error, error)

    {:noreply, socket}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp handle_backend_tool_result(tool_call, result, socket) do
    task_id = socket.assigns.task_id

    # Send in_progress update
    notification = ACP.tool_call_update(task_id, tool_call.tool_call_id, "in_progress")
    push(socket, "acp:message", notification)

    # Handle result
    case result do
      {:ok, content} ->
        handle_tool_success(tool_call, content, socket)

      {:error, reason} ->
        handle_tool_error(tool_call, reason, socket)
    end

    {:noreply, socket}
  end

  defp handle_tool_success(tool_call, result, socket) do
    task_id = socket.assigns.task_id

    # Convert result to ACP content format
    content = format_tool_content(result)

    # Send completed update
    notification = ACP.tool_call_update(task_id, tool_call.tool_call_id, "completed", content)
    push(socket, "acp:message", notification)

    # Store structured data (not JSON)
    Tasks.add_tool_result(
      task_id,
      tool_call.agent_id,
      %{id: tool_call.tool_call_id, name: tool_call.tool_name},
      result,
      false
    )
  end

  defp handle_tool_error(tool_call, error, socket) do
    task_id = socket.assigns.task_id
    error_message = to_string(error)

    # Convert error to ACP content format
    content = [%{type: "content", content: %{type: "text", text: error_message}}]

    # Send failed update
    notification = ACP.tool_call_update(task_id, tool_call.tool_call_id, "failed", content)
    push(socket, "acp:message", notification)

    # Store error
    Tasks.add_tool_result(
      task_id,
      tool_call.agent_id,
      %{id: tool_call.tool_call_id, name: tool_call.tool_name},
      error_message,
      true
    )
  end

  defp format_tool_content(result) when is_map(result) do
    [%{type: "content", content: %{type: "text", text: Jason.encode!(result)}}]
  end

  defp route_to_mcp(tool_call, socket) do
    task_id = socket.assigns.task_id
    request_id = System.unique_integer([:positive])

    TelemetryEvents.mcp_tool_start(
      request_id,
      tool_call.tool_call_id,
      tool_call.tool_name,
      tool_call.agent_id,
      task_id,
      tool_call.arguments
    )

    request =
      MCPProtocol.tools_call_request(%MCPProtocol.ToolCallParams{
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

  # ===========================================================================
  # Todo Event Notification Helpers
  # ===========================================================================

  # Emit todo-specific UX notifications based on tool result
  defp emit_todo_event_notification(socket, %Interaction.ToolResult{} = tool_result) do
    task_id = socket.assigns.task_id

    case tool_result.tool_name do
      "todo_add" ->
        # For todo_add, emit todo_batch_created with the single entry
        # The UI will aggregate consecutive todo_add calls
        emit_todo_batch_created(socket, task_id, tool_result)

      "todo_update" ->
        # For todo_update, emit started/completed based on new status
        emit_todo_status_change(socket, task_id, tool_result)

      _ ->
        # todo_list, todo_remove, etc. - no special notification needed
        :ok
    end
  end

  # Emit todo_batch_created for a single todo_add result
  # Note: The UI will handle batching consecutive adds visually
  # The result is the raw todo struct (not wrapped in {:ok, ...})
  defp emit_todo_batch_created(socket, task_id, tool_result) do
    todo = tool_result.result

    if is_map(todo) and Map.has_key?(todo, :id) and Map.has_key?(todo, :content) do
      entry = %{
        "id" => todo.id,
        "content" => todo.content,
        "active_form" => Map.get(todo, :active_form, todo.content),
        "status" => Atom.to_string(todo.status)
      }

      notification = ACP.todo_batch_created(task_id, [entry])
      push(socket, "acp:message", notification)
    else
      :ok
    end
  end

  # Emit todo_started or todo_completed based on the update result
  # The result is the raw todo struct (not wrapped in {:ok, ...})
  defp emit_todo_status_change(socket, task_id, tool_result) do
    todo = tool_result.result

    if is_map(todo) and Map.has_key?(todo, :status) do
      # Get the content for display (prefer active_form, fallback to content)
      content = Map.get(todo, :active_form) || todo.content

      case todo.status do
        :in_progress ->
          notification = ACP.todo_started(task_id, todo.id, content)
          push(socket, "acp:message", notification)

        :completed ->
          notification = ACP.todo_completed(task_id, todo.id, content)
          push(socket, "acp:message", notification)

        _ ->
          # pending or other status - no notification
          :ok
      end
    else
      :ok
    end
  end

  @impl true
  def terminate(reason, socket) do
    task_id = socket.assigns[:task_id]
    Logger.info("Client disconnected from task #{task_id}: #{inspect(reason)}")

    # Emit task stop if still processing (client disconnected mid-prompt)
    if socket.assigns[:pending_prompt_id] do
      TelemetryEvents.task_stop(task_id)
    end

    :ok
  end
end
