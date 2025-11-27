defmodule FrontmanServer.Agents.AgentServer do
  @moduledoc """
  Agent server that executes an agentic loop with LLM.

  Uses a push model where all data is pushed to the agent:
  - Messages arrive via {:execute_iteration, messages}
  - Tool results arrive via {:tool_result, ...}
  - Wake signals arrive via :wake_agent

  The agent emits events via the on_event callback and has no knowledge
  of Tasks, PubSub, or any other bounded context.
  """
  use GenServer
  require Logger

  @default_model "anthropic:claude-sonnet-4-20250514"
  @idle_timeout_ms 5 * 60 * 1000

  defstruct [
    :agent_id,
    :task_id,
    :tools,
    :on_event,
    :pending_tool_calls,
    :idle_timer_ref,
    :fixture_path
  ]

  # Client API

  def start_link(opts) do
    agent_id = Keyword.fetch!(opts, :agent_id)
    task_id = Keyword.fetch!(opts, :task_id)
    tools = Keyword.get(opts, :tools, [])
    on_event = Keyword.fetch!(opts, :on_event)

    GenServer.start_link(
      __MODULE__,
      %{
        agent_id: agent_id,
        task_id: task_id,
        tools: tools,
        on_event: on_event
      },
      name: {:via, Registry, {FrontmanServer.AgentRegistry, task_id, :processing}}
    )
  end

  # Server Callbacks

  @impl true
  def init(%{agent_id: agent_id, task_id: task_id, tools: tools, on_event: on_event}) do
    state = %__MODULE__{
      agent_id: agent_id,
      task_id: task_id,
      tools: tools,
      on_event: on_event,
      fixture_path: nil,
      idle_timer_ref: nil,
      pending_tool_calls: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_info({:execute_iteration, messages}, state) do
    Logger.info("Agent #{state.agent_id} starting iteration with #{length(messages)} messages")

    case stream_and_handle_response(state, messages) do
      {:wait_for_tools, state} ->
        {:noreply, state}

      {:stop, state} ->
        emit(state, {:completed, state.agent_id})
        set_registry_state(state.task_id, :idle)
        state = schedule_idle_timeout(state)
        {:noreply, state}

      {:error, reason, state} ->
        emit(state, {:error, state.agent_id, reason})
        {:stop, :normal, state}
    end
  end

  @impl true
  def handle_info({:tool_result, tool_call_id, _result, _is_error}, state) do
    case Map.get(state.pending_tool_calls, tool_call_id) do
      nil ->
        {:noreply, state}

      tool_call ->
        Logger.info("Tool #{tool_call.name} completed")
        pending = Map.delete(state.pending_tool_calls, tool_call_id)
        state = %{state | pending_tool_calls: pending}

        if Enum.empty?(pending) do
          emit(state, {:need_iteration, state.agent_id})
        end

        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:wake_agent, state) do
    case Registry.lookup(FrontmanServer.AgentRegistry, state.task_id) do
      [{_pid, :idle}] ->
        state = cancel_idle_timeout(state)
        set_registry_state(state.task_id, :processing)
        emit(state, {:need_iteration, state.agent_id})
        {:noreply, state}

      [{_pid, :processing}] ->
        {:noreply, state}

      [] ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:idle_timeout, state) do
    Logger.info("Agent #{state.agent_id} idle timeout - terminating")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({ref, _result}, state) when is_reference(ref) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  # Private Functions

  defp emit(state, event) do
    state.on_event.(event)
  end

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
      text = Map.get(chunk, :text) || ""

      if text != "" do
        emit(state, {:token, state.agent_id, text})
      end

      chunk
    end)
  end

  defp handle_response(state, text, []) do
    emit(state, {:response, state.agent_id, text, %{}})
    {:stop, state}
  end

  defp handle_response(state, text, tool_calls) do
    emit(state, {:response, state.agent_id, text, %{tool_calls: tool_calls}})

    pending =
      Enum.reduce(tool_calls, state.pending_tool_calls, fn tool_call, acc ->
        emit(state, {:tool_call, state.agent_id, tool_call})
        Map.put(acc, tool_call.id, tool_call)
      end)

    state = %{state | pending_tool_calls: pending}
    {:wait_for_tools, state}
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
