defmodule FrontmanServer.Agents.AgentServer do
  @moduledoc """
  Real agent server that executes agentic loop with LLM.

  The agent iteratively calls the LLM until no more tool calls are needed.
  Each iteration processes the conversation history and either:
  - Completes with a final response (no tools requested)
  - Executes tools and continues to next iteration
  """
  use GenServer
  require Logger

  alias FrontmanServer.Tasks
  alias FrontmanServer.LLM.Client

  defstruct [
    :agent_id,
    :task_id,
    :messages,
    :accumulated_content,
    :token_stream,
    :fixture_path
  ]

  # Client API

  def start_link(opts) do
    agent_id = Keyword.fetch!(opts, :agent_id)
    task_id = Keyword.fetch!(opts, :task_id)
    messages = Keyword.fetch!(opts, :messages)
    fixture_path = Keyword.get(opts, :fixture_path)

    GenServer.start_link(
      __MODULE__,
      %{
        agent_id: agent_id,
        task_id: task_id,
        messages: messages,
        fixture_path: fixture_path
      },
      name: {:via, Registry, {FrontmanServer.AgentRegistry, task_id}}
    )
  end

  @doc """
  Executes one iteration of the agentic loop.

  Called initially by the task when spawning the agent,
  and then by the agent itself if more iterations are needed.
  """
  def execute_iteration(agent_pid) do
    send(agent_pid, :execute_iteration)
  end

  # Server Callbacks

  @impl true
  def init(%{
        agent_id: agent_id,
        task_id: task_id,
        messages: messages,
        fixture_path: fixture_path
      }) do
    state = %__MODULE__{
      agent_id: agent_id,
      task_id: task_id,
      messages: messages,
      accumulated_content: "",
      token_stream: nil,
      fixture_path: fixture_path
    }

    {:ok, state}
  end

  @impl true
  def handle_info({ref, _metadata}, state) when is_reference(ref) do
    # Ignore metadata task completion from ReqLLM
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Ignore Task process exit
    {:noreply, state}
  end

  @impl true
  def handle_info(:execute_iteration, state) do
    # Start streaming from LLM
    case Client.stream_chat(state.messages, fixture_path: state.fixture_path) do
      {:ok, token_stream} ->
        # Process first token immediately
        send(self(), :process_next_token)
        {:noreply, %{state | token_stream: token_stream}}

      {:error, reason} ->
        Logger.error("LLM stream failed: #{inspect(reason)}")
        broadcast_error(state, "LLM request failed: #{inspect(reason)}")
        {:stop, :normal, state}
    end
  end

  @impl true
  def handle_info(:process_next_token, %{token_stream: nil} = state) do
    # Stream ended
    finalize_response(state)
  end

  @impl true
  def handle_info(:process_next_token, state) do
    try do
      case Enum.take(state.token_stream, 1) do
        [token] ->
          # Broadcast token
          broadcast_token(state, token)

          # Accumulate content
          new_content = state.accumulated_content <> token

          # Get remaining stream
          remaining_stream = Stream.drop(state.token_stream, 1)

          # Schedule next token
          send(self(), :process_next_token)

          {:noreply, %{state | accumulated_content: new_content, token_stream: remaining_stream}}

        [] ->
          # Stream ended
          finalize_response(state)
      end
    rescue
      error ->
        Logger.error("Error processing token: #{inspect(error)}")
        Logger.error(Exception.format(:error, error, __STACKTRACE__))
        finalize_response(state)
    end
  end

  # Private Functions

  defp broadcast_token(state, token) do
    Phoenix.PubSub.broadcast(
      FrontmanServer.PubSub,
      "task:#{state.task_id}",
      {:stream_token, state.agent_id, token}
    )
  end

  defp finalize_response(state) do
    # Store agent response
    Tasks.add_agent_response(
      state.task_id,
      state.agent_id,
      state.accumulated_content
    )

    # Mark agent as completed
    Tasks.add_agent_completed(state.task_id, state.agent_id)

    # TODO Phase 5: Check for tool calls here
    # If tool calls: execute them, then call execute_iteration(self())
    # If no tool calls: mark complete and stop

    # For Phase 1: Always complete after one iteration
    broadcast_completion(state)
    {:stop, :normal, state}
  end

  defp broadcast_completion(state) do
    Phoenix.PubSub.broadcast(
      FrontmanServer.PubSub,
      "task:#{state.task_id}",
      {:agent_completed, state.agent_id}
    )

    Logger.info("Agent completed: #{state.agent_id}")
  end

  defp broadcast_error(state, message) do
    Phoenix.PubSub.broadcast(
      FrontmanServer.PubSub,
      "task:#{state.task_id}",
      {:agent_error, state.agent_id, message}
    )
  end
end
