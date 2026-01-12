defmodule AgentClientProtocol.Content do
  @moduledoc "Builders for ACP content blocks."

  defmodule TextBlock do
    @moduledoc false
    @enforce_keys [:text]
    defstruct [:text]
    @type t :: %__MODULE__{text: String.t()}

    defimpl Jason.Encoder do
      def encode(%{text: text}, opts) do
        Jason.Encode.map(%{"type" => "text", "text" => text}, opts)
      end
    end
  end

  defmodule ContentItem do
    @moduledoc false
    @enforce_keys [:content]
    defstruct [:content]
    @type t :: %__MODULE__{content: TextBlock.t()}

    defimpl Jason.Encoder do
      def encode(%{content: block}, opts) do
        Jason.Encode.map(%{"type" => "content", "content" => block}, opts)
      end
    end
  end

  @spec text(String.t()) :: TextBlock.t()
  def text(text) when is_binary(text), do: %TextBlock{text: text}

  @spec wrap(TextBlock.t()) :: ContentItem.t()
  def wrap(%TextBlock{} = block), do: %ContentItem{content: block}

  @spec from_tool_result(term()) :: [ContentItem.t()]
  def from_tool_result(result) when is_map(result),
    do: [result |> Jason.encode!() |> text() |> wrap()]

  def from_tool_result(result) when is_binary(result), do: [result |> text() |> wrap()]
  def from_tool_result(result), do: [result |> inspect() |> text() |> wrap()]
end
