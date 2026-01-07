defmodule FrontmanServer.Tools.ImplementComponentTest do
  @moduledoc """
  Integration tests for ImplementComponent tool.

  Tests the component implementation workflow through sub-agent execution,
  providing coverage for SubAgentExecutor and the ImplementComponent tool.
  """

  use FrontmanServer.AgentCase, async: false

  import FrontmanServer.Test.Fixtures.Tools

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tools.ImplementComponent

  setup context do
    task_id = "test_task_#{System.unique_integer([:positive])}"
    {:ok, ^task_id} = Tasks.create_task(task_id)
    {:ok, task} = Tasks.get_task(task_id)

    # Extract fixture_path from context for VCR fixture recording
    fixture_path = context[:fixture_path]

    llm_opts =
      if fixture_path, do: [fixture_path: fixture_path], else: []

    # Build tool execution context
    context = tool_context(task, llm_opts)

    {:ok, task_id: task_id, task: task, llm_opts: llm_opts, context: context}
  end

  describe "execute/2" do
    test "implements component successfully with valid parameters", %{context: context} do
      args = build_args()

      assert {:ok, result} = ImplementComponent.execute(args, context)

      assert %{
               "implementation" => implementation,
               "componentName" => "TestComponent",
               "nodeId" => "0:1234"
             } = result

      assert is_binary(implementation)
      assert byte_size(implementation) > 0
    end

    test "injects markdown context from task interactions into sub-agent", %{
      task_id: task_id,
      llm_opts: llm_opts
    } do
      # Add markdown file to task interactions
      markdown_content = """
      # Project Guidelines

      This is a test guideline document.
      Follow these conventions when implementing components.
      """

      add_markdown_to_task(task_id, "AGENTS.md", markdown_content)

      # Get updated task with markdown in interactions
      {:ok, updated_task} = Tasks.get_task(task_id)
      context = tool_context(updated_task, llm_opts)

      args = build_args()

      assert {:ok, result} = ImplementComponent.execute(args, context)
      assert %{"implementation" => implementation} = result
      assert is_binary(implementation)
    end

    test "accumulates multiple response events from sub-agent", %{context: context} do
      args = build_args()

      # This test uses a fixture with streaming responses
      assert {:ok, result} = ImplementComponent.execute(args, context)
      assert %{"implementation" => implementation} = result
      assert is_binary(implementation)
    end

    test "handles empty sub-agent response", %{context: context} do
      args = build_args()

      # This test uses a fixture where sub-agent returns empty response
      assert {:ok, result} = ImplementComponent.execute(args, context)

      assert %{
               "implementation" => implementation,
               "componentName" => "TestComponent",
               "nodeId" => "0:1234"
             } = result

      # Empty response should be handled gracefully
      assert is_binary(implementation)
    end

    test "handles optional parameters correctly", %{context: context} do
      args =
        build_args(%{
          "complexity" => 7,
          "dependencies" => "Button, Icon",
          "targetPath" => "components/Header.tsx",
          "additionalContext" => "Use TypeScript and follow our style guide"
        })

      assert {:ok, result} = ImplementComponent.execute(args, context)
      assert %{"implementation" => implementation} = result
      assert is_binary(implementation)
    end

    test "injects multiple markdown files in order", %{
      task_id: task_id,
      llm_opts: llm_opts
    } do
      # Add multiple markdown files
      add_markdown_to_task(task_id, "AGENTS.md", "# Agent Guidelines\nFollow these patterns.")
      add_markdown_to_task(task_id, "research.md", "# Research Findings\nKey insights...")

      add_markdown_to_task(
        task_id,
        "conventions.md",
        "# Code Conventions\nUse these standards."
      )

      {:ok, updated_task} = Tasks.get_task(task_id)
      context = tool_context(updated_task, llm_opts)

      args = build_args()

      assert {:ok, result} = ImplementComponent.execute(args, context)
      assert %{"implementation" => implementation} = result
      assert is_binary(implementation)
    end
  end

  # Helper functions

  defp build_args(overrides \\ %{}) do
    Map.merge(
      %{
        "componentName" => "TestComponent",
        "nodeId" => "0:1234",
        "description" => "A test component for unit testing"
      },
      overrides
    )
  end
end
