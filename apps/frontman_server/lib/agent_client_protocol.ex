defmodule AgentClientProtocol do
  @moduledoc """
  ACP (Agent Client Protocol) translation layer.

  Translates between domain events and ACP wire format (JSON-RPC 2.0).
  This is the boundary where domain concepts (Tasks) become transport
  concepts (Sessions).

  ACP is used for chat communication between the browser client and
  the agent server, separate from MCP which handles tool invocation.
  """

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
      "loadSession" => true,
      "mcpCapabilities" => %{"http" => false, "sse" => false, "websocket" => true},
      "promptCapabilities" => %{"image" => true, "audio" => false, "embeddedContext" => true}
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

  Session IDs are UUIDs. In ACP, sessions map 1:1 with domain Tasks.
  """
  def generate_session_id do
    Ecto.UUID.generate()
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

  Options:
    - `:parent_agent_id` - If present, indicates this tool call is from a sub-agent
    - `:spawning_tool_name` - Name of the tool that spawned this agent
  """
  def tool_call_create(session_id, tool_call_id, title, kind, status \\ "pending", opts \\ []) do
    parent_agent_id = Keyword.get(opts, :parent_agent_id)
    spawning_tool_name = Keyword.get(opts, :spawning_tool_name)

    update = %{
      "sessionUpdate" => "tool_call",
      "toolCallId" => tool_call_id,
      "title" => title,
      "kind" => kind,
      "status" => status
    }

    # Add parentAgentId if this is a sub-agent tool call
    update =
      if parent_agent_id do
        Map.put(update, "parentAgentId", parent_agent_id)
      else
        update
      end

    # Add spawningToolName if available (for sub-agent tool calls)
    update =
      if spawning_tool_name do
        Map.put(update, "spawningToolName", spawning_tool_name)
      else
        update
      end

    params = %{
      "sessionId" => session_id,
      "update" => update
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

  defp validate_priority!(priority),
    do:
      raise(
        ArgumentError,
        "priority must be one of: high, medium, low, got: #{inspect(priority)}"
      )

  defp validate_status!(status) when status in ["pending", "in_progress", "completed"], do: :ok

  defp validate_status!(status),
    do:
      raise(
        ArgumentError,
        "status must be one of: pending, in_progress, completed, got: #{inspect(status)}"
      )

  # Deprecated - use tool_call_create/6 instead
  def build_tool_call_notification(session_id, tool_call, status, opts \\ []) do
    tool_call_create(
      session_id,
      tool_call.tool_call_id,
      tool_call.tool_name,
      "other",
      status,
      opts
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

  @doc """
  Extracts text content from ACP prompt content blocks.

  Filters for text blocks and joins their text content with newlines.
  Used for logging and analysis of prompts.
  """
  @spec extract_text_content(list(map())) :: String.t()
  def extract_text_content(prompt_content) when is_list(prompt_content) do
    prompt_content
    |> Enum.filter(&(&1["type"] == "text"))
    |> Enum.map_join("\n", &(&1["text"] || ""))
  end

  def extract_text_content(_), do: ""

  @doc """
  Checks if prompt content includes embedded resources.

  Returns true if any content blocks are of type "resource_link" or "resource".
  These indicate the client has embedded context into the prompt.
  """
  @spec has_embedded_resources?(list(map())) :: boolean()
  def has_embedded_resources?(prompt_content) when is_list(prompt_content) do
    Enum.any?(prompt_content, fn block ->
      block["type"] in ["resource_link", "resource"]
    end)
  end

  def has_embedded_resources?(_), do: false

  @doc """
  Parses ACP session/prompt params into a structured format.

  Returns a map with:
  - `content`: The full ACP content blocks (for passing to agent)
  - `text_summary`: Extracted text for logging
  - `has_resources`: Whether embedded resources are present
  """
  @spec parse_prompt_params(map()) :: %{
          content: list(map()),
          text_summary: String.t(),
          has_resources: boolean()
        }
  def parse_prompt_params(%{"prompt" => content}) do
    %{
      content: content,
      text_summary: extract_text_content(content),
      has_resources: has_embedded_resources?(content)
    }
  end

  def parse_prompt_params(_params) do
    %{
      content: [],
      text_summary: "",
      has_resources: false
    }
  end
end
