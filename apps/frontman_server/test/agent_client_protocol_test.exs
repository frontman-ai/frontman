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
