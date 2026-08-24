# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule ModelContextProtocol do
  @moduledoc """
  MCP (Model Context Protocol) message builders and parsers.

  Provides MCP-specific request building and response parsing, composing
  the JsonRpc module for wire format. Similar to how the ACP module handles
  Agent Client Protocol messages.

  This module:
  - Builds MCP requests (server/discover, tools/list, tools/call)
  - Extracts data from MCP-specific response formats
  - Handles MCP content arrays and error flags

  Use with JsonRpc for complete message handling.
  """

  use Boundary, deps: [JsonRpc], exports: :all

  require Logger

  @protocol_version "2026-07-28"
  @execution_context_extension "ai.frontman/execution-context"
  @client_name "frontman-server"
  @client_version "1.0.0"

  defmodule ToolCallParams do
    @moduledoc """
    Parameters for building an MCP tools/call request.
    """

    @enforce_keys [:request_id, :tool_name, :arguments, :task_id, :call_id]
    defstruct request_id: nil,
              tool_name: nil,
              arguments: nil,
              task_id: nil,
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
    %{
      "resultType" => "complete",
      "content" => [%{"type" => "text", "text" => text}],
      "isError" => false
    }
  end

  @spec tool_result_json(map()) :: map()
  def tool_result_json(value) when is_map(value) do
    tool_result_text(Jason.encode!(value))
  end

  @spec tool_result_image(String.t(), String.t()) :: map()
  def tool_result_image(data, mime_type) when is_binary(data) and is_binary(mime_type) do
    %{
      "content" => [%{"type" => "image", "data" => data, "mimeType" => mime_type}],
      "resultType" => "complete",
      "isError" => false
    }
  end

  @spec tool_result_error(String.t()) :: map()
  def tool_result_error(text) when is_binary(text) do
    %{
      "resultType" => "complete",
      "content" => [%{"type" => "text", "text" => text}],
      "isError" => true
    }
  end

  @doc """
  Returns params for MCP discovery and list requests.
  """
  @spec request_params() :: map()
  def request_params, do: %{"_meta" => request_meta()}

  @doc """
  Extracts text content from MCP content array.

  MCP responses contain a content array with text blocks:
  %{"content" => [%{"type" => "text", "text" => "..."}]}
  """
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
  def error?(%{"isError" => is_error}), do: is_error
  def error?(_), do: false

  @doc """
  Builds an MCP tool execution request.

  Uses an integer JSON-RPC request id for protocol correlation. Task and call
  identifiers are carried by the negotiated execution-context extension.
  """
  def build_tool_execution(%ToolCallParams{} = params) do
    Logger.info("MCP tool call: #{params.tool_name}")

    JsonRpc.request(params.request_id, "tools/call", %{
      "name" => params.tool_name,
      "arguments" => params.arguments,
      "_meta" =>
        Map.put(request_meta(), @execution_context_extension, %{
          "taskId" => params.task_id,
          "callId" => params.call_id
        })
    })
  end

  defp request_meta do
    %{
      "io.modelcontextprotocol/protocolVersion" => @protocol_version,
      "io.modelcontextprotocol/clientCapabilities" => %{
        "extensions" => %{@execution_context_extension => %{"version" => 1}}
      },
      "io.modelcontextprotocol/clientInfo" => client_info()
    }
  end
end
