defmodule FrontmanServer.Agents.PromptsTest do
  @moduledoc """
  Tests for prompt construction behavior.

  These tests verify that the correct guidance sections are included/excluded
  based on context flags, not the exact wording of prompts (which changes frequently).
  """
  use ExUnit.Case, async: true

  alias FrontmanServer.Agents.Prompts

  describe "build/1 context-based guidance selection" do
    test "selected_component alone adds selected component guidance" do
      prompt = Prompts.build(has_selected_component: true)

      # Should include selected component specific section
      assert prompt =~ "Selected Component"
      assert prompt =~ "Read the file"
      # Should include direct-action guidance (not exploration)
      assert prompt =~ "Never explore"
    end

    test "framework nextjs adds framework-specific guidance" do
      prompt = Prompts.build(framework: "nextjs")

      assert prompt =~ "Next.js"
    end

    test "unknown framework adds no framework guidance" do
      base_prompt = Prompts.build([])
      unknown_framework_prompt = Prompts.build(framework: "rails")

      # Should be same length (no extra guidance added)
      assert String.length(base_prompt) == String.length(unknown_framework_prompt)
    end
  end

  describe "build_system_message/2 produces valid message structure" do
    test "returns list of two system messages (identity and content)" do
      [identity_msg, content_msg] = Prompts.build_system_message(nil, [])

      assert identity_msg.role == :system
      assert content_msg.role == :system
      assert is_list(identity_msg.content)
      assert is_list(content_msg.content)
    end

    test "first message contains identity line" do
      [identity_msg, _content_msg] = Prompts.build_system_message(nil, [])

      identity_text = Enum.map_join(identity_msg.content, & &1.text)
      assert identity_text =~ "coding assistant"
      assert identity_text =~ "build and modify"
    end

    test "always uses default identity (OAuth transformations happen at LLM boundary)" do
      [identity_msg, _content_msg] = Prompts.build_system_message(nil, [])

      identity_text = Enum.map_join(identity_msg.content, & &1.text)
      assert identity_text =~ "coding assistant"
      assert identity_text =~ "reading, searching, and editing"
    end

    test "selected_component flag affects content" do
      [_without_id, without_content] = Prompts.build_system_message(nil, [])

      [_with_id, with_sc_content] =
        Prompts.build_system_message(nil, has_selected_component: true)

      # With selected component should have more content
      without_text = Enum.map_join(without_content.content, & &1.text)
      with_sc_text = Enum.map_join(with_sc_content.content, & &1.text)

      assert String.length(with_sc_text) > String.length(without_text)
      assert with_sc_text =~ "Selected Component"
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
      assert prompt =~ "## Tool Selection Guidelines"
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
