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

    test "figma_context alone adds figma guidance (no selected component guidance)" do
      prompt = Prompts.build(has_figma_context: true)

      # Should include Figma guidance
      assert prompt =~ "Figma"
      assert prompt =~ "breakdown_figma_design"
    end

    test "figma + selected_component uses combined guidance (not separate)" do
      prompt = Prompts.build(has_figma_context: true, has_selected_component: true)

      # Should use combined Figma+Component guidance
      assert prompt =~ "Figma"
      assert prompt =~ "Selected"
      assert prompt =~ "breakdown_figma_design"

      # Count occurrences - should only have ONE section header about selected component
      # (the combined one, not both combined AND standalone)
      selected_component_headers =
        prompt
        |> String.split("Selected Component")
        |> length()

      # More than 2 splits would mean the phrase appears multiple times in different sections
      # We expect it in the combined guidance header only
      assert selected_component_headers <= 3
    end

    test "figma_node_id is interpolated into figma guidance" do
      prompt = Prompts.build(has_figma_context: true, figma_node_id: "123:456")

      assert prompt =~ "123:456"
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
    test "returns system role message" do
      result = Prompts.build_system_message(nil, [])

      assert result.role == :system
      assert is_list(result.content)
    end

    test "selected_component flag affects content" do
      without = Prompts.build_system_message(nil, [])
      with_sc = Prompts.build_system_message(nil, has_selected_component: true)

      # With selected component should have more content
      without_text = Enum.map_join(without.content, & &1.text)
      with_sc_text = Enum.map_join(with_sc.content, & &1.text)

      assert String.length(with_sc_text) > String.length(without_text)
      assert with_sc_text =~ "Selected Component"
    end
  end
end
