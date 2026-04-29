defmodule FrontmanServer.InteractionCase do
  @moduledoc """
  Test case template for tests that work with `FrontmanServer.Tasks.Interaction` structs.

  Provides factory functions for building Interaction structs and content block
  maps without reaching into the database. Tests that only exercise pure
  Interaction logic (parsing, encoding, LLM conversion) should `use` this case
  directly. Tests that also need the DB can combine it with `DataCase` or
  `ChannelCase` by importing the helpers module instead:

      import FrontmanServer.InteractionCase.Helpers

  ## Provided helpers

  ### Content block builders (raw maps matching the ACP wire format)

    * `text_block/1`         — `%{"type" => "text", "text" => text}`
    * `annotation_block/5,6` — annotation resource block with optional enrichment
    * `screenshot_block/2,3` — screenshot resource block paired to an annotation

  ### Interaction struct builders

    * `user_msg/1,2`         — `%UserMessage{}`
    * `agent_resp/1,2`       — `%AgentResponse{}`
    * `tool_call/2,3`        — `%ToolCall{}`
    * `tool_result/3,4`      — `%ToolResult{}`

  ### DB wire-format tool call maps

    * `db_tool_call/2,3`     — OpenAI nested format (string keys)
    * `flat_tool_call/3`     — flat format (string keys, no nested function)

  ### Assertion helpers

    * `extract_text/1`       — pull text from an LLM message (handles string + ContentPart list)
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import FrontmanServer.InteractionCase.Helpers
    end
  end

  defmodule Helpers do
    @moduledoc """
    Factory functions and assertion helpers for Interaction structs.

    Import this module directly in tests that already `use` another case
    template (e.g. DataCase, ChannelCase):

        import FrontmanServer.InteractionCase.Helpers
    """

    alias FrontmanServer.Tasks.Interaction

    alias FrontmanServer.Tasks.Interaction.{
      AgentResponse,
      ToolCall,
      ToolResult,
      UserMessage
    }

    # -------------------------------------------------------------------
    # Content block builders (raw maps matching ACP wire format)
    # -------------------------------------------------------------------

    @doc "Build a text content block map."
    def text_block(text), do: %{"type" => "text", "text" => text}

    @doc """
    Build an annotation resource block with optional enrichment fields.

    Accepted keys in `extra`:
      * `:index`          — annotation_index (defaults to 0)
      * `:component_name` — React/component name
      * `:css_classes`    — CSS class string
      * `:nearby_text`    — visible text near the element
      * `:comment`        — user comment
      * `:metadata`       — extra annotation `_meta` fields to preserve generically
      * `:bounding_box`   — `%{"x" => …, "y" => …, "width" => …, "height" => …}`
    """
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
        |> maybe_put("css_classes", extra[:css_classes])
        |> maybe_put("nearby_text", extra[:nearby_text])
        |> maybe_put("comment", extra[:comment])
        |> maybe_put("bounding_box", extra[:bounding_box])

      %{
        "type" => "resource",
        "resource" => %{
          "_meta" => meta,
          "resource" => %{
            "uri" => "file://#{file}:#{line}:#{col}",
            "mimeType" => "text/plain",
            "text" => "Annotated element: <#{tag}> at #{file}:#{line}:#{col}"
          }
        }
      }
    end

    @doc "Build a screenshot resource block paired to an annotation by id."
    def screenshot_block(annotation_id, blob, mime \\ "image/png") do
      %{
        "type" => "resource",
        "resource" => %{
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
      }
    end

    # -------------------------------------------------------------------
    # DB wire-format tool call maps
    # -------------------------------------------------------------------

    @doc "Build a tool_call map in DB wire format (string keys, OpenAI shape)."
    def db_tool_call(id, name, args \\ "{}") do
      %{
        "id" => id,
        "type" => "function",
        "function" => %{"name" => name, "arguments" => args}
      }
    end

    @doc "Build a tool_call map in flat format (string keys, no nested function)."
    def flat_tool_call(id, name, args) do
      %{"id" => id, "name" => name, "arguments" => args}
    end

    # -------------------------------------------------------------------
    # Interaction struct builders
    # -------------------------------------------------------------------

    @doc "Build a `%UserMessage{}` struct."
    def user_msg(messages, annotations \\ []) do
      %UserMessage{
        id: Interaction.new_id(),
        messages: List.wrap(messages),
        timestamp: Interaction.now(),
        annotations: annotations
      }
    end

    @doc "Build an `%AgentResponse{}` struct."
    def agent_resp(content, metadata \\ %{}) do
      %AgentResponse{
        id: Interaction.new_id(),
        content: content,
        timestamp: Interaction.now(),
        metadata: metadata
      }
    end

    @doc "Build a `%ToolCall{}` struct."
    def tool_call(call_id, name, args \\ %{}) do
      %ToolCall{
        id: Interaction.new_id(),
        tool_call_id: call_id,
        tool_name: name,
        arguments: args,
        timestamp: Interaction.now()
      }
    end

    @doc "Build a `%ToolResult{}` struct."
    def tool_result(call_id, name, result, opts \\ []) do
      %ToolResult{
        id: Interaction.new_id(),
        tool_call_id: call_id,
        tool_name: name,
        result: result,
        is_error: opts[:is_error] || false,
        timestamp: Interaction.now()
      }
    end

    # -------------------------------------------------------------------
    # SwarmAi struct builders
    # -------------------------------------------------------------------

    @doc "Build a `%SwarmAi.ToolCall{}` struct with an auto-generated id."
    def swarm_tool_call(name, args \\ "{}") do
      %SwarmAi.ToolCall{
        id: "tc_#{System.unique_integer([:positive])}",
        name: name,
        arguments: args
      }
    end

    # -------------------------------------------------------------------
    # Assertion / extraction helpers
    # -------------------------------------------------------------------

    @doc "Extract text content from an LLM message (handles string + ContentPart list)."
    def extract_text(msg) do
      case msg.content do
        content when is_binary(content) -> content
        [%{text: t} | _] -> t
        _ -> ""
      end
    end

    @doc """
    Extract and concatenate all text from an LLM message's content parts.

    Unlike `extract_text/1` which returns only the first text part, this
    joins all text parts together.
    """
    def extract_content_text(content) when is_binary(content), do: content

    def extract_content_text(content) when is_list(content) do
      Enum.map_join(content, "", fn
        %{text: text} -> text
        _ -> ""
      end)
    end

    # -------------------------------------------------------------------
    # Internal helpers
    # -------------------------------------------------------------------

    defp maybe_put(map, _key, nil), do: map
    defp maybe_put(map, key, val), do: Map.put(map, key, val)
  end
end
