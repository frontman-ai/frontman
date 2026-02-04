defmodule ModelContextProtocol do
  @moduledoc """
  MCP (Model Context Protocol) message builders and parsers.

  Provides MCP-specific request building and response parsing, composing
  the JsonRpc module for wire format. Similar to how the ACP module handles
  Agent Client Protocol messages.

  This module:
  - Builds MCP requests (initialize, tools/call)
  - Extracts data from MCP-specific response formats
  - Handles MCP content arrays and error flags
  - Parses structured tool results

  Use with JsonRpc for complete message handling.
  """

  @protocol_version "DRAFT-2025-v3"
  @client_name "frontman-server"
  @client_version "1.0.0"

  defmodule ToolCallParams do
    @moduledoc """
    Parameters for building an MCP tools/call request.
    """
    use TypedStruct

    typedstruct do
      field :request_id, integer(), enforce: true
      field :tool_name, String.t(), enforce: true
      field :arguments, map(), enforce: true
      field :call_id, String.t(), enforce: true
    end
  end

  def protocol_version, do: @protocol_version

  def client_info do
    %{
      "name" => @client_name,
      "version" => @client_version
    }
  end

  @doc """
  Returns params for an MCP initialize request.

  Use with `JsonRpc.request(id, "initialize", MCPProtocol.initialize_params())`.
  """
  def initialize_params do
    %{
      "protocolVersion" => @protocol_version,
      "capabilities" => %{},
      "clientInfo" => client_info()
    }
  end

  @doc """
  Extracts text content from MCP content array.

  MCP responses contain a content array with text blocks:
  %{"content" => [%{"type" => "text", "text" => "..."}]}
  """
  @spec extract_content_text(map()) :: String.t()
  def extract_content_text(%{"content" => content}) do
    Enum.map_join(content, "\n", fn
      %{"text" => text} -> text
      _ -> ""
    end)
  end

  def extract_content_text(_), do: ""

  @doc """
  Checks if MCP result indicates an error.
  """
  @spec error?(map()) :: boolean()
  def error?(%{"isError" => is_error}), do: is_error
  def error?(_), do: false

  @doc """
  Parses tool result text as JSON if possible, falls back to string.
  Preserves structured data like screenshots.
  """
  @spec parse_tool_result(String.t()) :: map() | String.t()
  def parse_tool_result(text_result) when is_binary(text_result) do
    case Jason.decode(text_result) do
      {:ok, parsed} when is_map(parsed) -> parsed
      _ -> text_result
    end
  end

  @doc """
  Builds an MCP tools/call request.

  Returns a JSON-RPC request ready to send to the MCP client.
  """
  @spec tools_call_request(ToolCallParams.t()) :: map()
  def tools_call_request(%ToolCallParams{} = params) do
    JsonRpc.request(params.request_id, "tools/call", %{
      "name" => params.tool_name,
      "arguments" => params.arguments,
      "callId" => params.call_id
    })
  end
end
