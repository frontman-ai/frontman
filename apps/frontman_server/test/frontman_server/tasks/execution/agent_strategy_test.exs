defmodule FrontmanServer.Tasks.Execution.AgentStrategyTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Execution.AgentStrategy
  alias SwarmAi.ToolCall

  @moduledoc """
  Unit tests for AgentStrategy — the domain's ExecutionStrategy implementation.

  These tests verify AgentStrategy as a pure struct + behaviour without
  standing up the full Swarm runtime, demonstrating the testability
  improvement from the boundary redesign.
  """

  # Minimal mock modules for testing
  defmodule MockBackendTool do
    def name, do: "read_file"
    def timeout_ms, do: 60_000
    def on_timeout, do: :error
    def execute(_args, _context), do: {:ok, "file contents"}
  end

  defmodule MockPauseTool do
    def name, do: "browser_click"
    def timeout_ms, do: 300_000
    def on_timeout, do: :pause_agent
    def execute(_args, _context), do: {:ok, "clicked"}
  end

  defp build_init_opts(overrides \\ []) do
    defaults = [
      scope: %FrontmanServer.Accounts.Scope{user: %{id: "test_user"}},
      task_id: "task_123",
      runtime: :test_runtime,
      backend_tool_modules: [MockBackendTool],
      mcp_tool_defs: [
        %{name: "take_screenshot", on_timeout: :pause_agent, timeout_ms: 120_000},
        %{name: "execute_js", on_timeout: :error, timeout_ms: 30_000}
      ],
      mcp_tools: [],
      llm_opts: [api_key: "test_key", model: "test_model"]
    ]

    Keyword.merge(defaults, overrides)
  end

  describe "init/1" do
    test "builds state with all required fields" do
      {:ok, state} = AgentStrategy.init(build_init_opts())

      assert state.task_id == "task_123"
      assert state.runtime == :test_runtime
      assert is_map(state.backend_module_map)
      assert Map.has_key?(state.backend_module_map, "read_file")
    end

    test "raises when required opts are missing" do
      assert_raise KeyError, fn ->
        AgentStrategy.init(scope: %FrontmanServer.Accounts.Scope{user: %{id: "u"}})
      end
    end

    test "builds backend_module_map from backend_tool_modules" do
      {:ok, state} = AgentStrategy.init(build_init_opts())

      assert state.backend_module_map["read_file"] == MockBackendTool
      refute Map.has_key?(state.backend_module_map, "take_screenshot")
    end
  end

  describe "on_deadline/2" do
    test "returns :error for backend tools with :error policy" do
      {:ok, state} = AgentStrategy.init(build_init_opts())
      tool_call = %ToolCall{id: "tc1", name: "read_file", arguments: "{}"}

      assert {:error, ^state} = AgentStrategy.on_deadline(state, tool_call)
    end

    test "returns :pause for backend tools with :pause_agent policy" do
      {:ok, state} = AgentStrategy.init(build_init_opts(backend_tool_modules: [MockPauseTool]))
      tool_call = %ToolCall{id: "tc1", name: "browser_click", arguments: "{}"}

      assert {:pause, ^state} = AgentStrategy.on_deadline(state, tool_call)
    end

    test "returns :pause for MCP tools with :pause_agent policy" do
      {:ok, state} = AgentStrategy.init(build_init_opts())
      tool_call = %ToolCall{id: "tc1", name: "take_screenshot", arguments: "{}"}

      assert {:pause, ^state} = AgentStrategy.on_deadline(state, tool_call)
    end

    test "returns :error for MCP tools with :error policy" do
      {:ok, state} = AgentStrategy.init(build_init_opts())
      tool_call = %ToolCall{id: "tc1", name: "execute_js", arguments: "{}"}

      assert {:error, ^state} = AgentStrategy.on_deadline(state, tool_call)
    end

    test "returns :error for unknown tools" do
      {:ok, state} = AgentStrategy.init(build_init_opts())
      tool_call = %ToolCall{id: "tc1", name: "nonexistent_tool", arguments: "{}"}

      assert {:error, ^state} = AgentStrategy.on_deadline(state, tool_call)
    end
  end

  describe "struct properties" do
    test "AgentStrategy is a plain struct (no closures, no PIDs)" do
      {:ok, state} = AgentStrategy.init(build_init_opts())

      # Verify it's a plain struct — fully serializable and testable
      assert is_struct(state, AgentStrategy)

      # All fields are data, not functions or PIDs
      assert is_binary(state.task_id)
      assert is_atom(state.runtime)
      assert is_map(state.backend_module_map)
      assert is_list(state.mcp_tool_defs)
      assert is_list(state.mcp_tools)
      assert is_list(state.llm_opts)
    end
  end
end
