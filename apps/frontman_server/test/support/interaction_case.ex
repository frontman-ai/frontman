defmodule FrontmanServer.InteractionCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import FrontmanServer.InteractionCase.Helpers
    end
  end

  defmodule Helpers do
    alias FrontmanServer.Tasks.Interaction

    alias FrontmanServer.Tasks.Interaction.{
      AgentResponse,
      ToolCall,
      ToolResult,
      UserMessage
    }

    def text_block(text), do: %{"type" => "text", "text" => text}

    def annotation_block(id, tag, file, line, col, extra \\ %{}) do
      base_meta =
        %{
          "annotation" => true,
          "annotation_index" => extra[:index] || 0,
          "annotation_id" => id,
          "tag_name" => tag,
          "file" => file,
          "line" => line,
          "column" => col
        }

      meta =
        (extra[:metadata] || %{})
        |> Map.merge(base_meta)
        |> maybe_put("component_name", extra[:component_name])
        |> maybe_put("component_props", extra[:component_props])
        |> maybe_put("css_classes", extra[:css_classes])
        |> maybe_put("nearby_text", extra[:nearby_text])
        |> maybe_put("comment", extra[:comment])
        |> maybe_put("bounding_box", extra[:bounding_box])
        |> maybe_put("parent", extra[:parent])

      %{
        "type" => "resource",
        "_meta" => meta,
        "resource" => %{
          "uri" => "file://#{file}:#{line}:#{col}",
          "mimeType" => "text/plain",
          "text" => "Annotated element: <#{tag}> at #{file}:#{line}:#{col}"
        }
      }
    end

    def screenshot_block(annotation_id, blob, mime \\ "image/png") do
      %{
        "type" => "resource",
        "_meta" => %{
          "annotation_screenshot" => true,
          "annotation_index" => 0,
          "annotation_id" => annotation_id
        },
        "resource" => %{
          "uri" => "annotation://#{annotation_id}/screenshot",
          "mimeType" => mime,
          "blob" => blob
        }
      }
    end

    def current_page_block(url, extra \\ %{}) do
      meta = Map.merge(extra, %{"current_page" => true, "url" => url})

      %{
        "type" => "resource",
        "_meta" => meta,
        "resource" => %{
          "uri" => "page://#{url}",
          "mimeType" => "text/plain",
          "text" => "Current page: #{url}"
        }
      }
    end

    def db_tool_call(id, name, args \\ "{}") do
      %{
        "id" => id,
        "type" => "function",
        "function" => %{"name" => name, "arguments" => args}
      }
    end

    def flat_tool_call(id, name, args) do
      %{"id" => id, "name" => name, "arguments" => args}
    end

    def user_msg(messages, annotations \\ []) do
      %UserMessage{
        id: Ecto.UUID.generate(),
        messages: List.wrap(messages),
        timestamp: Interaction.now(),
        annotations: annotations
      }
    end

    def agent_resp(content, metadata \\ %{}) do
      AgentResponse.attrs(content, metadata)
      |> Map.put(:id, Ecto.UUID.generate())
      |> Map.put(:timestamp, Interaction.now())
      |> then(&struct!(AgentResponse, &1))
    end

    def turn_started(user_message_ids) do
      %Interaction.TurnStarted{
        id: Ecto.UUID.generate(),
        timestamp: Interaction.now(),
        agent_id: "test-frontman",
        user_message_ids: user_message_ids
      }
    end

    def agent_error(message, kind \\ "failed", retryable \\ false, category \\ "unknown") do
      %Interaction.AgentError{
        id: Ecto.UUID.generate(),
        timestamp: Interaction.now(),
        error: message,
        kind: kind,
        retryable: retryable,
        category: category
      }
    end

    def agent_paused(tool_name, timeout_ms) do
      %Interaction.AgentPaused{
        id: Ecto.UUID.generate(),
        timestamp: Interaction.now(),
        reason: "Tool #{tool_name} timed out after #{timeout_ms}ms (on_timeout: :pause_agent)",
        tool_name: tool_name,
        timeout_ms: timeout_ms
      }
    end

    def agent_completed do
      %Interaction.AgentCompleted{id: Ecto.UUID.generate(), timestamp: Interaction.now()}
    end

    def tool_call(call_id, name, args \\ %{}) do
      %ToolCall{
        id: Ecto.UUID.generate(),
        tool_call_id: call_id,
        tool_name: name,
        arguments: args,
        timestamp: Interaction.now()
      }
    end

    def tool_result(call_id, name, result, opts \\ []) do
      %ToolResult{
        id: Ecto.UUID.generate(),
        tool_call_id: call_id,
        tool_name: name,
        result: result,
        is_error: opts[:is_error] || false,
        timestamp: Interaction.now()
      }
    end

    def swarm_tool_call(name, args \\ "{}") do
      %SwarmAi.ToolCall{
        id: "tc_#{System.unique_integer([:positive])}",
        name: name,
        arguments: args
      }
    end

    def interaction_event(interaction, turn_number) do
      {:interaction, interaction_row(interaction, turn_number)}
    end

    def interaction_row(interaction, turn_number) do
      schema = Module.concat([FrontmanServer, Tasks, InteractionSchema])

      struct!(schema, %{
        id: interaction.id,
        type:
          PolymorphicEmbed.get_polymorphic_type(
            schema,
            :data,
            interaction
          ),
        data: interaction,
        turn_number: turn_number
      })
    end

    defmacro assert_receive_interaction(data_pattern, turn_pattern, timeout \\ 5_000) do
      quote do
        assert_receive {:interaction,
                        %{data: unquote(data_pattern), turn_number: unquote(turn_pattern)}},
                       unquote(timeout)
      end
    end

    def extract_text(msg) do
      case msg.content do
        content when is_binary(content) -> content
        [%{text: t} | _] -> t
        _ -> ""
      end
    end

    def extract_content_text(content) when is_binary(content), do: content

    def extract_content_text(content) when is_list(content) do
      Enum.map_join(content, "", fn
        %{text: text} -> text
        _ -> ""
      end)
    end

    defp maybe_put(map, _key, nil), do: map
    defp maybe_put(map, key, val), do: Map.put(map, key, val)
  end
end
