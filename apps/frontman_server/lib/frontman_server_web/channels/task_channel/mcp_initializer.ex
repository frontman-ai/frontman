# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.TaskChannel.MCPInitializer do
  @moduledoc false
  require Logger

  alias FrontmanServer.Frameworks
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tools.MCP, as: MCPTools
  alias JsonRpc
  alias ModelContextProtocol, as: MCP
  alias ModelContextProtocol.Schema, as: MCPSchema

  @execution_context_extension "ai.frontman/execution-context"
  @tool_metadata_extension "ai.frontman/tool-metadata"
  @tools_page_limit 100
  @tools_size_limit 8 * 1024 * 1024
  @workspace_limit 128
  @project_structure_bytes_limit 512 * 1024

  def start(task_id, scope, framework) do
    request_id = System.unique_integer([:positive])

    request =
      JsonRpc.request(request_id, "server/discover", MCP.request_params())

    state = %{
      status: :discovering_mcp,
      task_id: task_id,
      scope: scope,
      discovery_request_id: request_id,
      tools_request_id: nil,
      project_rules_request_id: nil,
      project_structure_request_id: nil,
      seen_tool_cursors: MapSet.new(),
      seen_tool_names: MapSet.new(),
      tools_size: 0,
      load_project_context: Frameworks.load_project_context?(framework),
      tools: []
    }

    Logger.info("MCPInitializer: Discovering MCP server for task #{task_id}")

    {state, [{:push_mcp, request}]}
  end

  def handle_timeout(%{status: :discovering_mcp, discovery_request_id: request_id} = state)
      when is_integer(request_id),
      do: fail_initialization(state, "MCP discovery timed out")

  def handle_timeout(%{status: :loading_tools, tools_request_id: request_id} = state)
      when is_integer(request_id),
      do: fail_initialization(state, "MCP tools/list timed out")

  def handle_timeout(
        %{status: :loading_project_rules, project_rules_request_id: request_id} = state
      )
      when is_integer(request_id),
      do: fail_initialization(state, "MCP project rules timed out")

  def handle_timeout(
        %{status: :loading_project_structure, project_structure_request_id: request_id} = state
      )
      when is_integer(request_id),
      do: fail_initialization(state, "MCP project structure timed out")

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

  def handle_error(state, request_id, error) do
    case state do
      %{status: :discovering_mcp, discovery_request_id: ^request_id} ->
        Logger.error("MCPInitializer: MCP discovery failed", error_code: error_code(error))
        fail_initialization(state, error["message"])

      %{status: :loading_tools, tools_request_id: ^request_id} ->
        Logger.error("MCPInitializer: Tools list failed", error_code: error_code(error))
        fail_initialization(state, error["message"])

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
      :ok ->
        Logger.info("MCPInitializer: MCP server discovered for task #{state.task_id}")

        state = %{state | discovery_request_id: nil}

        request_id = System.unique_integer([:positive])

        request =
          JsonRpc.request(
            request_id,
            "tools/list",
            MCP.tools_list_params()
          )

        state = %{state | status: :loading_tools, tools_request_id: request_id}

        {state, [{:push_mcp, request}]}

      {:error, message} ->
        fail_initialization(state, message)
    end
  end

  defp validate_discovery_response(result) do
    with :ok <- MCPSchema.validate_discover_result(result),
         %{
           "supportedVersions" => supported_versions,
           "capabilities" => %{
             "tools" => _tools_capability,
             "extensions" => %{
               @execution_context_extension => %{"version" => 1},
               @tool_metadata_extension => %{"version" => 1}
             }
           }
         } <- result,
         true <- MCP.protocol_version() in supported_versions do
      :ok
    else
      _ -> {:error, "Invalid or incompatible MCP discovery response"}
    end
  end

  defp handle_tools_response(result, state) do
    case validate_tools_response(result, state.seen_tool_names) do
      {:ok, raw_tools, cursor, seen_tool_names} ->
        Logger.info("MCPInitializer: Received #{length(raw_tools)} tools from MCP server")
        tools_size = state.tools_size + :erlang.external_size(raw_tools)

        if tools_size > @tools_size_limit do
          raise "MCP tools/list catalog exceeded #{@tools_size_limit} bytes for task #{state.task_id}"
        end

        state = %{
          state
          | tools: Enum.reverse(MCPTools.from_maps(raw_tools), state.tools),
            seen_tool_names: seen_tool_names,
            tools_size: tools_size,
            tools_request_id: nil
        }

        case cursor do
          nil -> maybe_request_project_context(state)
          cursor -> request_next_tools_page(state, cursor)
        end

      {:error, message} ->
        fail_initialization(state, message)
    end
  end

  defp validate_tools_response(result, seen_tool_names) do
    with :ok <- MCPSchema.validate_tools_list_result(result),
         %{"tools" => tools} <- result,
         {:ok, seen_tool_names} <- track_tool_names(tools, seen_tool_names) do
      {:ok, tools, Map.get(result, "nextCursor"), seen_tool_names}
    else
      {:error, {:duplicate_tool_name, name}} ->
        {:error, "MCP tools/list returned duplicate tool name: #{name}"}

      _ ->
        {:error, "Invalid MCP tools/list response"}
    end
  end

  defp track_tool_names(tools, seen_tool_names) do
    Enum.reduce_while(tools, {:ok, seen_tool_names}, fn %{"name" => name}, {:ok, names} ->
      case MapSet.member?(names, name) do
        true -> {:halt, {:error, {:duplicate_tool_name, name}}}
        false -> {:cont, {:ok, MapSet.put(names, name)}}
      end
    end)
  end

  defp request_next_tools_page(state, cursor) do
    case {MapSet.member?(state.seen_tool_cursors, cursor), MapSet.size(state.seen_tool_cursors)} do
      {true, _page_count} ->
        fail_initialization(state, "MCP tools/list returned a repeated cursor")

      {false, page_count} when page_count >= @tools_page_limit - 1 ->
        raise "MCP tools/list exceeded #{@tools_page_limit} pages for task #{state.task_id}"

      {false, _page_count} ->
        request_id = System.unique_integer([:positive])
        request = JsonRpc.request(request_id, "tools/list", MCP.tools_list_params(cursor))

        state = %{
          state
          | tools_request_id: request_id,
            seen_tool_cursors: MapSet.put(state.seen_tool_cursors, cursor)
        }

        {state, [{:push_mcp, request}]}
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
    process_project_context_result(
      result,
      state,
      "project_rules",
      "load_agent_instructions",
      &parse_project_rules/2
    )

    state = %{state | project_rules_request_id: nil}
    request_project_structure(state)
  end

  defp parse_project_rules(result, state) do
    with text when text != "" <- MCP.extract_content_text(result) |> String.trim(),
         {:ok, rules} when is_list(rules) <- Jason.decode(text) do
      rules =
        Enum.map(rules, fn %{"fullPath" => path, "content" => content} -> {path, content} end)

      {:ok, _rules} = Tasks.add_discovered_project_rules(state.scope, state.task_id, rules)

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
    process_project_context_result(
      result,
      state,
      "project_structure",
      "list_tree",
      &parse_project_structure/2
    )

    complete_initialization(state)
  end

  defp parse_project_structure(result, state) do
    with text when text != "" <- MCP.extract_content_text(result) |> String.trim(),
         {:ok, %{"tree" => tree} = decoded} when is_binary(tree) <- Jason.decode(text) do
      monorepo_type = Map.get(decoded, "monorepoType")
      workspaces = Map.get(decoded, "workspaces", [])
      enforce_limit!(length(workspaces), @workspace_limit, "workspace count", state.task_id)

      type_line =
        case monorepo_type do
          type when is_binary(type) -> "Project type: monorepo (#{type})"
          _ -> "Project type: single project"
        end

      workspace_section = format_workspace_section(workspaces)

      summary = type_line <> workspace_section <> "\n\nDirectory layout:\n" <> tree

      enforce_limit!(
        byte_size(summary),
        @project_structure_bytes_limit,
        "structure bytes",
        state.task_id
      )

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

  defp enforce_limit!(actual, limit, _label, _task_id) when actual <= limit, do: :ok

  defp enforce_limit!(actual, limit, label, task_id) do
    raise "MCP project #{label} #{actual} exceeded limit #{limit} for task #{task_id}"
  end

  defp complete_initialization(state) do
    state =
      state
      |> clear_request_ids()
      |> Map.merge(%{status: :ready, tools: Enum.reverse(state.tools)})

    {state, [{:initialization_complete, %{tools: state.tools}}]}
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

  defp process_project_context_result(result, state, init_step, tool_name, parser) do
    with :ok <- MCPSchema.validate_call_tool_result(result),
         false <- MCP.error?(result) do
      parser.(result, state)
    else
      _error -> report_tool_error(init_step, tool_name)
    end
  end

  defp report_tool_error(init_step, tool_name) do
    Logger.warning("MCPInitializer: Tool error loading #{init_step} with #{tool_name}")
  end

  defp error_code(%{"code" => code}) when is_integer(code), do: code
  defp error_code(_error), do: :unknown
end
