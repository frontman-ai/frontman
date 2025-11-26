defmodule FrontmanServerWeb.SessionsChannel do
  @moduledoc """
  Channel for ACP session management.

  Handles protocol initialization and session creation.
  Clients join this channel first, then join session-specific
  channels after creating a session.
  """
  use FrontmanServerWeb, :channel
  require Logger

  alias FrontmanServer.ACP
  alias FrontmanServer.Tasks

  @jsonrpc_version "2.0"
  @acp_protocol_version ACP.protocol_version()

  @impl true
  def join("sessions", _params, socket) do
    Logger.info("Client joining sessions channel")
    socket = assign(socket, :acp_initialized, false)
    {:ok, %{status: "connected"}, socket}
  end

  # ACP initialize - correct protocol version
  @impl true
  def handle_in(
        "acp:message",
        %{
          "jsonrpc" => @jsonrpc_version,
          "id" => id,
          "method" => "initialize",
          "params" => %{"protocolVersion" => @acp_protocol_version} = params
        },
        socket
      ) do
    Logger.info("ACP initialize from #{inspect(params["clientInfo"])}")

    socket =
      socket
      |> assign(:acp_initialized, true)
      |> assign(:acp_client_info, params["clientInfo"])
      |> assign(:acp_client_capabilities, params["clientCapabilities"])

    response = %{
      "jsonrpc" => @jsonrpc_version,
      "id" => id,
      "result" => ACP.build_initialize_result()
    }

    push(socket, "acp:message", response)
    {:noreply, socket}
  end

  # ACP initialize - wrong protocol version
  @impl true
  def handle_in(
        "acp:message",
        %{
          "jsonrpc" => @jsonrpc_version,
          "id" => id,
          "method" => "initialize",
          "params" => %{"protocolVersion" => _}
        },
        socket
      ) do
    acp_error_reply(id, ACP.error_invalid_request(), "Unsupported protocol version", socket)
  end

  # ACP initialize - missing protocol version
  @impl true
  def handle_in(
        "acp:message",
        %{"jsonrpc" => @jsonrpc_version, "id" => id, "method" => "initialize"},
        socket
      ) do
    acp_error_reply(
      id,
      ACP.error_invalid_params(),
      "Missing required field: protocolVersion",
      socket
    )
  end

  # ACP session/new
  @impl true
  def handle_in(
        "acp:message",
        %{"jsonrpc" => @jsonrpc_version, "id" => id, "method" => "session/new"},
        socket
      ) do
    Logger.info("ACP session/new request received")
    session_id = ACP.generate_session_id()
    {:ok, ^session_id} = Tasks.create_task(session_id, %{})

    response = %{
      "jsonrpc" => @jsonrpc_version,
      "id" => id,
      "result" => ACP.build_session_new_result(session_id)
    }

    push(socket, "acp:message", response)
    {:noreply, socket}
  end

  # Unknown method
  @impl true
  def handle_in(
        "acp:message",
        %{"jsonrpc" => @jsonrpc_version, "id" => id, "method" => method},
        socket
      ) do
    Logger.info("ACP unknown method: #{method}")
    acp_error_reply(id, ACP.error_method_not_found(), "Method not found", socket)
  end

  # Notification (no id)
  @impl true
  def handle_in("acp:message", %{"jsonrpc" => @jsonrpc_version, "method" => _method}, socket) do
    {:noreply, socket}
  end

  # Helpers

  defp acp_error_reply(id, code, message, socket) do
    response = %{
      "jsonrpc" => @jsonrpc_version,
      "id" => id,
      "error" => %{
        "code" => code,
        "message" => message
      }
    }

    push(socket, "acp:message", response)
    {:noreply, socket}
  end
end
