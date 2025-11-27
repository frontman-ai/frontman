defmodule FrontmanServerWeb.SessionChannel do
  @moduledoc """
  Channel for session-specific ACP events.

  Clients join this channel after creating a session via the
  sessions channel. Handles prompt messages and streams
  agent responses back to the client.
  """
  use FrontmanServerWeb, :channel
  require Logger

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
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

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_in("mcp:message", payload, socket) do
    case payload do
      %{"jsonrpc" => "2.0", "id" => id, "result" => result} ->
        handle_mcp_response(id, result, socket)

      %{"jsonrpc" => "2.0", "id" => id, "error" => error} ->
        handle_mcp_error(id, error, socket)

      _ ->
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

        Logger.info("MCP tool #{tool_call.tool_name} completed: #{text_result}")

        # Send ACP notification: completed
        completed_notification =
          ACP.build_tool_call_update_notification(
            session_id,
            tool_call.tool_call_id,
            "completed",
            text_result
          )

        push(socket, "acp:message", completed_notification)

        # Store result and notify agent
        Tasks.add_tool_result(
          session_id,
          %{id: tool_call.tool_call_id, name: tool_call.tool_name},
          text_result,
          false
        )

        socket = assign(socket, :pending_mcp_calls, Map.delete(pending_calls, id))
        {:noreply, socket}

      true ->
        {:noreply, socket}
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

    text_content =
      prompt_content
      |> Enum.filter(fn block -> Map.get(block, "type") == "text" end)
      |> Enum.map(fn block -> Map.get(block, "text", "") end)
      |> Enum.join("\n")

    Logger.info("Received prompt for session #{session_id}: #{text_content}")

    socket = assign(socket, :pending_prompt_id, id)

    # Add user message to task - this triggers the real agent with MCP tools
    case Tasks.add_user_message(session_id, text_content, mcp_tools: mcp_tools_to_llm_format(mcp_tools)) do
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
  def handle_info({:stream_token, _agent_id, text}, socket) do
    # Translate domain event to ACP notification
    session_id = socket.assigns.session_id
    notification = ACP.build_agent_message_chunk_notification(session_id, text)
    push(socket, "acp:message", notification)
    {:noreply, socket}
  end

  def handle_info({:agent_completed, _agent_id}, socket) do
    # Translate domain event to ACP response
    case socket.assigns[:pending_prompt_id] do
      nil ->
        {:noreply, socket}

      id ->
        response = JsonRpc.success_response(id, ACP.build_prompt_result("end_turn"))
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

    # Route tool call to browser via MCP
    request_id = System.unique_integer([:positive])

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

    # Track pending call to match response
    pending_calls = socket.assigns[:pending_mcp_calls] || %{}

    socket =
      assign(socket, :pending_mcp_calls, Map.put(pending_calls, request_id, tool_call))

    push(socket, "mcp:message", request)
    {:noreply, socket}
  end

  def handle_info({:interaction, _interaction}, socket) do
    # Other interactions are stored but don't need transport handling
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
    :ok
  end
end
