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
  def make(id, raw_result, is_error \\ false) do
    content =
      case raw_result do
        [%ContentPart{} | _] = content_parts -> content_parts
        raw_result when is_binary(raw_result) -> [ContentPart.text(raw_result)]
        raw_result -> [ContentPart.text(Jason.encode!(raw_result))]
      end

    %__MODULE__{
      id: id,
      content: content,
      is_error: is_error
    }
  end
end
