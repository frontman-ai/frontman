# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.TasksChannel do
  @moduledoc """
  Channel for Tasks management.

  Handles protocol initialization and session creation.
  Clients join this channel first, then join session-specific
  channels after creating a session.
  """
  use FrontmanServerWeb, :channel
  use FrontmanServerWeb, :verified_routes
  require Logger

  alias FrontmanServer.Agents
  alias FrontmanServer.Billing
  alias FrontmanServer.Observability.SentryContext
  alias FrontmanServer.Protocols.{ACP, JsonRpc}
  alias FrontmanServer.Providers
  alias FrontmanServer.Tasks

  @billing_status_updated "billing_status_updated"
  @acp_protocol_version ACP.protocol_version()
  @acp_message ACP.event_acp_message()
  @model_catalog_updated "model_catalog_updated"
  @acp_list_sessions ACP.event_list_sessions()
  @acp_delete_session ACP.event_delete_session()
  @acp_method_initialize ACP.method_initialize()
  @acp_method_session_new ACP.method_session_new()

  @impl true
  def join("tasks", _params, socket) do
    if Map.has_key?(socket.assigns, :scope) do
      SentryContext.set_scope_context(socket.assigns.scope)

      Logger.info("Client joining tasks channel (authenticated)")

      user_id = socket.assigns.scope.user.id

      Phoenix.PubSub.subscribe(
        FrontmanServer.PubSub,
        Providers.config_pubsub_topic(user_id)
      )

      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Billing.status_topic(user_id))

      {:ok, %{status: "connected"}, socket}
    else
      Logger.info("Client joining tasks channel (unauthenticated)")
      {:error, %{reason: "unauthorized", login_url: url(~p"/users/log-in")}}
    end
  end

  @impl true
  def handle_in(@acp_message, payload, socket) do
    Logger.info("Received ACP message")

    case JsonRpc.parse(payload) do
      {:ok, message} -> handle_message(message, socket)
      {:error, reason} -> handle_parse_error(reason, payload, socket)
    end
  end

  @impl true
  def handle_in(@acp_list_sessions, _payload, socket) do
    scope = socket.assigns.scope
    {:ok, tasks} = Tasks.list_tasks(scope)
    sessions = Enum.map(tasks, &ACP.build_session_summary/1)
    {:reply, {:ok, %{"sessions" => sessions}}, socket}
  end

  @impl true
  def handle_in(@acp_delete_session, %{"sessionId" => session_id}, socket) do
    case Tasks.delete_task(socket.assigns.scope, session_id) do
      :ok -> {:reply, {:ok, %{}}, socket}
      {:error, reason} -> {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  defp handle_message(
         {:request, id, @acp_method_initialize,
          %{"protocolVersion" => @acp_protocol_version} = params},
         socket
       ) do
    Logger.info("ACP initialize received")

    case ACP.negotiate_agent_attribution_version(params["clientCapabilities"]) do
      {:ok, _version} ->
        socket = assign(socket, :acp_client_info, params["clientInfo"])

        push(
          socket,
          @model_catalog_updated,
          Providers.available_models(socket.assigns.scope)
        )

        push(socket, @billing_status_updated, Billing.status(socket.assigns.scope))
        agents = Agents.list_agents(socket.assigns.scope)

        push_response(
          socket,
          id,
          ACP.build_initialize_result(agents, Agents.default_agent_id(socket.assigns.scope))
        )

      {:error, message} ->
        push_error(socket, id, JsonRpc.error_invalid_params(), message)
    end
  end

  defp handle_message({:request, id, @acp_method_initialize, %{"protocolVersion" => _}}, socket) do
    push_error(socket, id, JsonRpc.error_invalid_request(), "Unsupported protocol version")
  end

  defp handle_message({:request, id, @acp_method_initialize, _params}, socket) do
    push_error(
      socket,
      id,
      JsonRpc.error_invalid_params(),
      "Missing required field: protocolVersion"
    )
  end

  defp handle_message(
         {:request, id, @acp_method_session_new, %{"sessionId" => session_id} = params},
         socket
       )
       when is_binary(session_id) and session_id != "" do
    Logger.info("ACP session/new request received with sessionId: #{session_id}")

    with :ok <- validate_uuid_format(session_id),
         raw_framework when is_binary(raw_framework) <-
           extract_framework(socket.assigns[:acp_client_info]),
         true <- Billing.allow_access?(socket.assigns.scope),
         catalog = Providers.available_models(socket.assigns.scope),
         {:ok, current_model} <- new_model(params, catalog),
         {:ok, %Tasks.TaskSchema{id: ^session_id} = task} <-
           Tasks.ensure_session(socket.assigns.scope, %{
             id: session_id,
             framework: raw_framework,
             current_model: current_model
           }) do
      push_response(
        socket,
        id,
        ACP.build_session_new_result(
          session_id,
          ACP.build_model_config_options(catalog, task.current_model)
        )
      )
    else
      false ->
        push(socket, @billing_status_updated, Billing.status(socket.assigns.scope))

        push_error(
          socket,
          id,
          JsonRpc.error_billing_inactive(),
          Tasks.billing_inactive_message(socket.assigns.scope)
        )

      :error ->
        push_error(
          socket,
          id,
          JsonRpc.error_invalid_params(),
          "Invalid sessionId: must be a valid UUID"
        )

      nil ->
        push_error(socket, id, JsonRpc.error_invalid_params(), "Missing framework in clientInfo")

      {:error, :missing_model} ->
        push_error(socket, id, JsonRpc.error_invalid_params(), "Model selection is required")

      {:error, :unknown_model} ->
        push_error(socket, id, JsonRpc.error_invalid_params(), "Selected model is unavailable")

      {:error, _changeset} ->
        push_error(socket, id, JsonRpc.error_invalid_params(), "Failed to create session")
    end
  end

  defp handle_message({:request, id, @acp_method_session_new, _params}, socket) do
    push_error(socket, id, JsonRpc.error_invalid_params(), "Missing required field: sessionId")
  end

  defp handle_message({:request, id, method, _params}, socket) do
    Logger.info("ACP unknown method: #{method}")
    push_error(socket, id, JsonRpc.error_method_not_found(), "Method not found")
  end

  defp handle_message({:notification, _method, _params}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(:config_options_changed, socket) do
    push(
      socket,
      @model_catalog_updated,
      Providers.available_models(socket.assigns.scope)
    )

    {:noreply, socket}
  end

  def handle_info(:billing_status_changed, socket) do
    push(socket, @billing_status_updated, Billing.status(socket.assigns.scope))
    {:noreply, socket}
  end

  defp new_model(%{"_meta" => meta}, _catalog) when not is_map(meta),
    do: {:error, :unknown_model}

  defp new_model(params, catalog) do
    params
    |> Map.get("_meta", %{})
    |> Map.get("frontman.dev/model")
    |> Tasks.validate_model(catalog)
  end

  defp validate_uuid_format(string) do
    case Ecto.UUID.cast(string) do
      {:ok, uuid} -> if uuid == String.downcase(string), do: :ok, else: :error
      :error -> :error
    end
  end

  defp extract_framework(%{"_meta" => %{"framework" => framework}}) when is_binary(framework),
    do: framework

  defp extract_framework(_), do: nil

  defp handle_parse_error(_reason, %{"id" => id}, socket) do
    Logger.error("Invalid ACP message")
    push_error(socket, id, JsonRpc.error_invalid_request(), "Invalid JSON-RPC message")
  end

  defp handle_parse_error(_reason, _payload, socket) do
    Logger.error("Invalid ACP message")
    {:noreply, socket}
  end

  defp push_response(socket, id, result) do
    push(socket, @acp_message, JsonRpc.success_response(id, result))
    {:noreply, socket}
  end

  defp push_error(socket, id, code, message) do
    push(socket, @acp_message, JsonRpc.error_response(id, code, message))
    {:noreply, socket}
  end
end
