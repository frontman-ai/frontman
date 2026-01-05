defmodule FrontmanServer.Agents.Executor do
  @moduledoc """
  Runs any Swarm.Agent with streaming and event callbacks.

  This module provides the execution infrastructure for agents, handling:
  - LLM streaming with token-by-token callbacks
  - Tool execution via ToolExecutor
  - Event emission for integration with the rest of the system
  - Task-supervised execution with proper Registry registration

  The executor works with any struct that implements the Swarm.Agent protocol,
  allowing specialized agents (RootAgent, FigmaBreakdownAgent, etc.) to focus
  on their domain while sharing execution infrastructure.
  """

  require Logger

  alias Swarm.{Loop, Message, ToolResult}
  alias Swarm.LLM.{Chunk, Response}
  alias FrontmanServer.Agents.ToolExecutor
  alias FrontmanServer.Observability.TelemetryEvents

  @doc """
  Runs an agent in a supervised Task with streaming callbacks.

  The agent runs to completion, emitting events via the callback functions.
  Returns `{:ok, task_ref}` where task_ref can be used to monitor the task.

  ## Arguments

  - `agent` - Any struct implementing Swarm.Agent protocol
  - `task_id` - The task ID this agent belongs to
  - `agent_id` - Unique identifier for this agent instance
  - `messages` - List of Swarm.Message structs to send
  - `opts` - Execution options

  ## Options

  - `:on_event` - Callback function for events (required)
  - `:parent_agent_id` - Optional parent agent ID for sub-agents
  - `:spawning_tool_name` - Optional name of tool that spawned this agent

  ## Events Emitted

  - `{:token, agent_id, text}` - Token streamed from LLM
  - `{:response, agent_id, text, metadata}` - Full LLM response
  - `{:tool_call, agent_id, tool_call}` - Tool call from LLM
  - `{:completed, agent_id}` - Agent finished successfully
  - `{:error, agent_id, reason}` - Agent failed
  """
  @spec run(Swarm.Agent.t(), String.t(), String.t(), [Message.t()], keyword()) ::
          {:ok, reference()} | {:error, term()}
  def run(agent, task_id, agent_id, messages, opts) do
    on_event = Keyword.fetch!(opts, :on_event)
    parent_agent_id = Keyword.get(opts, :parent_agent_id)
    spawning_tool_name = Keyword.get(opts, :spawning_tool_name)

    # Register agent in Registry for discovery
    role = if parent_agent_id, do: :sub_agent, else: :root

    Registry.register(FrontmanServer.AgentRegistry, {:agent, agent_id}, %{
      task_id: task_id,
      parent_agent_id: parent_agent_id,
      role: role,
      spawning_tool_name: spawning_tool_name
    })

    TelemetryEvents.agent_start(agent_id, task_id)

    task =
      Task.Supervisor.async_nolink(
        FrontmanServer.TaskSupervisor,
        fn ->
          execute(agent, task_id, agent_id, messages, on_event)
        end
      )

    {:ok, task.ref}
  end

  @doc """
  Runs an agent synchronously (blocking) with streaming callbacks.

  Same as `run/5` but blocks until completion and returns the result directly.
  Useful for sub-agent execution within backend tools.

  ## Returns

  - `{:ok, result}` - Agent completed successfully
  - `{:error, reason}` - Agent failed
  """
  @spec run_sync(Swarm.Agent.t(), String.t(), String.t(), [Message.t()], keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def run_sync(agent, task_id, agent_id, messages, opts) do
    on_event = Keyword.get(opts, :on_event, fn _event -> :ok end)

    # For sync execution, we don't register in Registry (short-lived)
    execute(agent, task_id, agent_id, messages, on_event)
  end

  # --- Internal Execution ---

  defp execute(agent, task_id, agent_id, messages, on_event) do
    # Build tool executor that handles both backend and MCP tools
    tool_executor =
      ToolExecutor.make_executor(task_id, agent_id,
        on_tool_call: fn _agent_id, tool_call ->
          on_event.({:tool_call, agent_id, to_reqllm_tool_call(tool_call)})
        end
      )

    # Wrap on_event with token streaming callback
    streaming_callback = fn chunk ->
      case chunk do
        %Chunk{type: :token, text: text} when is_binary(text) and text != "" ->
          on_event.({:token, agent_id, text})

        _ ->
          :ok
      end
    end

    Logger.info("Executor #{agent_id} starting execution")

    try do
      result = execute_loop(agent, messages, tool_executor, streaming_callback, on_event, agent_id)

      case result do
        {:ok, _result} ->
          on_event.({:completed, agent_id})
          TelemetryEvents.agent_stop(agent_id)

        {:error, reason} ->
          on_event.({:error, agent_id, reason})
          TelemetryEvents.agent_stop(agent_id)
      end

      result
    rescue
      e ->
        Logger.error("Executor #{agent_id} crashed: #{inspect(e)}")
        on_event.({:error, agent_id, inspect(e)})
        TelemetryEvents.agent_stop(agent_id)
        {:error, e}
    after
      Registry.unregister(FrontmanServer.AgentRegistry, {:agent, agent_id})
    end
  end

  defp execute_loop(agent, messages, tool_executor, streaming_callback, on_event, agent_id) do
    config = %Loop.Config{}
    loop = Loop.make(agent, config)

    {loop, effects} = Loop.execute(loop, messages)
    process_effects(loop, effects, tool_executor, streaming_callback, on_event, agent_id)
  end

  defp process_effects(loop, [], _tool_executor, _streaming_callback, _on_event, _agent_id) do
    case loop.status do
      :completed -> {:ok, loop.result}
      :failed -> {:error, loop.error}
      other -> {:error, "Unexpected loop status: #{other}"}
    end
  end

  defp process_effects(
         loop,
         [{:call_llm, llm, messages} | rest],
         tool_executor,
         streaming_callback,
         on_event,
         agent_id
       ) do
    case Swarm.LLM.stream(llm, messages, []) do
      {:ok, stream} ->
        # Wrap stream to emit tokens while consuming
        stream_with_callback =
          Stream.each(stream, fn chunk ->
            streaming_callback.(chunk)
          end)

        response = Response.from_stream(stream_with_callback)

        # Emit full response event
        metadata = build_response_metadata(response)
        on_event.({:response, agent_id, response.content || "", metadata})

        {loop, new_effects} = Loop.handle_response(loop, response)

        process_effects(
          loop,
          new_effects ++ rest,
          tool_executor,
          streaming_callback,
          on_event,
          agent_id
        )

      {:error, reason} ->
        {loop, new_effects} = Loop.handle_error(loop, reason)

        process_effects(
          loop,
          new_effects ++ rest,
          tool_executor,
          streaming_callback,
          on_event,
          agent_id
        )
    end
  end

  defp process_effects(
         loop,
         [{:execute_tool, tc} | rest],
         tool_executor,
         streaming_callback,
         on_event,
         agent_id
       ) do
    # Execute tool (blocking) - ToolExecutor handles backend vs MCP routing
    result =
      case tool_executor.(tc) do
        {:ok, content} ->
          %ToolResult{id: tc.id, content: content, is_error: false}

        {:error, reason} ->
          %ToolResult{id: tc.id, content: to_string(reason), is_error: true}
      end

    {loop, new_effects} = Loop.handle_tool_result(loop, result)

    process_effects(
      loop,
      new_effects ++ rest,
      tool_executor,
      streaming_callback,
      on_event,
      agent_id
    )
  end

  defp process_effects(
         loop,
         [{:complete, _result} | _rest],
         _tool_executor,
         _streaming_callback,
         _on_event,
         _agent_id
       ) do
    {:ok, loop.result}
  end

  defp process_effects(
         loop,
         [{:fail, _error} | _rest],
         _tool_executor,
         _streaming_callback,
         _on_event,
         _agent_id
       ) do
    {:error, loop.error}
  end

  defp process_effects(
         loop,
         [{:emit_event, _event} | rest],
         tool_executor,
         streaming_callback,
         on_event,
         agent_id
       ) do
    process_effects(loop, rest, tool_executor, streaming_callback, on_event, agent_id)
  end

  # --- Helpers ---

  defp build_response_metadata(%Response{} = response) do
    metadata = %{}

    if response.tool_calls && response.tool_calls != [] do
      Map.put(metadata, :tool_calls, Enum.map(response.tool_calls, &to_reqllm_tool_call/1))
    else
      metadata
    end
  end

  defp to_reqllm_tool_call(%Swarm.ToolCall{} = tc) do
    ReqLLM.ToolCall.new(tc.id, tc.name, tc.arguments)
  end
end
