defmodule FrontmanServer.Tasks.MessageOptimizer do
  @moduledoc """
  Composable message optimization pipeline that minimizes token usage
  without losing accuracy.

  Slots between `Interaction.to_llm_messages()` and `to_swarm_message/1`
  in the execution pipeline. Each layer is a pure function over a list
  of `ReqLLM.Message` structs.

  Core principle: recent context is sacred, old context is compactable.
  A message is "old" if an assistant message appears after it — the model
  has already processed it.
  """

  alias FrontmanServer.Tasks.MessageOptimizer.{
    ImageDecay,
    PageContextDedup,
    ToolResultCompaction,
    ToolResultTruncation
  }

  @type opts :: keyword()

  @doc """
  Run the full optimization pipeline over a list of messages.

  Returns the optimized message list. When the optimizer is disabled
  via config, acts as a pass-through.
  """
  @spec optimize([ReqLLM.Message.t()], opts()) :: [ReqLLM.Message.t()]
  def optimize(messages, opts \\ []) do
    if enabled?() do
      old_boundary = find_old_boundary(messages)

      messages
      |> ImageDecay.run(old_boundary, opts)
      |> ToolResultCompaction.run(old_boundary, opts)
      |> ToolResultTruncation.run(opts)
      |> PageContextDedup.run(opts)
    else
      messages
    end
  end

  @doc """
  Find the boundary between old and live messages.

  Returns the index *after* the last assistant message. Everything
  before that index is old (already processed). Everything from that
  index onward is live (current turn).

  Returns 0 when there are no assistant messages (all messages are live).
  """
  @spec find_old_boundary([ReqLLM.Message.t()]) :: non_neg_integer()
  def find_old_boundary(messages) do
    messages
    |> Enum.with_index()
    |> Enum.reduce(0, fn {msg, idx}, acc ->
      if msg.role == :assistant, do: idx + 1, else: acc
    end)
  end

  defp enabled? do
    Application.get_env(:frontman_server, __MODULE__, [])
    |> Keyword.get(:enabled, true)
  end
end
