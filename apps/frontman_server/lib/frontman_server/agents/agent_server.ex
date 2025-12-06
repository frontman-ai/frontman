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

  @default_model "openai:gpt-5-chat-latest"
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

  alias FrontmanServer.Agents
  alias FrontmanServer.Agents.{SubAgent, SubAgentTool}

  defstruct [
    :agent_id,
    :task_id,
    :tools,
    :on_event,
    :pending_tool_calls,
    :idle_timer_ref,
    # Sub-agent support
    :parent_agent_id,
    :parent_pid,
    :role,
    :task,
    :sub_agent_supervisor,
    :pending_sub_agents,
    :started_at,
    :iteration_count
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
            role: :root,
            state: :processing
          }}}
    )
  end

  @doc """
  Starts a sub-agent under a parent's supervisor.
  """
  def start_sub_agent(opts) do
    agent_id = Keyword.fetch!(opts, :agent_id)
    task_id = Keyword.fetch!(opts, :task_id)
    tools = Keyword.get(opts, :tools, [])
    on_event = Keyword.fetch!(opts, :on_event)
    parent_agent_id = Keyword.fetch!(opts, :parent_agent_id)
    parent_pid = Keyword.fetch!(opts, :parent_pid)
    role = Keyword.fetch!(opts, :role)
    task = Keyword.fetch!(opts, :task)

    GenServer.start_link(
      __MODULE__,
      {:sub_agent,
       %{
         agent_id: agent_id,
         task_id: task_id,
         tools: tools,
         on_event: on_event,
         parent_agent_id: parent_agent_id,
         parent_pid: parent_pid,
         role: role,
         task: task
       }},
      name:
        {:via, Registry,
         {FrontmanServer.AgentRegistry, {:agent, agent_id},
          %{
            task_id: task_id,
            parent_agent_id: parent_agent_id,
            role: role,
            state: :processing
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

  # Server Callbacks

  @impl true
  def init({:root, %{agent_id: agent_id, task_id: task_id, tools: tools, on_event: on_event}}) do
    # Flat supervision: all agents under FrontmanServer.AgentSupervisor
    # No more nested DynamicSupervisor per agent

    state = %__MODULE__{
      agent_id: agent_id,
      task_id: task_id,
      tools: tools,
      on_event: on_event,
      idle_timer_ref: nil,
      pending_tool_calls: %{},
      # Root agent fields
      parent_agent_id: nil,
      parent_pid: nil,
      role: nil,
      task: nil,
      sub_agent_supervisor: nil,
      pending_sub_agents: %{},
      started_at: System.monotonic_time(:millisecond),
      iteration_count: 0
    }

    {:ok, state}
  end

  def init({:sub_agent, opts}) do
    %{
      agent_id: agent_id,
      task_id: task_id,
      tools: tools,
      on_event: on_event,
      parent_agent_id: parent_agent_id,
      parent_pid: parent_pid,
      role: role,
      task: task
    } = opts

    # Monitor parent for crash detection
    Process.monitor(parent_pid)

    state = %__MODULE__{
      agent_id: agent_id,
      task_id: task_id,
      tools: tools,
      on_event: on_event,
      idle_timer_ref: nil,
      pending_tool_calls: %{},
      # Sub-agent fields
      parent_agent_id: parent_agent_id,
      parent_pid: parent_pid,
      role: role,
      task: task,
      sub_agent_supervisor: nil,
      pending_sub_agents: %{},
      started_at: System.monotonic_time(:millisecond),
      iteration_count: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_info({:execute_iteration, messages}, state) do
    Logger.info("Agent #{state.agent_id} starting iteration with #{length(messages)} messages")
    set_registry_state(state.agent_id, :processing)

    case stream_and_handle_response(state, messages) do
      {:wait_for_tools, state} ->
        set_registry_state(state.agent_id, :waiting_for_tools)
        state = schedule_idle_timeout(state)
        {:noreply, state}

      {:stop, state} ->
        emit(state, {:completed, state.agent_id})
        set_registry_state(state.agent_id, :idle)
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
        # With direct routing, this shouldn't happen
        Logger.warning("Received tool result for unknown tool_call_id: #{tool_call_id}")
        {:noreply, state}

      tool_call ->
        Logger.info("Tool #{tool_call.name} completed")
        # Unregister tool call from Registry
        Registry.unregister(FrontmanServer.AgentRegistry, {:tool_call, tool_call_id})
        pending = Map.delete(state.pending_tool_calls, tool_call_id)
        state = %{state | pending_tool_calls: pending}

        if Enum.empty?(pending) and not has_pending_sub_agents?(state) do
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
    case Registry.lookup(FrontmanServer.AgentRegistry, {:agent, state.agent_id}) do
      [{_pid, %{state: :idle}}] ->
        state = cancel_idle_timeout(state)
        set_registry_state(state.agent_id, :processing)
        emit(state, {:need_iteration, state.agent_id})
        {:noreply, state}

      [{_pid, %{state: :processing}}] ->
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
  def handle_info({:sub_agent_result, sub_agent_id, result}, state) do
    case Map.get(state.pending_sub_agents, sub_agent_id) do
      nil ->
        {:noreply, state}

      sub_agent ->
        duration_ms = System.monotonic_time(:millisecond) - sub_agent.started_at
        completed = %{sub_agent | status: :completed, result: result}

        emit(state, {:sub_agent_completed, state.agent_id, completed, duration_ms})

        state = %{state | pending_sub_agents: Map.delete(state.pending_sub_agents, sub_agent_id)}

        if has_pending_work?(state) do
          {:noreply, state}
        else
          state = cancel_idle_timeout(state)
          emit(state, {:need_iteration, state.agent_id})
          {:noreply, state}
        end
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    # Check if it's a sub-agent that died
    case Enum.find(state.pending_sub_agents, fn {_id, sa} -> sa.pid == pid end) do
      nil ->
        # Check if parent died (for sub-agents)
        if state.parent_pid == pid do
          Logger.info("Sub-agent #{state.agent_id} parent died, terminating")
          {:stop, :normal, state}
        else
          {:noreply, state}
        end

      {sub_agent_id, sub_agent} ->
        duration_ms = System.monotonic_time(:millisecond) - sub_agent.started_at
        failed = %{sub_agent | status: :failed, error: reason}

        emit(state, {:sub_agent_failed, state.agent_id, failed, duration_ms})

        state = %{state | pending_sub_agents: Map.delete(state.pending_sub_agents, sub_agent_id)}

        if has_pending_work?(state) do
          {:noreply, state}
        else
          state = cancel_idle_timeout(state)
          emit(state, {:need_iteration, state.agent_id})
          {:noreply, state}
        end
    end
  end

  # Private Functions

  defp emit(state, event) do
    Logger.debug("Agent #{state.agent_id} emitting: #{elem(event, 0)}")
    state.on_event.(event)
  end

  defp stream_and_handle_response(state, messages) do
    api_key = get_api_key(@default_model)

    # Build system prompt - use role prompt for sub-agents, base prompt for root
    system_prompt = build_system_prompt(state)
    system_msg = ReqLLM.Context.system(system_prompt, cache_control: %{type: "ephemeral"})
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
        response_id = extract_response_id(chunks)

        # DEBUG: Log what we extracted from chunks
        Logger.info(
          "Agent #{state.agent_id} extracted: text=#{byte_size(text || "")} bytes, tool_calls=#{length(tool_calls)}, response_id=#{inspect(response_id)}, chunks=#{length(chunks)}"
        )

        handle_response(state, text, tool_calls, response_id)

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

  defp handle_response(state, text, [], _response_id) do
    Logger.info("Agent #{state.agent_id} completing with text: #{byte_size(text || "")} bytes")
    emit(state, {:response, state.agent_id, text, %{}})

    if sub_agent?(state) do
      send(state.parent_pid, {:sub_agent_result, state.agent_id, text})
    end

    {:stop, state}
  end

  defp handle_response(state, text, tool_calls, response_id) do
    Logger.info(
      "Agent #{state.agent_id} has #{length(tool_calls)} tool calls, text: #{byte_size(text || "")} bytes"
    )

    # Include response_id in metadata for OpenAI Responses API (previous_response_id)
    metadata = %{tool_calls: tool_calls}
    metadata = if response_id, do: Map.put(metadata, :response_id, response_id), else: metadata
    emit(state, {:response, state.agent_id, text, metadata})

    {spawn_calls, regular_tools} =
      Enum.split_with(tool_calls, fn tc -> tc.name == SubAgentTool.tool_name() end)

    state =
      state
      |> track_tool_calls(regular_tools)
      |> spawn_sub_agents(spawn_calls)

    if has_pending_work?(state) do
      {:wait_for_tools, state}
    else
      {:stop, state}
    end
  end

  defp track_tool_calls(state, []), do: state

  defp track_tool_calls(state, tool_calls) do
    Enum.each(tool_calls, fn tc ->
      emit(state, {:tool_call, state.agent_id, tc})
      # Register tool call for direct routing
      Registry.register(FrontmanServer.AgentRegistry, {:tool_call, tc.id}, state.agent_id)
    end)

    new_pending = Map.new(tool_calls, &{&1.id, &1})
    %{state | pending_tool_calls: Map.merge(state.pending_tool_calls, new_pending)}
  end

  defp spawn_sub_agents(state, []), do: state
  defp spawn_sub_agents(state, _calls) when state.parent_agent_id != nil, do: state

  defp spawn_sub_agents(state, calls) do
    Enum.reduce(calls, state, fn call, acc ->
      case spawn_sub_agent(acc, call) do
        {:ok, sub_agent} ->
          emit(acc, {:sub_agent_spawned, acc.agent_id, sub_agent})
          %{acc | pending_sub_agents: Map.put(acc.pending_sub_agents, sub_agent.id, sub_agent)}

        {:error, _reason} ->
          acc
      end
    end)
  end

  defp spawn_sub_agent(state, tool_call) do
    with {:ok, %{role: role, task: task}} <- SubAgentTool.parse_arguments(tool_call.arguments) do
      id = generate_sub_agent_id()

      child_spec = %{
        id: id,
        start:
          {__MODULE__, :start_sub_agent,
           [
             [
               agent_id: id,
               task_id: state.task_id,
               tools: state.tools,
               on_event: state.on_event,
               parent_agent_id: state.agent_id,
               parent_pid: self(),
               role: role,
               task: task
             ]
           ]},
        restart: :temporary
      }

      # Spawn under global supervisor (flat supervision)
      case DynamicSupervisor.start_child(FrontmanServer.AgentSupervisor, child_spec) do
        {:ok, pid} ->
          Process.monitor(pid)

          sub_agent = %SubAgent{
            id: id,
            tool_call_id: tool_call.id,
            role: role,
            task: task,
            pid: pid,
            status: :running,
            started_at: System.monotonic_time(:millisecond)
          }

          send(pid, {:execute_iteration, [%{role: "user", content: task}]})
          {:ok, sub_agent}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp generate_sub_agent_id do
    "sub_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end

  defp build_system_prompt(%{role: nil}) do
    @base_system_prompt <> "\n" <> sub_agent_guidance()
  end

  defp build_system_prompt(%{role: role}) do
    {:ok, config} = Agents.get_role(role)
    config.system_prompt
  end

  defp sub_agent_guidance do
    role_list =
      Agents.roles()
      |> Enum.map(fn role ->
        {:ok, config} = Agents.get_role(role)
        "- **#{role}**: #{config.description}"
      end)
      |> Enum.join("\n")

    """
    ## Sub-agents

    Use `spawn_sub_agent` to delegate specialized work:
    #{role_list}

    Spawn sub-agents early for complex tasks. They run autonomously and return results.
    """
  end

  defp sub_agent?(state), do: state.parent_agent_id != nil

  defp has_pending_work?(state) do
    not Enum.empty?(state.pending_tool_calls) or not Enum.empty?(state.pending_sub_agents)
  end

  defp has_pending_sub_agents?(state), do: not Enum.empty?(state.pending_sub_agents)

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

  # Extract response_id from meta chunks (for OpenAI Responses API previous_response_id)
  defp extract_response_id(chunks) do
    chunks
    |> Enum.find_value(fn
      %{type: :meta, metadata: %{response_id: id}} when is_binary(id) -> id
      _ -> nil
    end)
  end

  defp set_registry_state(agent_id, new_state) do
    Registry.update_value(FrontmanServer.AgentRegistry, {:agent, agent_id}, fn metadata ->
      %{metadata | state: new_state}
    end)
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
