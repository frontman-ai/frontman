defmodule AgentClientProtocolTest do
  use ExUnit.Case, async: true

  alias AgentClientProtocol, as: ACP

  describe "plan_update/2" do
    test "builds valid plan update notification" do
      entries = [
        %{"content" => "Test task", "priority" => "medium", "status" => "pending"}
      ]

      result = ACP.plan_update("sess_123", entries)

      assert result["jsonrpc"] == "2.0"
      assert result["method"] == "session/update"
      assert result["params"]["sessionId"] == "sess_123"
      assert result["params"]["update"]["sessionUpdate"] == "plan"
      assert result["params"]["update"]["entries"] == entries
    end

    test "validates entries have required fields" do
      invalid_entries = [%{"content" => "Missing priority and status"}]

      assert_raise FunctionClauseError, fn ->
        ACP.plan_update("sess_123", invalid_entries)
      end
    end

    test "validates priority values" do
      invalid_entries = [
        %{"content" => "Test", "priority" => "urgent", "status" => "pending"}
      ]

      assert_raise FunctionClauseError, fn ->
        ACP.plan_update("sess_123", invalid_entries)
      end
    end

    test "validates status values" do
      invalid_entries = [
        %{"content" => "Test", "priority" => "medium", "status" => "done"}
      ]

      assert_raise FunctionClauseError, fn ->
        ACP.plan_update("sess_123", invalid_entries)
      end
    end

    test "accepts valid entries with all status values" do
      entries = [
        %{"content" => "Pending", "priority" => "medium", "status" => "pending"},
        %{"content" => "In progress", "priority" => "high", "status" => "in_progress"},
        %{"content" => "Done", "priority" => "low", "status" => "completed"}
      ]

      notification = ACP.plan_update("sess_test", entries)
      assert notification["params"]["update"]["entries"] == entries
    end

    test "accepts empty entries list" do
      notification = ACP.plan_update("sess_test", [])
      assert notification["params"]["update"]["entries"] == []
    end
  end

  describe "build_model_config_options/1" do
    defp config_data(groups, default_model \\ "anthropic:claude-sonnet-4-5") do
      %{groups: groups, default_model: default_model}
    end

    defp model_group(id, name, options) do
      %{id: id, name: name, options: options}
    end

    defp model_option(name, value), do: %{name: name, value: value}

    test "returns a single select config option with category model" do
      data =
        config_data([
          model_group("anthropic", "Anthropic", [
            model_option("Claude Sonnet 4.5", "anthropic:claude-sonnet-4-5")
          ])
        ])

      [option] = ACP.build_model_config_options(data)
      assert option["type"] == "select"
      assert option["id"] == "model"
      assert option["name"] == "Model"
      assert option["category"] == "model"
    end

    test "groups models by provider" do
      data =
        config_data([
          model_group("anthropic", "Anthropic", [
            model_option("Claude Sonnet 4.5", "anthropic:claude-sonnet-4-5")
          ]),
          model_group("openrouter", "OpenRouter", [
            model_option("GPT-5.5", "openrouter:openai/gpt-5.5")
          ])
        ])

      [option] = ACP.build_model_config_options(data)

      groups = option["options"]
      assert length(groups) == 2

      [anthropic_group, openrouter_group] = groups
      assert anthropic_group["group"] == "anthropic"
      assert openrouter_group["group"] == "openrouter"
    end

    test "option values are passed through verbatim" do
      data =
        config_data([
          model_group("anthropic", "Anthropic", [
            model_option("Claude Sonnet 4.5", "anthropic:claude-sonnet-4-5"),
            model_option("Claude Opus 4.6", "anthropic:claude-opus-4-6")
          ])
        ])

      [option] = ACP.build_model_config_options(data)
      [group] = option["options"]
      values = Enum.map(group["options"], & &1["value"])

      assert Enum.all?(values, &String.starts_with?(&1, "anthropic:"))
    end

    test "currentValue uses provided default" do
      data = config_data([], "anthropic:claude-sonnet-4-5")

      [option] = ACP.build_model_config_options(data)

      assert option["currentValue"] == "anthropic:claude-sonnet-4-5"
    end
  end

  describe "question_to_elicitation_schema/1" do
    test "uses label only when description is nil" do
      questions = [
        %{
          "header" => "Framework",
          "question" => "Which framework?",
          "options" => [%{"label" => "React", "description" => nil}]
        }
      ]

      schema = ACP.question_to_elicitation_schema(questions)
      one_of = schema["properties"]["q0_answer"]["oneOf"]

      assert [%{"const" => "React", "title" => "React"}] = one_of
    end

    test "uses label only when description is empty string" do
      questions = [
        %{
          "header" => "Framework",
          "question" => "Which framework?",
          "options" => [%{"label" => "React", "description" => ""}]
        }
      ]

      schema = ACP.question_to_elicitation_schema(questions)
      one_of = schema["properties"]["q0_answer"]["oneOf"]

      assert [%{"const" => "React", "title" => "React"}] = one_of
    end

    test "includes description in title when present" do
      questions = [
        %{
          "header" => "Framework",
          "question" => "Which framework?",
          "options" => [%{"label" => "React", "description" => "A UI library"}]
        }
      ]

      schema = ACP.question_to_elicitation_schema(questions)
      one_of = schema["properties"]["q0_answer"]["oneOf"]

      assert [%{"const" => "React", "title" => "React - A UI library"}] = one_of
    end
  end
end
