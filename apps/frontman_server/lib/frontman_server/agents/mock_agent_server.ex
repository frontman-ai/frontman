defmodule FrontmanServer.Agents.MockAgentServer do
  @moduledoc """
  Mock agent server that streams predefined tokens.

  This is used for testing the streaming infrastructure without real LLM integration.
  Streams the same response regardless of input.
  """
  use GenServer
  require Logger

  alias FrontmanServer.Tasks

  defstruct [:agent_id, :task_id, :accumulated_content, :token_index]

  @mock_tokens ["Hello", " ", "from", " ", "the", " ", "mock", " ", "agent", "!", " ", "This", " ", "is", " ", "a", " ", "test", " ", "response", "."]
  @stream_delay_ms 50

  # Client API

  @doc """
  Starts a mock agent to respond to a user message.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Returns the via tuple for Registry lookup.
  """
  def via(agent_id) do
    {:via, Registry, {FrontmanServer.AgentRegistry, agent_id}}
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    agent_id = Keyword.fetch!(opts, :agent_id)
    task_id = Keyword.fetch!(opts, :task_id)

    Logger.info("Starting MockAgentServer #{agent_id} for task #{task_id}")

    state = %__MODULE__{
      agent_id: agent_id,
      task_id: task_id,
      accumulated_content: "",
      token_index: 0
    }

    # Start streaming immediately
    send(self(), :stream_next_token)

    {:ok, state}
  end

  @impl true
  def handle_info(:stream_next_token, state) do
    if state.token_index < length(@mock_tokens) do
      token = Enum.at(@mock_tokens, state.token_index)
      new_content = state.accumulated_content <> token

      # Broadcast ephemeral stream token via PubSub
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        topic(state.task_id),
        {:stream_token, state.agent_id, token}
      )

      # Schedule next token
      Process.send_after(self(), :stream_next_token, @stream_delay_ms)

      {:noreply, %{state | accumulated_content: new_content, token_index: state.token_index + 1}}
    else
      # Streaming complete - store final AgentResponse interaction
      Tasks.add_agent_response(state.task_id, state.agent_id, state.accumulated_content)

      # Broadcast completion
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        topic(state.task_id),
        {:agent_completed, state.agent_id}
      )

      Logger.info("MockAgentServer #{state.agent_id} completed streaming")

      # Stop the GenServer
      {:stop, :normal, state}
    end
  end

  # Private Functions

  defp topic(task_id), do: "task:#{task_id}"
end
