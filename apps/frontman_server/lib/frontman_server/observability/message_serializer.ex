defmodule FrontmanServer.Observability.MessageSerializer do
  @moduledoc """
  Serializes ReqLLM messages to OpenTelemetry GenAI format.

  Follows OTel GenAI semantic conventions for message structure:
  - Input messages: Array of {role, content} pairs
  - Output messages: Assistant response with tool_calls if present
  """

  @doc """
  Serializes input messages to OTel GenAI format.

  Returns a list of maps with "role" and "content" keys.
  """
  @spec serialize_input(list()) :: list(map())
  def serialize_input(messages) when is_list(messages) do
    Enum.map(messages, &serialize_message/1)
  end

  @doc """
  Serializes output (assistant response) to OTel GenAI format.

  Includes tool_calls when present.
  """
  @spec serialize_output(String.t(), list()) :: list(map())
  def serialize_output(text, tool_calls) when is_binary(text) do
    base = %{"role" => "assistant", "content" => text}

    if Enum.empty?(tool_calls) do
      [base]
    else
      tool_calls_data =
        Enum.map(tool_calls, fn tc ->
          %{
            "id" => tc.id,
            "type" => "function",
            "function" => %{
              "name" => tc.tool_name,
              "arguments" => Jason.encode!(tc.arguments)
            }
          }
        end)

      [Map.put(base, "tool_calls", tool_calls_data)]
    end
  end

  # Serialize different message formats

  defp serialize_message(%ReqLLM.Message{role: role, content: content}) do
    %{
      "role" => to_string(role),
      "content" => serialize_content(content)
    }
  end

  defp serialize_message(%{role: role, content: content}) do
    %{
      "role" => to_string(role),
      "content" => serialize_content(content)
    }
  end

  defp serialize_message(msg) when is_map(msg) do
    role = Map.get(msg, :role) || Map.get(msg, "role") || "unknown"
    content = Map.get(msg, :content) || Map.get(msg, "content") || ""

    %{
      "role" => to_string(role),
      "content" => serialize_content(content)
    }
  end

  # Serialize content (can be string or list of content parts)

  defp serialize_content(content) when is_binary(content), do: content

  defp serialize_content(content) when is_list(content) do
    content
    |> Enum.map(&serialize_content_part/1)
    |> Enum.join("\n")
  end

  defp serialize_content(nil), do: ""

  defp serialize_content_part(%ReqLLM.Message.ContentPart{type: :text, text: text}), do: text
  defp serialize_content_part(%{type: :text, text: text}), do: text
  defp serialize_content_part(%{"type" => "text", "text" => text}), do: text
  defp serialize_content_part(_), do: "[non-text content]"
end
