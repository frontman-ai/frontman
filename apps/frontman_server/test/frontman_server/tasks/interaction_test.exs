defmodule FrontmanServer.Tasks.InteractionTest do
  use FrontmanServer.InteractionCase, async: true

  alias FrontmanServer.CurrentPageContext
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.InteractionSchema

  alias FrontmanServer.Tasks.Interaction.{
    Annotation,
    UserImage,
    UserMessage
  }

  alias ModelContextProtocol, as: MCP

  # ---------------------------------------------------------------------------
  # UserMessage.new/1
  # ---------------------------------------------------------------------------

  describe "UserMessage.new/1" do
    test "extracts non-empty text messages" do
      msg = UserMessage.new([text_block("Hello")])

      assert msg.messages == ["Hello"]
    end

    test "raises for text blocks without non-empty string text" do
      assert_raise ArgumentError, "text content block must include non-empty string text", fn ->
        UserMessage.new([%{"type" => "text"}])
      end

      assert_raise ArgumentError, "text content block must include non-empty string text", fn ->
        UserMessage.new([%{"type" => "text", "text" => ""}])
      end

      assert_raise ArgumentError, "text content block must include non-empty string text", fn ->
        UserMessage.new([%{"type" => "text", "text" => 1}])
      end
    end

    test "extracts annotation from resource block" do
      msg =
        UserMessage.new([
          text_block("Hello"),
          annotation_block("ann-1", "div", "/path/to/component.tsx", 42, 10)
        ])

      assert [ann] = msg.annotations
      assert ann.annotation_id == "ann-1"
      assert ann.tag_name == "div"
      assert ann.file == "/path/to/component.tsx"
      assert ann.line == 42
      assert ann.column == 10
      assert ann.screenshot == nil
      assert ann.bounding_box == nil
    end

    test "returns empty annotations when no annotation blocks" do
      msg = UserMessage.new([text_block("Hello")])
      assert msg.annotations == []
    end

    test "pairs screenshot with annotation by annotation_id" do
      msg =
        UserMessage.new([
          text_block("Fix this button"),
          annotation_block("ann-1", "button", "/src/Button.tsx", 15, 3),
          screenshot_block("ann-1", "base64screenshotdata")
        ])

      assert [ann] = msg.annotations
      assert ann.file == "/src/Button.tsx"

      assert ann.screenshot == %Interaction.Screenshot{
               blob: "base64screenshotdata",
               mime_type: "image/png"
             }
    end

    test "extracts multiple annotations with enrichment data" do
      msg =
        UserMessage.new([
          text_block("Fix these"),
          annotation_block("ann-1", "div", "/src/A.tsx", 10, 1,
            component_name: "Header",
            css_classes: "header main",
            nearby_text: "Welcome"
          ),
          annotation_block("ann-2", "button", "/src/B.tsx", 20, 5,
            index: 1,
            comment: "Make this red"
          )
        ])

      assert [ann1, ann2] = msg.annotations
      assert ann1.annotation_index == 0
      assert ann1.component_name == "Header"
      assert ann1.css_classes == "header main"
      assert ann1.nearby_text == "Welcome"
      assert ann2.annotation_index == 1
      assert ann2.comment == "Make this red"
    end

    test "extracts bounding_box when provided" do
      bb = %{"x" => 10.5, "y" => 20.0, "width" => 200.0, "height" => 50.0}

      msg =
        UserMessage.new([
          annotation_block("ann-bb", "div", "/src/Component.tsx", 5, 1, bounding_box: bb)
        ])

      assert [ann] = msg.annotations

      assert ann.bounding_box == %Interaction.BoundingBox{
               x: 10.5,
               y: 20.0,
               width: 200.0,
               height: 50.0
             }
    end

    test "preserves generic annotation metadata when provided" do
      context = %{
        "target_id" => "abc12345",
        "target_type" => "widget"
      }

      msg =
        UserMessage.new([
          text_block("Fix this"),
          annotation_block("ann-el", "span", "/src/Component.tsx", 5, 1,
            metadata: %{"custom_context" => context}
          )
        ])

      assert [ann] = msg.annotations
      assert ann.metadata == %{"custom_context" => context}
    end

    test "extracts current page context from resource block" do
      msg =
        UserMessage.new([
          text_block("Hello"),
          current_page_block("https://example.com/app", %{
            "viewport_width" => 390,
            "viewport_height" => 844,
            "device_pixel_ratio" => 3.0,
            "title" => "Dashboard",
            "color_scheme" => "dark",
            "scroll_y" => 120
          })
        ])

      assert msg.current_page == %Interaction.CurrentPage{
               url: "https://example.com/app",
               viewport_width: 390,
               viewport_height: 844,
               device_pixel_ratio: 3.0,
               title: "Dashboard",
               color_scheme: "dark",
               scroll_y: 120
             }
    end

    test "coerces integer device pixel ratio before persistence" do
      msg =
        UserMessage.new([
          current_page_block("https://example.com/app", %{"device_pixel_ratio" => 1})
        ])

      assert msg.current_page.device_pixel_ratio == 1.0

      assert %{current_page: %{device_pixel_ratio: 1.0}} = Interaction.to_data_map(msg)
    end

    test "ignores resource url meta without current page marker" do
      msg =
        UserMessage.new([
          text_block("Hello"),
          %{
            "type" => "resource",
            "resource" => %{
              "_meta" => %{"url" => "https://example.com/not-page-context"},
              "resource" => %{
                "uri" => "custom://resource",
                "mimeType" => "text/plain",
                "text" => "Resource with URL metadata"
              }
            }
          }
        ])

      assert msg.current_page == nil
    end
  end

  # ---------------------------------------------------------------------------
  # to_swarm_messages/1
  # ---------------------------------------------------------------------------

  describe "to_swarm_messages/1" do
    test "converts user message text and images to Swarm content parts" do
      msg = %{
        user_msg("Look at this")
        | images: [
            %UserImage{
              blob: Base.encode64("image-bytes"),
              mime_type: "image/png",
              filename: "screen.png"
            }
          ]
      }

      [swarm_msg] = Interaction.to_swarm_messages([msg])

      assert %SwarmAi.Message.User{content: content} = swarm_msg

      assert [
               %SwarmAi.Message.ContentPart{type: :text, text: "Look at this"},
               %SwarmAi.Message.ContentPart{
                 type: :image,
                 data: "image-bytes",
                 media_type: "image/png"
               }
             ] = content
    end

    test "converts assistant tool calls to Swarm tool calls" do
      interactions = [
        agent_resp("I'll read it", %{
          "tool_calls" => [db_tool_call("toolu_012", "read_file", ~s({"path":"README.md"}))],
          "response_id" => "resp_123",
          "phase" => "tool_call"
        })
      ]

      [swarm_msg] = Interaction.to_swarm_messages(interactions)

      assert %SwarmAi.Message.Assistant{
               content: [%SwarmAi.Message.ContentPart{type: :text, text: "I'll read it"}],
               tool_calls: [
                 %SwarmAi.ToolCall{
                   id: "toolu_012",
                   name: "read_file",
                   arguments: ~s({"path":"README.md"})
                 }
               ],
               metadata: %{response_id: "resp_123", phase: "tool_call"}
             } = swarm_msg
    end
  end

  # ---------------------------------------------------------------------------
  # to_swarm_messages/1
  # ---------------------------------------------------------------------------

  describe "to_swarm_messages/1 conversation coverage" do
    test "converts user message with correct role and content" do
      messages = Interaction.to_swarm_messages([user_msg("Hello")])

      assert [msg] = messages
      assert SwarmAi.Message.role(msg) == :user
      assert is_list(msg.content)
    end

    test "converts agent response to assistant message with content" do
      messages = Interaction.to_swarm_messages([agent_resp("Hi there")])

      assert [msg] = messages
      assert SwarmAi.Message.role(msg) == :assistant
      assert [%{type: :text, text: "Hi there"}] = msg.content
    end

    test "converts tool results to tool messages" do
      interaction = tool_result("call_123", "calculator", MCP.tool_result_text("42"))

      messages = Interaction.to_swarm_messages([interaction])

      assert [msg] = messages
      assert SwarmAi.Message.role(msg) == :tool
      assert msg.tool_call_id == "call_123"
      assert msg.metadata == %{}
    end

    test "skips ToolCall structs (they live in agent response metadata)" do
      messages = Interaction.to_swarm_messages([tool_call("call_123", "calculator")])
      assert messages == []
    end

    test "handles mixed conversation in correct order" do
      interactions = [
        user_msg("Calculate 2+2"),
        agent_resp("Let me calculate", %{
          "tool_calls" => [%{"id" => "c1", "name" => "calc", "arguments" => %{}}]
        }),
        tool_call("c1", "calc"),
        tool_result("c1", "calc", MCP.tool_result_text("4")),
        agent_resp("The answer is 4")
      ]

      messages = Interaction.to_swarm_messages(interactions)
      # UserMessage + AgentResponse(with tool) + ToolResult + AgentResponse(final)
      # ToolCall is skipped
      assert length(messages) == 4
      assert Enum.map(messages, &SwarmAi.Message.role/1) == [:user, :assistant, :tool, :assistant]
    end

    test "includes annotation location info in user message content" do
      ann = %Annotation{
        annotation_id: "ann-1",
        annotation_index: 0,
        tag_name: "div",
        file: "/path/to/Component.tsx",
        line: 42,
        column: 5
      }

      messages = Interaction.to_swarm_messages([user_msg("Change the text", [ann])])
      text = extract_text(hd(messages))

      assert text =~ "Change the text"
      assert text =~ "[Annotated Elements]"
      assert text =~ "/path/to/Component.tsx"
      assert text =~ "Line: 42"
    end

    test "includes bounding_box in annotation LLM message" do
      ann = %Annotation{
        annotation_id: "ann-bb",
        annotation_index: 0,
        tag_name: "div",
        file: "/src/Layout.tsx",
        line: 10,
        column: 1,
        bounding_box: %Interaction.BoundingBox{x: 10.5, y: 20.0, width: 200.0, height: 50.0}
      }

      messages = Interaction.to_swarm_messages([user_msg("Fix layout", [ann])])
      text = extract_text(hd(messages))

      assert text =~ "Bounding Box:"
      assert text =~ "200"
    end

    test "does not add annotation section when annotations is empty" do
      messages = Interaction.to_swarm_messages([user_msg("Just a regular message")])
      text = extract_text(hd(messages))

      assert text =~ "Just a regular message"
      refute text =~ "[Annotated Elements]"
    end

    test "includes current page context in user message content" do
      msg = %{
        user_msg("Fix this route")
        | current_page: %Interaction.CurrentPage{
            url: "https://example.com/settings",
            viewport_width: 1440,
            viewport_height: 900,
            device_pixel_ratio: 2.0,
            title: "Settings",
            color_scheme: "light",
            scroll_y: 0
          }
      }

      [llm_msg] = Interaction.to_swarm_messages([msg])
      text = extract_text(llm_msg)

      assert text =~ CurrentPageContext.header()
      assert text =~ "URL: https://example.com/settings"
      assert text =~ "Viewport: 1440x900"
      assert text =~ "Page Title: Settings"
    end

    test "lists attachment URI without tool-specific guidance" do
      msg =
        user_msg("Save the image")
        |> then(fn msg ->
          %{
            msg
            | images: [
                %UserImage{
                  blob: Base.encode64("image-bytes"),
                  mime_type: "image/png",
                  filename: "hero.png",
                  uri: "attachment://att_hero/hero.png"
                }
              ]
          }
        end)

      [llm_msg] = Interaction.to_swarm_messages([msg])
      text = extract_text(llm_msg)
      assert text =~ "attachment://att_hero/hero.png"
      refute text =~ "write_file with image_ref"
    end
  end

  # ---------------------------------------------------------------------------
  # to_swarm_messages/1 — DB-loaded metadata (string keys)
  # ---------------------------------------------------------------------------

  describe "to_swarm_messages/1 with DB-loaded metadata (string keys)" do
    test "converts tool_calls stored in OpenAI wire format (string keys)" do
      interactions = [
        agent_resp("I'll read the file", %{
          "tool_calls" => [
            db_tool_call("toolu_012", "read_file", ~s({"path": "src/app/page.tsx"}))
          ]
        })
      ]

      [msg] = Interaction.to_swarm_messages(interactions)

      assert SwarmAi.Message.role(msg) == :assistant
      assert [tc] = msg.tool_calls
      assert %SwarmAi.ToolCall{} = tc
      assert tc.id == "toolu_012"
      assert tc.name == "read_file"
      assert tc.arguments == ~s({"path": "src/app/page.tsx"})
    end

    test "converts multiple tool_calls from DB" do
      interactions = [
        agent_resp("Let me search", %{
          "tool_calls" => [
            db_tool_call("toolu_001", "read_file", ~s({"path": "file1.txt"})),
            db_tool_call("toolu_002", "glob", ~s({"pattern": "*.tsx"}))
          ]
        })
      ]

      [msg] = Interaction.to_swarm_messages(interactions)

      assert length(msg.tool_calls) == 2
      assert Enum.all?(msg.tool_calls, &match?(%SwarmAi.ToolCall{}, &1))
      assert Enum.map(msg.tool_calls, & &1.id) == ["toolu_001", "toolu_002"]
      assert Enum.map(msg.tool_calls, & &1.name) == ["read_file", "glob"]
    end

    test "handles empty or nil tool_calls from DB gracefully" do
      for tool_calls <- [[], nil] do
        [msg] =
          Interaction.to_swarm_messages([agent_resp("Just text", %{"tool_calls" => tool_calls})])

        assert SwarmAi.Message.role(msg) == :assistant
        assert [%{type: :text, text: "Just text"}] = msg.content
        assert msg.tool_calls == []
      end
    end

    test "preserves response metadata and reasoning_details from DB metadata" do
      interactions = [
        agent_resp("Thinking...", %{
          "tool_calls" => [db_tool_call("call_123", "test_tool")],
          "response_id" => "resp_abc123",
          "phase" => "final_answer",
          "phase_items" => [
            %{
              "phase" => "commentary",
              "content" => [%{"type" => "output_text", "text" => "Thinking"}]
            },
            %{
              "phase" => "final_answer",
              "content" => [%{"type" => "output_text", "text" => "Done"}]
            }
          ],
          "reasoning_details" => [%{"type" => "reasoning.encrypted", "data" => "encrypted_data"}]
        })
      ]

      [msg] = Interaction.to_swarm_messages(interactions)

      assert msg.metadata == %{
               response_id: "resp_abc123",
               phase: "final_answer",
               phase_items: [
                 %{
                   "phase" => "commentary",
                   "content" => [%{"type" => "output_text", "text" => "Thinking"}]
                 },
                 %{
                   "phase" => "final_answer",
                   "content" => [%{"type" => "output_text", "text" => "Done"}]
                 }
               ]
             }

      assert msg.reasoning_details == [
               %{"type" => "reasoning.encrypted", "data" => "encrypted_data"}
             ]
    end

    test "preserves response metadata even when assistant has no tool_calls" do
      interactions = [
        agent_resp("All done", %{
          "response_id" => "resp_final_123",
          "phase" => "final_answer"
        })
      ]

      [msg] = Interaction.to_swarm_messages(interactions)

      assert msg.metadata == %{response_id: "resp_final_123", phase: "final_answer"}
      assert msg.tool_calls == []
    end

    test "full conversation round-trip with tool calls from DB" do
      interactions = [
        user_msg("What's in the file?"),
        agent_resp("I'll read the file for you.", %{
          "tool_calls" => [db_tool_call("toolu_read_123", "read_file", ~s({"path": "README.md"}))]
        }),
        tool_call("toolu_read_123", "read_file", %{"path" => "README.md"}),
        tool_result(
          "toolu_read_123",
          "read_file",
          MCP.tool_result_text("# README\nThis is a readme file.")
        ),
        agent_resp("The file contains a README header.")
      ]

      messages = Interaction.to_swarm_messages(interactions)

      assert length(messages) == 4

      [user_msg_, assistant_with_tool, tool_result_, final_assistant] = messages
      assert SwarmAi.Message.role(user_msg_) == :user
      assert SwarmAi.Message.role(assistant_with_tool) == :assistant
      assert SwarmAi.Message.role(tool_result_) == :tool
      assert SwarmAi.Message.role(final_assistant) == :assistant

      assert [tc] = assistant_with_tool.tool_calls
      assert %SwarmAi.ToolCall{} = tc
      assert tc.id == "toolu_read_123"
      assert tc.name == "read_file"

      assert tool_result_.tool_call_id == "toolu_read_123"
    end

    test "handles flat format tool_calls with string keys" do
      interactions = [
        agent_resp("Checking weather", %{
          "tool_calls" => [flat_tool_call("call_flat_1", "get_weather", ~s({"city": "NYC"}))]
        })
      ]

      [msg] = Interaction.to_swarm_messages(interactions)

      assert [tc] = msg.tool_calls
      assert %SwarmAi.ToolCall{} = tc
      assert tc.id == "call_flat_1"
      assert tc.name == "get_weather"
    end
  end

  describe "InteractionSchema.to_struct/1" do
    test "deserializes normalized user message data" do
      message =
        UserMessage.new([
          text_block("hello"),
          current_page_block("http://localhost:4321/"),
          annotation_block("ann-1", "H1", "/src/Hero.tsx", 12, 4,
            bounding_box: %{"x" => 1.0, "y" => 2.0, "width" => 3.0, "height" => 4.0}
          )
        ])

      row = %InteractionSchema{
        type: :user_message,
        data: Interaction.to_data_map(message)
      }

      assert %Interaction.UserMessage{current_page: %Interaction.CurrentPage{}, annotations: [_]} =
               InteractionSchema.to_struct(row)
    end
  end

  # ---------------------------------------------------------------------------
  # JSON encoding
  # ---------------------------------------------------------------------------

  describe "JSON encoding" do
    test "encodes UserMessage with annotation including all enrichment fields" do
      msg =
        UserMessage.new([
          text_block("Fix this"),
          annotation_block("ann-full", "H1", "/src/Hero.tsx", 30, 5,
            component_name: "Hero",
            css_classes: "hero-title text-xl",
            nearby_text: "Welcome to our app",
            metadata: %{
              "custom_context" => %{
                "target_id" => "abc12345"
              }
            },
            bounding_box: %{"x" => 24.0, "y" => 176.0, "width" => 822.0, "height" => 42.0}
          ),
          screenshot_block("ann-full", "base64screenshotdata", "image/jpeg")
        ])

      decoded = msg |> Jason.encode!() |> Jason.decode!()

      assert decoded["type"] == "user_message"
      assert decoded["messages"] == ["Fix this"]
      assert [ann] = decoded["annotations"]
      assert ann["annotation_id"] == "ann-full"
      assert ann["tag_name"] == "H1"
      assert ann["css_classes"] == "hero-title text-xl"
      assert ann["nearby_text"] == "Welcome to our app"

      assert ann["custom_context"] == %{
               "target_id" => "abc12345"
             }

      assert ann["bounding_box"] == %{
               "x" => 24.0,
               "y" => 176.0,
               "width" => 822.0,
               "height" => 42.0
             }

      assert ann["screenshot"] == %{"blob" => "base64screenshotdata", "mime_type" => "image/jpeg"}

      # Nil enrichment fields are stripped from JSON
      refute Map.has_key?(ann, "comment")
    end

    test "encodes ToolCall to JSON" do
      tc = tool_call("call_123", "calculator", %{"x" => 1})

      decoded = tc |> Jason.encode!() |> Jason.decode!()

      assert decoded["type"] == "tool_call"
      assert decoded["tool_name"] == "calculator"
      assert decoded["tool_call_id"] == "call_123"
    end

    test "encodes ToolResult to JSON" do
      tr = tool_result("call_123", "calculator", MCP.tool_result_text("42"))

      decoded = tr |> Jason.encode!() |> Jason.decode!()

      assert decoded["type"] == "tool_result"
      assert decoded["result"] == MCP.tool_result_text("42")
      assert decoded["is_error"] == false
    end
  end

  describe "AgentPaused" do
    test "new/2 builds struct with correct fields" do
      interaction = Interaction.AgentPaused.new("question", 120_000)

      assert interaction.tool_name == "question"
      assert interaction.timeout_ms == 120_000
      assert interaction.reason =~ "question"
      assert interaction.reason =~ "120000"
      assert interaction.reason =~ "pause_agent"
      assert is_binary(interaction.id)
      assert %DateTime{} = interaction.timestamp
    end

    test "AgentPaused is in interaction_modules list" do
      assert Interaction.AgentPaused in Interaction.interaction_modules()
    end
  end
end
