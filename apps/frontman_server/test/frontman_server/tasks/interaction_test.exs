defmodule FrontmanServer.Tasks.InteractionTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.Interaction.{AgentResponse, ToolCall, ToolResult, UserMessage}

  # Test helper to generate sequence numbers
  defp seq, do: System.unique_integer([:monotonic, :positive])

  describe "UserMessage.new/1" do
    test "extracts selected_component from resource with _meta annotation" do
      content_blocks = [
        %{"type" => "text", "text" => "Hello"},
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{
              "selected_component" => true,
              "file" => "/path/to/component.tsx",
              "line" => 42,
              "column" => 10
            },
            "resource" => %{
              "uri" => "file:///path/to/component.tsx:42:10",
              "mimeType" => "text/plain",
              "text" => "Selected component: div at /path/to/component.tsx:42:10"
            }
          }
        }
      ]

      msg = UserMessage.new(content_blocks)

      assert msg.selected_component == %{
               file: "/path/to/component.tsx",
               line: 42,
               column: 10,
               source_snippet: nil,
               source_type: nil,
               component_name: nil,
               component_props: nil,
               parent: nil
             }
    end

    test "returns nil for all context fields when no context" do
      content_blocks = [%{"type" => "text", "text" => "Hello"}]

      msg = UserMessage.new(content_blocks)

      assert msg.selected_component == nil
      assert msg.selected_component_screenshot == nil
    end

    test "prefers _meta extraction over URI parsing" do
      # When both _meta and URI are present, _meta takes precedence
      content_blocks = [
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{
              "selected_component" => true,
              "file" => "/correct/path.tsx",
              "line" => 100,
              "column" => 50
            },
            "resource" => %{
              "uri" => "file:///wrong/path.tsx:1:1",
              "mimeType" => "text/plain",
              "text" => "Selected component"
            }
          }
        }
      ]

      msg = UserMessage.new(content_blocks)

      # Should use _meta values, not parsed URI
      assert msg.selected_component == %{
               file: "/correct/path.tsx",
               line: 100,
               column: 50,
               source_snippet: nil,
               source_type: nil,
               component_name: nil,
               component_props: nil,
               parent: nil
             }
    end

    test "extracts selected_component_screenshot from resource with _meta annotation" do
      content_blocks = [
        %{"type" => "text", "text" => "Hello"},
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{"selected_component_screenshot" => true},
            "resource" => %{
              "uri" => "component://screenshot",
              "mimeType" => "image/png",
              "blob" => "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk"
            }
          }
        }
      ]

      msg = UserMessage.new(content_blocks)

      assert msg.selected_component_screenshot == %{
               blob: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk",
               mime_type: "image/png"
             }
    end

    test "extracts both selected_component and screenshot together" do
      content_blocks = [
        %{"type" => "text", "text" => "Fix this button"},
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{
              "selected_component" => true,
              "file" => "/src/Button.tsx",
              "line" => 15,
              "column" => 3
            },
            "resource" => %{
              "uri" => "file:///src/Button.tsx:15:3",
              "mimeType" => "text/plain",
              "text" => "Selected component: button"
            }
          }
        },
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{"selected_component_screenshot" => true},
            "resource" => %{
              "uri" => "component://screenshot",
              "mimeType" => "image/png",
              "blob" => "base64screenshotdata"
            }
          }
        }
      ]

      msg = UserMessage.new(content_blocks)

      assert msg.selected_component == %{
               file: "/src/Button.tsx",
               line: 15,
               column: 3,
               source_snippet: nil,
               source_type: nil,
               component_name: nil,
               component_props: nil,
               parent: nil
             }

      assert msg.selected_component_screenshot == %{
               blob: "base64screenshotdata",
               mime_type: "image/png"
             }
    end
  end

  describe "has_selected_component?/1" do
    test "returns true when UserMessage has selected component" do
      interactions = [
        UserMessage.new([
          %{"type" => "text", "text" => "Hello"},
          %{
            "type" => "resource",
            "resource" => %{
              "_meta" => %{
                "selected_component" => true,
                "file" => "/path/to/file.tsx",
                "line" => 1,
                "column" => 1
              },
              "resource" => %{"uri" => "file:///path/to/file.tsx:1:1", "text" => "Component"}
            }
          }
        ])
      ]

      assert Interaction.has_selected_component?(interactions) == true
    end

    test "returns false when no selected component" do
      interactions = [
        UserMessage.new([%{"type" => "text", "text" => "Hello"}])
      ]

      assert Interaction.has_selected_component?(interactions) == false
    end
  end

  describe "to_llm_messages/1" do
    test "converts user messages" do
      interactions = [
        %UserMessage{
          id: "1",
          sequence: seq(),
          messages: ["Hello"],
          timestamp: DateTime.utc_now(),
          selected_component: nil,
          selected_component_screenshot: nil
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      assert length(messages) == 1
      assert hd(messages).role == :user
      # ReqLLM.Context.user wraps string content in ContentPart structs
      # The content field contains a list of ContentPart structs
      content = hd(messages).content
      # ContentPart structs have a text field - extract and verify
      # Note: ReqLLM may wrap strings differently, so we check the structure
      assert is_list(content)
    end

    test "converts agent responses without tool calls" do
      interactions = [
        %AgentResponse{
          id: "1",
          sequence: seq(),
          content: "Hi there",
          timestamp: DateTime.utc_now(),
          metadata: %{}
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      assert length(messages) == 1
      assert hd(messages).role == :assistant
      # content is wrapped in ContentPart structs
      assert [%{type: :text, text: "Hi there"}] = hd(messages).content
    end

    test "converts agent responses with tool calls" do
      tool_calls = [%{id: "call_1", name: "calculator", arguments: %{}}]

      interactions = [
        %AgentResponse{
          id: "1",
          sequence: seq(),
          content: "Let me calculate",
          timestamp: DateTime.utc_now(),
          metadata: %{tool_calls: tool_calls}
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      assert length(messages) == 1
      msg = hd(messages)
      assert msg.role == :assistant
    end

    test "converts tool results" do
      interactions = [
        %ToolResult{
          id: "1",
          sequence: seq(),
          tool_call_id: "call_123",
          tool_name: "calculator",
          result: 42,
          is_error: false,
          timestamp: DateTime.utc_now()
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      assert length(messages) == 1
    end

    test "skips tool calls (they are in agent response metadata)" do
      interactions = [
        %ToolCall{
          id: "1",
          sequence: seq(),
          tool_call_id: "call_123",
          tool_name: "calculator",
          arguments: %{},
          timestamp: DateTime.utc_now()
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      assert messages == []
    end

    test "includes selected_component location in user message content" do
      interactions = [
        %UserMessage{
          id: "1",
          sequence: seq(),
          messages: ["Change the text"],
          timestamp: DateTime.utc_now(),
          selected_component: %{
            file: "file:///path/to/Component.tsx",
            line: 42,
            column: 5
          },
          selected_component_screenshot: nil
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      assert length(messages) == 1

      msg = hd(messages)
      assert msg.role == :user

      # Extract text content
      text =
        case msg.content do
          content when is_binary(content) -> content
          [%{text: t} | _] -> t
          _ -> ""
        end

      # Should include the original message
      assert text =~ "Change the text"

      # Should include selected component location info
      assert text =~ "[Selected Component Location]"
      assert text =~ "file:///path/to/Component.tsx"
      assert text =~ "Line: 42"
      assert text =~ "Column: 5"
    end

    test "does not add selected_component section when selected_component is nil" do
      interactions = [
        %UserMessage{
          id: "1",
          sequence: seq(),
          messages: ["Just a regular message"],
          timestamp: DateTime.utc_now(),
          selected_component: nil,
          selected_component_screenshot: nil
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      msg = hd(messages)

      text =
        case msg.content do
          content when is_binary(content) -> content
          [%{text: t} | _] -> t
          _ -> ""
        end

      # Should have the message but NOT the selected component section
      assert text =~ "Just a regular message"
      refute text =~ "[Selected Component Location]"
    end

    test "handles mixed interactions in order" do
      now = DateTime.utc_now()

      interactions = [
        %UserMessage{
          id: "1",
          sequence: seq(),
          messages: ["Calculate 2+2"],
          timestamp: now,
          selected_component: nil,
          selected_component_screenshot: nil
        },
        %AgentResponse{
          id: "2",
          sequence: seq(),
          content: "Let me calculate",
          timestamp: now,
          metadata: %{tool_calls: [%{id: "c1", name: "calc", arguments: %{}}]}
        },
        %ToolCall{
          id: "3",
          sequence: seq(),
          tool_call_id: "c1",
          tool_name: "calc",
          arguments: %{},
          timestamp: now
        },
        %ToolResult{
          id: "4",
          sequence: seq(),
          tool_call_id: "c1",
          tool_name: "calc",
          result: 4,
          is_error: false,
          timestamp: now
        },
        %AgentResponse{
          id: "5",
          sequence: seq(),
          content: "The answer is 4",
          timestamp: now,
          metadata: %{}
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      # UserMessage, AgentResponse (with tools), ToolResult, AgentResponse (final)
      # ToolCall is skipped
      assert length(messages) == 4
    end
  end

  describe "to_llm_messages/1 with DB-loaded metadata (string keys)" do
    # These tests cover the bug where metadata loaded from DB has string keys,
    # but the code was trying to access with atom keys (e.g., :tool_calls vs "tool_calls").
    # This caused tool_calls to be nil when reconstructing conversation history,
    # leading to Anthropic rejecting subsequent requests with:
    # "unexpected tool_use_id found in tool_result blocks"

    test "converts agent responses with tool_calls stored as string keys (OpenAI wire format)" do
      # This is exactly how tool_calls are stored in the DB after JSON serialization
      tool_calls_from_db = [
        %{
          "function" => %{
            "arguments" => ~s({"path": "src/app/page.tsx"}),
            "name" => "read_file"
          },
          "id" => "toolu_012YbdZVHHNLf7EtGWY9m5Gy",
          "type" => "function"
        }
      ]

      interactions = [
        %AgentResponse{
          id: "1",
          sequence: seq(),
          content: "I'll read the file",
          timestamp: DateTime.utc_now(),
          # Simulating DB-loaded metadata with string keys
          metadata: %{"tool_calls" => tool_calls_from_db}
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      assert length(messages) == 1

      msg = hd(messages)
      assert msg.role == :assistant

      # Verify tool_calls are present and converted to ReqLLM.ToolCall structs
      assert msg.tool_calls != nil
      assert length(msg.tool_calls) == 1

      tc = hd(msg.tool_calls)
      assert %ReqLLM.ToolCall{} = tc
      assert tc.id == "toolu_012YbdZVHHNLf7EtGWY9m5Gy"
      assert tc.function.name == "read_file"
      assert tc.function.arguments == ~s({"path": "src/app/page.tsx"})
    end

    test "converts agent responses with multiple tool_calls from DB" do
      tool_calls_from_db = [
        %{
          "function" => %{"arguments" => ~s({"path": "file1.txt"}), "name" => "read_file"},
          "id" => "toolu_001",
          "type" => "function"
        },
        %{
          "function" => %{"arguments" => ~s({"pattern": "*.tsx"}), "name" => "glob"},
          "id" => "toolu_002",
          "type" => "function"
        }
      ]

      interactions = [
        %AgentResponse{
          id: "1",
          sequence: seq(),
          content: "Let me search for files",
          timestamp: DateTime.utc_now(),
          metadata: %{"tool_calls" => tool_calls_from_db}
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      msg = hd(messages)

      assert length(msg.tool_calls) == 2
      assert Enum.all?(msg.tool_calls, &match?(%ReqLLM.ToolCall{}, &1))
      assert Enum.map(msg.tool_calls, & &1.id) == ["toolu_001", "toolu_002"]
      assert Enum.map(msg.tool_calls, & &1.function.name) == ["read_file", "glob"]
    end

    test "handles empty tool_calls list from DB" do
      interactions = [
        %AgentResponse{
          id: "1",
          sequence: seq(),
          content: "Just a text response",
          timestamp: DateTime.utc_now(),
          metadata: %{"tool_calls" => []}
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      msg = hd(messages)

      # Should be a simple assistant message without tool_calls
      assert msg.role == :assistant
      assert [%{type: :text, text: "Just a text response"}] = msg.content
    end

    test "handles nil tool_calls from DB" do
      interactions = [
        %AgentResponse{
          id: "1",
          sequence: seq(),
          content: "Just a text response",
          timestamp: DateTime.utc_now(),
          metadata: %{"tool_calls" => nil}
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      msg = hd(messages)

      assert msg.role == :assistant
      assert [%{type: :text, text: "Just a text response"}] = msg.content
    end

    test "handles response_id and reasoning_details with string keys from DB" do
      interactions = [
        %AgentResponse{
          id: "1",
          sequence: seq(),
          content: "Thinking...",
          timestamp: DateTime.utc_now(),
          metadata: %{
            "tool_calls" => [
              %{
                "function" => %{"arguments" => "{}", "name" => "test_tool"},
                "id" => "call_123",
                "type" => "function"
              }
            ],
            "response_id" => "resp_abc123",
            "reasoning_details" => [
              %{"type" => "reasoning.encrypted", "data" => "encrypted_data"}
            ]
          }
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      msg = hd(messages)

      # response_id should be in metadata
      assert msg.metadata == %{response_id: "resp_abc123"}

      # reasoning_details should be preserved (only encrypted ones)
      assert msg.reasoning_details == [
               %{"type" => "reasoning.encrypted", "data" => "encrypted_data"}
             ]
    end

    test "full conversation round-trip with tool calls from DB" do
      # Simulates a complete conversation loaded from DB
      now = DateTime.utc_now()

      interactions = [
        # User asks a question
        %UserMessage{
          id: "1",
          sequence: seq(),
          messages: ["What's in the file?"],
          timestamp: now,
          selected_component: nil,
          selected_component_screenshot: nil
        },
        # Agent responds with tool call (DB format with string keys)
        %AgentResponse{
          id: "2",
          sequence: seq(),
          content: "I'll read the file for you.",
          timestamp: now,
          metadata: %{
            "tool_calls" => [
              %{
                "function" => %{"arguments" => ~s({"path": "README.md"}), "name" => "read_file"},
                "id" => "toolu_read_123",
                "type" => "function"
              }
            ]
          }
        },
        # Tool call record (skipped in LLM messages)
        %ToolCall{
          id: "3",
          sequence: seq(),
          tool_call_id: "toolu_read_123",
          tool_name: "read_file",
          arguments: %{"path" => "README.md"},
          timestamp: now
        },
        # Tool result
        %ToolResult{
          id: "4",
          sequence: seq(),
          tool_call_id: "toolu_read_123",
          tool_name: "read_file",
          result: "# README\nThis is a readme file.",
          is_error: false,
          timestamp: now
        },
        # Agent's final response
        %AgentResponse{
          id: "5",
          sequence: seq(),
          content: "The file contains a README header.",
          timestamp: now,
          metadata: %{}
        }
      ]

      messages = Interaction.to_llm_messages(interactions)

      # Should have: UserMessage, AgentResponse with tool, ToolResult, AgentResponse
      # ToolCall is skipped
      assert length(messages) == 4

      # Verify message roles
      [user_msg, assistant_with_tool, tool_result, final_assistant] = messages
      assert user_msg.role == :user
      assert assistant_with_tool.role == :assistant
      assert tool_result.role == :tool
      assert final_assistant.role == :assistant

      # Verify the assistant message has proper tool_calls
      assert length(assistant_with_tool.tool_calls) == 1
      tc = hd(assistant_with_tool.tool_calls)
      assert %ReqLLM.ToolCall{} = tc
      assert tc.id == "toolu_read_123"
      assert tc.function.name == "read_file"

      # Verify the tool_result has matching tool_call_id
      assert tool_result.tool_call_id == "toolu_read_123"
    end

    test "handles flat format tool_calls with string keys" do
      # Some code paths might store tool_calls in flat format
      tool_calls_flat = [
        %{"id" => "call_flat_1", "name" => "get_weather", "arguments" => ~s({"city": "NYC"})}
      ]

      interactions = [
        %AgentResponse{
          id: "1",
          sequence: seq(),
          content: "Checking weather",
          timestamp: DateTime.utc_now(),
          metadata: %{"tool_calls" => tool_calls_flat}
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      msg = hd(messages)

      assert length(msg.tool_calls) == 1
      tc = hd(msg.tool_calls)
      assert %ReqLLM.ToolCall{} = tc
      assert tc.id == "call_flat_1"
      assert tc.function.name == "get_weather"
    end

    test "handles atom keys (fresh from response, not DB)" do
      # When tool_calls come fresh from a response (not loaded from DB),
      # they have atom keys. This should also work.
      tool_calls_with_atoms = [
        %{
          function: %{arguments: ~s({"x": 1}), name: "calculator"},
          id: "call_atom_1",
          type: "function"
        }
      ]

      interactions = [
        %AgentResponse{
          id: "1",
          sequence: seq(),
          content: "Calculating",
          timestamp: DateTime.utc_now(),
          metadata: %{tool_calls: tool_calls_with_atoms}
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      msg = hd(messages)

      assert length(msg.tool_calls) == 1
      tc = hd(msg.tool_calls)
      assert %ReqLLM.ToolCall{} = tc
      assert tc.function.name == "calculator"
    end

    test "passes through ReqLLM.ToolCall structs unchanged" do
      # If tool_calls are already ReqLLM.ToolCall structs, they should pass through
      existing_struct = ReqLLM.ToolCall.new("call_struct_1", "my_tool", "{}")

      interactions = [
        %AgentResponse{
          id: "1",
          sequence: seq(),
          content: "Using tool",
          timestamp: DateTime.utc_now(),
          metadata: %{tool_calls: [existing_struct]}
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      msg = hd(messages)

      assert length(msg.tool_calls) == 1
      tc = hd(msg.tool_calls)
      assert tc == existing_struct
    end
  end

  describe "JSON encoding" do
    test "encodes UserMessage to JSON with messages and selected_component" do
      msg =
        UserMessage.new([
          %{"type" => "text", "text" => "Hello"},
          %{
            "type" => "resource",
            "resource" => %{
              "_meta" => %{
                "selected_component" => true,
                "file" => "/path/to/file.tsx",
                "line" => 10,
                "column" => 5
              },
              "resource" => %{"uri" => "file:///path/to/file.tsx:10:5", "text" => "Component"}
            }
          }
        ])

      json = Jason.encode!(msg)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "user_message"
      assert decoded["messages"] == ["Hello"]

      assert decoded["selected_component"] == %{
               "file" => "/path/to/file.tsx",
               "line" => 10,
               "column" => 5,
               "source_snippet" => nil,
               "source_type" => nil,
               "component_name" => nil,
               "component_props" => nil,
               "parent" => nil
             }
    end

    test "encodes ToolCall to JSON" do
      tool_call = %ToolCall{
        id: "1",
        sequence: seq(),
        tool_call_id: "call_123",
        tool_name: "calculator",
        arguments: %{"x" => 1},
        timestamp: ~U[2025-01-01 00:00:00Z]
      }

      json = Jason.encode!(tool_call)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "tool_call"
      assert decoded["tool_name"] == "calculator"
      assert decoded["tool_call_id"] == "call_123"
    end

    test "encodes ToolResult to JSON" do
      tool_result = %ToolResult{
        id: "1",
        sequence: seq(),
        tool_call_id: "call_123",
        tool_name: "calculator",
        result: 42,
        is_error: false,
        timestamp: ~U[2025-01-01 00:00:00Z]
      }

      json = Jason.encode!(tool_result)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "tool_result"
      assert decoded["result"] == 42
      assert decoded["is_error"] == false
    end
  end
end
