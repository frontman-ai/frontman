defmodule FrontmanServerWeb.TaskChannel.MCPInitializer do
  @moduledoc """
  Pure functional state machine for MCP initialization.

  Manages the sequential initialization process:
  1. Initialize MCP connection
  2. Load tools list
  3. Load project rules
  4. Discover project structure
  5. Signal completion

  State is stored in socket assigns by TaskChannel. Functions return
  `{new_state, actions}` tuples where actions are instructions for the
  channel to execute synchronously (push messages, update assigns, etc).

  This design eliminates async process hops — every MCP response is
  processed within the channel's own `handle_in` callback, making the
  initialization flow deterministic and race-free.
  """
  require Logger

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tools.MCP, as: MCPTools
  alias JsonRpc
  alias ModelContextProtocol, as: MCP

  @type status ::
          :initializing_mcp
          | :loading_tools
          | :loading_project_rules
          | :loading_project_structure
          | :ready
          | :failed

  @type t :: %{
          status: status(),
          task_id: String.t(),
          scope: Scope.t(),
          mcp_init_request_id: integer() | nil,
          tools_request_id: integer() | nil,
          project_rules_request_id: integer() | nil,
          project_structure_request_id: integer() | nil,
          mcp_capabilities: map() | nil,
          mcp_server_info: map() | nil,
          tools: list() | nil
        }

  @type action ::
          {:push_mcp, map()}
          | {:push_acp, map()}
          | {:initialization_complete, map()}
          | {:initialization_failed, any()}

  # Public API

  @doc """
  Creates the initial state and returns the MCP initialize request to send.
  """
  @spec start(String.t(), Scope.t()) :: {t(), [action()]}
  def start(task_id, scope) do
    request_id = System.unique_integer([:positive])
    request = JsonRpc.request(request_id, "initialize", MCP.initialize_params())

    state = %{
      status: :initializing_mcp,
      task_id: task_id,
      scope: scope,
      mcp_init_request_id: request_id,
      tools_request_id: nil,
      project_rules_request_id: nil,
      project_structure_request_id: nil,
      mcp_capabilities: nil,
      mcp_server_info: nil,
      tools: nil
    }

    Logger.info("MCPInitializer: Starting MCP initialization for task #{task_id}")

    {state, [{:push_mcp, request}]}
  end

  @doc """
  Returns true if this initializer state is expecting a response with the given request_id.
  Used by TaskChannel to route MCP responses to the correct handler.
  """
  @spec expects_response?(t(), integer()) :: boolean()
  def expects_response?(state, request_id) do
    request_id == state.mcp_init_request_id or
      request_id == state.tools_request_id or
      request_id == state.project_rules_request_id or
      request_id == state.project_structure_request_id
  end

  @doc """
  Handle a successful MCP response. Returns updated state and actions.
  """
  @spec handle_response(t(), integer(), map()) :: {t(), [action()]}
  def handle_response(state, request_id, result) do
    cond do
      request_id == state.mcp_init_request_id ->
        handle_init_response(result, state)

      request_id == state.tools_request_id ->
        handle_tools_response(result, state)

      request_id == state.project_rules_request_id ->
        handle_project_rules_response(result, state)

      request_id == state.project_structure_request_id ->
        handle_project_structure_response(result, state)

      true ->
        Logger.warning("MCPInitializer: Received response for unknown request_id #{request_id}")
        {state, []}
    end
  end

  @doc """
  Handle an MCP error response. Returns updated state and actions.
  """
  @spec handle_error(t(), integer(), map()) :: {t(), [action()]}
  def handle_error(state, request_id, error) do
    cond do
      request_id == state.mcp_init_request_id ->
        Logger.error("MCPInitializer: MCP initialization failed: #{inspect(error)}")
        state = %{state | status: :failed}
        {state, [{:initialization_failed, error["message"]}]}

      request_id == state.tools_request_id ->
        Logger.warning("MCPInitializer: Tools list failed: #{inspect(error)}")
        # Continue with empty tools list
        request_project_rules([], state)

      request_id == state.project_rules_request_id ->
        Logger.warning("MCPInitializer: Project rules failed: #{inspect(error)}")
        # Continue without project rules, try project structure
        request_project_structure(state)

      request_id == state.project_structure_request_id ->
        Logger.warning("MCPInitializer: Project structure failed: #{inspect(error)}")
        # Complete initialization without project structure
        complete_initialization(state)

      true ->
        {state, []}
    end
  end

  # Private Helpers

  defp handle_init_response(result, state) do
    Logger.info("MCPInitializer: MCP initialized for task #{state.task_id}")

    state = %{
      state
      | mcp_capabilities: result["capabilities"],
        mcp_server_info: result["serverInfo"],
        mcp_init_request_id: nil
    }

    # Send initialized notification
    notification = JsonRpc.notification("notifications/initialized", %{})

    # Request tools list
    request_id = System.unique_integer([:positive])
    request = JsonRpc.request(request_id, "tools/list", %{})

    state = %{state | status: :loading_tools, tools_request_id: request_id}

    {state, [{:push_mcp, notification}, {:push_mcp, request}]}
  end

  defp handle_tools_response(result, state) do
    raw_tools = Map.get(result, "tools", [])
    tools = MCPTools.from_maps(raw_tools)

    Logger.info("MCPInitializer: Received #{length(tools)} tools from MCP server")

    state = %{state | tools: tools, tools_request_id: nil}

    request_project_rules(tools, state)
  end

  defp request_project_rules(_tools, state) do
    request_id = System.unique_integer([:positive])
    call_id = "project_rules_init_#{request_id}"

    request =
      JsonRpc.request(request_id, "tools/call", %{
        "callId" => call_id,
        "name" => "load_agent_instructions",
        "arguments" => %{"startPath" => "."}
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
        Logger.warning("MCPInitializer: Unexpected project rules format (expected a list)")

      {:error, reason} ->
        Logger.warning("MCPInitializer: Failed to parse project rules: #{inspect(reason)}")
    end
  end

  # Step 4: Discover project structure via list_tree

  defp request_project_structure(state) do
    request_id = System.unique_integer([:positive])
    call_id = "project_structure_init_#{request_id}"

    request =
      JsonRpc.request(request_id, "tools/call", %{
        "callId" => call_id,
        "name" => "list_tree",
        "arguments" => %{}
      })

    state = %{
      state
      | status: :loading_project_structure,
        project_rules_request_id: nil,
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
      Tasks.add_discovered_project_structure(state.scope, state.task_id, summary)
      Logger.info("MCPInitializer: Discovered project structure")
    else
      "" ->
        Logger.info("MCPInitializer: No project structure discovered")

      {:ok, _other} ->
        Logger.warning("MCPInitializer: Unexpected project structure format")

      {:error, reason} ->
        Logger.warning("MCPInitializer: Failed to parse project structure: #{inspect(reason)}")
    end
  end

  defp format_workspace_section(ws) when is_list(ws) and ws != [] do
    ws_lines =
      Enum.map(ws, fn w ->
        "  #{Map.get(w, "name", "unknown")} → #{Map.get(w, "path", "")}"
      end)

    "\n\nWorkspaces:\n" <> Enum.join(ws_lines, "\n")
  end

  defp format_workspace_section(_), do: ""

  defp complete_initialization(state) do
    state = %{
      state
      | status: :ready,
        project_rules_request_id: nil,
        project_structure_request_id: nil
    }

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

  defp report_tool_error(state, init_step, tool_name, result) do
    text = MCP.extract_content_text(result)
    Logger.warning("MCPInitializer: Tool error loading #{init_step}: #{text}")

    Sentry.capture_message("MCP tool error during initialization",
      level: :warning,
      tags: %{error_type: "mcp_tool_error", init_step: init_step},
      extra: %{task_id: state.task_id, tool_name: tool_name, error_text: text}
    )
  end
end
