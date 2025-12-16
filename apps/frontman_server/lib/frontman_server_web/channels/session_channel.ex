defmodule FrontmanServerWeb.SessionChannel do
  @moduledoc """
  Channel for session-specific ACP events.

  Clients join this channel after creating a session via the
  sessions channel. Handles prompt messages and streams
  agent responses back to the client.
  """
  use FrontmanServerWeb, :channel
  require Logger

  alias FrontmanServer.Observability.TelemetryEvents
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.ToolRegistry
  alias FrontmanServerWeb.{ACP, JsonRpc, MCPProtocol}

  @impl true
  def join("session:" <> session_id, _params, socket) do
    case Tasks.get_task(session_id) do
      {:ok, _task} ->
        Logger.info("Client joining session: #{session_id}")
        Phoenix.PubSub.subscribe(FrontmanServer.PubSub, "task:#{session_id}")

        socket =
          socket
          |> assign(:session_id, session_id)
          |> assign(:mcp_status, :pending)

        send(self(), :init_mcp)
        {:ok, %{session_id: session_id}, socket}

      {:error, :not_found} ->
        Logger.warning("Client tried to join non-existent session: #{session_id}")
        {:error, %{reason: "session_not_found"}}
    end
  end

  @impl true
  def handle_in("acp:message", payload, socket) do
    case JsonRpc.parse(payload) do
      {:ok, {:request, id, "session/prompt", params}} ->
        handle_prompt(id, params, socket)

      {:ok, {:request, id, method, _params}} ->
        Logger.warning("Unknown ACP method in session channel: #{method}")

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
          "Invalid ACP message in session channel: #{inspect(reason)}, payload: #{inspect(payload)}"
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
    pending_calls = socket.assigns[:pending_mcp_calls] || %{}

    cond do
      socket.assigns[:mcp_init_request_id] == id ->
        Logger.info("MCP initialized for session #{socket.assigns.session_id}")

        socket =
          socket
          |> assign(:mcp_status, :ready)
          |> assign(:mcp_capabilities, result["capabilities"])
          |> assign(:mcp_server_info, result["serverInfo"])
          |> assign(:mcp_init_request_id, nil)

        notification = JsonRpc.notification("notifications/initialized", %{})
        push(socket, "mcp:message", notification)

        # Request tools list after initialization
        send(self(), :request_tools_list)
        {:noreply, socket}

      socket.assigns[:mcp_tools_request_id] == id ->
        tools = Map.get(result, "tools", [])
        Logger.info("Received #{length(tools)} tools from MCP server")

        socket =
          socket
          |> assign(:mcp_tools, tools)
          |> assign(:mcp_tools_request_id, nil)

        {:noreply, socket}

      Map.has_key?(pending_calls, id) ->
        tool_call = pending_calls[id]
        session_id = socket.assigns.session_id

        # Extract text from MCP content array
        text_result =
          result
          |> Map.get("content", [])
          |> Enum.map(fn block -> Map.get(block, "text", "") end)
          |> Enum.join("\n")

        # Try to parse the result as JSON to preserve structured data (e.g., screenshots)
        parsed_result = parse_tool_result(text_result)

        # Check if the tool call resulted in an error
        is_error = Map.get(result, "isError", false)

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
            session_id,
            tool_call.tool_call_id,
            status,
            text_result
          )

        push(socket, "acp:message", notification)

        # Store result and notify agent (use parsed result to preserve structured data like screenshots)
        Tasks.add_tool_result(
          session_id,
          tool_call.agent_id,
          %{id: tool_call.tool_call_id, name: tool_call.tool_name},
          parsed_result,
          is_error
        )

        socket = assign(socket, :pending_mcp_calls, Map.delete(pending_calls, id))
        {:noreply, socket}

      true ->
        {:noreply, socket}
    end
  end

  # Try to parse tool result as JSON to preserve structured data (e.g., screenshots, figma nodes)
  # Falls back to original string if parsing fails
  defp parse_tool_result(text_result) when is_binary(text_result) do
    case Jason.decode(text_result) do
      {:ok, parsed} when is_map(parsed) -> parsed
      _ -> text_result
    end
  end

  defp handle_mcp_error(id, error, socket) do
    pending_calls = socket.assigns[:pending_mcp_calls] || %{}

    cond do
      socket.assigns[:mcp_init_request_id] == id ->
        Logger.error("MCP initialization failed: #{inspect(error)}")

        socket =
          socket
          |> assign(:mcp_status, :failed)
          |> assign(:mcp_error, error["message"])
          |> assign(:mcp_init_request_id, nil)

        {:noreply, socket}

      Map.has_key?(pending_calls, id) ->
        tool_call = pending_calls[id]
        session_id = socket.assigns.session_id
        error_message = error["message"] || "Unknown MCP error"

        # Emit MCP tool stop telemetry event with error
        TelemetryEvents.mcp_tool_stop(id, status: "error", error: error_message)

        Logger.error("MCP tool #{tool_call.tool_name} failed: #{error_message}")

        # Send ACP notification: failed
        failed_notification =
          ACP.build_tool_call_update_notification(
            session_id,
            tool_call.tool_call_id,
            "failed",
            error_message
          )

        push(socket, "acp:message", failed_notification)

        # Store error result and notify agent
        Tasks.add_tool_result(
          session_id,
          tool_call.agent_id,
          %{id: tool_call.tool_call_id, name: tool_call.tool_name},
          error_message,
          true
        )

        socket = assign(socket, :pending_mcp_calls, Map.delete(pending_calls, id))
        {:noreply, socket}

      true ->
        {:noreply, socket}
    end
  end

  defp handle_prompt(id, params, socket) do
    session_id = socket.assigns.session_id
    prompt_content = Map.get(params, "prompt", [])
    mcp_tools = socket.assigns[:mcp_tools] || []

    # Extract text content from text blocks
    text_content =
      prompt_content
      |> Enum.filter(fn block -> Map.get(block, "type") == "text" end)
      |> Enum.map(fn block -> Map.get(block, "text", "") end)
      |> Enum.join("\n")

    Logger.info("Received prompt for session #{session_id}: #{text_content}")

    # Pass the full prompt_content (ContentBlocks) to the agent
    # The agent will convert these to the appropriate LLM format
    has_embedded_context =
      Enum.any?(prompt_content, fn block ->
        type = Map.get(block, "type")
        type == "resource_link" or type == "resource"
      end)

    if has_embedded_context do
      Logger.info("Prompt includes embedded context (resource_link or resource)")
    end

    # Emit task start telemetry event
    TelemetryEvents.task_start(session_id)

    socket = assign(socket, :pending_prompt_id, id)

    # Merge backend tools with client tools
    backend_tools = FrontmanServer.Tools.backend_tools(session_id)
    all_tools = backend_tools ++ mcp_tools_to_llm_format(mcp_tools)

    opts = [tools: all_tools]

    # Add user message to task - this triggers the agent with ALL tools and content blocks
    case Tasks.add_user_message(session_id, prompt_content, opts) do
      {:ok, _interaction} ->
        Logger.info("User message added, agent spawned for session #{session_id}")

      {:error, reason} ->
        Logger.error("Failed to add user message: #{inspect(reason)}")
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info(:init_mcp, socket) do
    request_id = System.unique_integer([:positive])

    request = JsonRpc.request(request_id, "initialize", MCPProtocol.initialize_params())

    socket =
      socket
      |> assign(:mcp_status, :initializing)
      |> assign(:mcp_init_request_id, request_id)

    push(socket, "mcp:message", request)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:request_tools_list, socket) do
    request_id = System.unique_integer([:positive])

    request = JsonRpc.request(request_id, "tools/list", %{})

    socket = assign(socket, :mcp_tools_request_id, request_id)

    push(socket, "mcp:message", request)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:agent_stream_token, _agent_id, text}, socket) do
    # Translate domain event to ACP notification
    # ACP compliant: agent_message_chunk implicitly signals message start
    Logger.debug("Channel received agent_stream_token: #{byte_size(text)} bytes, text=#{inspect(text)}")
    session_id = socket.assigns.session_id
    notification = ACP.build_agent_message_chunk_notification(session_id, text)
    Logger.debug("Pushing notification: #{inspect(notification)}")
    push(socket, "acp:message", notification)
    {:noreply, socket}
  end

  def handle_info({:agent_completed, _agent_id}, socket) do
    Logger.debug("Channel received agent_completed, pending_prompt_id=#{inspect(socket.assigns[:pending_prompt_id])}")

    session_id = socket.assigns.session_id

    # Emit task stop telemetry event
    TelemetryEvents.task_stop(session_id)

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
    session_id = socket.assigns.session_id

    # Send ACP notification: pending
    pending_notification = ACP.build_tool_call_notification(session_id, tool_call, "pending")
    push(socket, "acp:message", pending_notification)

    # Try backend execution first
    case FrontmanServer.Tools.execute_backend_tool(tool_call, session_id) do
      {:executed, result} ->
        handle_backend_tool_result(tool_call, result, socket)

      :not_found ->
        # Not a backend tool, route to MCP
        route_to_mcp(tool_call, socket)
    end
  end

  def handle_info({:interaction, %Interaction.ToolResult{} = tool_result}, socket) do
    # Check if this was a todo tool that produces events
    if ToolRegistry.produces_events?(tool_result.tool_name) do
      session_id = socket.assigns.session_id

      case Tasks.list_todos(session_id) do
        {:ok, todos} ->
          entries = ACP.todos_to_plan_entries(todos)
          notification = ACP.plan_update(session_id, entries)
          push(socket, "acp:message", notification)

        {:error, _reason} ->
          :ok
      end
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

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp handle_backend_tool_result(tool_call, result, socket) do
    session_id = socket.assigns.session_id

    # Send in_progress update
    notification = ACP.tool_call_update(session_id, tool_call.tool_call_id, "in_progress")
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
    session_id = socket.assigns.session_id

    # Convert result to ACP content format
    content = format_tool_content(result)

    # Send completed update
    notification = ACP.tool_call_update(session_id, tool_call.tool_call_id, "completed", content)
    push(socket, "acp:message", notification)

    # Store structured data (not JSON)
    Tasks.add_tool_result(
      session_id,
      tool_call.agent_id,
      %{id: tool_call.tool_call_id, name: tool_call.tool_name},
      result,
      false
    )
  end

  defp handle_tool_error(tool_call, error, socket) do
    session_id = socket.assigns.session_id
    error_message = to_string(error)

    # Convert error to ACP content format
    content = [%{type: "content", content: %{type: "text", text: error_message}}]

    # Send failed update
    notification = ACP.tool_call_update(session_id, tool_call.tool_call_id, "failed", content)
    push(socket, "acp:message", notification)

    # Store error
    Tasks.add_tool_result(
      session_id,
      tool_call.agent_id,
      %{id: tool_call.tool_call_id, name: tool_call.tool_name},
      error_message,
      true
    )
  end

  defp format_tool_content(result) when is_map(result) do
    # Wrap structured result in ACP content block
    [%{type: "content", content: %{type: "text", text: Jason.encode!(result)}}]
  end

  defp route_to_mcp(tool_call, socket) do
    session_id = socket.assigns.session_id
    request_id = System.unique_integer([:positive])

    # Emit MCP tool start telemetry event
    TelemetryEvents.mcp_tool_start(
      request_id,
      tool_call.tool_call_id,
      tool_call.tool_name,
      tool_call.agent_id,
      session_id,
      tool_call.arguments
    )

    request =
      JsonRpc.request(request_id, "tools/call", %{
        "name" => tool_call.tool_name,
        "arguments" => tool_call.arguments,
        "callId" => tool_call.tool_call_id
      })

    # Send ACP notification: in_progress
    in_progress_notification =
      ACP.build_tool_call_update_notification(session_id, tool_call.tool_call_id, "in_progress")

    push(socket, "acp:message", in_progress_notification)

    # Track pending call for response correlation (request_id -> tool_call)
    pending_calls = socket.assigns[:pending_mcp_calls] || %{}
    socket = assign(socket, :pending_mcp_calls, Map.put(pending_calls, request_id, tool_call))

    push(socket, "mcp:message", request)
    {:noreply, socket}
  end

  defp mcp_tools_to_llm_format(mcp_tools) do
    Enum.map(mcp_tools, fn tool ->
      # MCP tools are executed externally via SessionChannel, so we use a dummy callback.
      # The callback is never actually called - tool calls are routed to MCP instead.
      ReqLLM.Tool.new!(
        name: tool["name"],
        description: tool["description"] || "",
        parameter_schema: tool["inputSchema"] || %{"type" => "object", "properties" => %{}},
        callback: fn _args -> {:ok, "MCP tool - executed externally"} end
      )
    end)
  end

  @impl true
  def terminate(reason, socket) do
    session_id = socket.assigns[:session_id]
    Logger.info("Client disconnected from session #{session_id}: #{inspect(reason)}")

    # Emit task stop if still processing (client disconnected mid-prompt)
    if socket.assigns[:pending_prompt_id] do
      TelemetryEvents.task_stop(session_id)
    end

    :ok
  end
end
