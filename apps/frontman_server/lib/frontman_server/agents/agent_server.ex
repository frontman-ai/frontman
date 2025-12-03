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

  @default_model "openrouter:openai/gpt-5.1-codex"
  @idle_timeout_ms 5 * 60 * 1000

  @base_system_prompt """
  You are a coding assistant for a Next.js app (TypeScript, React, Tailwind, some ReScript output).

  ## Rules

  - Paths relative to repo root.
  - List → Read → Modify. Never edit unseen files.
  - Keep diffs small and reversible. Match repo style.
  - After 2 failed tool calls, ask one clarifying question.

  ## ReScript handling (explicit)

  - Treat generated files (*.res.mjs) as read-only.
  - Always edit the source *.res.
  - Procedure when you see X.res.mjs:
    1. Locate X.res by name/path. If not found, search siblings or module index.
    2. read_file both X.res and X.res.mjs to understand mapping and exports.
    3. Apply changes to X.res only. Preserve types and module boundaries.
  - If no matching *.res exists or mapping is unclear, stop and ask for the exact source path.
  - Never write to generated artifacts. Note this in the output if a change seems required there.

  ## Next.js

  - Detect router (app/pages) and stick to it.
  - "use client" only when required.
  - Keep server actions and non-serializable logic on the server.

  ## TypeScript / React / Tailwind

  - Avoid any. Prefer discriminated unions.
  - Pure components and stable hooks.
  - Use Tailwind utilities and existing tokens.

  ## Output

  - Short plan
  - Single unified diff block
  - Brief notes: build/test results or follow-ups
  """

  defstruct [
    :agent_id,
    :task_id,
    :tools,
    :on_event,
    :pending_tool_calls,
    :idle_timer_ref
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

  @doc """
  Triggers the agent to execute an iteration with the given messages.
  """
  @spec execute_iteration(String.t(), list()) :: :ok | {:error, :not_found}
  def execute_iteration(task_id, messages) do
    with_agent(task_id, fn pid ->
      send(pid, {:execute_iteration, messages})
      :ok
    end)
  end

  @doc """
  Notifies the agent that a tool result has arrived.
  """
  @spec notify_tool_result(String.t(), String.t(), term(), boolean()) ::
          :ok | {:error, :not_found}
  def notify_tool_result(task_id, tool_call_id, result, is_error) do
    with_agent(task_id, fn pid ->
      send(pid, {:tool_result, tool_call_id, result, is_error})
      :ok
    end)
  end

  @doc """
  Wakes an idle agent to check for new work.
  """
  @spec wake(String.t()) :: :ok | {:error, :not_found}
  def wake(task_id) do
    with_agent(task_id, fn pid ->
      send(pid, :wake_agent)
      :ok
    end)
  end

  defp with_agent(task_id, fun) do
    case Registry.lookup(FrontmanServer.AgentRegistry, task_id) do
      [{pid, _state}] -> fun.(pid)
      [] -> {:error, :not_found}
    end
  end

  # Server Callbacks

  @impl true
  def init(%{agent_id: agent_id, task_id: task_id, tools: tools, on_event: on_event}) do
    state = %__MODULE__{
      agent_id: agent_id,
      task_id: task_id,
      tools: tools,
      on_event: on_event,
      idle_timer_ref: nil,
      pending_tool_calls: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_info({:execute_iteration, messages}, state) do
    Logger.info("Agent #{state.agent_id} starting iteration with #{length(messages)} messages")
    set_registry_state(state.task_id, :processing)

    case stream_and_handle_response(state, messages) do
      {:wait_for_tools, state} ->
        set_registry_state(state.task_id, :waiting_for_tools)
        state = schedule_idle_timeout(state)
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
          state = cancel_idle_timeout(state)
          emit(state, {:need_iteration, state.agent_id})
          {:noreply, state}
        else
          state = schedule_idle_timeout(state)
          {:noreply, state}
        end
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

    # Prepend base system prompt with caching
    # ContentBlocks from the prompt are now embedded in the user messages
    system_msg = ReqLLM.Context.system(@base_system_prompt, cache_control: %{type: "ephemeral"})
    messages_with_system = [system_msg | messages]

    # Base options with API key
    llm_opts = [api_key: api_key]

    llm_opts =
      case state.tools do
        [] -> llm_opts
        tools -> Keyword.put(llm_opts, :tools, tools)
      end

    IO.inspect(System.get_env("REQ_LLM_TIMEOUT"), label: "REQ_LLM_TIMEOUT")

    case ReqLLM.stream_text(@default_model, messages_with_system, llm_opts) do
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
    # ACP compliant: First agent_message_chunk implicitly signals message start
    # No need for explicit message_start event
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

    Enum.each(tool_calls, fn tool_call ->
      emit(state, {:tool_call, state.agent_id, tool_call})
    end)

    new_pending = Map.new(tool_calls, &{&1.id, &1})
    pending = Map.merge(state.pending_tool_calls, new_pending)

    state = %{state | pending_tool_calls: pending}
    {:wait_for_tools, state}
  end

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
