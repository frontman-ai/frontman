defmodule ModelContextProtocol do
  use Boundary, deps: [JsonRpc], exports: :all

  require Logger

  @protocol_version "DRAFT-2025-v3"
  @client_name "frontman-server"
  @client_version "1.0.0"

  defmodule ToolCallParams do
    @enforce_keys [:request_id, :tool_name, :arguments, :call_id]
    defstruct request_id: nil,
              tool_name: nil,
              arguments: nil,
              call_id: nil
  end

  def protocol_version, do: @protocol_version

  def client_info do
    %{
      "name" => @client_name,
      "version" => @client_version
    }
  end

  @spec tool_result_text(String.t()) :: map()
  def tool_result_text(text) when is_binary(text) do
    %{"content" => [%{"type" => "text", "text" => text}], "isError" => false}
  end

  @spec tool_result_json(map()) :: map()
  def tool_result_json(value) when is_map(value) do
    tool_result_text(Jason.encode!(value))
  end

  @spec tool_result_image(String.t(), String.t()) :: map()
  def tool_result_image(data, mime_type) when is_binary(data) and is_binary(mime_type) do
    %{
      "content" => [%{"type" => "image", "data" => data, "mimeType" => mime_type}],
      "isError" => false
    }
  end

  @spec tool_result_error(String.t()) :: map()
  def tool_result_error(text) when is_binary(text) do
    %{"content" => [%{"type" => "text", "text" => text}], "isError" => true}
  end

  def initialize_params do
    %{
      "protocolVersion" => @protocol_version,
      "capabilities" => %{},
      "clientInfo" => client_info()
    }
  end

  def extract_content_text(%{"content" => content}) do
    Enum.map_join(content, "\n", fn
      %{"text" => text} -> text
      _ -> ""
    end)
  end

  def extract_content_text(_), do: ""

  def error?(%{"isError" => is_error}), do: is_error
  def error?(_), do: false

  def build_tool_execution(%ToolCallParams{} = params) do
    Logger.info("MCP tool call: #{params.tool_name} arguments=#{inspect(params.arguments)}")

    JsonRpc.request(params.request_id, "tools/call", %{
      "name" => params.tool_name,
      "arguments" => params.arguments,
      "callId" => params.call_id
    })
  end
end
