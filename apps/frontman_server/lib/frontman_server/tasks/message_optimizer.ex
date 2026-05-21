# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.MessageOptimizer do
  @moduledoc """
  Composable message optimization pipeline that minimizes token usage
  without losing accuracy.

  Runs in `LLMClient` before each provider request. Each layer is a pure
  function over a list of `SwarmAi.Message` structs.

  Core principle: recent context is sacred, old context is compactable.
  A message is "old" if an assistant message appears after it — the model
  has already processed it.
  """

  alias FrontmanServer.Tasks.MessageOptimizer.{
    ConstrainImageDimensions,
    ImageDecay,
    PageContextDedup,
    StripUnsupportedImages,
    ToolResultCompaction,
    ToolResultImageExpansion,
    ToolResultTruncation
  }

  alias SwarmAi.Message

  @type opts :: keyword()

  @doc """
  Run the full optimization pipeline over a list of messages.

  Returns the optimized message list. When the optimizer is disabled
  via config, acts as a pass-through.
  """
  @spec optimize([Message.t()], opts()) :: [Message.t()]
  def optimize(messages, opts \\ []) do
    if enabled?() do
      old_boundary = find_old_boundary(messages)

      messages
      |> ToolResultCompaction.run(old_boundary, opts)
      |> ToolResultImageExpansion.run(opts)
      |> ImageDecay.run(old_boundary, opts)
      |> StripUnsupportedImages.run(opts)
      |> ConstrainImageDimensions.run(opts)
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
  @spec find_old_boundary([Message.t()]) :: non_neg_integer()
  def find_old_boundary(messages) do
    messages
    |> Enum.with_index()
    |> Enum.reduce(0, fn {msg, idx}, acc ->
      if match?(%Message.Assistant{}, msg), do: idx + 1, else: acc
    end)
  end

  defp enabled? do
    Application.get_env(:frontman_server, __MODULE__, [])
    |> Keyword.get(:enabled, true)
  end
end
