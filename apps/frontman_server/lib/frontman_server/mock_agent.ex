defmodule FrontmanServer.MockAgent do
  @moduledoc """
  Mock agent that simulates streaming responses for ACP testing.
  Sends chunked responses via PubSub to demonstrate the streaming flow.
  """

  alias FrontmanServer.ACP

  @chunk_delay_ms 100

  @doc """
  Streams a mock response for the given user message.
  Sends chunks via PubSub to the session topic.
  """
  def stream_response(session_id, user_message) do
    chunks = generate_response_chunks(user_message)

    Enum.each(chunks, fn chunk ->
      Process.sleep(@chunk_delay_ms)
      broadcast_chunk(session_id, chunk)
    end)

    broadcast_complete(session_id)
  end

  defp generate_response_chunks(user_message) do
    response =
      "I received your message: \"#{user_message}\". This is a mocked streaming response from the agent."

    response
    |> String.graphemes()
    |> Enum.chunk_every(20)
    |> Enum.map(&Enum.join/1)
  end

  defp broadcast_chunk(session_id, text) do
    notification = ACP.build_agent_message_chunk_update(session_id, text)

    Phoenix.PubSub.broadcast(
      FrontmanServer.PubSub,
      "task:#{session_id}",
      {:acp_notification, notification}
    )
  end

  defp broadcast_complete(session_id) do
    Phoenix.PubSub.broadcast(
      FrontmanServer.PubSub,
      "task:#{session_id}",
      {:prompt_complete, "end_turn"}
    )
  end
end
