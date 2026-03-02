defmodule FrontmanServer.TasksTest do
  use FrontmanServer.DataCase, async: false

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Tasks

  setup do
    # Create a test user for scope
    {:ok, user} =
      Accounts.register_user(%{
        email: "test_#{System.unique_integer([:positive])}@test.local",
        name: "Test User",
        password: "testpassword123!"
      })

    scope = Scope.for_user(user)
    %{scope: scope, user: user}
  end

  describe "topic/1" do
    test "returns topic string for task_id" do
      assert Tasks.topic("abc123") == "task:abc123"
    end
  end

  describe "subscribe/2" do
    test "subscribes calling process to task topic" do
      task_id = Ecto.UUID.generate()

      :ok = Tasks.subscribe(FrontmanServer.PubSub, task_id)

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:test_event, "hello"}
      )

      assert_receive {:test_event, "hello"}, 100
    end
  end

  describe "create_task/3" do
    test "creates task with framework", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      framework = "nextjs"
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, framework)

      {:ok, task} = Tasks.get_task(scope, task_id)
      assert task.task_id == task_id
      assert task.framework == framework
    end
  end

  describe "get_short_desc/2" do
    test "returns title for existing task", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      assert {:ok, "New Task"} = Tasks.get_short_desc(scope, task_id)
    end

    test "returns updated title after update_short_desc", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      {:ok, _} = Tasks.update_short_desc(scope, task_id, "My Custom Title")
      assert {:ok, "My Custom Title"} = Tasks.get_short_desc(scope, task_id)
    end

    test "returns not_found for non-existent task", %{scope: scope} do
      assert {:error, :not_found} = Tasks.get_short_desc(scope, Ecto.UUID.generate())
    end

    test "returns not_found for task owned by different user", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      {:ok, other_user} =
        Accounts.register_user(%{
          email: "other_#{System.unique_integer([:positive])}@test.local",
          name: "Other User",
          password: "testpassword123!"
        })

      other_scope = Scope.for_user(other_user)
      assert {:error, :not_found} = Tasks.get_short_desc(other_scope, task_id)
    end
  end

  describe "task_exists?/2" do
    test "returns true for existing task owned by user", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      assert Tasks.task_exists?(scope, task_id) == true
    end

    test "returns false for non-existent task", %{scope: scope} do
      assert Tasks.task_exists?(scope, Ecto.UUID.generate()) == false
    end

    test "returns false for task owned by different user", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      # Create a different user/scope
      {:ok, other_user} =
        Accounts.register_user(%{
          email: "other_#{System.unique_integer([:positive])}@test.local",
          name: "Other User",
          password: "testpassword123!"
        })

      other_scope = Scope.for_user(other_user)

      assert Tasks.task_exists?(other_scope, task_id) == false
    end
  end

  describe "get_task/2 authorization" do
    test "returns not_found when accessing task owned by different user", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      # Create a different user/scope
      {:ok, other_user} =
        Accounts.register_user(%{
          email: "other_#{System.unique_integer([:positive])}@test.local",
          name: "Other User",
          password: "testpassword123!"
        })

      other_scope = Scope.for_user(other_user)

      # Returns :not_found to prevent task enumeration attacks
      assert {:error, :not_found} = Tasks.get_task(other_scope, task_id)
    end
  end

  describe "get_interactions/2" do
    test "returns error for non-existent task", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      assert {:error, :not_found} = Tasks.get_interactions(scope, task_id)
    end

    test "returns interactions for existing task", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      assert {:ok, []} = Tasks.get_interactions(scope, task_id)
    end
  end

  describe "get_llm_messages/2" do
    test "returns all messages for task", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      # Add a user message
      Tasks.add_user_message(scope, task_id, [%{"type" => "text", "text" => "Hello"}], [])

      # Add responses
      Tasks.add_agent_response(scope, task_id, "Response from agent", %{})
      Tasks.add_agent_response(scope, task_id, "Another response", %{})

      {:ok, messages} = Tasks.get_llm_messages(scope, task_id)

      # Should have: UserMessage + 2 responses = 3 messages
      assert length(messages) == 3

      # Should have assistant messages
      assistant_messages = Enum.filter(messages, &(&1.role == :assistant))
      assert length(assistant_messages) == 2
    end
  end

  describe "add_tool_call/3" do
    test "creates tool call interaction", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      tool_call = ReqLLM.ToolCall.new("call_123", "calculator", ~s({"expression": "1 + 1"}))

      {:ok, interaction} = Tasks.add_tool_call(scope, task_id, tool_call)

      assert interaction.tool_name == "calculator"
      assert interaction.tool_call_id == "call_123"
      assert interaction.arguments == %{"expression" => "1 + 1"}
    end

    test "returns error for non-existent task", %{scope: scope} do
      nonexistent_id = Ecto.UUID.generate()
      tool_call = ReqLLM.ToolCall.new("call_123", "test", "{}")

      assert {:error, :not_found} =
               Tasks.add_tool_call(scope, nonexistent_id, tool_call)
    end
  end

  describe "add_tool_result/5" do
    test "creates tool result interaction", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      tool_call_data = %{id: "call_123", name: "calculator"}

      {:ok, interaction} = Tasks.add_tool_result(scope, task_id, tool_call_data, 2, false)

      assert interaction.result == 2
      assert interaction.is_error == false
      assert interaction.tool_call_id == "call_123"
    end

    test "creates error tool result", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      tool_call_data = %{id: "call_456", name: "failing_tool"}

      {:ok, interaction} =
        Tasks.add_tool_result(scope, task_id, tool_call_data, "error message", true)

      assert interaction.is_error == true
      assert interaction.result == "error message"
    end

    test "stores tool result in interactions", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      tool_call_data = %{id: "call_notify", name: "some_tool"}

      {:ok, _interaction} =
        Tasks.add_tool_result(scope, task_id, tool_call_data, "result", false)

      # The tool result should have been stored successfully
      {:ok, interactions} = Tasks.get_interactions(scope, task_id)
      assert length(interactions) == 1
    end
  end

  describe "add_discovered_project_rule/4" do
    test "adds rule to task", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      {:ok, rule} =
        Tasks.add_discovered_project_rule(scope, task_id, "/project/AGENTS.md", "# Rules")

      assert rule.path == "/project/AGENTS.md"
      assert rule.content == "# Rules"
    end

    test "deduplicates by path", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      {:ok, _rule} =
        Tasks.add_discovered_project_rule(scope, task_id, "/project/AGENTS.md", "# Rules v1")

      {:ok, :already_loaded} =
        Tasks.add_discovered_project_rule(scope, task_id, "/project/AGENTS.md", "# Rules v2")

      {:ok, rules} = Tasks.get_discovered_project_rules(scope, task_id)
      assert length(rules) == 1
      assert hd(rules).content == "# Rules v1"
    end

    test "returns error for non-existent task", %{scope: scope} do
      nonexistent_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               Tasks.add_discovered_project_rule(scope, nonexistent_id, "/path", "content")
    end
  end

  describe "get_discovered_project_rules/2" do
    test "returns empty list for task with no rules", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      assert {:ok, []} = Tasks.get_discovered_project_rules(scope, task_id)
    end

    test "returns all rules for task", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      Tasks.add_discovered_project_rule(scope, task_id, "/a/AGENTS.md", "A rules")
      Tasks.add_discovered_project_rule(scope, task_id, "/b/AGENTS.md", "B rules")

      {:ok, rules} = Tasks.get_discovered_project_rules(scope, task_id)
      assert length(rules) == 2
    end
  end

  describe "add_discovered_project_structure/3" do
    test "adds structure to task", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      summary = "Project type: single project\n\nDirectory layout:\n."

      {:ok, structure} =
        Tasks.add_discovered_project_structure(scope, task_id, summary)

      assert structure.summary == summary
    end

    test "returns error for non-existent task", %{scope: scope} do
      nonexistent_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               Tasks.add_discovered_project_structure(scope, nonexistent_id, "summary")
    end
  end

  describe "get_discovered_project_structure/2" do
    test "returns nil for task with no structure", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      assert {:ok, nil} = Tasks.get_discovered_project_structure(scope, task_id)
    end

    test "returns summary for task with structure", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      summary = "Project type: monorepo (turborepo)\n\nWorkspaces:\n  @app/web -> apps/web"

      Tasks.add_discovered_project_structure(scope, task_id, summary)

      {:ok, result} = Tasks.get_discovered_project_structure(scope, task_id)
      assert result == summary
    end

    test "structure is excluded from LLM messages", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      Tasks.add_discovered_project_structure(scope, task_id, "Project layout...")
      Tasks.add_user_message(scope, task_id, [%{"type" => "text", "text" => "Hello"}], [])

      {:ok, messages} = Tasks.get_llm_messages(scope, task_id)

      # Only the user message should be present — structure goes in system prompt
      assert length(messages) == 1
      [msg] = messages
      assert msg.role == :user
    end
  end

  describe "get_llm_messages/2 with discovered rules" do
    # Note: Project rules are NOT prepended to messages by get_llm_messages.
    # They are retrieved separately via get_discovered_project_rules and
    # included in the system prompt via Prompts.build(project_rules: rules).

    test "returns messages without modification (rules stored separately)", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      Tasks.add_discovered_project_rule(scope, task_id, "/project/AGENTS.md", "# Project Rules")
      Tasks.add_user_message(scope, task_id, [%{"type" => "text", "text" => "Hello"}], [])

      {:ok, messages} = Tasks.get_llm_messages(scope, task_id)

      # Messages are returned as-is, without rule injection
      assert length(messages) == 1
      [msg] = messages
      assert msg.role == :user

      content_text = extract_content_text(msg.content)
      # Rules are NOT in the user message - they go in the system prompt
      refute content_text =~ "<system-reminder>"
      refute content_text =~ "# Project Rules"
      assert content_text =~ "Hello"
    end

    test "returns messages unchanged when no rules", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      Tasks.add_user_message(scope, task_id, [%{"type" => "text", "text" => "Hello"}], [])

      {:ok, messages} = Tasks.get_llm_messages(scope, task_id)

      assert length(messages) == 1
      [msg] = messages

      content_text = extract_content_text(msg.content)
      refute content_text =~ "<system-reminder>"
      assert content_text =~ "Hello"
    end

    test "rules are retrievable separately via get_discovered_project_rules", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      Tasks.add_discovered_project_rule(scope, task_id, "/a/AGENTS.md", "Rule A")
      Tasks.add_discovered_project_rule(scope, task_id, "/b/AGENTS.md", "Rule B")
      Tasks.add_user_message(scope, task_id, [%{"type" => "text", "text" => "Hello"}], [])

      # Rules are stored and retrievable separately
      {:ok, rules} = Tasks.get_discovered_project_rules(scope, task_id)
      assert length(rules) == 2

      rule_contents = Enum.map(rules, & &1.content)
      assert "Rule A" in rule_contents
      assert "Rule B" in rule_contents

      # Messages don't contain the rules
      {:ok, messages} = Tasks.get_llm_messages(scope, task_id)
      [msg] = messages
      content_text = extract_content_text(msg.content)
      refute content_text =~ "Rule A"
      refute content_text =~ "Rule B"
    end
  end

  describe "annotation round-trip through JSONB" do
    test "annotation survives DB round-trip and appears in LLM messages", %{
      scope: scope
    } do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      # Content blocks matching the new annotation ACP format:
      # 1. Text message
      # 2. Resource with annotation _meta
      # 3. Resource with annotation_screenshot blob
      content_blocks = [
        %{"type" => "text", "text" => "Fix the button"},
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{
              "annotation" => true,
              "annotation_index" => 0,
              "annotation_id" => "ann-test-1",
              "tag_name" => "button",
              "file" => "src/components/Button.tsx",
              "line" => 42,
              "column" => 5
            },
            "resource" => %{
              "uri" => "file://src/components/Button.tsx:42:5",
              "mimeType" => "text/plain",
              "text" => "Annotated element: <button> at src/components/Button.tsx:42:5"
            }
          }
        },
        %{
          "type" => "resource",
          "resource" => %{
            "_meta" => %{
              "annotation_screenshot" => true,
              "annotation_index" => 0,
              "annotation_id" => "ann-test-1"
            },
            "resource" => %{
              "uri" => "annotation://ann-test-1/screenshot",
              "mimeType" => "image/png",
              "blob" => "iVBORw0KGgoAAAANSUhEUg=="
            }
          }
        }
      ]

      {:ok, _interaction} = Tasks.add_user_message(scope, task_id, content_blocks, [])

      # Retrieve via LLM conversion (exercises the full JSONB round-trip)
      {:ok, messages} = Tasks.get_llm_messages(scope, task_id)

      assert length(messages) == 1
      [msg] = messages
      assert msg.role == :user

      # Extract text from content parts
      content_text = extract_content_text(msg.content)

      # The annotation location should have been appended by append_annotations/2
      assert content_text =~ "[Annotated Elements]"
      assert content_text =~ "src/components/Button.tsx"
      assert content_text =~ "42"

      # Screenshot should be present as an image content part
      image_parts =
        case msg.content do
          parts when is_list(parts) ->
            Enum.filter(parts, fn
              %{type: :image} -> true
              _ -> false
            end)

          _ ->
            []
        end

      assert [_ | _] = image_parts
    end
  end

  defp extract_content_text(content) when is_binary(content), do: content

  defp extract_content_text(content) when is_list(content) do
    Enum.map_join(content, "", fn
      %{text: text} -> text
      _ -> ""
    end)
  end

  describe "list_todos/2" do
    test "returns empty list for task with no todos", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      assert {:ok, []} = Tasks.list_todos(scope, task_id)
    end

    test "returns error for non-existent task", %{scope: scope} do
      nonexistent_id = Ecto.UUID.generate()
      assert {:error, :not_found} = Tasks.list_todos(scope, nonexistent_id)
    end

    test "returns todos from task", %{scope: scope} do
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      {:ok, todo1} = Tasks.create_todo("First", "First", "pending")
      Tasks.add_tool_result(scope, task_id, %{id: "c1", name: "todo_add"}, todo1, false)

      {:ok, todo2} = Tasks.create_todo("Second", "Second", "in_progress")
      Tasks.add_tool_result(scope, task_id, %{id: "c2", name: "todo_add"}, todo2, false)

      {:ok, todos} = Tasks.list_todos(scope, task_id)

      assert length(todos) == 2
      contents = Enum.map(todos, & &1.content)
      assert "First" in contents
      assert "Second" in contents
    end

    test "todos are isolated per task", %{scope: scope} do
      task_a = Ecto.UUID.generate()
      task_b = Ecto.UUID.generate()
      {:ok, ^task_a} = Tasks.create_task(scope, task_a, "nextjs")
      {:ok, ^task_b} = Tasks.create_task(scope, task_b, "nextjs")

      {:ok, todo} = Tasks.create_todo("Task A todo", "Working", "pending")
      Tasks.add_tool_result(scope, task_a, %{id: "c1", name: "todo_add"}, todo, false)

      {:ok, todos_a} = Tasks.list_todos(scope, task_a)
      {:ok, todos_b} = Tasks.list_todos(scope, task_b)

      assert match?([_], todos_a)
      assert todos_b == []
    end
  end
end
