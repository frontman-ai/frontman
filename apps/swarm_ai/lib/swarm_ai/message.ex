defmodule SwarmAi.Message do
  @moduledoc """
  Represents a message in the agentic loop.

  Messages form the conversation history passed to LLMs. Each message has a role
  (system, user, assistant, or tool) and content parts that can include text,
  images, and other modalities.

  This module is designed to be compatible with external LLM libraries while
  remaining self-contained within the Swarm framework.
  """

  use TypedStruct
  alias SwarmAi.Message.ContentPart

  @type role :: :system | :user | :assistant | :tool

  typedstruct do
    field(:role, role(), enforce: true)
    field(:content, [ContentPart.t()], default: [])
    field(:tool_calls, [SwarmAi.ToolCall.t()], default: [])
    field(:tool_call_id, String.t())
    field(:name, String.t())
    field(:metadata, map(), default: %{})
  end

  @doc "Creates a system message from text or a list of content parts"
  @spec system(String.t() | [String.t()]) :: t()
  def system(text) when is_binary(text) do
    %__MODULE__{role: :system, content: [ContentPart.text(text)]}
  end

  def system(parts) when is_list(parts) do
    content =
      Enum.map(parts, fn
        text when is_binary(text) -> ContentPart.text(text)
        %ContentPart{} = part -> part
      end)

    %__MODULE__{role: :system, content: content}
  end

  @doc "Creates a user message"
  @spec user(String.t()) :: t()
  def user(text) when is_binary(text) do
    %__MODULE__{role: :user, content: [ContentPart.text(text)]}
  end

  @doc "Creates an assistant message"
  @spec assistant(String.t() | nil, [SwarmAi.ToolCall.t()], map()) :: t()
  def assistant(text, tool_calls \\ [], metadata \\ %{}) do
    %__MODULE__{
      role: :assistant,
      content: [ContentPart.text(text || "")],
      tool_calls: tool_calls,
      metadata: metadata
    }
  end

  @doc "Creates a tool result message from content parts"
  @spec tool_result(String.t(), String.t(), [ContentPart.t()], map()) :: t()
  def tool_result(name, tool_call_id, content, metadata \\ %{}) when is_list(content) do
    %__MODULE__{
      role: :tool,
      name: name,
      tool_call_id: tool_call_id,
      content: content,
      metadata: metadata
    }
  end

  @doc "Extracts text content from a message"
  @spec text(t()) :: String.t() | nil
  def text(%__MODULE__{content: parts}) do
    Enum.find_value(parts, fn
      %ContentPart{type: :text, text: text} -> text
      _ -> nil
    end)
  end
end
