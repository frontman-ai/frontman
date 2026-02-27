defmodule FrontmanServer.Tasks.InteractionTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Interaction

  alias FrontmanServer.Tasks.Interaction.{
    AgentResponse,
    Annotation,
    ToolCall,
    ToolResult,
    UserMessage
  }

  # Test helper to generate sequence numbers
  defp seq, do: System.unique_integer([:monotonic, :positive])

  describe "UserMessage.new/1" do
    test "extracts annotation from resource with _meta annotation: true" do
      content_blocks = [
        %{"type" => "text", "text" => "Hello"},
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{
              "annotation" => true,
              "annotation_index" => 0,
              "annotation_id" => "ann-1",
              "tag_name" => "div",
              "file" => "/path/to/component.tsx",
              "line" => 42,
              "column" => 10
            },
            "resource" => %{
              "uri" => "file:///path/to/component.tsx:42:10",
              "mimeType" => "text/plain",
              "text" => "Annotated element: <div> at /path/to/component.tsx:42:10"
            }
          }
        }
      ]

      msg = UserMessage.new(content_blocks)

      assert length(msg.annotations) == 1
      ann = hd(msg.annotations)
      assert ann.annotation_id == "ann-1"
      assert ann.tag_name == "div"
      assert ann.file == "/path/to/component.tsx"
      assert ann.line == 42
      assert ann.column == 10
      assert ann.screenshot == nil
    end

    test "returns empty annotations when no annotation blocks" do
      content_blocks = [%{"type" => "text", "text" => "Hello"}]

      msg = UserMessage.new(content_blocks)

      assert msg.annotations == []
    end

    test "extracts annotation with screenshot paired by annotation_id" do
      content_blocks = [
        %{"type" => "text", "text" => "Fix this button"},
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{
              "annotation" => true,
              "annotation_index" => 0,
              "annotation_id" => "ann-1",
              "tag_name" => "button",
              "file" => "/src/Button.tsx",
              "line" => 15,
              "column" => 3
            },
            "resource" => %{
              "uri" => "file:///src/Button.tsx:15:3",
              "mimeType" => "text/plain",
              "text" => "Annotated element: <button>"
            }
          }
        },
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{
              "annotation_screenshot" => true,
              "annotation_index" => 0,
              "annotation_id" => "ann-1"
            },
            "resource" => %{
              "uri" => "annotation://ann-1/screenshot",
              "mimeType" => "image/png",
              "blob" => "base64screenshotdata"
            }
          }
        }
      ]

      msg = UserMessage.new(content_blocks)

      assert length(msg.annotations) == 1
      ann = hd(msg.annotations)
      assert ann.file == "/src/Button.tsx"
      assert ann.line == 15

      assert ann.screenshot == %Interaction.Screenshot{
               blob: "base64screenshotdata",
               mime_type: "image/png"
             }
    end

    test "extracts multiple annotations with enrichment data" do
      content_blocks = [
        %{"type" => "text", "text" => "Fix these"},
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{
              "annotation" => true,
              "annotation_index" => 0,
              "annotation_id" => "ann-1",
              "tag_name" => "div",
              "file" => "/src/A.tsx",
              "line" => 10,
              "column" => 1,
              "component_name" => "Header",
              "css_classes" => "header main",
              "nearby_text" => "Welcome"
            },
            "resource" => %{"uri" => "file:///src/A.tsx:10:1", "text" => "Annotated element"}
          }
        },
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{
              "annotation" => true,
              "annotation_index" => 1,
              "annotation_id" => "ann-2",
              "tag_name" => "button",
              "file" => "/src/B.tsx",
              "line" => 20,
              "column" => 5,
              "comment" => "Make this red"
            },
            "resource" => %{"uri" => "file:///src/B.tsx:20:5", "text" => "Annotated element"}
          }
        }
      ]

      msg = UserMessage.new(content_blocks)

      assert length(msg.annotations) == 2
      [ann1, ann2] = msg.annotations
      assert ann1.annotation_index == 0
      assert ann1.component_name == "Header"
      assert ann1.css_classes == "header main"
      assert ann1.nearby_text == "Welcome"
      assert ann2.annotation_index == 1
      assert ann2.comment == "Make this red"
    end

    test "extracts annotation with bounding_box" do
      content_blocks = [
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{
              "annotation" => true,
              "annotation_index" => 0,
              "annotation_id" => "ann-bb",
              "tag_name" => "div",
              "file" => "/src/Component.tsx",
              "line" => 5,
              "column" => 1,
              "bounding_box" => %{
                "x" => 10.5,
                "y" => 20.0,
                "width" => 200.0,
                "height" => 50.0
              }
            },
            "resource" => %{
              "uri" => "file:///src/Component.tsx:5:1",
              "text" => "Annotated element"
            }
          }
        }
      ]

      msg = UserMessage.new(content_blocks)

      assert length(msg.annotations) == 1
      ann = hd(msg.annotations)

      assert ann.bounding_box == %Interaction.BoundingBox{
               x: 10.5,
               y: 20.0,
               width: 200.0,
               height: 50.0
             }
    end

    test "annotation bounding_box is nil when not provided" do
      content_blocks = [
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{
              "annotation" => true,
              "annotation_index" => 0,
              "annotation_id" => "ann-no-bb",
              "tag_name" => "span",
              "file" => "/src/Text.tsx",
              "line" => 1,
              "column" => 1
            },
            "resource" => %{
              "uri" => "file:///src/Text.tsx:1:1",
              "text" => "Annotated element"
            }
          }
        }
      ]

      msg = UserMessage.new(content_blocks)
      ann = hd(msg.annotations)
      assert ann.bounding_box == nil
    end
  end

  describe "has_annotations?/1" do
    test "returns true when UserMessage has annotations" do
      interactions = [
        UserMessage.new([
          %{"type" => "text", "text" => "Hello"},
          %{
            "type" => "resource",
            "resource" => %{
              "_meta" => %{
                "annotation" => true,
                "annotation_index" => 0,
                "annotation_id" => "ann-1",
                "tag_name" => "div",
                "file" => "/path/to/file.tsx",
                "line" => 1,
                "column" => 1
              },
              "resource" => %{"uri" => "file:///path/to/file.tsx:1:1", "text" => "Annotated"}
            }
          }
        ])
      ]

      assert Interaction.has_annotations?(interactions) == true
    end

    test "returns false when no annotations" do
      interactions = [
        UserMessage.new([%{"type" => "text", "text" => "Hello"}])
      ]

      assert Interaction.has_annotations?(interactions) == false
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
          annotations: []
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

    test "includes annotation location in user message content" do
      interactions = [
        %UserMessage{
          id: "1",
          sequence: seq(),
          messages: ["Change the text"],
          timestamp: DateTime.utc_now(),
          annotations: [
            %Annotation{
              annotation_id: "ann-1",
              annotation_index: 0,
              tag_name: "div",
              file: "/path/to/Component.tsx",
              line: 42,
              column: 5
            }
          ]
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

      # Should include annotation location info
      assert text =~ "[Annotated Elements]"
      assert text =~ "/path/to/Component.tsx"
      assert text =~ "Line: 42"
    end

    test "includes bounding_box in annotation LLM message" do
      interactions = [
        %UserMessage{
          id: "1",
          sequence: seq(),
          messages: ["Fix layout"],
          timestamp: DateTime.utc_now(),
          annotations: [
            %Annotation{
              annotation_id: "ann-bb",
              annotation_index: 0,
              tag_name: "div",
              file: "/src/Layout.tsx",
              line: 10,
              column: 1,
              bounding_box: %Interaction.BoundingBox{x: 10.5, y: 20.0, width: 200.0, height: 50.0}
            }
          ]
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

      assert text =~ "Bounding Box:"
      assert text =~ "200"
    end

    test "does not add annotation section when annotations is empty" do
      interactions = [
        %UserMessage{
          id: "1",
          sequence: seq(),
          messages: ["Just a regular message"],
          timestamp: DateTime.utc_now(),
          annotations: []
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

      # Should have the message but NOT the annotation section
      assert text =~ "Just a regular message"
      refute text =~ "[Annotated Elements]"
    end

    test "handles mixed interactions in order" do
      now = DateTime.utc_now()

      interactions = [
        %UserMessage{
          id: "1",
          sequence: seq(),
          messages: ["Calculate 2+2"],
          timestamp: now,
          annotations: []
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
          annotations: []
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
    test "encodes UserMessage to JSON with messages and annotations" do
      msg =
        UserMessage.new([
          %{"type" => "text", "text" => "Hello"},
          %{
            "type" => "resource",
            "resource" => %{
              "_meta" => %{
                "annotation" => true,
                "annotation_index" => 0,
                "annotation_id" => "ann-1",
                "tag_name" => "div",
                "file" => "/path/to/file.tsx",
                "line" => 10,
                "column" => 5
              },
              "resource" => %{"uri" => "file:///path/to/file.tsx:10:5", "text" => "Annotated"}
            }
          }
        ])

      json = Jason.encode!(msg)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "user_message"
      assert decoded["messages"] == ["Hello"]

      assert length(decoded["annotations"]) == 1
      ann = hd(decoded["annotations"])
      assert ann["annotation_id"] == "ann-1"
      assert ann["tag_name"] == "div"
      assert ann["file"] == "/path/to/file.tsx"
      assert ann["line"] == 10
      assert ann["column"] == 5
      # Nil fields are stripped from JSON
      refute Map.has_key?(ann, "css_classes")
      refute Map.has_key?(ann, "screenshot")
    end

    test "encodes UserMessage with fully-populated annotation (screenshot, bounding_box, enrichment)" do
      # This test catches the bug where @derive Jason.Encoder was missing on Annotation.
      # The annotation includes all enrichment fields that would be present in a real flow.
      msg =
        UserMessage.new([
          %{"type" => "text", "text" => "Fix this"},
          %{
            "type" => "resource",
            "resource" => %{
              "_meta" => %{
                "annotation" => true,
                "annotation_index" => 0,
                "annotation_id" => "ann-full",
                "tag_name" => "H1",
                "file" => "/src/Hero.tsx",
                "line" => 30,
                "column" => 5,
                "component_name" => "Hero",
                "css_classes" => "hero-title text-xl",
                "nearby_text" => "Welcome to our app",
                "bounding_box" => %{
                  "x" => 24.0,
                  "y" => 176.0,
                  "width" => 822.0,
                  "height" => 42.0
                }
              },
              "resource" => %{
                "uri" => "file:///src/Hero.tsx:30:5",
                "text" => "Annotated element"
              }
            }
          },
          %{
            "type" => "resource",
            "resource" => %{
              "_meta" => %{
                "annotation_screenshot" => true,
                "annotation_index" => 0,
                "annotation_id" => "ann-full"
              },
              "resource" => %{
                "uri" => "annotation://ann-full/screenshot",
                "mimeType" => "image/jpeg",
                "blob" => "base64screenshotdata"
              }
            }
          }
        ])

      # This must not raise — it would crash with Protocol.UndefinedError
      # if @derive Jason.Encoder is missing on Annotation
      json = Jason.encode!(msg)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "user_message"
      assert length(decoded["annotations"]) == 1

      ann = hd(decoded["annotations"])
      assert ann["annotation_id"] == "ann-full"
      assert ann["tag_name"] == "H1"
      assert ann["css_classes"] == "hero-title text-xl"
      assert ann["nearby_text"] == "Welcome to our app"

      assert ann["bounding_box"] == %{
               "x" => 24.0,
               "y" => 176.0,
               "width" => 822.0,
               "height" => 42.0
             }

      assert ann["screenshot"] == %{"blob" => "base64screenshotdata", "mime_type" => "image/jpeg"}
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
