# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.TaskChannel.MCPInitializer do
  @moduledoc """
  Pure functional state machine for MCP initialization.

  Manages browser-side MCP setup:
  1. Discover MCP server capabilities
  2. Load tool definitions
  3. Optionally load project rules and structure for code projects
  4. Signal completion

  State is stored in socket assigns by TaskChannel. Functions return
  `{new_state, actions}` tuples where actions are instructions for the
  channel to execute synchronously (push messages, update assigns, etc).

  This design eliminates async process hops — every MCP response is
  processed within the channel's own `handle_in` callback, making the
  initialization flow deterministic and race-free.
  """
  require Logger

  alias FrontmanServer.Frameworks
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tools.MCP, as: MCPTools
  alias JsonRpc
  alias ModelContextProtocol, as: MCP

  @execution_context_extension "ai.frontman/execution-context"

  @doc """
  Creates the initial state and returns the MCP discovery request to send.
  """
  def start(task_id, scope, framework) do
    request_id = System.unique_integer([:positive])
    request = JsonRpc.request(request_id, "server/discover", MCP.request_params())

    state = %{
      status: :discovering_mcp,
      task_id: task_id,
      scope: scope,
      discovery_request_id: request_id,
      tools_request_id: nil,
      project_rules_request_id: nil,
      project_structure_request_id: nil,
      mcp_capabilities: nil,
      mcp_server_info: nil,
      load_project_context: Frameworks.load_project_context?(framework),
      tools: []
    }

    Logger.info("MCPInitializer: Discovering MCP server for task #{task_id}")

    {state, [{:push_mcp, request}]}
  end

  @doc """
  Handle a successful MCP response. Returns updated state and actions.
  """
  def handle_response(state, request_id, result) do
    case state do
      %{status: :discovering_mcp, discovery_request_id: ^request_id} ->
        handle_discovery_response(result, state)

      %{status: :loading_tools, tools_request_id: ^request_id} ->
        handle_tools_response(result, state)

      %{status: :loading_project_rules, project_rules_request_id: ^request_id} ->
        handle_project_rules_response(result, state)

      %{status: :loading_project_structure, project_structure_request_id: ^request_id} ->
        handle_project_structure_response(result, state)

      _state ->
        Logger.warning("MCPInitializer: Received response for unknown request_id #{request_id}")
        {state, []}
    end
  end

  @doc """
  Handle an MCP error response. Returns updated state and actions.
  """
  def handle_error(state, request_id, error) do
    case state do
      %{status: :discovering_mcp, discovery_request_id: ^request_id} ->
        Logger.error("MCPInitializer: MCP discovery failed", error_code: error_code(error))
        fail_initialization(state, error["message"])

      %{status: :loading_tools, tools_request_id: ^request_id} ->
        Logger.warning("MCPInitializer: Tools list failed", error_code: error_code(error))
        state = %{state | tools: [], tools_request_id: nil}
        maybe_request_project_context(state)

      %{status: :loading_project_rules, project_rules_request_id: ^request_id} ->
        Logger.warning("MCPInitializer: Project rules failed", error_code: error_code(error))
        state = %{state | project_rules_request_id: nil}
        request_project_structure(state)

      %{status: :loading_project_structure, project_structure_request_id: ^request_id} ->
        Logger.warning("MCPInitializer: Project structure failed", error_code: error_code(error))
        complete_initialization(state)

      _state ->
        Logger.warning("MCPInitializer: Received error for unknown request_id #{request_id}")
        {state, []}
    end
  end

  defp handle_discovery_response(result, state) do
    case validate_discovery_response(result) do
      {:ok, capabilities, server_info} ->
        Logger.info("MCPInitializer: MCP server discovered for task #{state.task_id}")

        state = %{
          state
          | mcp_capabilities: capabilities,
            mcp_server_info: server_info,
            discovery_request_id: nil
        }

        request_id = System.unique_integer([:positive])
        request = JsonRpc.request(request_id, "tools/list", MCP.request_params())

        state = %{state | status: :loading_tools, tools_request_id: request_id}

        {state, [{:push_mcp, request}]}

      {:error, message} ->
        fail_initialization(state, message)
    end
  end

  defp validate_discovery_response(
         %{
           "resultType" => "complete",
           "supportedVersions" => supported_versions,
           "ttlMs" => ttl_ms,
           "cacheScope" => cache_scope,
           "capabilities" =>
             %{
               "tools" => tools_capability,
               "extensions" => %{@execution_context_extension => %{"version" => 1}}
             } = capabilities
         } = result
       ) do
    with true <- is_list(supported_versions),
         true <- Enum.all?(supported_versions, &is_binary/1),
         true <- MCP.protocol_version() in supported_versions,
         true <- is_map(tools_capability),
         true <- valid_optional_tool_field?(tools_capability, "listChanged", &is_boolean/1),
         true <- is_integer(ttl_ms) and ttl_ms >= 0,
         true <- cache_scope in ["public", "private"],
         {:ok, server_info} <- server_info(result) do
      {:ok, capabilities, server_info}
    else
      _ -> {:error, "Invalid or incompatible MCP discovery response"}
    end
  end

  defp validate_discovery_response(_result),
    do: {:error, "Invalid or incompatible MCP discovery response"}

  defp server_info(%{
         "_meta" => %{
           "io.modelcontextprotocol/serverInfo" => %{"name" => name, "version" => version} = info
         }
       })
       when is_binary(name) and is_binary(version),
       do: {:ok, info}

  defp server_info(%{"_meta" => meta})
       when is_map(meta) and
              not is_map_key(
                meta,
                "io.modelcontextprotocol/serverInfo"
              ),
       do: {:ok, nil}

  defp server_info(result) when not is_map_key(result, "_meta"), do: {:ok, nil}
  defp server_info(_result), do: {:error, :invalid_server_info}

  defp handle_tools_response(result, state) do
    case validate_tools_response(result) do
      {:ok, raw_tools} ->
        Logger.info("MCPInitializer: Received #{length(raw_tools)} tools from MCP server")
        state = %{state | tools: MCPTools.from_maps(raw_tools), tools_request_id: nil}
        maybe_request_project_context(state)

      {:error, message} ->
        fail_initialization(state, message)
    end
  end

  defp validate_tools_response(
         %{
           "resultType" => "complete",
           "tools" => tools,
           "ttlMs" => ttl_ms,
           "cacheScope" => cache_scope
         } = result
       ) do
    with true <- is_list(tools),
         true <- is_integer(ttl_ms) and ttl_ms >= 0,
         true <- cache_scope in ["public", "private"],
         true <- Enum.all?(tools, &valid_tool?/1),
         {:ok, _server_info} <- server_info(result) do
      {:ok, tools}
    else
      _ -> {:error, "Invalid MCP tools/list response"}
    end
  end

  defp validate_tools_response(_result), do: {:error, "Invalid MCP tools/list response"}

  defp valid_tool?(%{"name" => name, "inputSchema" => input_schema} = tool) do
    [
      is_binary(name),
      name != "",
      is_map(input_schema),
      input_schema["type"] == "object",
      valid_optional_tool_field?(tool, "description", &is_binary/1),
      valid_optional_tool_field?(tool, "outputSchema", &is_map/1),
      valid_optional_tool_field?(tool, "visibleToAgent", &is_boolean/1),
      valid_optional_tool_field?(tool, "executionMode", &is_binary/1),
      valid_optional_tool_field?(tool, "access", &(&1 in ["read", "write", "read-write"]))
    ]
    |> Enum.all?()
  end

  defp valid_tool?(_tool), do: false

  defp valid_optional_tool_field?(tool, field, predicate) do
    case Map.fetch(tool, field) do
      {:ok, value} -> predicate.(value)
      :error -> true
    end
  end

  defp fail_initialization(state, message) do
    state = state |> clear_request_ids() |> Map.put(:status, :failed)
    {state, [{:initialization_failed, message}]}
  end

  defp maybe_request_project_context(%{load_project_context: true} = state),
    do: request_project_rules(state)

  defp maybe_request_project_context(%{load_project_context: false} = state),
    do: complete_initialization(state)

  defp request_project_rules(state) do
    request_id = System.unique_integer([:positive])
    call_id = "project_rules_init_#{request_id}"

    request =
      MCP.build_tool_execution(%MCP.ToolCallParams{
        request_id: request_id,
        tool_name: "load_agent_instructions",
        arguments: %{"startPath" => "."},
        task_id: state.task_id,
        call_id: call_id
      })

    state = %{state | status: :loading_project_rules, project_rules_request_id: request_id}

    Logger.info("MCPInitializer: Sending MCP request to load agent instructions")

    {state, [{:push_mcp, request}]}
  end

  defp handle_project_rules_response(result, state) do
    if MCP.error?(result) do
      report_tool_error(state, "project_rules", "load_agent_instructions", result)
    else
      parse_project_rules(result, state)
    end

    state = %{state | project_rules_request_id: nil}
    request_project_structure(state)
  end

  defp parse_project_rules(result, state) do
    with text when text != "" <- MCP.extract_content_text(result) |> String.trim(),
         {:ok, rules} when is_list(rules) <- Jason.decode(text) do
      Enum.each(rules, fn %{"fullPath" => path, "content" => content} ->
        Tasks.add_discovered_project_rule(state.scope, state.task_id, path, content)
      end)

      Logger.info("MCPInitializer: Initialized #{length(rules)} project rules")
    else
      "" ->
        Logger.info("MCPInitializer: Initialized 0 project rules")

      {:ok, _other} ->
        Logger.info("MCPInitializer: Unexpected project rules format (expected a list)")

      {:error, _reason} ->
        Logger.warning("MCPInitializer: Failed to parse project rules")
    end
  end

  defp request_project_structure(state) do
    request_id = System.unique_integer([:positive])
    call_id = "project_structure_init_#{request_id}"

    request =
      MCP.build_tool_execution(%MCP.ToolCallParams{
        request_id: request_id,
        tool_name: "list_tree",
        arguments: %{},
        task_id: state.task_id,
        call_id: call_id
      })

    state = %{
      state
      | status: :loading_project_structure,
        project_structure_request_id: request_id
    }

    Logger.info("MCPInitializer: Sending MCP request to discover project structure")

    {state, [{:push_mcp, request}]}
  end

  defp handle_project_structure_response(result, state) do
    if MCP.error?(result) do
      report_tool_error(state, "project_structure", "list_tree", result)
    else
      parse_project_structure(result, state)
    end

    complete_initialization(state)
  end

  defp parse_project_structure(result, state) do
    with text when text != "" <- MCP.extract_content_text(result) |> String.trim(),
         {:ok, %{"tree" => tree} = decoded} when is_binary(tree) <- Jason.decode(text) do
      monorepo_type = Map.get(decoded, "monorepoType")
      workspaces = Map.get(decoded, "workspaces", [])

      type_line =
        case monorepo_type do
          type when is_binary(type) -> "Project type: monorepo (#{type})"
          _ -> "Project type: single project"
        end

      workspace_section = format_workspace_section(workspaces)

      summary = type_line <> workspace_section <> "\n\nDirectory layout:\n" <> tree
      {:ok, _} = Tasks.add_discovered_project_structure(state.scope, state.task_id, summary)
      Logger.info("MCPInitializer: Discovered project structure")
    else
      "" ->
        Logger.info("MCPInitializer: No project structure discovered")

      {:ok, _other} ->
        Logger.warning("MCPInitializer: Unexpected project structure format")

      {:error, _reason} ->
        Logger.warning("MCPInitializer: Failed to parse project structure")
    end
  end

  defp format_workspace_section([]), do: ""

  defp format_workspace_section(ws) when is_list(ws) do
    ws_lines =
      Enum.map(ws, fn w ->
        "  #{Map.get(w, "name", "unknown")} → #{Map.get(w, "path", "")}"
      end)

    "\n\nWorkspaces:\n" <> Enum.join(ws_lines, "\n")
  end

  defp format_workspace_section(_other), do: ""

  defp complete_initialization(state) do
    state = state |> clear_request_ids() |> Map.put(:status, :ready)

    tools = if is_list(state.tools), do: state.tools, else: []

    initialization_data = %{
      mcp_capabilities: state.mcp_capabilities,
      mcp_server_info: state.mcp_server_info,
      tools: tools
    }

    notification =
      JsonRpc.notification("mcp_initialization_complete", %{
        "count" => length(initialization_data.tools),
        "taskId" => state.task_id
      })

    {state, [{:push_acp, notification}, {:initialization_complete, initialization_data}]}
  end

  defp clear_request_ids(state) do
    %{
      state
      | discovery_request_id: nil,
        tools_request_id: nil,
        project_rules_request_id: nil,
        project_structure_request_id: nil
    }
  end

  defp report_tool_error(_state, init_step, tool_name, _result) do
    Logger.warning("MCPInitializer: Tool error loading #{init_step} with #{tool_name}")
  end

  defp error_code(%{"code" => code}) when is_integer(code), do: code
  defp error_code(_error), do: :unknown
end
