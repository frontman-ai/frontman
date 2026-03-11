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

  # Tool call status constants — the single source of truth for ACP wire values.
  @tool_call_status_pending "pending"
  @tool_call_status_in_progress "in_progress"
  @tool_call_status_completed "completed"
  @tool_call_status_failed "failed"

  @tool_call_statuses [
    @tool_call_status_pending,
    @tool_call_status_in_progress,
    @tool_call_status_completed,
    @tool_call_status_failed
  ]

  # Plan entry priority constants
  @plan_priority_high "high"
  @plan_priority_medium "medium"
  @plan_priority_low "low"

  @plan_priorities [@plan_priority_high, @plan_priority_medium, @plan_priority_low]

  # Plan entry status constants
  @plan_status_pending "pending"
  @plan_status_in_progress "in_progress"
  @plan_status_completed "completed"

  @plan_statuses [@plan_status_pending, @plan_status_in_progress, @plan_status_completed]

  # Stop reason constants — the single source of truth for ACP wire values.
  @stop_reason_end_turn "end_turn"
  @stop_reason_max_tokens "max_tokens"
  @stop_reason_max_turn_requests "max_turn_requests"
  @stop_reason_refusal "refusal"
  @stop_reason_cancelled "cancelled"

  @stop_reasons [
    @stop_reason_end_turn,
    @stop_reason_max_tokens,
    @stop_reason_max_turn_requests,
    @stop_reason_refusal,
    @stop_reason_cancelled
  ]

  def tool_call_status_pending, do: @tool_call_status_pending
  def tool_call_status_in_progress, do: @tool_call_status_in_progress
  def tool_call_status_completed, do: @tool_call_status_completed
  def tool_call_status_failed, do: @tool_call_status_failed

  def stop_reason_end_turn, do: @stop_reason_end_turn
  def stop_reason_max_tokens, do: @stop_reason_max_tokens
  def stop_reason_max_turn_requests, do: @stop_reason_max_turn_requests
  def stop_reason_refusal, do: @stop_reason_refusal
  def stop_reason_cancelled, do: @stop_reason_cancelled

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
  def build_prompt_result(stop_reason) when stop_reason in @stop_reasons do
    %{"stopReason" => stop_reason}
  end

  @doc """
  Creates a new tool call notification (sessionUpdate: "tool_call").

  Used when the LLM first requests a tool invocation.

  Options:
    - `:parent_agent_id` - If present, indicates this tool call is from a sub-agent
    - `:spawning_tool_name` - Name of the tool that spawned this agent
  """
  def tool_call_create(
        session_id,
        tool_call_id,
        title,
        kind,
        status \\ @tool_call_status_pending,
        opts \\ []
      )
      when status in @tool_call_statuses do
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
  def tool_call_update(session_id, tool_call_id, status, content \\ nil)
      when status in @tool_call_statuses do
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

  defp validate_priority!(priority) when priority in @plan_priorities, do: :ok

  defp validate_priority!(priority),
    do:
      raise(
        ArgumentError,
        "priority must be one of: #{Enum.join(@plan_priorities, ", ")}, got: #{inspect(priority)}"
      )

  defp validate_status!(status) when status in @plan_statuses, do: :ok

  defp validate_status!(status),
    do:
      raise(
        ArgumentError,
        "status must be one of: #{Enum.join(@plan_statuses, ", ")}, got: #{inspect(status)}"
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
