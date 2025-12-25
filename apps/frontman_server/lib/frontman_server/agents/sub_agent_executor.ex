defmodule FrontmanServer.Agents.SubAgentExecutor do
  @moduledoc """
  Executes a sub-agent synchronously, blocking until completion.

  Used by backend tools that need to spawn an agent and wait for results.
  The sub-agent runs with its own system prompt and tools, and this module
  blocks until the agent completes and returns the result.

  Handles the full agent lifecycle including:
  - Tool calls (routed through Tasks infrastructure to MCP)
  - Multiple iterations (when tools complete)
  - Response accumulation
  - Timeout handling
  """

  require Logger

  alias FrontmanServer.Agents.AgentServer
  alias FrontmanServer.Observability.TelemetryEvents
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.Interaction.UserMessage

  # Default timeout: 5 minutes
  @default_timeout_ms 5 * 60 * 1000

  @doc """
  Executes a sub-agent synchronously.

  Spawns a new agent with the given messages, waits for it to complete,
  and returns the result. Handles tool calls by routing them through
  the Tasks infrastructure.

  ## Arguments
  - `task_id` - The parent task ID
  - `messages` - List of messages including system prompt
  - `opts` - Options:
    - `:tools` - List of tool definitions for the sub-agent (default: [])
    - `:role` - Role name for telemetry (e.g., "figma_breakdown")
    - `:timeout` - Timeout in milliseconds (default: 5 minutes)
    - `:parent_agent_id` - The parent agent that spawned this sub-agent
    - `:llm_opts` - LLM options (e.g., fixture_path for testing) passed to AgentServer

  ## Returns
  - `{:ok, text}` - The agent's response text
  - `{:error, reason}` - If the agent failed
  """
  @spec execute(String.t(), list(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def execute(task_id, messages, opts \\ []) do
    agent_id = Ecto.UUID.generate()
    caller = self()
    tools = Keyword.get(opts, :tools, [])
    role = Keyword.get(opts, :role, "sub_agent")
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)
    parent_agent_id = Keyword.get(opts, :parent_agent_id)
    llm_opts = Keyword.get(opts, :llm_opts, [])

    # Emit telemetry start
    TelemetryEvents.spawn_sub_agent_start(agent_id, task_id, role)

    on_event = build_event_handler(caller, agent_id, task_id)

    # Debug: log tool names being passed
    tool_names = Enum.map(tools, fn t -> t.name end)
    Logger.info("SubAgentExecutor tools for #{role}: #{inspect(tool_names)}")

    case AgentServer.start_link(
           agent_id: agent_id,
           task_id: task_id,
           tools: tools,
           on_event: on_event,
           parent_agent_id: parent_agent_id,
           llm_opts: llm_opts
         ) do
      {:ok, _pid} ->
        Logger.info(
          "SubAgentExecutor started agent #{agent_id} for task #{task_id} with #{length(tools)} tools"
        )

        AgentServer.execute_iteration(agent_id, messages)

        result = await_result_loop(agent_id, task_id, messages, nil, timeout)

        # Emit telemetry stop
        case result do
          {:ok, _} ->
            TelemetryEvents.spawn_sub_agent_stop(agent_id, status: "success")

          {:error, reason} ->
            TelemetryEvents.spawn_sub_agent_stop(agent_id, status: "error", error: reason)
        end

        result

      {:error, reason} ->
        Logger.error("SubAgentExecutor failed to start agent: #{inspect(reason)}")
        TelemetryEvents.spawn_sub_agent_stop(agent_id, status: "error", error: reason)
        {:error, reason}
    end
  end

  defp build_event_handler(caller, agent_id, task_id) do
    fn
      {:response, ^agent_id, text, metadata} ->
        # Store the agent response with metadata (including tool_calls)
        # This is essential for rebuilding conversation history correctly
        Tasks.add_agent_response(task_id, agent_id, text, metadata)
        send(caller, {:sub_agent_response, agent_id, text})

      {:completed, ^agent_id} ->
        Tasks.add_agent_completed(task_id, agent_id)
        send(caller, {:sub_agent_completed, agent_id})

      {:error, ^agent_id, reason} ->
        send(caller, {:sub_agent_error, agent_id, reason})

      {:tool_call, ^agent_id, tool_call} ->
        send(caller, {:sub_agent_tool_call, agent_id, tool_call})

      {:need_iteration, ^agent_id} ->
        send(caller, {:sub_agent_need_iteration, agent_id})

      # Tokens and other events - ignore
      _ ->
        :ok
    end
  end

  defp await_result_loop(agent_id, task_id, messages, accumulated_response, timeout) do
    receive do
      {:sub_agent_response, ^agent_id, text} ->
        # Store response, continue waiting for completed or more events
        Logger.debug(
          "SubAgentExecutor received response from #{agent_id}: #{byte_size(text)} bytes"
        )

        await_result_loop(agent_id, task_id, messages, text, timeout)

      {:sub_agent_completed, ^agent_id} ->
        # Done!
        Logger.info("SubAgentExecutor agent #{agent_id} completed")
        {:ok, accumulated_response || ""}

      {:sub_agent_error, ^agent_id, reason} ->
        Logger.error("SubAgentExecutor agent #{agent_id} error: #{inspect(reason)}")
        {:error, reason}

      {:sub_agent_tool_call, ^agent_id, tool_call} ->
        # Route through Tasks infrastructure (same as parent agent)
        # This will broadcast to task_channel which routes to MCP
        Logger.info(
          "SubAgentExecutor routing tool call #{tool_call.id} (#{ReqLLM.ToolCall.name(tool_call)}) for agent #{agent_id}"
        )

        Tasks.add_tool_call(task_id, agent_id, tool_call)

        # Continue waiting - tool result will come via Agents.notify_tool_result
        # which sends {:tool_result, ...} to the AgentServer, which then emits
        # {:need_iteration, ...} when all tools complete
        await_result_loop(agent_id, task_id, messages, accumulated_response, timeout)

      {:sub_agent_need_iteration, ^agent_id} ->
        # Sub-agent needs next iteration (tools completed)
        Logger.info("SubAgentExecutor pushing iteration for agent #{agent_id}")
        push_sub_agent_iteration(task_id, agent_id, messages)
        await_result_loop(agent_id, task_id, messages, accumulated_response, timeout)
    after
      timeout ->
        Logger.error("SubAgentExecutor timeout for agent #{agent_id} after #{timeout}ms")
        {:error, :timeout}
    end
  end

  defp push_sub_agent_iteration(task_id, agent_id, messages) do
    # Get conversation messages from task (filtered to this agent)
    conversation_messages =
      Tasks.get_interactions(task_id)
      |> Enum.reject(fn interaction -> match?(%UserMessage{}, interaction) end)
      |> Interaction.to_llm_messages(agent_id)

    # Prepend system message and execute
    AgentServer.execute_iteration(agent_id, Enum.concat(messages, conversation_messages))
  end
end
