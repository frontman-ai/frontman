defmodule FrontmanServer.Tasks.InteractionTest do
  use FrontmanServer.InteractionCase, async: true

  alias FrontmanServer.CurrentPageContext
  alias FrontmanServer.Skills.Skill
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.InteractionSchema

  alias FrontmanServer.Tasks.Interaction.{
    Annotation,
    UserImage,
    UserMessage
  }

  alias ModelContextProtocol, as: MCP

  describe "SkillUsed.build/1" do
    test "snapshots skill content" do
      skill = %Skill{
        id: Ecto.UUID.generate(),
        name: "design_polish",
        description: "Improve visual quality.",
        content: "Use hierarchy."
      }

      assert %Interaction.SkillUsed{
               skill_id: skill_id,
               skill_name: "design_polish",
               skill_content: "Use hierarchy."
             } = Interaction.SkillUsed.build(skill)

      assert skill_id == skill.id
    end
  end

  describe "UserMessage.attrs/1" do
    test "extracts non-empty text messages" do
      msg = build_user_message([text_block("Hello")])

      assert msg.messages == ["Hello"]
    end

    test "accepts resource-only prompts without a text block" do
      msg =
        build_user_message([
          current_page_block("https://example.com/app", %{
            "viewport_width" => 390,
            "viewport_height" => 844
          })
        ])

      assert msg.messages == []
      assert msg.current_page.url == "https://example.com/app"
    end

    test "returns error for text blocks without non-empty string text" do
      assert {:error,
              {:invalid_content_block, "text content block must include non-empty string text"}} =
               UserMessage.attrs([%{"type" => "text"}])

      assert {:error,
              {:invalid_content_block, "text content block must include non-empty string text"}} =
               UserMessage.attrs([%{"type" => "text", "text" => ""}])

      assert {:error,
              {:invalid_content_block, "text content block must include non-empty string text"}} =
               UserMessage.attrs([%{"type" => "text", "text" => 1}])
    end

    test "extracts annotation from resource block" do
      msg =
        build_user_message([
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
      msg = build_user_message([text_block("Hello")])
      assert msg.annotations == []
    end

    test "pairs screenshot with annotation by annotation_id" do
      msg =
        build_user_message([
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
        build_user_message([
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
      assert ann1.metadata["css_classes"] == "header main"
      assert ann1.metadata["nearby_text"] == "Welcome"
      assert ann2.annotation_index == 1
      assert ann2.comment == "Make this red"
    end

    test "extracts annotated definition and recursive invocation chain" do
      parent = %{
        "component_name" => "HeroPost",
        "file" => "src/app/_components/hero-post.tsx",
        "line" => 42,
        "column" => 11,
        "parent" => %{
          "component_name" => "Index",
          "file" => "src/app/page.tsx",
          "line" => 18,
          "column" => 5
        }
      }

      msg =
        build_user_message([
          annotation_block("ann-avatar", "div", "src/app/_components/avatar.tsx", 10, 7,
            component_name: "Avatar",
            parent: parent
          )
        ])

      assert [ann] = msg.annotations
      assert ann.component_name == "Avatar"
      assert ann.file == "src/app/_components/avatar.tsx"
      assert ann.line == 10
      assert ann.parent.component_name == "HeroPost"
      assert ann.parent.file == "src/app/_components/hero-post.tsx"
      assert ann.parent.parent.component_name == "Index"
      assert ann.parent.parent.file == "src/app/page.tsx"
    end

    test "extracts bounding_box when provided" do
      bb = %{"x" => 10.5, "y" => 20.0, "width" => 200.0, "height" => 50.0}

      msg =
        build_user_message([
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
        build_user_message([
          text_block("Fix this"),
          annotation_block("ann-el", "span", "/src/Component.tsx", 5, 1,
            element_context: ~s(selected tag="span" selector="#target"),
            metadata: %{"custom_context" => context}
          )
        ])

      assert [ann] = msg.annotations

      assert ann.metadata["custom_context"] == context
      assert ann.metadata["element_context"] == ~s(selected tag="span" selector="#target")
    end

    test "extracts current page context from resource block" do
      msg =
        build_user_message([
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
        build_user_message([
          current_page_block("https://example.com/app", %{"device_pixel_ratio" => 1})
        ])

      assert msg.current_page.device_pixel_ratio == 1.0
    end

    test "ignores resource url meta without current page marker" do
      msg =
        build_user_message([
          text_block("Hello"),
          %{
            "type" => "resource",
            "_meta" => %{"url" => "https://example.com/not-page-context"},
            "resource" => %{
              "uri" => "custom://resource",
              "mimeType" => "text/plain",
              "text" => "Resource with URL metadata"
            }
          }
        ])

      assert msg.current_page == nil
    end
  end

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

    test "converts tool-call-only assistant responses without text content" do
      interactions = [
        agent_resp(nil, %{
          "tool_calls" => [db_tool_call("toolu_012", "read_file", ~s({"path":"README.md"}))],
          "response_id" => "resp_123",
          "phase" => "tool_call"
        })
      ]

      [swarm_msg] = Interaction.to_swarm_messages(interactions)

      assert %SwarmAi.Message.Assistant{
               content: [],
               tool_calls: [%SwarmAi.ToolCall{id: "toolu_012", name: "read_file"}],
               metadata: %{response_id: "resp_123", phase: "tool_call"}
             } = swarm_msg
    end
  end

  describe "to_swarm_messages/1 conversation coverage" do
    test "skips ToolCall structs (they live in agent response metadata)" do
      messages = Interaction.to_swarm_messages([tool_call("call_123", "calculator")])
      assert messages == []
    end

    test "adds active skill as separate content part on previous user message" do
      skill_used = %Interaction.SkillUsed{
        id: "skill-used-1",
        timestamp: DateTime.utc_now(),
        skill_id: Ecto.UUID.generate(),
        skill_name: "design_polish",
        skill_content: "Use hierarchy."
      }

      messages = Interaction.to_swarm_messages([user_msg("Improve hero"), skill_used])

      assert [%SwarmAi.Message.User{content: content}] = messages

      assert [
               %SwarmAi.Message.ContentPart{
                 type: :text,
                 text:
                   "## Active Skill: design_polish\n\nUse this expert lens for this turn.\n\nUse hierarchy."
               },
               %SwarmAi.Message.ContentPart{type: :text, text: "Improve hero"}
             ] = content
    end

    test "skips unpaired SkillUsed structs" do
      skill_used = %Interaction.SkillUsed{
        id: "skill-used-1",
        timestamp: DateTime.utc_now(),
        skill_id: Ecto.UUID.generate(),
        skill_name: "design_polish",
        skill_content: "Use hierarchy."
      }

      assert Interaction.to_swarm_messages([skill_used]) == []
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
      assert length(messages) == 4
      assert Enum.map(messages, &SwarmAi.Message.role/1) == [:user, :assistant, :tool, :assistant]
      assert [%SwarmAi.ToolCall{arguments: "{}"}] = Enum.at(messages, 1).tool_calls
    end

    test "formats complete page and annotation context exactly" do
      ann = %Annotation{
        annotation_id: "ann-avatar",
        annotation_index: 0,
        tag_name: "div",
        selector: ".avatar-name",
        component_name: "Avatar",
        component_props: %{"name" => "JJ Kasper"},
        file: "src/app/_components/avatar.tsx",
        line: 10,
        column: 7,
        bounding_box: %Interaction.BoundingBox{x: 10.5, y: 20.0, width: 200.0, height: 50.0},
        metadata: %{
          "element_context" => ~s(selected tag="div" selector=".avatar-name" children=1),
          "source_location_error" => "source map unavailable"
        },
        parent: %Interaction.ParentLocation{
          component_name: "HeroPost",
          component_props: %{"slug" => "hello-world"},
          file: "src/app/_components/hero-post.tsx",
          line: 42,
          column: 11,
          parent: %Interaction.ParentLocation{
            component_name: "Index",
            file: "src/app/page.tsx",
            line: 18,
            column: 5
          }
        }
      }

      msg = %{
        user_msg("Show the call tree", [ann])
        | current_page: %Interaction.CurrentPage{
            url: "https://example.com/posts/hello-world",
            viewport_width: 1440,
            viewport_height: 900,
            device_pixel_ratio: 2.0,
            title: "Hello World",
            color_scheme: "dark",
            scroll_y: 320
          }
      }

      assert [message] = Interaction.to_swarm_messages([msg])
      text = extract_text(message)

      assert text =~
               """
               Show the call tree
               [Current Page Context]
               URL: https://example.com/posts/hello-world
               Viewport: 1440x900
               Device Pixel Ratio: 2.0
               Page Title: Hello World
               Color Scheme: dark
               Scroll Position: 320px
               """

      assert text =~
               """
               [Annotated Elements]
               Annotation 1:
                 Tag: <div>
                 File: src/app/_components/avatar.tsx
                 Line: 10
                 Column: 7
                 Component: Avatar
                 CSS Selector: .avatar-name
                 Element Context: selected tag="div" selector=".avatar-name" children=1
                 Bounding Box: {x: 10.5, y: 20.0, width: 200.0, height: 50.0}
                 Props: {"name":"JJ Kasper"}
                 Source Location Error: source map unavailable
                 Parent: 1. src/app/_components/hero-post.tsx:42:11 (HeroPost)
                  Props: {"slug":"hello-world"}
                 2. src/app/page.tsx:18:5 (Index)
               """

      assert :binary.match(text, "src/app/_components/avatar.tsx") <
               :binary.match(text, "src/app/_components/hero-post.tsx")
    end

    test "does not add annotation section when annotations is empty" do
      messages = Interaction.to_swarm_messages([user_msg("Just a regular message")])
      text = extract_text(hd(messages))

      assert text =~ "Just a regular message"
      refute text =~ "[Annotated Elements]"
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

  describe "to_swarm_messages/1 with DB-loaded metadata (string keys)" do
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

  describe "InteractionSchema data" do
    test "keeps typed embedded interaction data" do
      message =
        build_user_message([
          text_block("hello"),
          current_page_block("http://localhost:4321/"),
          annotation_block("ann-1", "H1", "/src/Hero.tsx", 12, 4,
            bounding_box: %{"x" => 1.0, "y" => 2.0, "width" => 3.0, "height" => 4.0}
          )
        ])

      row = %InteractionSchema{
        type: :user_message,
        data: message
      }

      assert %Interaction.UserMessage{current_page: %Interaction.CurrentPage{}, annotations: [_]} =
               row.data
    end

    test "deserializes skill used data" do
      skill_used = %Interaction.SkillUsed{
        id: "skill-used-1",
        timestamp: DateTime.utc_now(),
        skill_id: Ecto.UUID.generate(),
        skill_name: "design_polish",
        skill_content: "Use hierarchy."
      }

      row = %InteractionSchema{
        type: :skill_used,
        data: Interaction.to_data_map(skill_used)
      }

      assert %Interaction.SkillUsed{skill_name: "design_polish", skill_content: "Use hierarchy."} =
               InteractionSchema.to_struct(row)
    end
  end

  describe "InteractionSchema.create_changeset/3" do
    test "requires a turn number for SkillUsed" do
      skill_used = %Interaction.SkillUsed{
        id: "skill-used-1",
        timestamp: DateTime.utc_now(),
        skill_id: Ecto.UUID.generate(),
        skill_name: "design_polish"
      }

      changeset =
        InteractionSchema.create_changeset(
          %FrontmanServer.Tasks.TaskSchema{id: Ecto.UUID.generate()},
          skill_used,
          nil
        )

      refute changeset.valid?
      assert {"missing for skill_used", []} = changeset.errors[:turn_number]
    end
  end

  describe "JSON encoding" do
    test "encodes UserMessage with annotation including all enrichment fields" do
      msg =
        build_user_message([
          text_block("Fix this"),
          current_page_block("https://example.com/settings", %{
            "viewport_width" => 1440,
            "viewport_height" => 900,
            "device_pixel_ratio" => 2.0,
            "title" => "Settings",
            "color_scheme" => "dark",
            "scroll_y" => 320
          }),
          annotation_block("ann-full", "H1", "/src/Hero.tsx", 30, 5,
            component_name: "Hero",
            element_context: ~s(selected tag="h1" selector="#hero-title"),
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

      refute Map.has_key?(decoded, "type")
      assert decoded["messages"] == ["Fix this"]

      assert decoded["current_page"] == %{
               "url" => "https://example.com/settings",
               "viewport_width" => 1440,
               "viewport_height" => 900,
               "device_pixel_ratio" => 2.0,
               "title" => "Settings",
               "color_scheme" => "dark",
               "scroll_y" => 320
             }

      assert [ann] = decoded["annotations"]
      assert ann["annotation_id"] == "ann-full"
      assert ann["tag_name"] == "H1"
      assert ann["css_classes"] == "hero-title text-xl"
      assert ann["element_context"] =~ "#hero-title"
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

      refute Map.has_key?(ann, "comment")
    end
  end

  describe "AgentPaused" do
    test "struct has correct fields" do
      interaction = agent_paused("question", 120_000)

      assert interaction.tool_name == "question"
      assert interaction.timeout_ms == 120_000
      assert interaction.reason =~ "question"
      assert interaction.reason =~ "120000"
      assert interaction.reason =~ "pause_agent"
      assert is_binary(interaction.id)
      assert %DateTime{} = interaction.timestamp
    end

    test "AgentPaused is in persisted interaction types" do
      assert Interaction.AgentPaused in Keyword.values(InteractionSchema.types())
    end
  end

  defp build_user_message(content_blocks) do
    assert {:ok, attrs} = UserMessage.attrs(content_blocks)

    %UserMessage{}
    |> UserMessage.changeset(attrs)
    |> Ecto.Changeset.apply_action!(:insert)
  end
end
