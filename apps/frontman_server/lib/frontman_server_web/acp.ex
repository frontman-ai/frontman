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
      "promptCapabilities" => %{"image" => false, "audio" => false, "embeddedContext" => true}
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
  Per ACP spec: The first agent_message_chunk implicitly signals message start.
  Message end is signaled by the session/prompt response with stopReason.
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
  Creates a new tool call notification (sessionUpdate: "tool_call").

  Used when the LLM first requests a tool invocation.
  """
  def tool_call_create(session_id, tool_call_id, title, kind, status \\ "pending") do
    params = %{
      "sessionId" => session_id,
      "update" => %{
        "sessionUpdate" => "tool_call",
        "toolCallId" => tool_call_id,
        "title" => title,
        "kind" => kind,
        "status" => status
      }
    }

    JsonRpc.notification("session/update", params)
  end

  @doc """
  Updates an existing tool call (sessionUpdate: "tool_call_update").

  Content should be an array of ACP content blocks if provided.
  Per ACP spec: "All fields except toolCallId are optional in updates"
  """
  def tool_call_update(session_id, tool_call_id, status, content \\ nil) do
    update = %{
      "sessionUpdate" => "tool_call_update",
      "toolCallId" => tool_call_id,
      "status" => status
    }

    update = if content, do: Map.put(update, "content", content), else: update

    params = %{
      "sessionId" => session_id,
      "update" => update
    }

    JsonRpc.notification("session/update", params)
  end

  @doc """
  Creates or updates a plan notification (sessionUpdate: "plan").

  Sends a complete list of all plan entries to the client. Per ACP spec,
  the Agent MUST send a complete list of all plan entries in each update,
  and the Client MUST replace the current plan completely.

  ## Parameters
    - `session_id` - The ACP session ID
    - `entries` - List of plan entry maps with required fields:
      - `content` (string): Human-readable description
      - `priority` (string): "high", "medium", or "low"
      - `status` (string): "pending", "in_progress", or "completed"

  ## Example
      entries = [
        %{
          "content" => "Analyze the existing codebase structure",
          "priority" => "high",
          "status" => "pending"
        }
      ]
      ACP.plan_update(session_id, entries)
  """
  def plan_update(session_id, entries) do
    validate_plan_entries!(entries)

    params = %{
      "sessionId" => session_id,
      "update" => %{
        "sessionUpdate" => "plan",
        "entries" => entries
      }
    }

    JsonRpc.notification("session/update", params)
  end

  defp validate_plan_entries!(entries) when is_list(entries) do
    Enum.each(entries, &validate_plan_entry!/1)
  end

  defp validate_plan_entries!(_), do: raise(ArgumentError, "entries must be a list")

  defp validate_plan_entry!(entry) when is_map(entry) do
    validate_required_field!(entry, "content")
    validate_required_field!(entry, "priority")
    validate_required_field!(entry, "status")
    validate_priority!(entry["priority"])
    validate_status!(entry["status"])
  end

  defp validate_plan_entry!(_), do: raise(ArgumentError, "each entry must be a map")

  defp validate_required_field!(entry, field) do
    unless Map.has_key?(entry, field) and entry[field] != nil do
      raise ArgumentError, "plan entry must have #{field} field"
    end
  end

  defp validate_priority!(priority) when priority in ["high", "medium", "low"], do: :ok
  defp validate_priority!(priority), do: raise(ArgumentError, "priority must be one of: high, medium, low, got: #{inspect(priority)}")

  defp validate_status!(status) when status in ["pending", "in_progress", "completed"], do: :ok
  defp validate_status!(status), do: raise(ArgumentError, "status must be one of: pending, in_progress, completed, got: #{inspect(status)}")

  @doc """
  Converts domain todos to ACP plan entries format.
  Uses "medium" as default priority since todos have no priority concept.
  """
  @spec todos_to_plan_entries(list(FrontmanServer.Tasks.Todos.Todo.t())) :: list(map())
  def todos_to_plan_entries(todos) when is_list(todos) do
    todos
    |> Enum.sort_by(& &1.created_at, DateTime)
    |> Enum.map(&todo_to_plan_entry/1)
  end

  defp todo_to_plan_entry(todo) do
    %{
      "content" => todo.content,
      "priority" => "medium",
      "status" => Atom.to_string(todo.status)
    }
  end

  # Deprecated - use tool_call_create/5 instead
  def build_tool_call_notification(session_id, tool_call, status) do
    tool_call_create(
      session_id,
      tool_call.tool_call_id,
      "Calling #{tool_call.tool_name}",
      "other",
      status
    )
  end

  # Deprecated - use tool_call_update/4 instead
  def build_tool_call_update_notification(session_id, tool_call_id, status, content \\ nil) do
    formatted_content =
      if content do
        [%{"type" => "content", "content" => %{"type" => "text", "text" => content}}]
      else
        nil
      end

    tool_call_update(session_id, tool_call_id, status, formatted_content)
  end

  # Deprecated - use tool_call_update/4 instead
  def build_tool_call_update_notification_with_structured_content(
        session_id,
        tool_call_id,
        status,
        structured_content
      ) do
    content = [%{"type" => "content", "content" => structured_content}]
    tool_call_update(session_id, tool_call_id, status, content)
  end
end
