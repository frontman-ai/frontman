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

  alias AgentClientProtocol, as: ACP
  alias FrontmanServer.Agents
  alias FrontmanServer.Frameworks
  alias FrontmanServer.MCPCatalog
  alias FrontmanServer.MCPConnection
  alias FrontmanServer.MCPTerminalRequests
  alias FrontmanServer.Observability.SentryContext
  alias FrontmanServer.Providers
  alias FrontmanServer.Tasks
  alias ModelContextProtocol, as: MCP

  @acp_protocol_version ACP.protocol_version()
  @acp_message ACP.event_acp_message()
  @acp_config_updated ACP.event_config_options_updated()
  @acp_list_sessions ACP.event_list_sessions()
  @acp_delete_session ACP.event_delete_session()
  @acp_method_initialize ACP.method_initialize()
  @acp_method_session_new ACP.method_session_new()
  @mcp_message "mcp:message"
  @max_pending_mcp_requests 256
  @mcp_request_timeout_ms 600_000
  @mcp_claim_lease_ms 60_000
  @mcp_claim_renewal_ms 20_000
  @mcp_connection_closed_reason "Connection closed"
  @max_project_contexts 256
  @max_project_rules 64
  @max_project_rule_path_bytes 4_096
  @max_project_rule_content_bytes 65_536
  @max_project_tree_bytes 262_144
  @max_project_workspaces 64
  @max_project_workspace_name_bytes 4_096
  @max_project_workspace_path_bytes 4_096
  @project_rules_tool "load_agent_instructions"
  @project_structure_tool "list_tree"
  @input_required_error "MCP tool requested additional input"

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

      {:ok, owner_connection_id} = MCPConnection.register(socket.assigns.scope)

      socket =
        socket
        |> assign(:mcp_catalog, %{status: :waiting, request_id: nil, timer: nil, tools: []})
        |> assign(:pending_mcp_requests, %{})
        |> assign(:terminal_mcp_requests, [])
        |> assign(:mcp_claim_recoveries, %{})
        |> assign(:mcp_response_counts, %{duplicate: 0, late: 0, unknown: 0})
        |> assign(:mcp_now_ms, fn -> System.monotonic_time(:millisecond) end)
        |> assign(:project_contexts, %{})
        |> assign(:mcp_owner_pid, nil)
        |> assign(:mcp_owner_monitor, nil)
        |> assign(:mcp_owner_connection_id, owner_connection_id)

      socket = synchronize_mcp_owner(socket)

      {:ok, %{status: "connected"}, socket}
    else
      Logger.info("Client joining tasks channel (unauthenticated)")
      {:error, %{reason: "unauthorized", login_url: url(~p"/users/log-in")}}
    end
  end

  @impl true
  def handle_in("mcp:ready", %{}, %{assigns: %{mcp_catalog: %{status: :waiting}}} = socket) do
    {catalog, request} = MCPCatalog.start()
    push(socket, @mcp_message, request)
    {:noreply, assign(socket, :mcp_catalog, start_catalog_timer(catalog))}
  end

  def handle_in("mcp:ready", %{}, socket), do: {:noreply, socket}

  @impl true
  def handle_in(@mcp_message, payload, socket) do
    case parse_mcp_response(payload, socket) do
      {:ok, {:success, id, result}} ->
        handle_mcp_success(id, result, socket)

      {:ok, {:error, id, error}} ->
        handle_mcp_error(id, error, socket)

      {:error, reason} ->
        Logger.error("Invalid MCP response: #{reason}")
        {:noreply, fail_active_mcp_request(payload, reason, socket)}
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
    case Tasks.get_task(socket.assigns.scope, session_id) do
      {:ok, _task} ->
        cancel_execution_before_delete(socket, session_id)

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  defp cancel_execution_before_delete(socket, session_id) do
    case Tasks.cancel_execution(socket.assigns.scope, session_id) do
      :ok -> forget_and_delete_task(socket, session_id)
      {:error, :not_running} -> forget_and_delete_task(socket, session_id)
      {:error, reason} -> {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  defp forget_and_delete_task(socket, session_id) do
    socket = forget_task_before_delete(socket, session_id)

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
          @acp_config_updated,
          ACP.build_config_options_updated_payload(current_config_options(socket))
        )

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
         {:request, id, @acp_method_session_new, %{"sessionId" => session_id}},
         socket
       )
       when is_binary(session_id) and session_id != "" do
    Logger.info("ACP session/new request received with sessionId: #{session_id}")

    with :ok <- validate_uuid_format(session_id),
         raw_framework when is_binary(raw_framework) <-
           extract_framework(socket.assigns[:acp_client_info]),
         {:ok, %Tasks.TaskSchema{id: ^session_id}} <-
           Tasks.create_task(
             socket.assigns.scope,
             session_id,
             raw_framework
           ) do
      MCPConnection.load_task(socket.assigns.scope, session_id)

      push_response(
        socket,
        id,
        ACP.build_session_new_result(
          session_id,
          current_config_options(socket)
        )
      )
    else
      :error ->
        push_error(
          socket,
          id,
          JsonRpc.error_invalid_params(),
          "Invalid sessionId: must be a valid UUID"
        )

      nil ->
        push_error(socket, id, JsonRpc.error_invalid_params(), "Missing framework in clientInfo")

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
  def handle_info({:push_mcp, request}, socket) do
    push(socket, @mcp_message, request)
    {:noreply, socket}
  end

  def handle_info({:execute_mcp_tool, reference, tool_call}, socket) do
    {:noreply, dispatch_mcp_tool(socket, reference, tool_call)}
  end

  def handle_info({:cancel_mcp_task, task_id, reason}, socket) do
    {:noreply, cancel_mcp_task(socket, task_id, reason)}
  end

  def handle_info({:cancel_mcp_tool, caller, reference, task_id, tool_call_id, reason}, socket) do
    {socket, status} = cancel_mcp_tool(socket, task_id, tool_call_id, reason)
    send(caller, {:mcp_tool_cancelled, reference, status})
    {:noreply, socket}
  end

  def handle_info({:load_mcp_task, task_id}, socket) do
    {:noreply, redispatch_unresolved_tool_calls(socket, task_id)}
  end

  def handle_info({:hydrate_mcp_task, task_id}, socket) do
    {:noreply, maybe_load_project_context(socket, task_id)}
  end

  def handle_info({:forget_mcp_task, caller, reference, task_id}, socket) do
    socket = forget_mcp_task(socket, task_id, "Session deleted")
    send(caller, {:mcp_task_forgotten, reference})
    {:noreply, socket}
  end

  def handle_info({:mcp_catalog_timeout, request_id}, socket) do
    case MCPCatalog.response_method(socket.assigns.mcp_catalog, request_id) do
      nil ->
        {:noreply, socket}

      method ->
        push(socket, @mcp_message, MCP.cancelled_notification(request_id, "Request timed out"))
        catalog = fail_catalog(socket.assigns.mcp_catalog)
        MCPConnection.update_catalog(socket.assigns.scope, :failed, [])

        {:noreply,
         socket
         |> assign(:mcp_catalog, catalog)
         |> remember_mcp_request(request_id, method, :catalog, :timeout)}
    end
  end

  def handle_info({:mcp_owner_departed, _owner_pid}, socket) do
    {:noreply, synchronize_mcp_owner(socket)}
  end

  def handle_info(:restore_mcp_connection_state, socket) do
    {status, tools} = restorable_catalog(socket.assigns.mcp_catalog)
    MCPConnection.update_catalog(socket.assigns.scope, status, tools)
    restore_project_contexts(socket)
    {:noreply, socket}
  end

  def handle_info(
        {:DOWN, monitor, :process, _pid, _reason},
        %{assigns: %{mcp_owner_monitor: monitor}} = socket
      ) do
    {:noreply, synchronize_mcp_owner(socket)}
  end

  def handle_info({:mcp_request_timeout, request_id}, socket) do
    case socket.assigns.pending_mcp_requests[request_id] do
      %{kind: :tool} = pending ->
        {:noreply, timeout_pending_tool(socket, request_id, pending)}

      %{kind: {:project_context, _step}} ->
        case pop_pending_request(socket, request_id, :timeout) do
          {:ok, pending, socket} ->
            push(
              socket,
              @mcp_message,
              MCP.cancelled_notification(request_id, "Request timed out")
            )

            {:noreply, complete_timed_out_request(socket, pending)}

          :error ->
            {:noreply, socket}
        end

      nil ->
        {:noreply, socket}
    end
  end

  def handle_info({:renew_mcp_claim, request_id, generation}, socket) do
    {:noreply, renew_mcp_claim(socket, request_id, generation)}
  end

  def handle_info({:recover_mcp_claim, interaction_id}, socket) do
    case Map.pop(socket.assigns.mcp_claim_recoveries, interaction_id) do
      {nil, _recoveries} ->
        {:noreply, socket}

      {{_timer, reference, tool_call}, recoveries} ->
        socket = assign(socket, :mcp_claim_recoveries, recoveries)
        {:noreply, dispatch_mcp_tool(socket, reference, tool_call)}
    end
  end

  def handle_info(:config_options_changed, socket) do
    push(
      socket,
      @acp_config_updated,
      ACP.build_config_options_updated_payload(current_config_options(socket))
    )

    {:noreply, socket}
  end

  defp parse_mcp_response(%{"id" => id} = payload, socket) do
    case response_method(socket, id) do
      nil -> MCP.parse_response(payload)
      method -> MCP.parse_response(payload, method)
    end
  end

  defp parse_mcp_response(payload, _socket), do: MCP.parse_response(payload)

  defp restorable_catalog(%{status: :ready, tools: tools}), do: {:ready, tools}
  defp restorable_catalog(%{status: :failed}), do: {:failed, []}
  defp restorable_catalog(_catalog), do: {:pending, []}

  defp response_method(socket, id) do
    case MCPCatalog.response_method(socket.assigns.mcp_catalog, id) do
      nil ->
        case socket.assigns.pending_mcp_requests[id] do
          %{method: method} -> method
          nil -> nil
        end

      method ->
        method
    end
  end

  defp handle_mcp_success(id, result, socket) do
    case MCPCatalog.handle_response(socket.assigns.mcp_catalog, id, result) do
      {:request, catalog, request} ->
        socket =
          socket
          |> cancel_catalog_timer()
          |> remember_mcp_request(id, "server/discover", :catalog, :response)

        push(socket, @mcp_message, request)
        {:noreply, assign(socket, :mcp_catalog, start_catalog_timer(catalog))}

      {:ready, catalog} ->
        socket =
          socket
          |> cancel_catalog_timer()
          |> remember_mcp_request(id, "tools/list", :catalog, :response)

        MCPConnection.update_catalog(socket.assigns.scope, :ready, catalog.tools)
        socket = assign(socket, :mcp_catalog, catalog)
        {:noreply, load_known_project_contexts(socket)}

      {:error, catalog, reason} ->
        method = MCPCatalog.response_method(socket.assigns.mcp_catalog, id)

        socket =
          socket
          |> cancel_catalog_timer()
          |> remember_mcp_request(id, method, :catalog, :malformed_response)

        Logger.error("MCP catalog discovery failed: #{reason}")
        MCPConnection.update_catalog(socket.assigns.scope, :failed, [])
        {:noreply, assign(socket, :mcp_catalog, catalog)}

      :unknown ->
        route_pending_response(id, {:ok, result}, socket)
    end
  end

  defp handle_mcp_error(id, error, socket) do
    method = MCPCatalog.response_method(socket.assigns.mcp_catalog, id)

    case MCPCatalog.handle_error(socket.assigns.mcp_catalog, id, error) do
      {:error, catalog, reason} ->
        socket =
          socket
          |> cancel_catalog_timer()
          |> remember_mcp_request(id, method, :catalog, :error_response)

        Logger.error("MCP catalog request failed: #{reason}")
        MCPConnection.update_catalog(socket.assigns.scope, :failed, [])
        {:noreply, assign(socket, :mcp_catalog, catalog)}

      :unknown ->
        route_pending_response(id, {:error, error}, socket)
    end
  end

  defp route_pending_response(id, outcome, socket) do
    reason = if match?({:ok, _result}, outcome), do: :response, else: :error_response

    case pop_pending_request(socket, id, reason) do
      {:ok, pending, socket} ->
        {:noreply, complete_pending_request(socket, pending, outcome)}

      :error ->
        {:noreply, classify_terminal_response(socket, id)}
    end
  end

  defp classify_terminal_response(socket, request_id) do
    {classification, _record, records} =
      MCPTerminalRequests.classify(
        socket.assigns.terminal_mcp_requests,
        request_id,
        mcp_now_ms(socket)
      )

    case classification do
      :unknown -> Logger.warning("Received MCP response for unknown request")
      classification when classification in [:duplicate, :late] -> :ok
    end

    counts = Map.update!(socket.assigns.mcp_response_counts, classification, &(&1 + 1))

    socket
    |> assign(:terminal_mcp_requests, records)
    |> assign(:mcp_response_counts, counts)
  end

  defp tool_result({:ok, result}), do: result

  defp tool_result({:error, error}) do
    MCP.tool_result_error(error["message"] || "Unknown MCP error")
  end

  defp complete_pending_request(socket, %{kind: :tool} = pending, {:error, error} = outcome) do
    Logger.error("MCP tool execution failed",
      error_type: "mcp_tool_error",
      tool_name: pending.invocation.tool_name,
      tool_call_id: pending.invocation.tool_call_id,
      task_id: pending.task_id,
      error_code: mcp_error_code(error)
    )

    persist_mcp_result(socket, pending, tool_result(outcome))
    socket
  end

  defp complete_pending_request(
         socket,
         %{kind: :tool} = pending,
         {:ok, %{"resultType" => "input_required"}}
       ) do
    persist_mcp_result(socket, pending, MCP.tool_result_error(@input_required_error))
    socket
  end

  defp complete_pending_request(socket, %{kind: :tool} = pending, outcome) do
    persist_mcp_result(socket, pending, tool_result(outcome))
    socket
  end

  defp complete_pending_request(socket, %{kind: {:project_context, step}} = pending, outcome) do
    complete_project_context(socket, pending.task_id, step, outcome)
  end

  defp mcp_error_code(%{"code" => code}) when is_integer(code), do: code
  defp mcp_error_code(_error), do: :unknown

  defp dispatch_mcp_tool(socket, reference, %Tasks.Interaction.ToolCall{} = tool_call) do
    pending = socket.assigns.pending_mcp_requests
    invocation = mcp_invocation(tool_call)

    case Enum.any?(pending, fn
           {_id, %{kind: :tool} = request} ->
             request.task_id == reference.task_id and
               request.invocation.tool_call_id == invocation.tool_call_id

           {_id, _request} ->
             false
         end) do
      true ->
        socket

      false ->
        acquire_and_dispatch_mcp_tool(socket, reference, tool_call, invocation)
    end
  end

  defp acquire_and_dispatch_mcp_tool(socket, reference, tool_call, invocation) do
    if map_size(socket.assigns.pending_mcp_requests) >= @max_pending_mcp_requests do
      raise "MCP connection request limit exceeded"
    end

    case Tasks.acquire_tool_call_claim(
           socket.assigns.scope,
           reference,
           socket.assigns.mcp_owner_connection_id,
           @mcp_claim_lease_ms,
           :non_idempotent
         ) do
      {:ok, token} ->
        socket
        |> cancel_claim_recovery(reference.interaction_id)
        |> start_claimed_mcp_dispatch(token, tool_call, invocation)

      {:error, :already_claimed} ->
        schedule_claim_recovery(socket, reference, tool_call)

      {:error, :dispatch_ambiguous} ->
        socket
        |> cancel_claim_recovery(reference.interaction_id)
        |> fail_ambiguous_mcp_dispatch(reference)

      {:error, reason} when reason in [:already_resolved, :not_found] ->
        cancel_claim_recovery(socket, reference.interaction_id)

      {:error, reason} ->
        raise "Failed to acquire durable MCP tool claim: #{inspect(reason)}"
    end
  end

  defp start_claimed_mcp_dispatch(socket, token, tool_call, invocation) do
    {:ok, token} = Tasks.mark_tool_call_dispatch_started(socket.assigns.scope, token)
    request_id = System.unique_integer([:positive])

    request =
      MCP.build_tool_execution(%MCP.ToolCallParams{
        request_id: request_id,
        task_id: token.reference.task_id,
        tool_name: invocation.tool_name,
        arguments: invocation.arguments,
        tool_call_id: invocation.tool_call_id
      })

    entry = %{
      kind: :tool,
      method: "tools/call",
      task_id: token.reference.task_id,
      turn_number: token.reference.turn_number,
      invocation: invocation,
      persisted_tool_call: tool_call,
      claim_token: token,
      claim_timer: schedule_claim_renewal(request_id, token),
      timer: schedule_tool_timeout(socket.assigns.scope, request_id, token)
    }

    push(socket, @mcp_message, request)

    assign(
      socket,
      :pending_mcp_requests,
      Map.put(socket.assigns.pending_mcp_requests, request_id, entry)
    )
  end

  defp fail_ambiguous_mcp_dispatch(socket, reference) do
    case Tasks.fail_ambiguous_tool_call(socket.assigns.scope, reference) do
      {:ok, _result, :notified} ->
        socket

      {:ok, _result, :no_executor} ->
        resume_task(socket, reference.task_id)
        socket

      {:error, reason} ->
        raise "Failed to terminally resolve ambiguous MCP dispatch: #{inspect(reason)}"
    end
  end

  defp mcp_invocation(%Tasks.Interaction.ToolCall{} = tool_call) do
    %{
      tool_call_id: tool_call.tool_call_id,
      tool_name: tool_call.tool_name,
      arguments: tool_call.arguments
    }
  end

  defp schedule_claim_renewal(request_id, token) do
    Process.send_after(
      self(),
      {:renew_mcp_claim, request_id, token.generation},
      @mcp_claim_renewal_ms
    )
  end

  defp schedule_tool_timeout(scope, request_id, token) do
    {:ok, delay_ms} = Tasks.tool_call_deadline_delay_ms(scope, token)
    Process.send_after(self(), {:mcp_request_timeout, request_id}, max(delay_ms, 1))
  end

  defp schedule_claim_recovery(socket, reference, tool_call) do
    case Map.has_key?(socket.assigns.mcp_claim_recoveries, reference.interaction_id) do
      true ->
        socket

      false ->
        {:ok, delay_ms} = Tasks.tool_call_claim_delay_ms(socket.assigns.scope, reference)

        timer =
          Process.send_after(
            self(),
            {:recover_mcp_claim, reference.interaction_id},
            max(delay_ms, 1)
          )

        recovery = {timer, reference, tool_call}

        assign(
          socket,
          :mcp_claim_recoveries,
          Map.put(socket.assigns.mcp_claim_recoveries, reference.interaction_id, recovery)
        )
    end
  end

  defp cancel_claim_recovery(socket, interaction_id) do
    case Map.pop(socket.assigns.mcp_claim_recoveries, interaction_id) do
      {nil, _recoveries} ->
        socket

      {{timer, _reference, _tool_call}, recoveries} ->
        Process.cancel_timer(timer)
        assign(socket, :mcp_claim_recoveries, recoveries)
    end
  end

  defp renew_mcp_claim(socket, request_id, generation) do
    case socket.assigns.pending_mcp_requests[request_id] do
      %{kind: :tool, claim_token: %{generation: ^generation} = token} = pending ->
        renew_pending_mcp_claim(socket, request_id, pending, token)

      _missing_or_stale ->
        socket
    end
  end

  defp renew_pending_mcp_claim(socket, request_id, pending, token) do
    case Tasks.renew_tool_call_claim(socket.assigns.scope, token, @mcp_claim_lease_ms) do
      {:ok, renewed_token} ->
        renewed = %{
          pending
          | claim_token: renewed_token,
            claim_timer: schedule_claim_renewal(request_id, renewed_token)
        }

        assign(
          socket,
          :pending_mcp_requests,
          Map.put(socket.assigns.pending_mcp_requests, request_id, renewed)
        )

      {:error, reason} ->
        fence_failed_claim_renewal(socket, request_id, pending, reason)
    end
  end

  defp fence_failed_claim_renewal(socket, request_id, pending, reason) do
    Logger.error("MCP durable claim renewal failed; fencing local execution",
      task_id: pending.task_id,
      tool_call_id: pending.invocation.tool_call_id,
      reason: inspect(reason)
    )

    Process.cancel_timer(pending.timer)
    cancel_claim_timer(pending)
    push(socket, @mcp_message, MCP.cancelled_notification(request_id, "Execution claim lost"))

    socket
    |> assign(:pending_mcp_requests, Map.delete(socket.assigns.pending_mcp_requests, request_id))
    |> remember_mcp_request(request_id, pending.method, pending.kind, :claim_lost)
  end

  defp cancel_claim_timer(%{claim_timer: timer}) when is_reference(timer) do
    Process.cancel_timer(timer)
    :ok
  end

  defp cancel_claim_timer(_request), do: :ok

  defp cancel_claimed_request(socket, %{kind: :tool, claim_token: token}, reason) do
    case Tasks.cancel_claimed_tool_call(socket.assigns.scope, token, reason) do
      {:ok, _result, _executor_status} -> :ok
      {:error, error} -> raise "Failed to cancel claimed MCP tool: #{inspect(error)}"
    end
  end

  defp cancel_claimed_request(_socket, _request, _reason), do: :ok

  defp pop_pending_request(socket, request_id, reason) do
    case Map.pop(socket.assigns.pending_mcp_requests, request_id) do
      {nil, _pending} ->
        :error

      {entry, pending} ->
        Process.cancel_timer(entry.timer)
        cancel_claim_timer(entry)

        socket =
          socket
          |> assign(:pending_mcp_requests, pending)
          |> remember_mcp_request(request_id, entry.method, entry.kind, reason)

        {:ok, entry, socket}
    end
  end

  defp persist_mcp_result(socket, pending, result) do
    {:ok, _interaction, executor_status} =
      Tasks.complete_claimed_tool_call(socket.assigns.scope, pending.claim_token, result)

    case executor_status do
      :notified -> :ok
      :no_executor -> resume_task(socket, pending.task_id)
      :already_resolved -> :ok
    end
  end

  defp timeout_pending_tool(socket, request_id, pending) do
    reason = "Tool #{pending.invocation.tool_name} timed out"

    case Tasks.timeout_claimed_tool_call(socket.assigns.scope, pending.claim_token, reason) do
      {:ok, _result, executor_status} ->
        {:ok, _pending, socket} = pop_pending_request(socket, request_id, :timeout)
        push(socket, @mcp_message, MCP.cancelled_notification(request_id, "Request timed out"))
        resume_timed_out_task(socket, pending.task_id, executor_status)

      {:error, {:deadline_active, delay_ms}} ->
        Process.cancel_timer(pending.timer)
        renewed = %{pending | timer: schedule_timeout_after(request_id, delay_ms)}

        assign(
          socket,
          :pending_mcp_requests,
          Map.put(socket.assigns.pending_mcp_requests, request_id, renewed)
        )

      {:error, reason} ->
        raise "Failed to select durable MCP timeout: #{inspect(reason)}"
    end
  end

  defp schedule_timeout_after(request_id, delay_ms) do
    Process.send_after(self(), {:mcp_request_timeout, request_id}, max(delay_ms, 1))
  end

  defp resume_timed_out_task(socket, task_id, :no_executor) do
    resume_task(socket, task_id)
    socket
  end

  defp resume_timed_out_task(socket, _task_id, status)
       when status in [:notified, :already_resolved],
       do: socket

  defp resume_task(socket, task_id) do
    case SwarmAi.running?(FrontmanServer.AgentRuntime, task_id) do
      true -> :ok
      false -> resume_inactive_task(socket, task_id)
    end
  end

  defp resume_inactive_task(socket, task_id) do
    case Tasks.get_active_run_unresolved_tool_calls(socket.assigns.scope, task_id) do
      {:ok, _turn_number, []} ->
        {:ok, task} = Tasks.get_task(socket.assigns.scope, task_id)

        case Tasks.resume_execution(socket.assigns.scope, task_id, %{
               mcp_tools: socket.assigns.mcp_catalog.tools,
               project_traits: Frameworks.project_traits_from_meta(nil, task.framework)
             }) do
          :ok -> Tasks.complete_restart_recovery(socket.assigns.scope, task_id)
          {:error, reason} -> {:error, reason}
        end

      {:ok, _turn_number, [_ | _]} ->
        :ok

      {:ok, :no_active_run} ->
        :ok
    end
  end

  defp cancel_mcp_task(socket, task_id, reason) do
    {cancelled, retained} =
      Enum.split_with(socket.assigns.pending_mcp_requests, fn {_id, request} ->
        request.task_id == task_id
      end)

    socket = assign(socket, :pending_mcp_requests, Map.new(retained))

    Enum.each(cancelled, fn {request_id, request} ->
      Process.cancel_timer(request.timer)
      cancel_claim_timer(request)
      cancel_claimed_request(socket, request, reason)
      push(socket, @mcp_message, MCP.cancelled_notification(request_id, reason))
    end)

    Enum.reduce(cancelled, socket, fn {request_id, request}, acc ->
      remember_mcp_request(acc, request_id, request.method, request.kind, :cancelled)
    end)
  end

  defp cancel_mcp_tool(socket, task_id, tool_call_id, reason) do
    {cancelled, retained} =
      Enum.split_with(socket.assigns.pending_mcp_requests, fn
        {_id, %{kind: :tool} = request} ->
          request.task_id == task_id and request.invocation.tool_call_id == tool_call_id

        {_id, _request} ->
          false
      end)

    socket = assign(socket, :pending_mcp_requests, Map.new(retained))

    Enum.each(cancelled, fn {request_id, request} ->
      Process.cancel_timer(request.timer)
      cancel_claim_timer(request)
      cancel_claimed_request(socket, request, reason)
      push(socket, @mcp_message, MCP.cancelled_notification(request_id, reason))
    end)

    socket =
      Enum.reduce(cancelled, socket, fn {request_id, request}, acc ->
        remember_mcp_request(acc, request_id, request.method, request.kind, :cancelled)
      end)

    status = if cancelled == [], do: :not_found, else: :claimed_cancelled
    {socket, status}
  end

  defp fail_active_mcp_request(%{"id" => id}, reason, socket) do
    case MCPCatalog.response_method(socket.assigns.mcp_catalog, id) do
      nil ->
        fail_pending_request(id, reason, socket)

      _method ->
        socket = cancel_catalog_timer(socket)
        catalog = %{socket.assigns.mcp_catalog | status: :failed, request_id: nil, tools: []}
        MCPConnection.update_catalog(socket.assigns.scope, :failed, [])

        socket
        |> assign(:mcp_catalog, catalog)
        |> remember_mcp_request(
          id,
          MCPCatalog.response_method(socket.assigns.mcp_catalog, id),
          :catalog,
          :malformed_response
        )
    end
  end

  defp fail_active_mcp_request(_payload, _reason, socket), do: socket

  defp fail_pending_request(id, reason, socket) do
    case pop_pending_request(socket, id, :malformed_response) do
      {:ok, pending, socket} -> complete_malformed_request(socket, pending, reason)
      :error -> socket
    end
  end

  defp complete_malformed_request(socket, %{kind: :tool} = pending, _reason) do
    persist_mcp_result(socket, pending, MCP.tool_result_error("Invalid MCP tool response"))
    socket
  end

  defp complete_malformed_request(socket, %{kind: {:project_context, step}} = pending, reason) do
    Logger.warning("Invalid MCP project context response for #{step}", reason: reason)

    socket
    |> fail_project_context(pending.task_id)
    |> continue_project_context(pending.task_id, step)
  end

  defp redispatch_unresolved_tool_calls(socket, task_id) do
    socket = maybe_load_project_context(socket, task_id)

    case Tasks.get_active_run_unresolved_tool_call_executions(socket.assigns.scope, task_id) do
      {:ok, _turn_number, []} ->
        resume_recovered_task(socket, task_id)
        socket

      {:ok, _turn_number, executions} when is_list(executions) ->
        Enum.reduce(executions, socket, fn {reference, tool_call}, acc ->
          dispatch_mcp_tool(acc, reference, tool_call)
        end)

      {:ok, :no_active_run} ->
        socket
    end
  end

  defp resume_recovered_task(socket, task_id) do
    case Tasks.restart_recovery_pending?(socket.assigns.scope, task_id) do
      true ->
        case resume_task(socket, task_id) do
          :ok ->
            :ok = Tasks.complete_restart_recovery(socket.assigns.scope, task_id)

          {:error, reason} ->
            Logger.error("Failed to resume recovered MCP task: #{inspect(reason)}")
        end

      false ->
        :ok
    end
  end

  defp load_known_project_contexts(socket) do
    Enum.reduce(socket.assigns.project_contexts, socket, fn
      {task_id, :pending}, acc -> maybe_load_project_context(acc, task_id)
      {_task_id, _state}, acc -> acc
    end)
  end

  defp restore_project_contexts(socket) do
    Enum.each(socket.assigns.project_contexts, fn
      {task_id, {:loaded, _fingerprint}} ->
        MCPConnection.update_project_context(socket.assigns.scope, task_id, :ready)

      {_task_id, _state} ->
        :ok
    end)
  end

  defp maybe_load_project_context(%{assigns: %{mcp_catalog: %{status: :ready}}} = socket, task_id) do
    {:ok, task} = Tasks.get_task(socket.assigns.scope, task_id)
    fingerprint = catalog_fingerprint(socket.assigns.mcp_catalog.tools)

    case {Frameworks.load_project_context?(task.framework),
          socket.assigns.project_contexts[task_id]} do
      {false, _state} -> finish_project_context(socket, task_id, fingerprint, :ready)
      {true, {:loaded, ^fingerprint}} -> publish_project_context_ready(socket, task_id, :ready)
      {true, {:loading, ^fingerprint, _successful}} -> socket
      {true, _state} -> start_project_context(socket, task_id, fingerprint)
    end
  end

  defp maybe_load_project_context(socket, task_id) do
    case put_project_context(socket, task_id, :pending) do
      {:error, socket} -> publish_project_context_ready(socket, task_id, :failed)
      socket -> socket
    end
  end

  defp start_project_context(socket, task_id, fingerprint) do
    case put_project_context(socket, task_id, {:loading, fingerprint, true}) do
      {:error, socket} -> socket
      socket -> request_project_rules(socket, task_id)
    end
  end

  defp request_project_rules(socket, task_id) do
    case tool_present?(socket, @project_rules_tool) do
      true ->
        dispatch_project_context(
          socket,
          task_id,
          :rules,
          @project_rules_tool,
          %{"startPath" => "."}
        )

      false ->
        request_project_structure(socket, task_id)
    end
  end

  defp request_project_structure(socket, task_id) do
    case tool_present?(socket, @project_structure_tool) do
      true -> dispatch_project_context(socket, task_id, :structure, @project_structure_tool, %{})
      false -> finish_project_context(socket, task_id)
    end
  end

  defp dispatch_project_context(socket, task_id, step, tool_name, arguments) do
    if map_size(socket.assigns.pending_mcp_requests) >= @max_pending_mcp_requests do
      raise "MCP connection request limit exceeded"
    end

    request_id = System.unique_integer([:positive])
    tool_call_id = "project_context_#{step}_#{request_id}"

    request =
      MCP.build_tool_execution(%MCP.ToolCallParams{
        request_id: request_id,
        task_id: task_id,
        tool_name: tool_name,
        arguments: arguments,
        tool_call_id: tool_call_id
      })

    timer =
      Process.send_after(self(), {:mcp_request_timeout, request_id}, @mcp_request_timeout_ms)

    pending =
      Map.put(socket.assigns.pending_mcp_requests, request_id, %{
        kind: {:project_context, step},
        method: "tools/call",
        task_id: task_id,
        timer: timer
      })

    push(socket, @mcp_message, request)
    assign(socket, :pending_mcp_requests, pending)
  end

  defp complete_project_context(socket, task_id, step, {:error, _error}) do
    Logger.warning("MCP project context call failed for #{step}")
    socket |> fail_project_context(task_id) |> continue_project_context(task_id, step)
  end

  defp complete_project_context(socket, task_id, step, {:ok, %{"isError" => true}}) do
    Logger.warning("MCP project context tool failed for #{step}", task_id: task_id)
    socket |> fail_project_context(task_id) |> continue_project_context(task_id, step)
  end

  defp complete_project_context(socket, task_id, :rules, {:ok, result}) do
    socket =
      case Map.fetch(result, "structuredContent") do
        {:ok, rules} when is_list(rules) ->
          case valid_project_rules?(rules) do
            true ->
              persist_project_rules(socket, task_id, rules)

            false ->
              reject_project_context(socket, task_id, "Invalid or oversized MCP project rules")
          end

        _invalid ->
          reject_project_context(
            socket,
            task_id,
            "MCP project rules missing canonical structured content"
          )
      end

    request_project_structure(socket, task_id)
  end

  defp complete_project_context(socket, task_id, :structure, {:ok, result}) do
    socket =
      case Map.fetch(result, "structuredContent") do
        {:ok, %{"tree" => tree, "workspaces" => workspaces} = context}
        when is_binary(tree) and is_list(workspaces) ->
          case valid_project_structure?(context) do
            true ->
              persist_project_structure(socket, task_id, context)

            false ->
              reject_project_context(
                socket,
                task_id,
                "Invalid or oversized MCP project structure"
              )
          end

        _invalid ->
          reject_project_context(
            socket,
            task_id,
            "MCP project structure missing canonical structured content"
          )
      end

    finish_project_context(socket, task_id)
  end

  defp persist_project_rules(socket, task_id, rules) do
    fingerprint = content_fingerprint(rules)

    Enum.reduce_while(rules, socket, fn %{"fullPath" => path, "content" => content}, acc ->
      case Tasks.add_discovered_project_rule(
             acc.assigns.scope,
             task_id,
             path,
             content,
             content_fingerprint({fingerprint, path, content})
           ) do
        {:ok, _result} ->
          {:cont, acc}

        {:error, reason} ->
          {:halt,
           reject_project_context(
             acc,
             task_id,
             "Failed to persist MCP project rules: #{inspect(reason)}"
           )}
      end
    end)
  end

  defp persist_project_structure(socket, task_id, context) do
    case Tasks.add_discovered_project_structure(
           socket.assigns.scope,
           task_id,
           project_structure_summary(context),
           content_fingerprint(context)
         ) do
      {:ok, _result} ->
        socket

      {:error, reason} ->
        reject_project_context(
          socket,
          task_id,
          "Failed to persist MCP project structure: #{inspect(reason)}"
        )
    end
  end

  defp project_structure_summary(%{"tree" => tree, "workspaces" => workspaces} = context) do
    type_line =
      case context["monorepoType"] do
        type when is_binary(type) -> "Project type: monorepo (#{type})"
        nil -> "Project type: single project"
      end

    workspace_lines =
      Enum.map(workspaces, fn %{"name" => name, "path" => path}
                              when is_binary(name) and is_binary(path) ->
        "  #{name} -> #{path}"
      end)

    workspace_section =
      case workspace_lines do
        [] -> ""
        lines -> "\n\nWorkspaces:\n" <> Enum.join(lines, "\n")
      end

    type_line <> workspace_section <> "\n\nDirectory layout:\n" <> tree
  end

  defp valid_project_rules?(rules) when length(rules) <= @max_project_rules,
    do: Enum.all?(rules, &valid_project_rule?/1)

  defp valid_project_rules?(_rules), do: false

  defp valid_project_rule?(%{"fullPath" => path, "content" => content})
       when is_binary(path) and is_binary(content) do
    with true <- byte_size(path) <= @max_project_rule_path_bytes,
         true <- byte_size(content) <= @max_project_rule_content_bytes do
      true
    else
      false -> false
    end
  end

  defp valid_project_rule?(_rule), do: false

  defp valid_project_structure?(context) do
    with true <- byte_size(context["tree"]) <= @max_project_tree_bytes,
         true <- length(context["workspaces"]) <= @max_project_workspaces,
         true <- valid_monorepo_type?(context["monorepoType"]),
         true <- Enum.all?(context["workspaces"], &valid_workspace?/1) do
      true
    else
      false -> false
    end
  end

  defp valid_monorepo_type?(nil), do: true
  defp valid_monorepo_type?(type), do: is_binary(type)

  defp valid_workspace?(%{"name" => name, "path" => path})
       when is_binary(name) and is_binary(path) do
    with true <- byte_size(name) <= @max_project_workspace_name_bytes,
         true <- byte_size(path) <= @max_project_workspace_path_bytes do
      true
    else
      false -> false
    end
  end

  defp valid_workspace?(_workspace), do: false

  defp continue_project_context(socket, task_id, :rules),
    do: request_project_structure(socket, task_id)

  defp continue_project_context(socket, task_id, :structure),
    do: finish_project_context(socket, task_id)

  defp complete_timed_out_request(socket, %{kind: {:project_context, step}} = pending) do
    Logger.warning("MCP project context call timed out for #{step}")

    socket
    |> fail_project_context(pending.task_id)
    |> continue_project_context(pending.task_id, step)
  end

  defp tool_present?(socket, name),
    do: Enum.any?(socket.assigns.mcp_catalog.tools, &(&1.name == name))

  defp catalog_fingerprint(tools) do
    tools
    |> Enum.map(& &1.name)
    |> Enum.sort()
    |> content_fingerprint()
  end

  defp content_fingerprint(value) do
    :crypto.hash(:sha256, :erlang.term_to_binary(value))
    |> Base.encode16(case: :lower)
  end

  defp remember_mcp_request(socket, request_id, method, kind, reason) when is_binary(method) do
    records =
      MCPTerminalRequests.remember(
        socket.assigns.terminal_mcp_requests,
        %{
          id: request_id,
          method: method,
          kind: kind,
          reason: reason,
          former_owner: self()
        },
        mcp_now_ms(socket)
      )

    assign(socket, :terminal_mcp_requests, records)
  end

  defp mcp_now_ms(socket), do: socket.assigns.mcp_now_ms.()

  defp start_catalog_timer(catalog) do
    timer =
      Process.send_after(
        self(),
        {:mcp_catalog_timeout, catalog.request_id},
        @mcp_request_timeout_ms
      )

    MCPCatalog.put_timer(catalog, timer)
  end

  defp cancel_catalog_timer(socket) do
    assign(socket, :mcp_catalog, MCPCatalog.cancel_timer(socket.assigns.mcp_catalog))
  end

  defp fail_catalog(catalog) do
    catalog = MCPCatalog.cancel_timer(catalog)
    %{catalog | status: :failed, request_id: nil, tools: []}
  end

  defp synchronize_mcp_owner(socket) do
    owner_pid = MCPConnection.owner_pid(socket.assigns.scope)
    socket = replace_owner_monitor(socket, owner_pid)

    case owner_pid == self() do
      true ->
        MCPConnection.publish_own_catalog(socket.assigns.scope)
        redispatch_known_unresolved_tool_calls(socket)

      false ->
        socket
    end
  end

  defp redispatch_known_unresolved_tool_calls(socket) do
    socket.assigns.project_contexts
    |> Map.keys()
    |> Enum.reduce(socket, &redispatch_unresolved_tool_calls(&2, &1))
  end

  defp replace_owner_monitor(socket, owner_pid) when owner_pid == self() do
    demonitor_owner(socket)
    socket |> assign(:mcp_owner_pid, owner_pid) |> assign(:mcp_owner_monitor, nil)
  end

  defp replace_owner_monitor(%{assigns: %{mcp_owner_pid: owner_pid}} = socket, owner_pid),
    do: socket

  defp replace_owner_monitor(socket, owner_pid) when is_pid(owner_pid) do
    socket = demonitor_owner(socket)

    socket
    |> assign(:mcp_owner_pid, owner_pid)
    |> assign(:mcp_owner_monitor, Process.monitor(owner_pid))
  end

  defp demonitor_owner(%{assigns: %{mcp_owner_monitor: nil}} = socket), do: socket

  defp demonitor_owner(%{assigns: %{mcp_owner_monitor: monitor}} = socket) do
    Process.demonitor(monitor, [:flush])
    socket
  end

  defp put_project_context(socket, task_id, state) do
    contexts = socket.assigns.project_contexts

    case Map.has_key?(contexts, task_id) do
      true ->
        assign(socket, :project_contexts, Map.put(contexts, task_id, state))

      false ->
        put_new_project_context(socket, contexts, task_id, state)
    end
  end

  defp put_new_project_context(socket, contexts, task_id, state)
       when map_size(contexts) < @max_project_contexts do
    assign(socket, :project_contexts, Map.put(contexts, task_id, state))
  end

  defp put_new_project_context(socket, _contexts, _task_id, _state) do
    Logger.warning(
      "MCP project context tracking limit exceeded (maximum #{@max_project_contexts})"
    )

    {:error, socket}
  end

  defp fail_project_context(socket, task_id) do
    case socket.assigns.project_contexts[task_id] do
      {:loading, fingerprint, _successful} ->
        put_project_context(socket, task_id, {:loading, fingerprint, false})

      _state ->
        socket
    end
  end

  defp finish_project_context(socket, task_id) do
    case socket.assigns.project_contexts[task_id] do
      {:loading, fingerprint, true} ->
        finish_project_context(socket, task_id, fingerprint, :ready)

      {:loading, fingerprint, false} ->
        finish_project_context(socket, task_id, fingerprint, :failed)

      _state ->
        socket
    end
  end

  defp finish_project_context(socket, task_id, fingerprint, status) do
    state = if status == :ready, do: {:loaded, fingerprint}, else: :pending

    socket
    |> unwrap_project_context(put_project_context(socket, task_id, state))
    |> publish_project_context_ready(task_id, status)
  end

  defp publish_project_context_ready(socket, task_id, status) do
    MCPConnection.update_project_context(socket.assigns.scope, task_id, status)
    socket
  end

  defp reject_project_context(socket, task_id, message) do
    Logger.warning(message, task_id: task_id)
    fail_project_context(socket, task_id)
  end

  defp unwrap_project_context(_socket, updated_socket) when is_map(updated_socket),
    do: updated_socket

  defp unwrap_project_context(socket, {:error, _updated_socket}), do: socket

  defp forget_task_before_delete(socket, task_id) do
    case MCPConnection.forget_task(socket.assigns.scope, task_id) do
      :local -> forget_mcp_task(socket, task_id, "Session deleted")
      result when result in [:ok, :unavailable] -> socket
    end
  end

  defp forget_mcp_task(socket, task_id, reason) do
    socket = cancel_mcp_task(socket, task_id, reason)
    socket = cancel_task_claim_recoveries(socket, task_id)
    assign(socket, :project_contexts, Map.delete(socket.assigns.project_contexts, task_id))
  end

  defp cancel_task_claim_recoveries(socket, task_id) do
    Enum.reduce(socket.assigns.mcp_claim_recoveries, socket, fn
      {interaction_id, {_timer, %{task_id: ^task_id}, _tool_call}}, acc ->
        cancel_claim_recovery(acc, interaction_id)

      {_interaction_id, _recovery}, acc ->
        acc
    end)
  end

  defp current_config_options(socket) do
    socket.assigns.scope
    |> Providers.available_models()
    |> ACP.build_model_config_options()
  end

  @uuid_regex ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  defp validate_uuid_format(string) do
    if Regex.match?(@uuid_regex, string), do: :ok, else: :error
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

  @impl true
  def terminate(_reason, socket) do
    Enum.each(socket.assigns.pending_mcp_requests, fn {_request_id, request} ->
      Process.cancel_timer(request.timer)
      cancel_claim_timer(request)
    end)

    Enum.each(socket.assigns.mcp_claim_recoveries, fn {_interaction_id, {timer, _, _}} ->
      Process.cancel_timer(timer)
    end)

    catalog = MCPCatalog.cancel_timer(socket.assigns.mcp_catalog)

    Enum.each(socket.assigns.pending_mcp_requests, fn {_request_id, request} ->
      cancel_claimed_request(socket, request, @mcp_connection_closed_reason)
    end)

    Enum.each(socket.assigns.pending_mcp_requests, fn {request_id, _request} ->
      push(
        socket,
        @mcp_message,
        MCP.cancelled_notification(request_id, @mcp_connection_closed_reason)
      )
    end)

    case catalog.request_id do
      nil ->
        :ok

      request_id ->
        push(
          socket,
          @mcp_message,
          MCP.cancelled_notification(request_id, @mcp_connection_closed_reason)
        )
    end

    MCPConnection.unregister(socket.assigns.scope)

    :ok
  end
end
