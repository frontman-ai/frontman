defmodule FrontmanServer.Tasks.MessageOptimizer.TokenBudget do
  @moduledoc """
  Safety net that enforces a maximum token budget on the message list.

  Estimates tokens (chars / 4 for text, flat cost per image) and applies
  escalating strategies until the total is under budget:

  1. Aggressive image decay — remove ALL old images
  2. Truncate old tool result text to a configurable length
  3. Drop oldest messages, keeping system prompt + last N turns
  """

  require Logger

  alias FrontmanServer.Tasks.MessageOptimizer
  alias ReqLLM.Message
  alias ReqLLM.Message.ContentPart

  @default_budget 128_000
  @default_truncation_length 500
  @default_keep_recent_turns 10
  @image_token_cost 4000

  @strategies [:aggressive_image_decay, :truncate_tool_results, :drop_oldest]

  @spec run([Message.t()], keyword()) :: [Message.t()]
  def run(messages, opts \\ []) do
    budget = budget(opts)

    if estimate_tokens(messages) <= budget do
      messages
    else
      apply_strategies(messages, budget, opts, @strategies)
    end
  end

  @doc """
  Estimate token count for a message list.
  """
  @spec estimate_tokens([Message.t()]) :: non_neg_integer()
  def estimate_tokens(messages) do
    Enum.reduce(messages, 0, fn msg, acc ->
      acc + estimate_message_tokens(msg)
    end)
  end

  defp apply_strategies(messages, _budget, _opts, []), do: messages

  defp apply_strategies(messages, budget, opts, [strategy | rest]) do
    messages = apply_strategy(messages, strategy, opts)

    if estimate_tokens(messages) <= budget do
      messages
    else
      apply_strategies(messages, budget, opts, rest)
    end
  end

  defp apply_strategy(messages, :aggressive_image_decay, opts) do
    old_boundary = Keyword.get(opts, :old_boundary, default_old_boundary(messages))
    aggressive_image_decay(messages, old_boundary)
  end

  defp apply_strategy(messages, :truncate_tool_results, opts) do
    old_boundary = Keyword.get(opts, :old_boundary, default_old_boundary(messages))
    truncation_length = truncation_length(opts)
    truncate_old_tool_results(messages, old_boundary, truncation_length)
  end

  defp apply_strategy(messages, :drop_oldest, opts) do
    keep_recent = keep_recent_turns(opts)
    drop_oldest(messages, keep_recent)
  end

  defp default_old_boundary(messages) do
    MessageOptimizer.find_old_boundary(messages)
  end

  defp aggressive_image_decay(messages, old_boundary) do
    messages
    |> Enum.with_index()
    |> Enum.map(fn {msg, idx} ->
      if idx < old_boundary do
        strip_all_images(msg)
      else
        msg
      end
    end)
  end

  defp strip_all_images(%Message{content: content} = msg) when is_list(content) do
    new_content =
      Enum.reject(content, fn
        %ContentPart{type: type} when type in [:image, :image_url] -> true
        _ -> false
      end)

    new_content =
      case new_content do
        [] -> [ContentPart.text("[images removed]")]
        kept -> kept
      end

    %{msg | content: new_content}
  end

  defp strip_all_images(msg), do: msg

  defp truncate_old_tool_results(messages, old_boundary, max_length) do
    messages
    |> Enum.with_index()
    |> Enum.map(fn {msg, idx} ->
      if idx < old_boundary and msg.role == :tool do
        truncate_content(msg, max_length)
      else
        msg
      end
    end)
  end

  defp truncate_content(%Message{content: content} = msg, max_length)
       when is_list(content) do
    new_content =
      Enum.map(content, fn
        %ContentPart{type: :text, text: text} = part when byte_size(text) > max_length ->
          %{part | text: binary_part(text, 0, max_length) <> "\n[truncated]"}

        other ->
          other
      end)

    %{msg | content: new_content}
  end

  defp truncate_content(msg, _max_length), do: msg

  defp drop_oldest(messages, keep_recent) do
    {system_msgs, non_system} = Enum.split_with(messages, &(&1.role == :system))

    # Count actual turns by grouping contiguous non-system messages
    # A turn = everything from one user message to (but not including) the next user message
    turns = chunk_into_turns(non_system)

    kept =
      if length(turns) > keep_recent do
        turns
        |> Enum.take(-keep_recent)
        |> List.flatten()
      else
        non_system
      end

    system_msgs ++ kept
  end

  # Groups messages into turns where each turn starts with a :user message
  # and includes all following non-user messages (assistant, tool, etc.)
  defp chunk_into_turns(messages) do
    messages
    |> Enum.reduce([], fn msg, acc ->
      case {msg.role, acc} do
        {:user, _} ->
          [[msg] | acc]

        {_, [current_turn | rest]} ->
          [[msg | current_turn] | rest]

        {_, []} ->
          [[msg]]
      end
    end)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
  end

  defp estimate_message_tokens(%Message{content: content}) when is_list(content) do
    Enum.reduce(content, 0, fn
      %ContentPart{type: :text, text: text}, acc when is_binary(text) ->
        acc + div(byte_size(text), 4)

      %ContentPart{type: type}, acc when type in [:image, :image_url] ->
        acc + @image_token_cost

      _, acc ->
        acc
    end)
  end

  defp estimate_message_tokens(_), do: 0

  defp budget(opts) do
    config_budget =
      Application.get_env(:frontman_server, FrontmanServer.Tasks.MessageOptimizer, [])
      |> Keyword.get(:token_budget, @default_budget)

    Keyword.get(opts, :token_budget, config_budget)
  end

  defp truncation_length(opts) do
    config_val =
      Application.get_env(:frontman_server, FrontmanServer.Tasks.MessageOptimizer, [])
      |> Keyword.get(:budget_truncation_length, @default_truncation_length)

    Keyword.get(opts, :budget_truncation_length, config_val)
  end

  defp keep_recent_turns(opts) do
    config_val =
      Application.get_env(:frontman_server, FrontmanServer.Tasks.MessageOptimizer, [])
      |> Keyword.get(:budget_keep_recent_turns, @default_keep_recent_turns)

    Keyword.get(opts, :budget_keep_recent_turns, config_val)
  end
end
