defmodule FrontmanServer.ACP do
  @moduledoc """
  ACP (Agent Client Protocol) context.

  Handles the initialization handshake and protocol negotiation between
  the browser client and the agent server. ACP is used for chat communication,
  separate from MCP which handles tool invocation.
  """

  @protocol_version 1

  # JSON-RPC 2.0 error codes
  @error_invalid_request -32600
  @error_method_not_found -32601
  @error_invalid_params -32602
  @error_internal -32603

  def protocol_version, do: @protocol_version

  def error_invalid_request, do: @error_invalid_request
  def error_method_not_found, do: @error_method_not_found
  def error_invalid_params, do: @error_invalid_params
  def error_internal, do: @error_internal

  def agent_info do
    %{
      "name" => "frontman-server",
      "version" => "1.0.0",
      "title" => "Frontman Agent Server"
    }
  end

  def agent_capabilities do
    %{
      "loadSession" => false,
      "mcpCapabilities" => %{"http" => false, "sse" => false, "websocket" => true},
      "promptCapabilities" => %{"image" => false, "audio" => false, "embeddedContext" => false}
    }
  end

  @doc """
  Builds the initialize response result.
  """
  def build_initialize_result do
    %{
      "protocolVersion" => @protocol_version,
      "agentCapabilities" => agent_capabilities(),
      "agentInfo" => agent_info(),
      "authMethods" => []
    }
  end

  @doc """
  Builds session/new result payload.
  """
  def build_session_new_result(session_id) do
    %{"sessionId" => session_id}
  end

  @doc """
  Generates ACP session ID (used as task_id).
  """
  def generate_session_id do
    "sess_" <> Base.encode16(:crypto.strong_rand_bytes(12), case: :lower)
  end

  @doc """
  Builds a session/update notification for agent_message_chunk.
  """
  def build_agent_message_chunk_update(session_id, text) do
    %{
      "jsonrpc" => "2.0",
      "method" => "session/update",
      "params" => %{
        "sessionId" => session_id,
        "update" => %{
          "sessionUpdate" => "agent_message_chunk",
          "content" => %{
            "type" => "text",
            "text" => text
          }
        }
      }
    }
  end

  @doc """
  Builds a session/prompt response with stop reason.
  """
  def build_prompt_result(stop_reason) do
    %{"stopReason" => stop_reason}
  end
end
