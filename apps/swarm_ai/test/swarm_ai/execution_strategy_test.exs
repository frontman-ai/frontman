defmodule SwarmAi.ExecutionStrategyTest do
  use ExUnit.Case, async: true

  alias SwarmAi.{ExecutionStrategy, DefaultExecutionStrategy, ToolCall, ToolResult}

  @moduledoc """
  Unit tests for the ExecutionStrategy behaviour and DefaultExecutionStrategy.
  """

  describe "DefaultExecutionStrategy.init/1" do
    test "builds state from opts" do
      opts = [runtime: :test_runtime, tool_defs: []]
      assert {:ok, %DefaultExecutionStrategy{runtime: :test_runtime}} = DefaultExecutionStrategy.init(opts)
    end

    test "raises when :runtime is missing" do
      assert_raise KeyError, fn ->
        DefaultExecutionStrategy.init(tool_defs: [])
      end
    end

    test "builds tool_map from tool_defs" do
      tool_def = %{name: "test_tool", on_timeout: :error, timeout_ms: 5000}
      opts = [runtime: :test_runtime, tool_defs: [tool_def]]

      {:ok, state} = DefaultExecutionStrategy.init(opts)
      assert Map.has_key?(state.tool_map, "test_tool")
      assert state.tool_map["test_tool"].on_timeout == :error
    end

    test "defaults tool_defs to empty list" do
      opts = [runtime: :test_runtime]
      {:ok, state} = DefaultExecutionStrategy.init(opts)
      assert state.tool_map == %{}
    end
  end

  describe "DefaultExecutionStrategy.on_deadline/2" do
    test "returns :error for unknown tools" do
      {:ok, state} = DefaultExecutionStrategy.init(runtime: :test_runtime, tool_defs: [])
      tool_call = %ToolCall{id: "tc1", name: "unknown", arguments: "{}"}

      assert {:error, ^state} = DefaultExecutionStrategy.on_deadline(state, tool_call)
    end

    test "returns :error for tools with :error policy" do
      tool_def = %{name: "fast_tool", on_timeout: :error, timeout_ms: 5000}
      {:ok, state} = DefaultExecutionStrategy.init(runtime: :test_runtime, tool_defs: [tool_def])
      tool_call = %ToolCall{id: "tc1", name: "fast_tool", arguments: "{}"}

      assert {:error, ^state} = DefaultExecutionStrategy.on_deadline(state, tool_call)
    end

    test "returns :pause for tools with :pause_agent policy" do
      tool_def = %{name: "interactive_tool", on_timeout: :pause_agent, timeout_ms: 60000}
      {:ok, state} = DefaultExecutionStrategy.init(runtime: :test_runtime, tool_defs: [tool_def])
      tool_call = %ToolCall{id: "tc1", name: "interactive_tool", arguments: "{}"}

      assert {:pause, ^state} = DefaultExecutionStrategy.on_deadline(state, tool_call)
    end
  end

  describe "DefaultExecutionStrategy `use` macro" do
    defmodule TestStrategy do
      use SwarmAi.DefaultExecutionStrategy

      @impl SwarmAi.ExecutionStrategy
      def on_deadline(state, tool_call) do
        # Custom override: always pause
        {:pause, state}
      end
    end

    test "can override individual callbacks" do
      {:ok, state} = TestStrategy.init(runtime: :test_runtime, tool_defs: [])
      tool_call = %ToolCall{id: "tc1", name: "any_tool", arguments: "{}"}

      # Our override always returns :pause
      assert {:pause, ^state} = TestStrategy.on_deadline(state, tool_call)
    end

    test "delegates non-overridden callbacks" do
      # init/1 is still delegated to DefaultExecutionStrategy
      {:ok, state} = TestStrategy.init(runtime: :test_runtime, tool_defs: [])
      assert %DefaultExecutionStrategy{} = state
    end
  end

  describe "ExecutionStrategy behaviour" do
    test "defines required callbacks" do
      callbacks = SwarmAi.ExecutionStrategy.behaviour_info(:callbacks)
      assert {:init, 1} in callbacks
      assert {:execute_tool, 2} in callbacks
      assert {:on_deadline, 2} in callbacks
    end

    test "defines optional callbacks" do
      optional = SwarmAi.ExecutionStrategy.behaviour_info(:optional_callbacks)
      assert {:should_continue?, 2} in optional
    end
  end
end
