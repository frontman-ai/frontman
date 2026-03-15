defmodule SwarmAi.ToolResult do
  @moduledoc """
  Result of a tool execution, supporting multimodal content (text + images).
  """
  use TypedStruct

  alias SwarmAi.Message.ContentPart

  typedstruct enforce: true do
    field(:id, String.t())
    field(:content, [ContentPart.t()])
    field(:is_error, boolean(), default: false)
  end

  @doc """
  Creates a ToolResult from raw tool output.

  Handles string and other term types by converting them to text content.
  """
  @spec make(String.t(), term(), boolean()) :: t()
  def make(id, raw_result, is_error \\ false)

  def make(id, [%ContentPart{} | _] = content_parts, is_error) do
    %__MODULE__{id: id, content: content_parts, is_error: is_error}
  end

  def make(id, raw_result, is_error) when is_binary(raw_result) do
    %__MODULE__{id: id, content: [ContentPart.text(raw_result)], is_error: is_error}
  end

  def make(id, raw_result, is_error) do
    %__MODULE__{
      id: id,
      content: [ContentPart.text(Jason.encode!(raw_result))],
      is_error: is_error
    }
  end
end
