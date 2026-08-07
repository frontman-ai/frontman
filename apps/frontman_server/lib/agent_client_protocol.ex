defmodule AgentClientProtocol do
  use Boundary,
    deps: [JsonRpc, FrontmanServer],
    exports: :all

  alias FrontmanServer.Agents.Agent

  @protocol_version 1
  @agent_attribution_version 1
  @extension_namespace "frontman.dev"
  @invalid_agent_attribution_capability {:error,
                                         "Invalid Frontman agent attribution capability metadata"}
  @agent_id_metadata_key "#{@extension_namespace}/agentId"
  @agent_error_id_metadata_key "#{@extension_namespace}/agentErrorId"
  @timestamp_metadata_key "#{@extension_namespace}/timestamp"

  @event_acp_message "acp:message"
  @event_config_options_updated "config_options_updated"
  @event_title_updated "title_updated"
  @event_list_sessions "list_sessions"
  @event_delete_session "delete_session"

  @method_initialize "initialize"
  @method_session_new "session/new"
  @method_session_load "session/load"
  @method_session_prompt "session/prompt"
  @method_session_cancel "session/cancel"
  @method_session_update "session/update"

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

  @plan_priority_high "high"
  @plan_priority_medium "medium"
  @plan_priority_low "low"

  @plan_priorities [@plan_priority_high, @plan_priority_medium, @plan_priority_low]

  @plan_status_pending "pending"
  @plan_status_in_progress "in_progress"
  @plan_status_completed "completed"

  @plan_statuses [@plan_status_pending, @plan_status_in_progress, @plan_status_completed]

  @stop_reason_end_turn "end_turn"
  @stop_reason_max_tokens "max_tokens"
  @stop_reason_max_turn_requests "max_turn_requests"
  @stop_reason_refusal "refusal"
  @stop_reason_cancelled "cancelled"

  def tool_call_status_pending, do: @tool_call_status_pending
  def tool_call_status_in_progress, do: @tool_call_status_in_progress
  def tool_call_status_completed, do: @tool_call_status_completed
  def tool_call_status_failed, do: @tool_call_status_failed
  def tool_call_status(false), do: @tool_call_status_completed
  def tool_call_status(true), do: @tool_call_status_failed

  def stop_reason_end_turn, do: @stop_reason_end_turn
  def stop_reason_max_tokens, do: @stop_reason_max_tokens
  def stop_reason_max_turn_requests, do: @stop_reason_max_turn_requests
  def stop_reason_refusal, do: @stop_reason_refusal
  def stop_reason_cancelled, do: @stop_reason_cancelled

  def protocol_version, do: @protocol_version

  def event_acp_message, do: @event_acp_message
  def event_config_options_updated, do: @event_config_options_updated
  def event_title_updated, do: @event_title_updated
  def event_list_sessions, do: @event_list_sessions
  def event_delete_session, do: @event_delete_session

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

  def agent_capabilities(agents, default_agent_id)
      when is_list(agents) and is_binary(default_agent_id) do
    %{
      "loadSession" => true,
      "mcpCapabilities" => %{"http" => false, "sse" => false, "websocket" => true},
      "promptCapabilities" => %{"image" => true, "audio" => false, "embeddedContext" => true},
      "_meta" => %{
        @extension_namespace => %{
          "agentAttribution" => %{"version" => @agent_attribution_version},
          "agents" => build_agent_catalog(agents),
          "defaultAgentId" => default_agent_id
        }
      }
    }
  end

  def negotiate_agent_attribution_version(nil), do: {:ok, nil}

  def negotiate_agent_attribution_version(%{} = capabilities) do
    with {:ok, metadata} <- optional_map(capabilities, "_meta"),
         {:ok, namespace} <- optional_map(metadata, @extension_namespace),
         {:ok, advertisement} <- optional_map(namespace, "agentAttribution") do
      case Map.fetch(advertisement, "version") do
        {:ok, @agent_attribution_version} -> {:ok, @agent_attribution_version}
        {:ok, version} when version in 1..65_535 -> {:ok, nil}
        _invalid -> @invalid_agent_attribution_capability
      end
    else
      :absent -> {:ok, nil}
      :invalid -> @invalid_agent_attribution_capability
    end
  end

  def negotiate_agent_attribution_version(_invalid), do: @invalid_agent_attribution_capability

  def build_initialize_result(agents, default_agent_id)
      when is_list(agents) and is_binary(default_agent_id) do
    %{
      "protocolVersion" => @protocol_version,
      "agentCapabilities" => agent_capabilities(agents, default_agent_id),
      "agentInfo" => agent_info(),
      "authMethods" => []
    }
  end

  defp optional_map(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} when is_map(value) -> {:ok, value}
      {:ok, _invalid} -> :invalid
      :error -> :absent
    end
  end

  def build_model_config_options(%{groups: groups}) do
    [
      %{
        "type" => "select",
        "id" => "model",
        "name" => "Model",
        "category" => "model",
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

  def build_agent_catalog(agents) when is_list(agents) do
    Enum.map(agents, &agent_entry/1)
  end

  def build_session_new_result(session_id, config_options) when is_list(config_options) do
    %{"sessionId" => session_id}
    |> put_config_options(config_options)
  end

  def build_session_load_result(config_options) when is_list(config_options) do
    %{}
    |> put_config_options(config_options)
  end

  defp agent_entry(%Agent{} = agent) do
    %{
      "id" => agent.id,
      "name" => agent.name,
      "displayName" => agent.display_name,
      "description" => agent.description,
      "color" => agent.color
    }
  end

  defp put_config_options(result, []), do: result

  defp put_config_options(result, config_options),
    do: Map.put(result, "configOptions", config_options)

  def build_session_summary(task) do
    %{
      "sessionId" => task.id,
      "title" => task.short_desc,
      "createdAt" => DateTime.to_iso8601(task.inserted_at),
      "updatedAt" => DateTime.to_iso8601(task.updated_at)
    }
  end

  def build_config_options_updated_payload(config_options) when is_list(config_options) do
    %{"configOptions" => config_options}
  end

  def generate_session_id do
    Ecto.UUID.generate()
  end

  def build_agent_message_chunk_notification(
        session_id,
        text,
        timestamp,
        message_id,
        agent_id
      ) do
    session_update_notification(session_id, %{
      "sessionUpdate" => "agent_message_chunk",
      "messageId" => message_id,
      "content" => %{"type" => "text", "text" => text},
      "_meta" => message_metadata(agent_id, timestamp)
    })
  end

  def agent_message_id(turn_started_id, ordinal), do: "#{turn_started_id}:#{ordinal}"

  def build_user_message_chunk_notification(session_id, message_id, content, agent_id, timestamp)
      when is_binary(agent_id) and agent_id != "" do
    session_update_notification(session_id, %{
      "sessionUpdate" => "user_message_chunk",
      "messageId" => message_id,
      "content" => content,
      "_meta" => message_metadata(agent_id, timestamp)
    })
  end

  defp message_metadata(agent_id, timestamp) do
    %{
      @agent_id_metadata_key => agent_id,
      @timestamp_metadata_key => DateTime.to_iso8601(timestamp)
    }
  end

  defp session_update_notification(session_id, update) do
    JsonRpc.notification(@method_session_update, %{"sessionId" => session_id, "update" => update})
  end

  def build_state_update_notification(session_id, state, stop_reason \\ nil) do
    update = %{
      "sessionUpdate" => "state_update",
      "state" => state
    }

    update =
      case stop_reason do
        nil -> update
        stop_reason -> Map.put(update, "stopReason", stop_reason)
      end

    session_update_notification(session_id, update)
  end

  def build_error_notification(session_id, message, timestamp, retry_opts \\ []) do
    update = %{
      "sessionUpdate" => "error",
      "message" => message,
      "timestamp" => DateTime.to_iso8601(timestamp),
      "category" => Keyword.fetch!(retry_opts, :category),
      "_meta" => %{@agent_error_id_metadata_key => Keyword.fetch!(retry_opts, :agent_error_id)}
    }

    update =
      case Keyword.get(retry_opts, :retry_at) do
        nil ->
          update

        %DateTime{} = retry_at ->
          update
          |> Map.put("retryAt", DateTime.to_iso8601(retry_at))
          |> Map.put("attempt", Keyword.fetch!(retry_opts, :attempt))
          |> Map.put("maxAttempts", Keyword.fetch!(retry_opts, :max_attempts))
      end

    session_update_notification(session_id, update)
  end

  def build_prompt_accepted_result do
    %{}
  end

  def tool_call_create(
        session_id,
        tool_call_id,
        title,
        kind,
        timestamp,
        status \\ @tool_call_status_pending,
        raw_input \\ nil,
        raw_output \\ nil
      )
      when status in @tool_call_statuses do
    update = %{
      "sessionUpdate" => "tool_call",
      "toolCallId" => tool_call_id,
      "title" => title,
      "kind" => kind,
      "status" => status,
      "timestamp" => DateTime.to_iso8601(timestamp)
    }

    update = if is_nil(raw_input), do: update, else: Map.put(update, "rawInput", raw_input)
    update = if is_nil(raw_output), do: update, else: Map.put(update, "rawOutput", raw_output)

    session_update_notification(session_id, update)
  end

  def tool_call_update(
        session_id,
        tool_call_id,
        status,
        content \\ nil,
        raw_input \\ nil,
        raw_output \\ nil
      )
      when status in @tool_call_statuses do
    update = %{
      "sessionUpdate" => "tool_call_update",
      "toolCallId" => tool_call_id,
      "status" => status
    }

    update = if content, do: Map.put(update, "content", content), else: update
    update = if is_nil(raw_input), do: update, else: Map.put(update, "rawInput", raw_input)
    update = if is_nil(raw_output), do: update, else: Map.put(update, "rawOutput", raw_output)

    session_update_notification(session_id, update)
  end

  def plan_update(session_id, entries) do
    validate_plan_entries!(entries)

    session_update_notification(session_id, %{
      "sessionUpdate" => "plan",
      "entries" => entries
    })
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

  def build_form_elicitation_request(id, session_id, message, requested_schema) do
    JsonRpc.request(id, "session/elicitation", %{
      "sessionId" => session_id,
      "mode" => "form",
      "message" => message,
      "requestedSchema" => requested_schema
    })
  end

  def build_url_elicitation_request(id, session_id, message, elicitation_id, url) do
    JsonRpc.request(id, "session/elicitation", %{
      "sessionId" => session_id,
      "mode" => "url",
      "message" => message,
      "elicitationId" => elicitation_id,
      "url" => url
    })
  end

  def build_elicitation_complete_notification(elicitation_id) do
    JsonRpc.notification("notifications/elicitation/complete", %{
      "elicitationId" => elicitation_id
    })
  end

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

  def parse_elicitation_response(%{"action" => action, "content" => content}) do
    {action, content}
  end

  def parse_elicitation_response(%{"action" => action}) do
    {action, nil}
  end

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
