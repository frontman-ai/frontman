defmodule FrontmanServer.Tasks.MessageOptimizer.ImageDecay do
  @moduledoc """
  Replace image content parts in old messages with a text placeholder.

  The assistant already described what it saw in its response — the
  binary image data adds no new information and is likely stale
  (the page has changed since). Live messages are untouched.
  """

  alias ReqLLM.Message
  alias ReqLLM.Message.ContentPart

  @placeholder "[image: previously analyzed]"

  @spec run([Message.t()], non_neg_integer(), keyword()) :: [Message.t()]
  def run(messages, old_boundary, _opts \\ []) do
    messages
    |> Enum.with_index()
    |> Enum.map(fn {msg, idx} ->
      if idx < old_boundary do
        decay_images(msg)
      else
        msg
      end
    end)
  end

  defp decay_images(%Message{content: content} = msg) when is_list(content) do
    new_content =
      Enum.map(content, fn
        %ContentPart{type: type} when type in [:image, :image_url] ->
          ContentPart.text(@placeholder)

        other ->
          other
      end)

    %{msg | content: new_content}
  end

  defp decay_images(msg), do: msg
end
