defmodule SwarmAi.Message do
  @moduledoc """
  Namespace for role-specific message structs used in the agentic loop.

  Messages form the conversation history passed to LLMs. Each role has its own
  struct so that invalid states (e.g. a system message with tool_calls) are
  unrepresentable at compile time.
  """

  alias SwarmAi.Message.{System, User, Assistant, Tool}
  alias SwarmAi.Message.ContentPart

  @type role :: :system | :user | :assistant | :tool
  @type t :: System.t() | User.t() | Assistant.t() | Tool.t()

  defguard is_message(msg)
           when is_struct(msg, System) or is_struct(msg, User) or
                  is_struct(msg, Assistant) or is_struct(msg, Tool)

  @doc "Derives the role atom from a message struct."
  @spec role(t()) :: role()
  def role(%System{}), do: :system
  def role(%User{}), do: :user
  def role(%Assistant{}), do: :assistant
  def role(%Tool{}), do: :tool

  @doc "Creates a system message from text or a list of content parts"
  @spec system(String.t() | [String.t() | ContentPart.t()]) :: System.t()
  def system(text) when is_binary(text) do
    %System{content: [ContentPart.text(text)]}
  end

  def system(parts) when is_list(parts) do
    content =
      Enum.map(parts, fn
        text when is_binary(text) -> ContentPart.text(text)
        %ContentPart{} = part -> part
      end)

    %System{content: content}
  end

  @doc "Creates a user message"
  @spec user(String.t()) :: User.t()
  def user(text) when is_binary(text) do
    %User{content: [ContentPart.text(text)]}
  end

  @doc "Creates an assistant message"
  @spec assistant(String.t() | nil, [SwarmAi.ToolCall.t()], map()) :: Assistant.t()
  def assistant(text, tool_calls \\ [], metadata \\ %{}) do
    %Assistant{
      content: [ContentPart.text(text || "")],
      tool_calls: tool_calls,
      metadata: metadata
    }
  end

  @doc "Creates a tool result message from content parts"
  @spec tool_result(String.t(), String.t(), [ContentPart.t()], map()) :: Tool.t()
  def tool_result(name, tool_call_id, content, metadata \\ %{}) when is_list(content) do
    %Tool{
      name: name,
      tool_call_id: tool_call_id,
      content: content,
      metadata: metadata
    }
  end

  @doc "Extracts text content from a message"
  @spec text(t()) :: String.t() | nil
  def text(%{content: parts}) do
    Enum.find_value(parts, fn
      %ContentPart{type: :text, text: text} -> text
      _ -> nil
    end)
  end
end
