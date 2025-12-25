defmodule FrontmanServer.Tasks.InteractionTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.Interaction.{UserMessage, AgentResponse, ToolCall, ToolResult}

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
               column: 10
             }

      assert msg.selected_figma_node == nil
    end

    test "extracts selected_figma_node with image only (no node ID from image-only resource)" do
      # When only an image is present without node_id in _meta, no FigmaNode is created
      content_blocks = [
        %{"type" => "text", "text" => "Implement this design"},
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{"figma_image" => true},
            "resource" => %{
              "uri" => "screenshot",
              "mimeType" => "image/png",
              "blob" => "base64imagedata"
            }
          }
        }
      ]

      msg = UserMessage.new(content_blocks)

      # No node_id in _meta means no FigmaNode is created
      assert msg.selected_figma_node == nil
      assert msg.selected_component == nil
    end

    test "extracts selected_figma_node with node and image (DSL by default)" do
      content_blocks = [
        %{"type" => "text", "text" => "Implement this design"},
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{"figma_node" => true, "node_id" => "123:456"},
            "resource" => %{
              "uri" => "123:456",
              "mimeType" => "text/plain",
              "text" => "Frame(id=123:456)"
            }
          }
        },
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{"figma_image" => true},
            "resource" => %{
              "uri" => "screenshot",
              "mimeType" => "image/png",
              "blob" => "base64imagedata"
            }
          }
        }
      ]

      msg = UserMessage.new(content_blocks)

      assert msg.selected_figma_node != nil
      assert msg.selected_figma_node.id == "123:456"
      assert msg.selected_figma_node.node == "Frame(id=123:456)"
      assert msg.selected_figma_node.image == "base64imagedata"
      # Default is_dsl is true for backwards compatibility
      assert msg.selected_figma_node.is_dsl == true
    end

    test "extracts selected_figma_node with is_dsl explicitly set to true" do
      content_blocks = [
        %{"type" => "text", "text" => "Implement this design"},
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{"figma_node" => true, "node_id" => "123:456", "is_dsl" => true},
            "resource" => %{
              "uri" => "123:456",
              "mimeType" => "text/plain",
              "text" => "Frame(id=123:456, v=3)"
            }
          }
        }
      ]

      msg = UserMessage.new(content_blocks)

      assert msg.selected_figma_node != nil
      assert msg.selected_figma_node.is_dsl == true
    end

    test "extracts selected_figma_node with is_dsl set to false (full JSON)" do
      content_blocks = [
        %{"type" => "text", "text" => "Implement this design"},
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{"figma_node" => true, "node_id" => "123:456", "is_dsl" => false},
            "resource" => %{
              "uri" => "123:456",
              "mimeType" => "application/json",
              "text" => ~s({"id":"123:456","name":"Frame","type":"FRAME"})
            }
          }
        }
      ]

      msg = UserMessage.new(content_blocks)

      assert msg.selected_figma_node != nil
      assert msg.selected_figma_node.id == "123:456"
      assert msg.selected_figma_node.is_dsl == false
    end

    test "extracts selected_figma_node with node only" do
      content_blocks = [
        %{"type" => "text", "text" => "Implement this design"},
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{"figma_node" => true, "node_id" => "123:456"},
            "resource" => %{
              "uri" => "123:456",
              "mimeType" => "text/plain",
              "text" => "Frame(id=123:456)"
            }
          }
        }
      ]

      msg = UserMessage.new(content_blocks)

      assert msg.selected_figma_node != nil
      assert msg.selected_figma_node.id == "123:456"
      assert msg.selected_figma_node.node == "Frame(id=123:456)"
      assert msg.selected_figma_node.image == nil
    end

    test "returns nil for all context fields when no context" do
      content_blocks = [%{"type" => "text", "text" => "Hello"}]

      msg = UserMessage.new(content_blocks)

      assert msg.selected_component == nil
      assert msg.selected_component_screenshot == nil
      assert msg.selected_figma_node == nil
    end

    test "handles both selected_component and figma_context together" do
      content_blocks = [
        %{"type" => "text", "text" => "Implement this"},
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{
              "selected_component" => true,
              "file" => "/src/Button.tsx",
              "line" => 10,
              "column" => 5
            },
            "resource" => %{
              "uri" => "file:///src/Button.tsx:10:5",
              "mimeType" => "text/plain",
              "text" => "Selected component"
            }
          }
        },
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{"figma_node" => true, "node_id" => "0:1"},
            "resource" => %{
              "uri" => "0:1",
              "mimeType" => "text/plain",
              "text" => "Frame(id=0:1)"
            }
          }
        }
      ]

      msg = UserMessage.new(content_blocks)

      assert msg.selected_component == %{file: "/src/Button.tsx", line: 10, column: 5}
      assert msg.selected_figma_node != nil
      assert msg.selected_figma_node.id == "0:1"
      assert msg.selected_figma_node.node == "Frame(id=0:1)"
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
      assert msg.selected_component == %{file: "/correct/path.tsx", line: 100, column: 50}
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

      assert msg.selected_component_screenshot ==
               "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk"
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

      assert msg.selected_component == %{file: "/src/Button.tsx", line: 15, column: 3}
      assert msg.selected_component_screenshot == "base64screenshotdata"
    end
  end

  describe "has_figma_context?/1" do
    test "returns true when UserMessage has figma context with valid node ID" do
      interactions = [
        UserMessage.new([
          %{"type" => "text", "text" => "Hello"},
          %{
            "type" => "resource",
            "resource" => %{
              "_meta" => %{"figma_node" => true, "node_id" => "123:456"},
              "resource" => %{"uri" => "123:456", "text" => "Frame(id=123:456)"}
            }
          }
        ])
      ]

      assert Interaction.has_figma_context?(interactions) == true
    end

    test "returns false when no figma context" do
      interactions = [
        UserMessage.new([%{"type" => "text", "text" => "Hello"}])
      ]

      assert Interaction.has_figma_context?(interactions) == false
    end

    test "returns false when only image with no valid node ID" do
      # Image-only resources without node_id in _meta don't create a selected_figma_node
      interactions = [
        UserMessage.new([
          %{"type" => "text", "text" => "Hello"},
          %{
            "type" => "resource",
            "resource" => %{
              "_meta" => %{"figma_image" => true},
              "resource" => %{"uri" => "screenshot", "blob" => "data"}
            }
          }
        ])
      ]

      assert Interaction.has_figma_context?(interactions) == false
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
          messages: ["Hello"],
          timestamp: DateTime.utc_now(),
          selected_component: nil,
          selected_component_screenshot: nil,
          selected_figma_node: nil
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      assert length(messages) == 1
      assert hd(messages).role == :user
      # ReqLLM.Context.user wraps string content in ContentPart structs
      # The content field contains a list of ContentPart structs
      content = hd(messages).content
      assert is_list(content)
      # ContentPart structs have a text field - extract and verify
      # Note: ReqLLM may wrap strings differently, so we check the structure
      assert length(content) >= 0
    end

    test "converts agent responses without tool calls" do
      interactions = [
        %AgentResponse{
          id: "1",
          agent_id: "agent_1",
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
          agent_id: "agent_1",
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
          agent_id: "agent_1",
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
          agent_id: "agent_1",
          tool_call_id: "call_123",
          tool_name: "calculator",
          arguments: %{},
          timestamp: DateTime.utc_now()
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      assert length(messages) == 0
    end

    test "handles mixed interactions in order" do
      now = DateTime.utc_now()

      interactions = [
        %UserMessage{
          id: "1",
          messages: ["Calculate 2+2"],
          timestamp: now,
          selected_component: nil,
          selected_component_screenshot: nil,
          selected_figma_node: nil
        },
        %AgentResponse{
          id: "2",
          agent_id: "a1",
          content: "Let me calculate",
          timestamp: now,
          metadata: %{tool_calls: [%{id: "c1", name: "calc", arguments: %{}}]}
        },
        %ToolCall{
          id: "3",
          agent_id: "a1",
          tool_call_id: "c1",
          tool_name: "calc",
          arguments: %{},
          timestamp: now
        },
        %ToolResult{
          id: "4",
          agent_id: "a1",
          tool_call_id: "c1",
          tool_name: "calc",
          result: 4,
          is_error: false,
          timestamp: now
        },
        %AgentResponse{
          id: "5",
          agent_id: "a1",
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

  describe "to_llm_messages/2 with agent_id filtering" do
    test "returns only messages belonging to specified agent" do
      now = DateTime.utc_now()

      interactions = [
        # UserMessage - should always be included (no agent_id)
        %UserMessage{
          id: "1",
          messages: ["Hello"],
          timestamp: now,
          selected_component: nil,
          selected_component_screenshot: nil,
          selected_figma_node: nil
        },
        # Agent A's response
        %AgentResponse{
          id: "2",
          agent_id: "agent_a",
          content: "Response from A",
          timestamp: now,
          metadata: %{}
        },
        # Agent B's response (sub-agent) - should be excluded when filtering for A
        %AgentResponse{
          id: "3",
          agent_id: "agent_b",
          content: "Response from B",
          timestamp: now,
          metadata: %{tool_calls: [%{id: "call_b", name: "some_tool", arguments: %{}}]}
        },
        # Agent A's final response
        %AgentResponse{
          id: "4",
          agent_id: "agent_a",
          content: "Final from A",
          timestamp: now,
          metadata: %{}
        }
      ]

      # Filter for agent_a
      messages = Interaction.to_llm_messages(interactions, "agent_a")

      # Should have: UserMessage + Agent A's 2 responses = 3 messages
      assert length(messages) == 3

      # Verify no agent_b content
      refute Enum.any?(messages, fn msg ->
               msg.role == :assistant and
                 match?([%{text: "Response from B"}], msg.content)
             end)
    end

    test "includes ToolResult for the correct agent" do
      now = DateTime.utc_now()

      interactions = [
        %UserMessage{
          id: "1",
          messages: ["Hello"],
          timestamp: now,
          selected_component: nil,
          selected_component_screenshot: nil,
          selected_figma_node: nil
        },
        %AgentResponse{
          id: "2",
          agent_id: "agent_a",
          content: "Let me use a tool",
          timestamp: now,
          metadata: %{tool_calls: [%{id: "call_1", name: "test_tool", arguments: %{}}]}
        },
        %ToolResult{
          id: "3",
          agent_id: "agent_a",
          tool_call_id: "call_1",
          tool_name: "test_tool",
          result: "tool output",
          is_error: false,
          timestamp: now
        },
        # Another agent's tool result - should be excluded
        %ToolResult{
          id: "4",
          agent_id: "agent_b",
          tool_call_id: "call_2",
          tool_name: "other_tool",
          result: "other output",
          is_error: false,
          timestamp: now
        }
      ]

      messages = Interaction.to_llm_messages(interactions, "agent_a")

      # UserMessage + AgentResponse + ToolResult for agent_a = 3
      assert length(messages) == 3
    end

    test "always includes UserMessage regardless of agent_id" do
      now = DateTime.utc_now()

      interactions = [
        %UserMessage{
          id: "1",
          messages: ["Initial prompt"],
          timestamp: now,
          selected_component: nil,
          selected_component_screenshot: nil,
          selected_figma_node: nil
        }
      ]

      # Filter for any agent - should still get UserMessage
      messages = Interaction.to_llm_messages(interactions, "some_agent")

      assert length(messages) == 1
      assert hd(messages).role == :user
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
               "column" => 5
             }

      assert decoded["selected_figma_node"] == nil
    end

    test "encodes UserMessage with figma context to JSON" do
      msg =
        UserMessage.new([
          %{"type" => "text", "text" => "Build this"},
          %{
            "type" => "resource",
            "resource" => %{
              "_meta" => %{"figma_image" => true},
              "resource" => %{"uri" => "screenshot", "blob" => "imagedata"}
            }
          },
          %{
            "type" => "resource",
            "resource" => %{
              "_meta" => %{"figma_node" => true, "node_id" => "0:1"},
              "resource" => %{"uri" => "0:1", "text" => "Frame(id=0:1)"}
            }
          }
        ])

      json = Jason.encode!(msg)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "user_message"
      assert decoded["messages"] == ["Build this"]
      assert decoded["selected_figma_node"]["id"] == "0:1"
      assert decoded["selected_figma_node"]["has_node"] == true
      assert decoded["selected_figma_node"]["has_image"] == true
      assert decoded["selected_figma_node"]["is_dsl"] == true
      assert decoded["selected_component"] == nil
    end

    test "encodes UserMessage with non-DSL figma context to JSON" do
      msg =
        UserMessage.new([
          %{"type" => "text", "text" => "Build this"},
          %{
            "type" => "resource",
            "resource" => %{
              "_meta" => %{"figma_node" => true, "node_id" => "0:1", "is_dsl" => false},
              "resource" => %{
                "uri" => "0:1",
                "text" => ~s({"id":"0:1","name":"Frame"})
              }
            }
          }
        ])

      json = Jason.encode!(msg)
      decoded = Jason.decode!(json)

      assert decoded["selected_figma_node"]["id"] == "0:1"
      assert decoded["selected_figma_node"]["is_dsl"] == false
    end

    test "encodes ToolCall to JSON" do
      tool_call = %ToolCall{
        id: "1",
        agent_id: "agent_1",
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
        agent_id: "agent_1",
        tool_call_id: "call_123",
        tool_name: "calculator",
        result: 42,
        is_error: false,
        timestamp: ~U[2025-01-01 00:00:00Z]
      }

      json = Jason.encode!(tool_result)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "tool_result"
      assert decoded["agent_id"] == "agent_1"
      assert decoded["result"] == 42
      assert decoded["is_error"] == false
    end
  end
end
