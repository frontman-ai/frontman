defmodule FrontmanServer.Agents.AgentServer do
  @moduledoc """
  GenServer managing agent process lifecycle.

  Uses a push model where all data is pushed to the agent:
  - Messages arrive via {:execute_iteration, messages}
  - Tool results arrive via {:tool_result, ...}
  - Wake signals arrive via :wake_agent

  The agent emits events via the on_event callback and has no knowledge
  of Tasks, PubSub, or any other bounded context.

  Domain state is held in the Agent struct; this module handles
  process lifecycle, timeouts, and message routing.
  """
  use GenServer
  require Logger

  @default_model "openrouter:anthropic/claude-haiku-4.5"
  @idle_timeout_ms 5 * 60 * 1000

  alias FrontmanServer.Agents.{Agent, StreamParser}
  alias FrontmanServer.Observability.TelemetryEvents
  alias ReqLLM.ToolCall

  # Infrastructure state - domain state lives in `agent`
  defstruct [
    :agent,
    :tools,
    :on_event,
    :idle_timer_ref,
    status: :processing,
    llm_opts: []
  ]

  # Client API

  @doc """
  Starts a root agent for a task.
  """
  def start_link(opts) do
    agent_id = Keyword.fetch!(opts, :agent_id)
    task_id = Keyword.fetch!(opts, :task_id)
    tools = Keyword.get(opts, :tools, [])
    on_event = Keyword.fetch!(opts, :on_event)

    GenServer.start_link(
      __MODULE__,
      {:root, %{agent_id: agent_id, task_id: task_id, tools: tools, on_event: on_event}},
      name:
        {:via, Registry,
         {FrontmanServer.AgentRegistry, {:agent, agent_id},
          %{
            task_id: task_id,
            parent_agent_id: nil,
            role: :root
          }}}
    )
  end

  @doc """
  Triggers a specific agent to execute an iteration with the given messages.
  """
  @spec execute_iteration(String.t(), list()) :: :ok | {:error, :not_found}
  def execute_iteration(agent_id, messages) do
    case Registry.lookup(FrontmanServer.AgentRegistry, {:agent, agent_id}) do
      [{pid, _metadata}] ->
        send(pid, {:execute_iteration, messages})
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Notifies the agent that a tool result has arrived.
  """
  @spec notify_tool_result(String.t(), String.t(), term(), boolean()) ::
          :ok | {:error, :not_found}
  def notify_tool_result(task_id, tool_call_id, result, is_error) do
    with_root_agent_by_task(task_id, fn pid ->
      send(pid, {:tool_result, tool_call_id, result, is_error})
      :ok
    end)
  end

  @doc """
  Wakes an idle agent to check for new work.
  """
  @spec wake(String.t()) :: :ok | {:error, :not_found}
  def wake(task_id) do
    with_root_agent_by_task(task_id, fn pid ->
      send(pid, :wake_agent)
      :ok
    end)
  end

  # Server Callbacks

  @impl true
  def init(
        {:root, %{agent_id: agent_id, task_id: task_id, tools: tools, on_event: on_event} = opts}
      ) do
    agent = Agent.new_root(agent_id, task_id)

    # Emit telemetry event for root agent start
    TelemetryEvents.agent_start(agent_id, task_id)

    state = %__MODULE__{
      agent: agent,
      tools: tools,
      on_event: on_event,
      idle_timer_ref: nil,
      llm_opts: Map.get(opts, :llm_opts, [])
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state.status, state}
  end

  @impl true
  def handle_info({:execute_iteration, messages}, state) do
    agent = Agent.increment_iteration(state.agent)
    state = %{state | agent: agent, status: :processing}
    iteration_number = agent.iteration_count

    Logger.info(
      "Agent #{agent.id} starting iteration #{iteration_number} with #{length(messages)} messages"
    )

    TelemetryEvents.iteration_start(agent.id, iteration_number)

    result = stream_and_handle_response(state, messages)

    case result do
      {:wait_for_tools, state} ->
        state = %{state | status: :waiting_for_tools}
        state = schedule_idle_timeout(state)
        {:noreply, state}

      {:stop, state} ->
        TelemetryEvents.iteration_stop(agent.id, iteration_number)
        emit(state, {:completed, state.agent.id})
        state = %{state | status: :idle}
        state = schedule_idle_timeout(state)
        {:noreply, state}

      {:error, reason, state} ->
        TelemetryEvents.iteration_stop(agent.id, iteration_number, status: :error, error: reason)
        emit(state, {:error, state.agent.id, reason})
        {:stop, :normal, state}
    end
  end

  @impl true
  def handle_info({:tool_result, tool_call_id, _result, _is_error}, state) do
    {tool_call, agent} = Agent.complete_tool(state.agent, tool_call_id)

    case tool_call do
      nil ->
        Logger.error("Received tool result for unknown tool_call_id: #{tool_call_id}")
        {:noreply, state}

      tool_call ->
        Logger.info("Tool #{ToolCall.name(tool_call)} completed")
        Registry.unregister(FrontmanServer.AgentRegistry, {:tool_call, tool_call_id})
        state = %{state | agent: agent}

        if not Agent.has_pending_work?(agent) do
          state = cancel_idle_timeout(state)
          emit(state, {:need_iteration, agent.id})
          {:noreply, state}
        else
          state = schedule_idle_timeout(state)
          {:noreply, state}
        end
    end
  end

  @impl true
  def handle_info(:wake_agent, %{status: :idle} = state) do
    state = cancel_idle_timeout(state)
    state = %{state | status: :processing}
    emit(state, {:need_iteration, state.agent.id})
    {:noreply, state}
  end

  def handle_info(:wake_agent, state) do
    # Already processing or waiting_for_tools - ignore wake
    {:noreply, state}
  end

  @impl true
  def handle_info(:idle_timeout, state) do
    Logger.info("Agent #{state.agent.id} idle timeout - terminating")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({ref, _result}, state) when is_reference(ref) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    TelemetryEvents.agent_stop(state.agent.id)
    :ok
  end

  # Private Functions

  # -- Event Emission --

  defp emit(state, event) do
    Logger.debug("Agent #{state.agent.id} emitting: #{elem(event, 0)}")
    state.on_event.(event)
  end

  # -- LLM Streaming & Response Handling --

  defp stream_and_handle_response(state, messages) do
    api_key = get_api_key(@default_model)

    # Build options: state.llm_opts (for test fixtures) + api_key + tools
    llm_opts =
      state.llm_opts
      |> Keyword.put(:api_key, api_key)
      |> then(fn opts ->
        case state.tools do
          [] -> opts
          tools -> Keyword.put(opts, :tools, tools)
        end
      end)

    TelemetryEvents.llm_start(
      state.agent.id,
      state.agent.task_id,
      @default_model,
      messages
    )

    case ReqLLM.stream_text(@default_model, messages, llm_opts) do
      {:ok, response} ->
        chunks = stream_chunks(state, response.stream)
        text = Enum.map_join(chunks, "", fn chunk -> chunk.text || "" end)
        tool_calls = StreamParser.extract_tool_calls(chunks)

        response_id =
          Enum.find_value(chunks, fn
            %{type: :meta, metadata: %{response_id: id}} when is_binary(id) -> id
            _ -> nil
          end)

        TelemetryEvents.llm_stop(state.agent.id,
          response_id: response_id,
          output_text: text,
          tool_calls: tool_calls
        )

        Logger.info(
          "Agent #{state.agent.id} extracted: text=#{byte_size(text)} bytes, tool_calls=#{length(tool_calls)}, response_id=#{inspect(response_id)}, chunks=#{length(chunks)}"
        )

        handle_response(state, text, tool_calls, response_id)

      {:error, reason} ->
        # Emit LLM stop event with error
        TelemetryEvents.llm_stop(state.agent.id, error: reason)
        Logger.error("LLM stream failed: #{inspect(reason)}")
        {:error, reason, state}
    end
  end

  defp stream_chunks(state, chunk_stream) do
    chunk_stream
    |> Enum.map(fn chunk ->
      text = Map.get(chunk, :text) || ""

      if text != "" do
        emit(state, {:token, state.agent.id, text})
      end

      chunk
    end)
  end

  defp handle_response(state, text, [], _response_id) do
    Logger.info("Agent #{state.agent.id} completing with text: #{byte_size(text)} bytes")
    emit(state, {:response, state.agent.id, text, %{}})
    {:stop, state}
  end

  defp handle_response(state, text, tool_calls, response_id) do
    Logger.info(
      "Agent #{state.agent.id} has #{length(tool_calls)} tool calls, text: #{byte_size(text)} bytes"
    )

    metadata = %{tool_calls: tool_calls}
    metadata = if response_id, do: Map.put(metadata, :response_id, response_id), else: metadata
    emit(state, {:response, state.agent.id, text, metadata})

    state = track_tool_calls(state, tool_calls)

    if Agent.has_pending_work?(state.agent) do
      {:wait_for_tools, state}
    else
      {:stop, state}
    end
  end

  # -- Tool Call Tracking --

  defp track_tool_calls(state, tool_calls) do
    agent =
      Enum.reduce(tool_calls, state.agent, fn tc, agent ->
        emit(state, {:tool_call, agent.id, tc})
        Registry.register(FrontmanServer.AgentRegistry, {:tool_call, tc.id}, agent.id)
        Agent.track_tool(agent, tc)
      end)

    %{state | agent: agent}
  end

  # -- Configuration & Utilities --

  defp get_api_key(model) do
    cond do
      String.starts_with?(model, "openai:") ->
        Application.get_env(:frontman_server, :openai_api_key)

      String.starts_with?(model, "anthropic:") ->
        Application.get_env(:frontman_server, :anthropic_api_key)

      String.starts_with?(model, "google:") ->
        Application.get_env(:frontman_server, :google_api_key)

      String.starts_with?(model, "xai:") ->
        Application.get_env(:frontman_server, :xai_api_key)

      String.starts_with?(model, "openrouter:") ->
        Application.get_env(:frontman_server, :openrouter_api_key)

      true ->
        Application.get_env(:frontman_server, :anthropic_api_key)
    end
  end

  # -- Registry Helpers --

  defp with_root_agent_by_task(task_id, fun) do
    match_spec = [
      {{{:agent, :"$1"}, :"$2", :"$3"},
       [
         {:andalso, {:==, {:map_get, :task_id, :"$3"}, task_id},
          {:==, {:map_get, :parent_agent_id, :"$3"}, nil}}
       ], [{{:"$1", :"$2"}}]}
    ]

    case Registry.select(FrontmanServer.AgentRegistry, match_spec) do
      [{_agent_id, pid}] -> fun.(pid)
      [] -> {:error, :not_found}
    end
  end

  # -- Timer Management --

  defp schedule_idle_timeout(state) do
    state = cancel_idle_timeout(state)
    ref = Process.send_after(self(), :idle_timeout, @idle_timeout_ms)
    %{state | idle_timer_ref: ref}
  end

  defp cancel_idle_timeout(%{idle_timer_ref: nil} = state), do: state

  defp cancel_idle_timeout(%{idle_timer_ref: ref} = state) do
    Process.cancel_timer(ref)
    %{state | idle_timer_ref: nil}
  end
end
