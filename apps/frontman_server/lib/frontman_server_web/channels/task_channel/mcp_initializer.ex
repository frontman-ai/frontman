defmodule FrontmanServerWeb.TaskChannel.MCPInitializer do
  @moduledoc """
  GenServer that manages the MCP initialization flow as a state machine.

  Handles the sequential initialization process:
  1. Initialize MCP connection
  2. Load tools list
  3. Load project rules
  4. Notify channel when complete

  This removes the complex async coordination from the channel itself.
  """
  use GenServer
  require Logger

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tools.MCP, as: MCPTools
  alias JsonRpc
  alias ModelContextProtocol, as: MCP

  @type status ::
          :pending
          | :initializing_mcp
          | :loading_tools
          | :loading_project_rules
          | :ready
          | :failed

  @type state :: %{
          status: status(),
          channel_pid: pid(),
          task_id: String.t(),
          scope: Scope.t(),
          mcp_init_request_id: integer() | nil,
          tools_request_id: integer() | nil,
          project_rules_request_id: integer() | nil,
          mcp_capabilities: map() | nil,
          mcp_server_info: map() | nil,
          tools: list() | nil,
          error: any() | nil
        }

  # Client API

  @spec start_link(pid(), String.t(), Scope.t()) :: GenServer.on_start()
  def start_link(channel_pid, task_id, scope) do
    GenServer.start_link(__MODULE__, {channel_pid, task_id, scope})
  end

  @spec handle_mcp_response(pid(), integer(), map()) :: :ok
  def handle_mcp_response(pid, request_id, result) do
    GenServer.cast(pid, {:mcp_response, request_id, result})
  end

  @spec handle_mcp_error(pid(), integer(), map()) :: :ok
  def handle_mcp_error(pid, request_id, error) do
    GenServer.cast(pid, {:mcp_error, request_id, error})
  end

  @doc """
  Returns true if this initializer is expecting a response with the given request_id.
  Used by TaskChannel to route MCP responses to the correct handler.
  """
  @spec expects_response?(pid(), integer()) :: boolean()
  def expects_response?(pid, request_id) do
    GenServer.call(pid, {:expects_response?, request_id})
  end

  # Server Callbacks

  @impl true
  def init({channel_pid, task_id, scope}) do
    state = %{
      status: :pending,
      channel_pid: channel_pid,
      task_id: task_id,
      scope: scope,
      mcp_init_request_id: nil,
      tools_request_id: nil,
      project_rules_request_id: nil,
      mcp_capabilities: nil,
      mcp_server_info: nil,
      tools: nil,
      error: nil
    }

    # Start initialization flow
    send(self(), :start_initialization)

    {:ok, state}
  end

  @impl true
  def handle_call({:expects_response?, request_id}, _from, state) do
    owns_id =
      request_id == state.mcp_init_request_id or
        request_id == state.tools_request_id or
        request_id == state.project_rules_request_id

    {:reply, owns_id, state}
  end

  @impl true
  def handle_info(:start_initialization, state) do
    request_id = System.unique_integer([:positive])
    request = JsonRpc.request(request_id, "initialize", MCP.initialize_params())

    # Send request to channel, which will push to client
    send(state.channel_pid, {:mcp_initializer_request, request})

    state = %{state | status: :initializing_mcp, mcp_init_request_id: request_id}

    Logger.info("MCPInitializer: Starting MCP initialization for task #{state.task_id}")

    {:noreply, state}
  end

  @impl true
  def handle_cast({:mcp_response, request_id, result}, state) do
    cond do
      request_id == state.mcp_init_request_id ->
        handle_init_response(result, state)

      request_id == state.tools_request_id ->
        handle_tools_response(result, state)

      request_id == state.project_rules_request_id ->
        handle_project_rules_response(result, state)

      true ->
        Logger.warning("MCPInitializer: Received response for unknown request_id #{request_id}")

        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:mcp_error, request_id, error}, state) do
    cond do
      request_id == state.mcp_init_request_id ->
        Logger.error("MCPInitializer: MCP initialization failed: #{inspect(error)}")
        state = %{state | status: :failed, error: error["message"]}
        notify_channel({:initialization_failed, error["message"]}, state)
        {:noreply, state}

      request_id == state.tools_request_id ->
        Logger.warning("MCPInitializer: Tools list failed: #{inspect(error)}")
        # Continue with empty tools list
        request_project_rules([], state)

      request_id == state.project_rules_request_id ->
        Logger.warning("MCPInitializer: Project rules failed: #{inspect(error)}")
        # Complete initialization without project rules
        complete_initialization(state)

      true ->
        {:noreply, state}
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

    # Send initialized notification to channel
    notification = JsonRpc.notification("notifications/initialized", %{})
    send(state.channel_pid, {:mcp_initializer_notification, notification})

    # Request tools list
    request_id = System.unique_integer([:positive])
    request = JsonRpc.request(request_id, "tools/list", %{})

    send(state.channel_pid, {:mcp_initializer_request, request})

    state = %{state | status: :loading_tools, tools_request_id: request_id}

    {:noreply, state}
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

    send(state.channel_pid, {:mcp_initializer_request, request})

    state = %{state | status: :loading_project_rules, project_rules_request_id: request_id}

    Logger.info("MCPInitializer: Sending MCP request to load agent instructions")

    {:noreply, state}
  end

  defp handle_project_rules_response(result, state) do
    content = Map.get(result, "content", [])

    text_result =
      Enum.map_join(content, "\n", fn block -> Map.get(block, "text", "") end)

    case Jason.decode(text_result) do
      {:ok, results} when is_list(results) ->
        # Create DiscoveredProjectRule interactions
        Enum.each(results, fn file ->
          file_content = Map.get(file, "content", "")
          path = Map.get(file, "fullPath", "")
          Tasks.add_discovered_project_rule(state.scope, state.task_id, path, file_content)
        end)

        Logger.info("MCPInitializer: Initialized #{length(results)} project rules")

        complete_initialization(state)

      {:error, reason} ->
        Logger.warning("MCPInitializer: Failed to parse project rules: #{inspect(reason)}")
        complete_initialization(state)
    end
  end

  defp complete_initialization(state) do
    state = %{state | status: :ready, project_rules_request_id: nil}

    initialization_data = %{
      mcp_capabilities: state.mcp_capabilities,
      mcp_server_info: state.mcp_server_info,
      tools: state.tools || []
    }

    notify_channel({:initialization_complete, initialization_data}, state)

    {:noreply, state}
  end

  defp notify_channel(message, state) do
    send(state.channel_pid, {:mcp_initializer, message})
  end
end
