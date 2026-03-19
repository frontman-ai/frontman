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

  # Channel event names — the single source of truth for Phoenix channel events.
  @event_acp_message "acp:message"
  @event_config_options_updated "config_options_updated"
  @event_title_updated "title_updated"
  @event_list_sessions "list_sessions"
  @event_delete_session "delete_session"

  # ACP method names — the single source of truth for JSON-RPC method strings.
  @method_initialize "initialize"
  @method_session_new "session/new"
  @method_session_load "session/load"
  @method_session_prompt "session/prompt"
  @method_session_cancel "session/cancel"
  @method_session_update "session/update"

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

  # Channel event accessors
  def event_acp_message, do: @event_acp_message
  def event_config_options_updated, do: @event_config_options_updated
  def event_title_updated, do: @event_title_updated
  def event_list_sessions, do: @event_list_sessions
  def event_delete_session, do: @event_delete_session

  # Method name accessors
  def method_initialize, do: @method_initialize
  def method_session_new, do: @method_session_new
  def method_session_load, do: @method_session_load
  def method_session_prompt, do: @method_session_prompt
  def method_session_cancel, do: @method_session_cancel
  def method_session_update, do: @method_session_update

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
  Translates domain model config data into ACP SessionConfigOption format.

  Receives the output of `Providers.model_config_data/2` — a domain DTO
  containing model groups and a default model — and serializes it into
  the ACP wire format.  This function has no knowledge of provider
  internals; all domain logic is encapsulated in the Providers context.
  """
  def build_model_config_options(%{groups: groups, default_model: default_model}) do
    [
      %{
        "type" => "select",
        "id" => "model",
        "name" => "Model",
        "category" => "model",
        "currentValue" => default_model,
        "options" =>
          Enum.map(groups, fn %{id: id, name: name, options: options} ->
            %{
              "group" => id,
              "name" => name,
              "options" =>
                Enum.map(options, fn %{name: display_name, value: value} ->
                  %{"value" => value, "name" => display_name}
                end)
            }
          end)
      }
    ]
  end

  @doc """
  Builds session/new result payload with optional config options.
  """
  def build_session_new_result(session_id, config_options \\ []) do
    result = %{"sessionId" => session_id}

    case config_options do
      [] -> result
      opts when is_list(opts) -> Map.put(result, "configOptions", opts)
    end
  end

  @doc """
  Builds session/load result payload with optional config options.
  """
  def build_session_load_result(config_options \\ []) do
    case config_options do
      [] -> %{}
      opts when is_list(opts) -> %{"configOptions" => opts}
    end
  end

  @doc """
  Builds a session summary for the list_sessions channel response.

  Translates a domain Task into ACP wire format. The channel should not
  build this map directly.
  """
  def build_session_summary(task) do
    %{
      "sessionId" => task.id,
      "title" => task.short_desc,
      "createdAt" => DateTime.to_iso8601(task.inserted_at),
      "updatedAt" => DateTime.to_iso8601(task.updated_at)
    }
  end

  @doc """
  Builds the payload for a config_options_updated channel push.
  """
  def build_config_options_updated_payload(config_options) when is_list(config_options) do
    %{"configOptions" => config_options}
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
  def build_agent_message_chunk_notification(session_id, text, timestamp) do
    params = %{
      "sessionId" => session_id,
      "update" => %{
        "sessionUpdate" => "agent_message_chunk",
        "content" => %{
          "type" => "text",
          "text" => text
        },
        "timestamp" => DateTime.to_iso8601(timestamp)
      }
    }

    JsonRpc.notification(@method_session_update, params)
  end

  @doc """
  Builds a user_message_chunk session/update notification.

  Used during history replay to send stored user messages back to the client.
  """
  def build_user_message_chunk_notification(session_id, text, timestamp) do
    params = %{
      "sessionId" => session_id,
      "update" => %{
        "sessionUpdate" => "user_message_chunk",
        "content" => %{
          "type" => "text",
          "text" => text
        },
        "timestamp" => DateTime.to_iso8601(timestamp)
      }
    }

    JsonRpc.notification(@method_session_update, params)
  end

  @doc """
  Builds an agent_turn_complete session/update notification.

  Sent when the agent finishes a turn that was resumed via elicitation response
  (not via session/prompt), so there is no pending JSON-RPC request to respond to.
  The client uses this to finalize the streaming message and reset the agent-running state.
  """
  def build_agent_turn_complete_notification(session_id, stop_reason) do
    params = %{
      "sessionId" => session_id,
      "update" => %{
        "sessionUpdate" => "agent_turn_complete",
        "stopReason" => stop_reason
      }
    }

    JsonRpc.notification(@method_session_update, params)
  end

  @doc """
  Builds an error session/update notification.

  Sent when the agent encounters an error. Always delivered as a notification
  so the client can display it regardless of whether a pending prompt exists.
  """
  def build_error_notification(session_id, message) do
    params = %{
      "sessionId" => session_id,
      "update" => %{
        "sessionUpdate" => "error",
        "message" => message
      }
    }

    JsonRpc.notification(@method_session_update, params)
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
        timestamp,
        status \\ @tool_call_status_pending,
        opts \\ []
      )
      when status in @tool_call_statuses do
    optional =
      opts
      |> Keyword.take([:parent_agent_id, :spawning_tool_name])
      |> Enum.reduce(%{}, fn
        {:parent_agent_id, v}, acc when not is_nil(v) -> Map.put(acc, "parentAgentId", v)
        {:spawning_tool_name, v}, acc when not is_nil(v) -> Map.put(acc, "spawningToolName", v)
        _, acc -> acc
      end)

    update =
      Map.merge(
        %{
          "sessionUpdate" => "tool_call",
          "toolCallId" => tool_call_id,
          "title" => title,
          "kind" => kind,
          "status" => status,
          "timestamp" => DateTime.to_iso8601(timestamp)
        },
        optional
      )

    JsonRpc.notification(@method_session_update, %{
      "sessionId" => session_id,
      "update" => update
    })
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

    JsonRpc.notification(@method_session_update, params)
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

    JsonRpc.notification(@method_session_update, params)
  end

  defp validate_plan_entries!(entries) when is_list(entries) do
    Enum.each(entries, &validate_plan_entry!/1)
  end

  defp validate_plan_entries!(_), do: raise(ArgumentError, "entries must be a list")

  defp validate_plan_entry!(%{
         "content" => content,
         "priority" => priority,
         "status" => status
       })
       when is_binary(content) and priority in @plan_priorities and status in @plan_statuses do
    :ok
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

  # ---------------------------------------------------------------------------
  # Elicitation (session/elicitation)
  # ---------------------------------------------------------------------------

  @doc """
  Builds a form-mode `session/elicitation` JSON-RPC request.

  The server sends this to the client when an interactive tool (e.g. `question`)
  needs user input. The client renders a form from `requested_schema` and responds
  with a standard JSON-RPC response containing `{action, content}`.
  """
  def build_form_elicitation_request(id, session_id, message, requested_schema) do
    JsonRpc.request(id, "session/elicitation", %{
      "sessionId" => session_id,
      "mode" => "form",
      "message" => message,
      "requestedSchema" => requested_schema
    })
  end

  @doc """
  Builds a URL-mode `session/elicitation` JSON-RPC request.

  Used for out-of-band flows (OAuth, payments, credential collection) where
  sensitive data must bypass the agent. The client opens the URL in a secure
  browser context; the user's interaction happens entirely out-of-band.

  `elicitation_id` correlates with a later `notifications/elicitation/complete`
  notification so the client knows when the flow finished.
  """
  def build_url_elicitation_request(id, session_id, message, elicitation_id, url) do
    JsonRpc.request(id, "session/elicitation", %{
      "sessionId" => session_id,
      "mode" => "url",
      "message" => message,
      "elicitationId" => elicitation_id,
      "url" => url
    })
  end

  @doc """
  Builds a `notifications/elicitation/complete` notification.

  Sent by the agent when an out-of-band URL-mode interaction has completed.
  The client may use this to retry a previously failed request or update the UI.
  """
  def build_elicitation_complete_notification(elicitation_id) do
    JsonRpc.notification("notifications/elicitation/complete", %{
      "elicitationId" => elicitation_id
    })
  end

  @doc """
  Converts question tool arguments into a flat JSON Schema object suitable
  for `session/elicitation`'s `requestedSchema`.

  Each question `i` produces two schema properties:
  - `q{i}_answer` — an enum (single-select) or array-of-enums (multi-select)
  - `q{i}_custom` — a free-text string for "Type your own answer"

  ## Examples

      questions = [
        %{"header" => "Framework", "question" => "Which?", "multiple" => false,
          "options" => [%{"label" => "React", "description" => "A UI library"}]}
      ]
      ACP.question_to_elicitation_schema(questions)
      #=> %{"type" => "object", "properties" => %{...}, "required" => []}
  """
  def question_to_elicitation_schema(questions) when is_list(questions) do
    properties =
      questions
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {%{
                                "header" => header,
                                "question" => description,
                                "options" => options
                              } = question, i},
                             acc ->
        multiple = Map.get(question, "multiple", false)

        one_of_entries = Enum.map(options, &option_to_schema_entry/1)

        answer_prop =
          if multiple do
            %{
              "type" => "array",
              "title" => header,
              "description" => description,
              "items" => %{"anyOf" => one_of_entries}
            }
          else
            %{
              "type" => "string",
              "title" => header,
              "description" => description,
              "oneOf" => one_of_entries
            }
          end

        custom_prop = %{
          "type" => "string",
          "title" => "Type your own answer"
        }

        acc
        |> Map.put("q#{i}_answer", answer_prop)
        |> Map.put("q#{i}_custom", custom_prop)
      end)

    %{
      "type" => "object",
      "properties" => properties,
      "required" => []
    }
  end

  defp option_to_schema_entry(%{"label" => label, "description" => desc}) do
    title =
      if desc in ["", nil] do
        label
      else
        "#{label} - #{desc}"
      end

    %{"const" => label, "title" => title}
  end

  @doc """
  Parses the `result` field from a `session/elicitation` JSON-RPC response.

  Returns `{action, content}` where action is `"accept"`, `"decline"`, or `"cancel"`,
  and content is the form data map (or `nil` for decline/cancel).
  """
  def parse_elicitation_response(%{"action" => action, "content" => content}) do
    {action, content}
  end

  def parse_elicitation_response(%{"action" => action}) do
    {action, nil}
  end

  @doc """
  Maps flat elicitation answer properties back to the `toolOutput` format
  expected by the LLM.

  Given the `content` map from the client response (e.g. `%{"q0_answer" => "React"}`)
  and the original questions list, produces:

      %{
        "answers" => [%{"question" => "...", "answer" => [...]}],
        "skippedAll" => false,
        "cancelled" => false
      }
  """
  def elicitation_content_to_tool_output("accept", content, questions)
      when is_map(content) and is_list(questions) do
    answers =
      questions
      |> Enum.with_index()
      |> Enum.map(fn {%{"question" => question_text}, i} ->
        raw_answer = Map.get(content, "q#{i}_answer")
        custom_answer = Map.get(content, "q#{i}_custom")

        answer_values =
          case raw_answer do
            list when is_list(list) -> list
            val when is_binary(val) and val != "" -> [val]
            _ -> []
          end

        # Append custom answer if provided
        answer_values =
          case custom_answer do
            val when is_binary(val) and val != "" -> answer_values ++ [val]
            _ -> answer_values
          end

        %{"question" => question_text, "answer" => answer_values}
      end)

    %{"answers" => answers, "skippedAll" => false, "cancelled" => false}
  end

  def elicitation_content_to_tool_output(action, _content, questions)
      when action in ["decline", "cancel"] and is_list(questions) do
    null_answers =
      Enum.map(questions, fn %{"question" => question_text} ->
        %{"question" => question_text, "answer" => nil}
      end)

    %{
      "answers" => null_answers,
      "skippedAll" => action == "decline",
      "cancelled" => action == "cancel"
    }
  end
end
