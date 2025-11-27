defmodule FrontmanServerWeb.ACP do
  @moduledoc """
  ACP (Agent Client Protocol) translation layer.

  Translates between domain events and ACP wire format (JSON-RPC 2.0).
  This is the boundary where domain concepts (Tasks) become transport
  concepts (Sessions).

  ACP is used for chat communication between the browser client and
  the agent server, separate from MCP which handles tool invocation.
  """

  alias FrontmanServerWeb.JsonRpc

  @protocol_version 1

  def protocol_version, do: @protocol_version

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
  Generates ACP session ID.

  Session IDs are prefixed with "sess_" to distinguish them from other IDs.
  In ACP, sessions map 1:1 with domain Tasks.
  """
  def generate_session_id do
    "sess_" <> Base.encode16(:crypto.strong_rand_bytes(12), case: :lower)
  end

  @doc """
  Builds a session/update notification for agent_message_chunk.

  Translates a text chunk into ACP wire format.
  """
  def build_agent_message_chunk_notification(session_id, text) do
    params = %{
      "sessionId" => session_id,
      "update" => %{
        "sessionUpdate" => "agent_message_chunk",
        "content" => %{
          "type" => "text",
          "text" => text
        }
      }
    }

    JsonRpc.notification("session/update", params)
  end

  @doc """
  Builds a session/prompt response with stop reason.
  """
  def build_prompt_result(stop_reason) do
    %{"stopReason" => stop_reason}
  end

  @doc """
  Builds a session/update notification for a tool call.
  """
  def build_tool_call_notification(session_id, tool_call, status) do
    params = %{
      "sessionId" => session_id,
      "update" => %{
        "sessionUpdate" => "tool_call",
        "toolCallId" => tool_call.tool_call_id,
        "title" => "Calling #{tool_call.tool_name}",
        "kind" => "other",
        "status" => status
      }
    }

    JsonRpc.notification("session/update", params)
  end

  @doc """
  Builds a session/update notification for a tool call status update.
  """
  def build_tool_call_update_notification(session_id, tool_call_id, status, content \\ nil) do
    update = %{
      "sessionUpdate" => "tool_call_update",
      "toolCallId" => tool_call_id,
      "status" => status
    }

    update =
      if content do
        Map.put(update, "content", [
          %{"type" => "content", "content" => %{"type" => "text", "text" => content}}
        ])
      else
        update
      end

    params = %{
      "sessionId" => session_id,
      "update" => update
    }

    JsonRpc.notification("session/update", params)
  end
end
