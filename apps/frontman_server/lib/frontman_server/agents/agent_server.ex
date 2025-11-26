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
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.LLM.Client

  defstruct [
    :agent_id,
    :task_id,
    :tools,
    :fixture_path
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
      name: {:via, Registry, {FrontmanServer.AgentRegistry, task_id}}
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
    state = %__MODULE__{
      agent_id: agent_id,
      task_id: task_id,
      tools: tools,
      fixture_path: nil
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
    # Fetch fresh interactions from Task
    interactions = Tasks.get_interactions(state.task_id)
    messages = Interaction.to_llm_messages(interactions)

    Logger.info("Agent #{state.agent_id} starting iteration with #{length(messages)} messages")

    case stream_and_handle_response(state, messages) do
      {:continue, state} ->
        # Tool calls were handled, continue to next iteration
        send(self(), :execute_iteration)
        {:noreply, state}

      {:stop, state} ->
        # No tool calls, we're done
        broadcast_completion(state)
        {:stop, :normal, state}

      {:error, reason, state} ->
        broadcast_error(state, "Agent error: #{inspect(reason)}")
        {:stop, :normal, state}
    end
  end

  # Private Functions

  defp stream_and_handle_response(state, messages) do
    opts = [tools: state.tools, fixture_path: state.fixture_path]

    case Client.stream_chat(messages, opts) do
      {:ok, chunk_stream} ->
        # Collect chunks while streaming tokens
        chunks = stream_chunks(state, chunk_stream)

        # Extract text and tool calls
        text = Client.extract_text(chunks)
        tool_calls = Client.extract_tool_calls(chunks)

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
end
