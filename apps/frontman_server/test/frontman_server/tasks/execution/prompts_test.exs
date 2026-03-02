defmodule FrontmanServer.Tasks.Execution.PromptsTest do
  @moduledoc """
  Tests for prompt construction behavior.

  These tests verify that the correct guidance sections are included/excluded
  based on context flags, not the exact wording of prompts (which changes frequently).
  """
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Execution.Framework
  alias FrontmanServer.Tasks.Execution.Prompts

  describe "build/1 context-based guidance selection" do
    test "has_annotations adds annotation guidance" do
      prompt = Prompts.build(has_annotations: true)

      # Should include annotation-specific section
      assert prompt =~ "Annotated Elements"
      assert prompt =~ "Read the file"
      # Should include direct-action guidance (not exploration)
      assert prompt =~ "Never explore"
    end

    test "nextjs framework adds framework-specific guidance" do
      fw = Framework.from_string("nextjs")
      prompt = Prompts.build(framework: fw)

      assert prompt =~ "Next.js"
    end

    test "non-nextjs framework adds no framework guidance" do
      base_prompt = Prompts.build([])
      vite_prompt = Prompts.build(framework: Framework.from_string("vite"))

      assert String.length(base_prompt) == String.length(vite_prompt)
    end

    test "nil framework adds no framework guidance" do
      base_prompt = Prompts.build([])
      nil_prompt = Prompts.build(framework: nil)

      assert String.length(base_prompt) == String.length(nil_prompt)
    end
  end

  describe "build/1" do
    test "returns single string with default identity" do
      result = Prompts.build([])

      assert is_binary(result)
      assert result =~ "You are a coding assistant"
      assert result =~ "build and modify their applications"
    end

    test "always returns string (OAuth transformations happen at LLM boundary)" do
      result = Prompts.build([])

      assert is_binary(result)
      assert result =~ "You are a coding assistant"
      assert result =~ "## Rules"
    end
  end

  describe "build/1 conditional sections" do
    test "base prompt (no flags) excludes ReScript and TypeScript content" do
      prompt = Prompts.build([])

      refute prompt =~ "ReScript"
      refute prompt =~ "## TypeScript / React"
    end

    test "base prompt always includes core sections" do
      prompt = Prompts.build([])

      assert prompt =~ "## Tone & Style"
      assert prompt =~ "## Professional Objectivity"
      assert prompt =~ "## Proactiveness"
      assert prompt =~ "## Rules"
      assert prompt =~ "## Response Formatting"
      assert prompt =~ "## Code Quality"
    end

    test "has_typescript_react includes TypeScript / React section" do
      prompt = Prompts.build(has_typescript_react: true)

      assert prompt =~ "## TypeScript / React"
      assert prompt =~ "discriminated unions"
    end

    test "has_typescript_react false excludes TypeScript / React section" do
      prompt = Prompts.build(has_typescript_react: false)

      refute prompt =~ "## TypeScript / React"
    end
  end

  describe "build/1 tool failure recovery rule" do
    test "includes alternative approach guidance before asking" do
      prompt = Prompts.build([])

      assert prompt =~ "try an alternative approach"
      assert prompt =~ "3 total failures"
    end
  end

  describe "build/1 project_structure option" do
    test "project structure is appended to prompt" do
      summary = "Project type: monorepo (yarn)\n\nDirectory layout:\nsrc/\n  app/"

      result = Prompts.build(project_structure: summary)

      assert result =~ "## Project Structure"
      assert result =~ "monorepo (yarn)"
      assert result =~ "Directory layout:"
    end

    test "nil project structure is omitted" do
      result = Prompts.build(project_structure: nil)

      refute result =~ "## Project Structure"
    end

    test "empty string project structure is omitted" do
      result = Prompts.build(project_structure: "")

      refute result =~ "## Project Structure"
    end

    test "project structure appears before project rules" do
      rules = [
        %{path: "AGENTS.md", content: "Rule content", timestamp: ~U[2024-01-01 00:00:00Z]}
      ]

      result =
        Prompts.build(
          project_structure: "Project type: single project",
          project_rules: rules
        )

      structure_pos = :binary.match(result, "## Project Structure") |> elem(0)
      rules_pos = :binary.match(result, "Instructions from:") |> elem(0)
      assert structure_pos < rules_pos
    end
  end

  describe "build/1 project_rules option" do
    test "project rules are appended to prompt" do
      rules = [
        %{
          path: "AGENTS.md",
          content: "Custom rule content here",
          timestamp: ~U[2024-01-01 00:00:00Z]
        }
      ]

      result = Prompts.build(project_rules: rules)

      assert result =~ "Instructions from: AGENTS.md"
      assert result =~ "Custom rule content here"
    end

    test "multiple rules are separated by ---" do
      rules = [
        %{path: "AGENTS.md", content: "Rule A", timestamp: ~U[2024-01-01 00:00:00Z]},
        %{path: "CONVENTIONS.md", content: "Rule B", timestamp: ~U[2024-01-02 00:00:00Z]}
      ]

      result = Prompts.build(project_rules: rules)

      assert result =~ "Rule A"
      assert result =~ "Rule B"
      assert result =~ "---"
    end

    test "malformed rules are filtered out" do
      rules = [
        %{path: "AGENTS.md", content: "Valid rule", timestamp: ~U[2024-01-01 00:00:00Z]},
        %{invalid: "rule"},
        nil
      ]

      result = Prompts.build(project_rules: rules)

      assert result =~ "Valid rule"
      # Should not crash
    end
  end
end
