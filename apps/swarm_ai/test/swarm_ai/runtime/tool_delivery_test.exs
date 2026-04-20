defmodule SwarmAi.Runtime.ToolDeliveryTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Tests for SwarmAi.Runtime.deliver_tool_result/5 and await_tool_result/3.

  These tests start a minimal Runtime supervision tree and verify the
  tool result Registry mechanics — the core of the boundary redesign.
  """

  @runtime_name :"#{__MODULE__}.Runtime"

  setup do
    # Start a minimal Runtime supervision tree for each test
    start_supervised!(
      {SwarmAi.Runtime,
       name: @runtime_name,
       event_dispatcher: nil}
    )

    :ok
  end

  describe "deliver_tool_result/5" do
    test "returns :no_executor when no process is waiting" do
      assert :no_executor =
               SwarmAi.Runtime.deliver_tool_result(
                 @runtime_name,
                 "task_1",
                 "tc_1",
                 "result content",
                 false
               )
    end

    test "returns :delivered when a process is waiting" do
      tool_call_id = "tc_#{System.unique_integer([:positive])}"
      test_pid = self()

      # Spawn a process that awaits the tool result
      waiter =
        spawn(fn ->
          result = SwarmAi.Runtime.await_tool_result(@runtime_name, tool_call_id, timeout: 5_000)
          send(test_pid, {:await_result, result})
        end)

      # Give the waiter time to register
      Process.sleep(50)

      # Deliver the result
      assert :delivered =
               SwarmAi.Runtime.deliver_tool_result(
                 @runtime_name,
                 "task_1",
                 tool_call_id,
                 "tool output",
                 false
               )

      # Verify the waiter received it
      assert_receive {:await_result, {:ok, "tool output", false}}, 1_000
    end

    test "delivers error results correctly" do
      tool_call_id = "tc_err_#{System.unique_integer([:positive])}"
      test_pid = self()

      spawn(fn ->
        result = SwarmAi.Runtime.await_tool_result(@runtime_name, tool_call_id, timeout: 5_000)
        send(test_pid, {:await_result, result})
      end)

      Process.sleep(50)

      assert :delivered =
               SwarmAi.Runtime.deliver_tool_result(
                 @runtime_name,
                 "task_1",
                 tool_call_id,
                 "error: something broke",
                 true
               )

      assert_receive {:await_result, {:ok, "error: something broke", true}}, 1_000
    end
  end

  describe "await_tool_result/3" do
    test "blocks until result is delivered" do
      tool_call_id = "tc_block_#{System.unique_integer([:positive])}"
      test_pid = self()

      # Start awaiting in a separate process
      spawn(fn ->
        result = SwarmAi.Runtime.await_tool_result(@runtime_name, tool_call_id, timeout: 5_000)
        send(test_pid, {:await_done, result})
      end)

      # Wait for registration
      Process.sleep(50)

      # Deliver after a short delay
      SwarmAi.Runtime.deliver_tool_result(@runtime_name, "task_1", tool_call_id, "delayed", false)

      assert_receive {:await_done, {:ok, "delayed", false}}, 1_000
    end

    test "returns {:error, :timeout} when no result arrives" do
      tool_call_id = "tc_timeout_#{System.unique_integer([:positive])}"
      test_pid = self()

      spawn(fn ->
        result = SwarmAi.Runtime.await_tool_result(@runtime_name, tool_call_id, timeout: 100)
        send(test_pid, {:await_done, result})
      end)

      # Don't deliver anything — let it timeout
      assert_receive {:await_done, {:error, :timeout}}, 1_000
    end

    test "unregisters after receiving result" do
      tool_call_id = "tc_unreg_#{System.unique_integer([:positive])}"
      test_pid = self()
      tool_reg = SwarmAi.Runtime.tool_registry_name(@runtime_name)

      spawn(fn ->
        result = SwarmAi.Runtime.await_tool_result(@runtime_name, tool_call_id, timeout: 5_000)
        send(test_pid, {:await_done, result})
      end)

      Process.sleep(50)

      # Verify registered
      assert [{_pid, _}] = Registry.lookup(tool_reg, {:awaiting_result, tool_call_id})

      SwarmAi.Runtime.deliver_tool_result(@runtime_name, "task_1", tool_call_id, "done", false)
      assert_receive {:await_done, {:ok, "done", false}}, 1_000

      # Small delay for cleanup
      Process.sleep(50)

      # Verify unregistered
      assert [] = Registry.lookup(tool_reg, {:awaiting_result, tool_call_id})
    end

    test "unregisters after timeout" do
      tool_call_id = "tc_unreg_timeout_#{System.unique_integer([:positive])}"
      test_pid = self()
      tool_reg = SwarmAi.Runtime.tool_registry_name(@runtime_name)

      spawn(fn ->
        result = SwarmAi.Runtime.await_tool_result(@runtime_name, tool_call_id, timeout: 100)
        send(test_pid, {:await_done, result})
      end)

      Process.sleep(50)
      assert [{_pid, _}] = Registry.lookup(tool_reg, {:awaiting_result, tool_call_id})

      assert_receive {:await_done, {:error, :timeout}}, 1_000
      Process.sleep(50)

      assert [] = Registry.lookup(tool_reg, {:awaiting_result, tool_call_id})
    end

    test "multiple concurrent tool results are routed correctly" do
      test_pid = self()

      ids =
        for i <- 1..5 do
          "tc_concurrent_#{i}_#{System.unique_integer([:positive])}"
        end

      # Spawn 5 concurrent waiters
      for id <- ids do
        spawn(fn ->
          result = SwarmAi.Runtime.await_tool_result(@runtime_name, id, timeout: 5_000)
          send(test_pid, {:await_done, id, result})
        end)
      end

      Process.sleep(100)

      # Deliver results in reverse order
      for id <- Enum.reverse(ids) do
        SwarmAi.Runtime.deliver_tool_result(@runtime_name, "task_1", id, "result_#{id}", false)
      end

      # All should receive correctly
      for id <- ids do
        assert_receive {:await_done, ^id, {:ok, content, false}}, 1_000
        assert content == "result_#{id}"
      end
    end
  end

  describe "tool_registry_name/1" do
    test "derives a deterministic name" do
      assert SwarmAi.Runtime.tool_registry_name(:MyRuntime) == :"MyRuntime.ToolRegistry"
    end
  end
end
