defmodule FrontmanServerWeb.SessionChannel do
  @moduledoc """
  WebSocket channel for session-based communication using MCP mechanics.

  ## MCP Role Clarification (IMPORTANT!)

  This is confusing because WebSocket and MCP roles are inverted:

  **WebSocket Perspective:**
  - Browser = WebSocket Client (initiates connection)
  - Elixir = WebSocket Server (accepts connection)

  **MCP Perspective:**
  - Browser = MCP Server (provides/exposes tools like click, navigate, etc.)
  - Elixir = MCP Client (consumes/calls those browser tools during agent execution)

  ## Protocol Flow (MCP mechanics adapted for WebSockets)

  1. **Join/Initialize**
     - Browser joins channel with protocol version and client info
     - Elixir responds with server capabilities

  2. **Tool Discovery**
     - Browser (MCP Server) announces what tools it can execute
     - Elixir (MCP Client) stores these for later use

  3. **Tool Execution**
     - Elixir agent needs a tool → pushes "tool:call" to browser
     - Browser executes → pushes "tool:result" back to Elixir

  4. **Task Management**
     - Browser creates tasks within the session
     - Tasks run agents that can call browser tools
  """
  use FrontmanServerWeb, :channel
  require Logger

  alias FrontmanServer.Sessions

  @impl true
  def join("session:" <> session_id, _params, socket) do
    Logger.info("Browser (MCP Server) joining session: #{session_id}")

    # Create or get existing session
    {:ok, session} =
      case Sessions.get_session(session_id) do
        {:ok, existing_session} ->
          # Reconnecting to existing session
          Logger.info("Reconnecting to existing session: #{session_id}")

          if existing_session.state == :disconnected do
            Sessions.prepare_reconnect(session_id)
          else
            {:ok, existing_session}
          end

        {:error, :not_found} ->
          # New session
          Logger.info("Creating new session: #{session_id}")
          Sessions.create_session(session_id)
          Sessions.mark_awaiting_capabilities(session_id)
      end

    # Subscribe to session events
    Phoenix.PubSub.subscribe(FrontmanServer.PubSub, "session:#{session_id}")

    socket =
      socket
      |> assign(:session_id, session_id)
      |> assign(:session_state, session.state)
      # Track outgoing requests by ID
      |> assign(:pending_requests, %{})

    {:ok, %{session_id: session_id, status: "connected", state: session.state}, socket}
  end

  # Channel Callbacks - handle_in

  @impl true
  def handle_in("mcp:request", %{"jsonrpc" => "2.0", "method" => method} = message, socket) do
    Logger.info("MCP request received: #{method}")

    case method do
      "initialize" -> handle_mcp_initialize(message, socket)
      "tools/list" -> handle_mcp_tools_list(message, socket)
      "tools/call" -> handle_mcp_tools_call(message, socket)
      _ -> mcp_error_reply(message["id"], -32601, "Method not found", socket)
    end
  end

  @impl true
  def handle_in("mcp:notification", %{"jsonrpc" => "2.0", "method" => method} = message, socket) do
    Logger.info("MCP notification received: #{method}")

    case method do
      "initialized" -> handle_mcp_initialized(message, socket)
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_in("mcp:response", %{"jsonrpc" => "2.0", "id" => id} = message, socket) do
    Logger.info("MCP response received for request ID: #{id}")
    handle_mcp_response(id, message, socket)
  end

  # Handle malformed MCP messages
  @impl true
  def handle_in("mcp:" <> _type, _message, socket) do
    {:reply, {:error, %{"error" => "Invalid JSON-RPC 2.0 message"}}, socket}
  end

  @impl true
  def handle_in("task:create", %{"message" => message, "task_id" => task_id}, socket) do
    session_id = socket.assigns.session_id
    Logger.info("Creating task #{task_id} in session #{session_id}")

    case Sessions.get_session(session_id) do
      {:ok, %{state: :ready}} ->
        # Session ready - create task with session_id
        metadata = %{session_id: session_id}

        case FrontmanServer.Tasks.create_task(%{task_id: task_id, message: message}, metadata) do
          {:ok, ^task_id} ->
            # Subscribe to task events
            Phoenix.PubSub.subscribe(FrontmanServer.PubSub, "task:#{task_id}")
            {:reply, {:ok, %{task_id: task_id}}, socket}

          {:error, reason} ->
            {:reply, {:error, %{reason: inspect(reason)}}, socket}
        end

      {:ok, %{state: other_state}} ->
        {:reply, {:error, %{reason: "session_not_ready", state: other_state}}, socket}

      {:error, :not_found} ->
        {:reply, {:error, %{reason: "session_not_found"}}, socket}
    end
  end

  @impl true
  def handle_in("task:create", _invalid, socket) do
    {:reply, {:error, %{reason: "message_and_task_id_required"}}, socket}
  end

  # MCP Method Implementations

  defp handle_mcp_initialize(%{"id" => id, "params" => params}, socket) do
    protocol_version = params["protocolVersion"] || "2025-06-18"
    client_info = params["clientInfo"] || %{}
    client_capabilities = params["capabilities"] || %{}

    Logger.info(
      "MCP initialize from #{client_info["name"]} v#{client_info["version"]}, protocol: #{protocol_version}"
    )

    # Store client info
    socket =
      socket
      |> assign(:protocol_version, protocol_version)
      |> assign(:client_info, client_info)
      |> assign(:client_capabilities, client_capabilities)

    # Reply with server capabilities
    response = %{
      "jsonrpc" => "2.0",
      "id" => id,
      "result" => %{
        "protocolVersion" => protocol_version,
        "capabilities" => %{
          "tools" => %{}
        },
        "serverInfo" => %{
          "name" => "frontman-server",
          "version" => "1.0.0"
        }
      }
    }

    {:reply, {:ok, response}, socket}
  end

  defp handle_mcp_initialized(_message, socket) do
    session_id = socket.assigns.session_id
    Logger.info("MCP session initialized: #{session_id}")

    # Now request tools from browser (MCP Server)
    request_id = generate_request_id()

    request = %{
      "jsonrpc" => "2.0",
      "id" => request_id,
      "method" => "tools/list"
    }

    # Store pending request
    pending_requests = Map.put(socket.assigns.pending_requests, request_id, :tools_list)
    socket = assign(socket, :pending_requests, pending_requests)

    # Push request to browser
    push(socket, "mcp:request", request)

    {:noreply, socket}
  end

  defp handle_mcp_tools_list(%{"id" => id}, socket) do
    # This is if browser requests our tools (we don't have any tools to provide)
    response = %{
      "jsonrpc" => "2.0",
      "id" => id,
      "result" => %{
        "tools" => []
      }
    }

    {:reply, {:ok, response}, socket}
  end

  defp handle_mcp_tools_call(%{"id" => id}, socket) do
    # Browser trying to call our tools (we don't have any)
    mcp_error_reply(id, -32602, "No tools available on server", socket)
  end

  defp handle_mcp_response(id, %{"result" => result}, socket) do
    # Handle response to our outgoing request
    pending_requests = socket.assigns.pending_requests

    case Map.get(pending_requests, id) do
      :tools_list ->
        handle_tools_list_response(result, socket)

      nil ->
        Logger.warning("Received response for unknown request ID: #{id}")
        {:noreply, socket}
    end
  end

  defp handle_mcp_response(id, %{"error" => error}, socket) do
    Logger.error("MCP error response for request #{id}: #{inspect(error)}")
    # Remove from pending
    socket = assign(socket, :pending_requests, Map.delete(socket.assigns.pending_requests, id))
    {:noreply, socket}
  end

  defp handle_tools_list_response(%{"tools" => tools}, socket) do
    session_id = socket.assigns.session_id
    Logger.info("Received #{length(tools)} tools from browser (MCP Server)")

    # Register tools as capabilities in session
    case Sessions.register_capabilities(session_id, tools) do
      {:ok, _session} ->
        # Broadcast readiness
        Phoenix.PubSub.broadcast(
          FrontmanServer.PubSub,
          "session:#{session_id}",
          {:session_ready, session_id}
        )

        # Remove the completed request from pending
        {request_id, _} =
          socket.assigns.pending_requests
          |> Enum.find(fn {_k, v} -> v == :tools_list end)

        socket =
          socket
          |> assign(:session_state, :ready)
          |> assign(:pending_requests, Map.delete(socket.assigns.pending_requests, request_id))

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Failed to register capabilities: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  # Helpers

  defp mcp_error_reply(id, code, message, socket) do
    response = %{
      "jsonrpc" => "2.0",
      "id" => id,
      "error" => %{
        "code" => code,
        "message" => message
      }
    }

    {:reply, {:error, response}, socket}
  end

  defp generate_request_id do
    "req_#{:erlang.unique_integer([:positive])}"
  end

  # PubSub event handlers

  @impl true
  def handle_info({:session_ready, session_id}, socket) do
    Logger.info("Session ready: #{session_id}")
    push(socket, "session:ready", %{session_id: session_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket) do
    # Ignore unknown messages
    {:noreply, socket}
  end

  @impl true
  def terminate(reason, socket) do
    session_id = socket.assigns.session_id
    Logger.info("Client disconnected from session #{session_id}: #{inspect(reason)}")

    # Mark session as disconnected
    case Sessions.get_session(session_id) do
      {:ok, %{state: :ready}} ->
        Sessions.mark_disconnected(session_id)

      _ ->
        :ok
    end

    :ok
  end
end
