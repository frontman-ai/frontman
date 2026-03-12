defmodule SwarmAi.Message.ContentPart do
  @moduledoc """
  Represents a content part within a message (text, image, etc).

  Content parts are the building blocks of message content, allowing
  for multi-modal messages with text, images, and other content types.
  """

  use TypedStruct

  @type content_type :: :text | :image | :image_url

  typedstruct do
    field(:type, content_type(), enforce: true)
    field(:text, String.t())
    field(:data, binary())
    field(:media_type, String.t())
    field(:url, String.t())
  end

  @doc "Creates a text content part"
  @spec text(String.t()) :: t()
  def text(text) when is_binary(text) do
    %__MODULE__{type: :text, text: text}
  end

  @doc "Creates an image content part from binary data"
  @spec image(binary(), String.t()) :: t()
  def image(data, media_type) when is_binary(data) do
    %__MODULE__{type: :image, data: data, media_type: media_type}
  end

  @doc "Creates an image URL content part"
  @spec image_url(String.t()) :: t()
  def image_url(url) when is_binary(url) do
    %__MODULE__{type: :image_url, url: url}
  end

  @doc """
  Extracts joined text from a mixed content value.

  Handles plain strings, lists of `ContentPart` structs, lists of atom-keyed
  maps (`%{type: :text, text: "..."}`) and string-keyed maps
  (`%{"type" => "text", "text" => "..."}`), and nil/other.

  Returns the concatenated text (newline-joined for lists) or `""`.

  ## Examples

      iex> ContentPart.extract_text("hello")
      "hello"

      iex> ContentPart.extract_text([ContentPart.text("a"), ContentPart.text("b")])
      "a\\nb"

      iex> ContentPart.extract_text(nil)
      ""
  """
  @spec extract_text(String.t() | [t() | map()] | nil) :: String.t()
  def extract_text(content) when is_binary(content), do: content

  def extract_text(content) when is_list(content) do
    content
    |> Enum.filter(&text_part?/1)
    |> Enum.map_join("\n", &get_text/1)
  end

  def extract_text(_), do: ""

  defp text_part?(%__MODULE__{type: :text}), do: true
  defp text_part?(%{type: :text}), do: true
  defp text_part?(%{"type" => "text"}), do: true
  defp text_part?(_), do: false

  defp get_text(%__MODULE__{text: text}), do: text || ""
  defp get_text(%{text: text}), do: text || ""
  defp get_text(%{"text" => text}), do: text || ""
  defp get_text(_), do: ""
end
