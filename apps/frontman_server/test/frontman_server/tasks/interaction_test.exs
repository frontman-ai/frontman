defmodule FrontmanServer.Tasks.InteractionTest do
  use FrontmanServer.InteractionCase, async: true

  alias FrontmanServer.Tasks.Interaction

  alias FrontmanServer.Tasks.Interaction.{
    Annotation,
    ToolCall,
    ToolResult,
    UserMessage
  }

  # ---------------------------------------------------------------------------
  # UserMessage.new/1
  # ---------------------------------------------------------------------------

  describe "UserMessage.new/1" do
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
  end

  # ---------------------------------------------------------------------------
  # has_annotations?/1
  # ---------------------------------------------------------------------------

  describe "has_annotations?/1" do
    test "returns true when UserMessage has annotations, false otherwise" do
      with_ann =
        UserMessage.new([
          text_block("Hello"),
          annotation_block("ann-1", "div", "/path/to/file.tsx", 1, 1)
        ])

      without_ann = UserMessage.new([text_block("Hello")])

      assert Interaction.has_annotations?([with_ann]) == true
      assert Interaction.has_annotations?([without_ann]) == false
    end
  end

  # ---------------------------------------------------------------------------
  # to_llm_messages/1
  # ---------------------------------------------------------------------------

  describe "to_llm_messages/1" do
    test "converts user message with correct role and content" do
      messages = Interaction.to_llm_messages([user_msg("Hello")])

      assert [msg] = messages
      assert msg.role == :user
      assert is_list(msg.content)
    end

    test "converts agent response to assistant message with content" do
      messages = Interaction.to_llm_messages([agent_resp("Hi there")])

      assert [msg] = messages
      assert msg.role == :assistant
      assert [%{type: :text, text: "Hi there"}] = msg.content
    end

    test "converts tool results to tool messages" do
      messages = Interaction.to_llm_messages([tool_result("call_123", "calculator", 42)])

      assert [msg] = messages
      assert msg.role == :tool
      assert msg.tool_call_id == "call_123"
    end

    test "skips ToolCall structs (they live in agent response metadata)" do
      messages = Interaction.to_llm_messages([tool_call("call_123", "calculator")])
      assert messages == []
    end

    test "handles mixed conversation in correct order" do
      interactions = [
        user_msg("Calculate 2+2"),
        agent_resp("Let me calculate", %{tool_calls: [%{id: "c1", name: "calc", arguments: %{}}]}),
        tool_call("c1", "calc"),
        tool_result("c1", "calc", 4),
        agent_resp("The answer is 4")
      ]

      messages = Interaction.to_llm_messages(interactions)
      # UserMessage + AgentResponse(with tool) + ToolResult + AgentResponse(final)
      # ToolCall is skipped
      assert length(messages) == 4
      assert Enum.map(messages, & &1.role) == [:user, :assistant, :tool, :assistant]
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

      messages = Interaction.to_llm_messages([user_msg("Change the text", [ann])])
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

      messages = Interaction.to_llm_messages([user_msg("Fix layout", [ann])])
      text = extract_text(hd(messages))

      assert text =~ "Bounding Box:"
      assert text =~ "200"
    end

    test "does not add annotation section when annotations is empty" do
      messages = Interaction.to_llm_messages([user_msg("Just a regular message")])
      text = extract_text(hd(messages))

      assert text =~ "Just a regular message"
      refute text =~ "[Annotated Elements]"
    end
  end

  # ---------------------------------------------------------------------------
  # to_llm_messages/1 — DB-loaded metadata (string keys)
  # ---------------------------------------------------------------------------

  describe "to_llm_messages/1 with DB-loaded metadata (string keys)" do
    test "converts tool_calls stored in OpenAI wire format (string keys)" do
      interactions = [
        agent_resp("I'll read the file", %{
          "tool_calls" => [
            db_tool_call("toolu_012", "read_file", ~s({"path": "src/app/page.tsx"}))
          ]
        })
      ]

      [msg] = Interaction.to_llm_messages(interactions)

      assert msg.role == :assistant
      assert [tc] = msg.tool_calls
      assert %ReqLLM.ToolCall{} = tc
      assert tc.id == "toolu_012"
      assert tc.function.name == "read_file"
      assert tc.function.arguments == ~s({"path": "src/app/page.tsx"})
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

      [msg] = Interaction.to_llm_messages(interactions)

      assert length(msg.tool_calls) == 2
      assert Enum.all?(msg.tool_calls, &match?(%ReqLLM.ToolCall{}, &1))
      assert Enum.map(msg.tool_calls, & &1.id) == ["toolu_001", "toolu_002"]
      assert Enum.map(msg.tool_calls, & &1.function.name) == ["read_file", "glob"]
    end

    test "handles empty or nil tool_calls from DB gracefully" do
      for tool_calls <- [[], nil] do
        [msg] =
          Interaction.to_llm_messages([agent_resp("Just text", %{"tool_calls" => tool_calls})])

        assert msg.role == :assistant
        assert [%{type: :text, text: "Just text"}] = msg.content
      end
    end

    test "preserves response_id and reasoning_details from DB metadata" do
      interactions = [
        agent_resp("Thinking...", %{
          "tool_calls" => [db_tool_call("call_123", "test_tool")],
          "response_id" => "resp_abc123",
          "reasoning_details" => [%{"type" => "reasoning.encrypted", "data" => "encrypted_data"}]
        })
      ]

      [msg] = Interaction.to_llm_messages(interactions)

      assert msg.metadata == %{response_id: "resp_abc123"}

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
        tool_result("toolu_read_123", "read_file", "# README\nThis is a readme file."),
        agent_resp("The file contains a README header.")
      ]

      messages = Interaction.to_llm_messages(interactions)

      assert length(messages) == 4

      [user_msg_, assistant_with_tool, tool_result_, final_assistant] = messages
      assert user_msg_.role == :user
      assert assistant_with_tool.role == :assistant
      assert tool_result_.role == :tool
      assert final_assistant.role == :assistant

      assert [tc] = assistant_with_tool.tool_calls
      assert %ReqLLM.ToolCall{} = tc
      assert tc.id == "toolu_read_123"
      assert tc.function.name == "read_file"

      assert tool_result_.tool_call_id == "toolu_read_123"
    end

    test "handles flat format tool_calls with string keys" do
      interactions = [
        agent_resp("Checking weather", %{
          "tool_calls" => [flat_tool_call("call_flat_1", "get_weather", ~s({"city": "NYC"}))]
        })
      ]

      [msg] = Interaction.to_llm_messages(interactions)

      assert [tc] = msg.tool_calls
      assert %ReqLLM.ToolCall{} = tc
      assert tc.id == "call_flat_1"
      assert tc.function.name == "get_weather"
    end

    test "handles atom keys (fresh from response, not DB)" do
      interactions = [
        agent_resp("Calculating", %{
          tool_calls: [
            %{
              function: %{arguments: ~s({"x": 1}), name: "calculator"},
              id: "call_atom_1",
              type: "function"
            }
          ]
        })
      ]

      [msg] = Interaction.to_llm_messages(interactions)

      assert [tc] = msg.tool_calls
      assert %ReqLLM.ToolCall{} = tc
      assert tc.function.name == "calculator"
    end

    test "passes through ReqLLM.ToolCall structs unchanged" do
      existing_struct = ReqLLM.ToolCall.new("call_struct_1", "my_tool", "{}")

      interactions = [agent_resp("Using tool", %{tool_calls: [existing_struct]})]

      [msg] = Interaction.to_llm_messages(interactions)

      assert [tc] = msg.tool_calls
      assert tc == existing_struct
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
      tc = %ToolCall{
        id: "1",
        sequence: System.unique_integer([:monotonic, :positive]),
        tool_call_id: "call_123",
        tool_name: "calculator",
        arguments: %{"x" => 1},
        timestamp: ~U[2025-01-01 00:00:00Z]
      }

      decoded = tc |> Jason.encode!() |> Jason.decode!()

      assert decoded["type"] == "tool_call"
      assert decoded["tool_name"] == "calculator"
      assert decoded["tool_call_id"] == "call_123"
    end

    test "encodes ToolResult to JSON" do
      tr = %ToolResult{
        id: "1",
        sequence: System.unique_integer([:monotonic, :positive]),
        tool_call_id: "call_123",
        tool_name: "calculator",
        result: 42,
        is_error: false,
        timestamp: ~U[2025-01-01 00:00:00Z]
      }

      decoded = tr |> Jason.encode!() |> Jason.decode!()

      assert decoded["type"] == "tool_result"
      assert decoded["result"] == 42
      assert decoded["is_error"] == false
    end
  end
end
