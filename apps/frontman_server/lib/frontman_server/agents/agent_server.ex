defmodule FrontmanServer.Agents.AgentServer do
  @moduledoc """
  Agent server that executes an agentic loop with LLM.

  The agent iteratively:
  1. Fetches fresh interaction history from Task
  2. Calls LLM with messages and tools
  3. Streams response chunks, broadcasting tokens
  4. If tool calls found: executes tools, stores results, continues loop
  5. If no tool calls: stores final response, stops

  Follows the req_llm agent pattern for tool handling.
  """
  use GenServer
  require Logger

  alias FrontmanServer.Tasks

  @default_model "anthropic:claude-sonnet-4-20250514"
  @idle_timeout_ms 5 * 60 * 1000

  defstruct [
    :agent_id,
    :task_id,
    :tools,
    :fixture_path,
    :idle_timer_ref
  ]

  # Client API

  def start_link(opts) do
    agent_id = Keyword.fetch!(opts, :agent_id)
    task_id = Keyword.fetch!(opts, :task_id)
    tools = Keyword.get(opts, :tools, [])

    GenServer.start_link(
      __MODULE__,
      %{
        agent_id: agent_id,
        task_id: task_id,
        tools: tools
      },
      name: {:via, Registry, {FrontmanServer.AgentRegistry, task_id, :processing}}
    )
  end

  @doc """
  Executes one iteration of the agentic loop.
  """
  def execute_iteration(agent_pid) do
    send(agent_pid, :execute_iteration)
  end

  # Server Callbacks

  @impl true
  def init(%{agent_id: agent_id, task_id: task_id, tools: tools}) do
    Phoenix.PubSub.subscribe(FrontmanServer.PubSub, "task:#{task_id}")

    state = %__MODULE__{
      agent_id: agent_id,
      task_id: task_id,
      tools: tools,
      fixture_path: nil,
      idle_timer_ref: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_info({ref, _result}, state) when is_reference(ref) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:execute_iteration, state) do
    messages = Tasks.get_llm_messages(state.task_id)

    Logger.info("Agent #{state.agent_id} starting iteration with #{length(messages)} messages")

    case stream_and_handle_response(state, messages) do
      {:continue, state} ->
        # Tool calls were handled, continue to next iteration
        send(self(), :execute_iteration)
        {:noreply, state}

      {:stop, state} ->
        # No tool calls, go idle and wait for more messages
        broadcast_completion(state)
        set_registry_state(state.task_id, :idle)
        state = schedule_idle_timeout(state)
        {:noreply, state}

      {:error, reason, state} ->
        broadcast_error(state, "Agent error: #{inspect(reason)}")
        {:stop, :normal, state}
    end
  end

  @impl true
  def handle_info({:interaction, interaction}, state) do
    if Tasks.user_message?(interaction) do
      case Registry.lookup(FrontmanServer.AgentRegistry, state.task_id) do
        [{_pid, :idle}] ->
          # Idle - start processing
          state = cancel_idle_timeout(state)
          set_registry_state(state.task_id, :processing)
          send(self(), :execute_iteration)
          {:noreply, state}

        [{_pid, :processing}] ->
          # Already processing - will pick up message on next iteration
          {:noreply, state}

        [] ->
          {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:idle_timeout, state) do
    Logger.info("Agent #{state.agent_id} idle timeout - terminating")
    {:stop, :normal, state}
  end

  # Ignore our own broadcasts (stream_token, agent_completed, agent_error)
  @impl true
  def handle_info({:stream_token, _agent_id, _token}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:agent_completed, _agent_id}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:agent_error, _agent_id, _message}, state) do
    {:noreply, state}
  end

  # Private Functions

  defp stream_and_handle_response(state, messages) do
    api_key = get_api_key(@default_model)

    llm_opts = [api_key: api_key]

    llm_opts =
      case state.fixture_path do
        nil -> llm_opts
        fixture_path -> Keyword.put(llm_opts, :fixture_path, fixture_path)
      end

    llm_opts =
      case state.tools do
        [] -> llm_opts
        tools -> Keyword.put(llm_opts, :tools, tools)
      end

    case ReqLLM.stream_text(@default_model, messages, llm_opts) do
      {:ok, response} ->
        chunks = stream_chunks(state, response.stream)
        text = extract_text(chunks)
        tool_calls = extract_tool_calls(chunks)
        handle_response(state, text, tool_calls)

      {:error, reason} ->
        Logger.error("LLM stream failed: #{inspect(reason)}")
        {:error, reason, state}
    end
  end

  defp stream_chunks(state, chunk_stream) do
    chunk_stream
    |> Enum.map(fn chunk ->
      # Broadcast text tokens in real-time
      text = Map.get(chunk, :text) || ""

      if text != "" do
        broadcast_token(state, text)
      end

      chunk
    end)
  end

  defp handle_response(state, text, []) do
    # No tool calls - store final response and stop
    Tasks.add_agent_response(state.task_id, state.agent_id, text)
    Tasks.add_agent_completed(state.task_id, state.agent_id)
    {:stop, state}
  end

  defp handle_response(state, text, tool_calls) do
    # Store agent response with tool_calls metadata
    Tasks.add_agent_response(
      state.task_id,
      state.agent_id,
      text,
      %{tool_calls: tool_calls}
    )

    # Execute each tool and store results
    Enum.each(tool_calls, fn tool_call ->
      # Store the tool call
      Tasks.add_tool_call(state.task_id, state.agent_id, tool_call)

      # Find and execute the tool
      case find_and_execute_tool(state.tools, tool_call) do
        {:ok, result} ->
          Tasks.add_tool_result(state.task_id, state.agent_id, tool_call, result, false)
          Logger.info("Tool #{tool_call.name} executed successfully")

        {:error, reason} ->
          Tasks.add_tool_result(state.task_id, state.agent_id, tool_call, reason, true)
          Logger.warning("Tool #{tool_call.name} failed: #{inspect(reason)}")
      end
    end)

    {:continue, state}
  end

  defp find_and_execute_tool(tools, tool_call) do
    case Enum.find(tools, fn t -> t.name == tool_call.name end) do
      nil ->
        {:error, "Tool not found: #{tool_call.name}"}

      tool ->
        ReqLLM.Tool.execute(tool, tool_call.arguments)
    end
  end

  defp broadcast_token(state, token) do
    Phoenix.PubSub.broadcast(
      FrontmanServer.PubSub,
      "task:#{state.task_id}",
      {:stream_token, state.agent_id, token}
    )
  end

  defp broadcast_completion(state) do
    Phoenix.PubSub.broadcast(
      FrontmanServer.PubSub,
      "task:#{state.task_id}",
      {:agent_completed, state.agent_id}
    )

    Logger.info("Agent #{state.agent_id} completed")
  end

  defp broadcast_error(state, message) do
    Phoenix.PubSub.broadcast(
      FrontmanServer.PubSub,
      "task:#{state.task_id}",
      {:agent_error, state.agent_id, message}
    )

    Logger.error("Agent #{state.agent_id} error: #{message}")
  end

  defp get_api_key(model) do
    cond do
      String.starts_with?(model, "openai:") ->
        Application.get_env(:frontman_server, :openai_api_key)

      String.starts_with?(model, "anthropic:") ->
        Application.get_env(:frontman_server, :anthropic_api_key)

      true ->
        Application.get_env(:frontman_server, :anthropic_api_key)
    end
  end

  defp extract_text(chunks) do
    chunks
    |> Enum.map_join("", fn chunk -> chunk.text || "" end)
  end

  defp extract_tool_calls(chunks) do
    tool_calls =
      chunks
      |> Enum.filter(&(&1.type == :tool_call))
      |> Enum.map(fn chunk ->
        %{
          id: Map.get(chunk.metadata, :id) || "call_#{:erlang.unique_integer([:positive])}",
          name: chunk.name,
          arguments: chunk.arguments || %{},
          index: Map.get(chunk.metadata, :index, 0)
        }
      end)

    arg_fragments =
      chunks
      |> Enum.filter(fn
        %{type: :meta, metadata: %{tool_call_args: _}} -> true
        _ -> false
      end)
      |> Enum.group_by(& &1.metadata.tool_call_args.index)
      |> Map.new(fn {index, fragments} ->
        json = fragments |> Enum.map_join("", & &1.metadata.tool_call_args.fragment)
        {index, json}
      end)

    tool_calls
    |> Enum.map(fn call ->
      case Map.get(arg_fragments, call.index) do
        nil ->
          Map.delete(call, :index)

        json ->
          case Jason.decode(json) do
            {:ok, args} -> call |> Map.put(:arguments, args) |> Map.delete(:index)
            {:error, _} -> Map.delete(call, :index)
          end
      end
    end)
  end

  defp set_registry_state(task_id, new_state) do
    Registry.update_value(FrontmanServer.AgentRegistry, task_id, fn _ -> new_state end)
  end

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
