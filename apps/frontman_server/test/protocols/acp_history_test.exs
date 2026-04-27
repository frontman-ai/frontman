defmodule FrontmanServer.Protocols.AcpHistoryTest do
  @moduledoc """
  Ensures every Interaction type has an ACPHistory protocol implementation.

  This test exists because the protocol has no @fallback_to_any — a missing
  implementation will raise Protocol.UndefinedError at runtime when
  stream_session_history iterates over task interactions.

  The completeness test dynamically checks every module in
  `Interaction.interaction_modules/0`, so adding a new type to that list
  without providing an ACPHistory impl will fail this test.
  """
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServerWeb.ACPHistory

  @session_id "test-session-123"

  # Minimal required fields per interaction type. Every type needs at least
  # :timestamp; types with additional enforced fields are listed explicitly.
  @minimal_fields %{
    Interaction.UserMessage => %{id: "t", messages: ["hi"], images: []},
    Interaction.AgentResponse => %{id: "t", content: "c"},
    Interaction.AgentSpawned => %{id: "t"},
    Interaction.AgentCompleted => %{id: "t"},
    Interaction.ToolCall => %{id: "t", tool_call_id: "tc", tool_name: "t", arguments: %{}},
    Interaction.ToolResult => %{
      id: "t",
      tool_call_id: "tc",
      tool_name: "t",
      result: "r",
      is_error: false
    },
    Interaction.AgentError => %{id: "t", error: "e"},
    Interaction.AgentPaused => %{id: "t", reason: "r", tool_name: "t", timeout_ms: 1000},
    Interaction.AgentRetry => %{id: "t", retried_error_id: "e"},
    Interaction.DiscoveredProjectRule => %{path: "/p", content: "c"},
    Interaction.DiscoveredProjectStructure => %{summary: "s"}
  }

  describe "ACPHistory protocol completeness" do
    for mod <- Interaction.interaction_modules() do
      type_name = mod |> Module.split() |> List.last()

      test "#{type_name} has a working ACPHistory implementation" do
        mod = unquote(mod)
        extra = Map.get(unquote(Macro.escape(@minimal_fields)), mod, %{})

        interaction = struct!(mod, Map.merge(%{timestamp: DateTime.utc_now()}, extra))

        # Must not raise Protocol.UndefinedError
        result = ACPHistory.to_history_items(interaction, @session_id)
        assert is_list(result)
      end
    end
  end

  describe "conversation types return non-empty history items" do
    test "UserMessage" do
      interaction = %Interaction.UserMessage{
        id: "um-1",
        timestamp: DateTime.utc_now(),
        messages: ["Hello"],
        images: []
      }

      items = ACPHistory.to_history_items(interaction, @session_id)
      assert items != []
    end

    test "AgentResponse" do
      interaction = %Interaction.AgentResponse{
        id: "ar-1",
        content: "Response text",
        timestamp: DateTime.utc_now()
      }

      items = ACPHistory.to_history_items(interaction, @session_id)
      assert items != []
    end

    test "ToolCall" do
      interaction = %Interaction.ToolCall{
        id: "tc-1",
        tool_call_id: "call-1",
        tool_name: "read_file",
        arguments: %{"path" => "test.txt"},
        timestamp: DateTime.utc_now()
      }

      items = ACPHistory.to_history_items(interaction, @session_id)
      assert items != []
    end

    test "ToolResult" do
      interaction = %Interaction.ToolResult{
        id: "tr-1",
        tool_call_id: "call-1",
        tool_name: "read_file",
        result: "file contents",
        is_error: false,
        timestamp: DateTime.utc_now()
      }

      items = ACPHistory.to_history_items(interaction, @session_id)
      assert items != []
    end
  end

  describe "non-conversation types return empty list" do
    test "AgentSpawned" do
      interaction = %Interaction.AgentSpawned{
        id: "as-1",
        timestamp: DateTime.utc_now()
      }

      assert ACPHistory.to_history_items(interaction, @session_id) == []
    end

    test "AgentCompleted" do
      interaction = %Interaction.AgentCompleted{
        id: "ac-1",
        timestamp: DateTime.utc_now()
      }

      assert ACPHistory.to_history_items(interaction, @session_id) == []
    end

    test "DiscoveredProjectRule" do
      interaction = %Interaction.DiscoveredProjectRule{
        path: "/project/AGENTS.md",
        content: "# Rules",
        timestamp: DateTime.utc_now()
      }

      assert ACPHistory.to_history_items(interaction, @session_id) == []
    end

    test "DiscoveredProjectStructure" do
      interaction = %Interaction.DiscoveredProjectStructure{
        summary: "Project type: single project\n\nDirectory layout:\n.",
        timestamp: DateTime.utc_now()
      }

      assert ACPHistory.to_history_items(interaction, @session_id) == []
    end
  end
end
