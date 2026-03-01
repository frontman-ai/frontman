defmodule SwarmAi.Runtime.ExecutionMonitorTest do
  use ExUnit.Case, async: true

  alias SwarmAi.Runtime.ExecutionMonitor

  describe "watch/3 and crash detection" do
    test "invokes on_crash when watched process exits abnormally" do
      {monitor, _registry} = start_monitor!()
      test_pid = self()

      pid =
        spawn(fn ->
          ExecutionMonitor.watch(monitor, "key-1",
            on_crash: fn reason -> send(test_pid, {:crashed, reason}) end
          )

          exit(:something_went_wrong)
        end)

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _}, 1000
      assert_receive {:crashed, {:something_went_wrong, []}}, 1000
    end

    test "invokes on_cancelled when watched process exits with :cancelled" do
      {monitor, _registry} = start_monitor!()
      test_pid = self()

      pid =
        spawn(fn ->
          ExecutionMonitor.watch(monitor, "key-cancel",
            on_cancelled: fn -> send(test_pid, :was_cancelled) end,
            on_crash: fn _ -> send(test_pid, :was_crashed) end
          )

          # Keep alive so we can send exit from outside
          Process.sleep(:infinity)
        end)

      Process.sleep(20)
      Process.exit(pid, :cancelled)

      assert_receive :was_cancelled, 1000
      refute_receive :was_crashed, 200
    end

    test "does not invoke callbacks on normal exit" do
      {monitor, _registry} = start_monitor!()
      test_pid = self()

      pid =
        spawn(fn ->
          ExecutionMonitor.watch(monitor, "key-normal",
            on_crash: fn _ -> send(test_pid, :crash) end,
            on_cancelled: fn -> send(test_pid, :cancel) end
          )

          # Normal exit
          :ok
        end)

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1000
      refute_receive :crash, 200
      refute_receive :cancel, 200
    end

    test "does not invoke callbacks on shutdown exit" do
      {monitor, _registry} = start_monitor!()
      test_pid = self()

      pid =
        spawn(fn ->
          ExecutionMonitor.watch(monitor, "key-shutdown",
            on_crash: fn _ -> send(test_pid, :crash) end,
            on_cancelled: fn -> send(test_pid, :cancel) end
          )

          Process.sleep(:infinity)
        end)

      Process.sleep(20)
      Process.exit(pid, :shutdown)

      refute_receive :crash, 300
      refute_receive :cancel, 100
    end

    test "normalizes exception crashes to {exception, stacktrace}" do
      {monitor, _registry} = start_monitor!()
      test_pid = self()

      pid =
        spawn(fn ->
          ExecutionMonitor.watch(monitor, "key-raise",
            on_crash: fn reason -> send(test_pid, {:crashed, reason}) end
          )

          raise "test error"
        end)

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _}, 1000

      assert_receive {:crashed, {%RuntimeError{message: "test error"}, stacktrace}}, 1000
      assert is_list(stacktrace)
      assert length(stacktrace) > 0
    end
  end

  describe "recovery from restart" do
    test "re-monitors processes found in Registry on init" do
      # Start a registry, register a fake running process, then start monitor
      registry = :"TestRecoveryRegistry_#{:erlang.unique_integer([:positive])}"
      start_supervised!({Registry, keys: :unique, name: registry})

      test_pid = self()

      # Spawn a process and register it as running
      pid =
        spawn(fn ->
          Registry.register(registry, {:running, "recovered-key"}, %{})
          send(test_pid, :registered)
          Process.sleep(:infinity)
        end)

      assert_receive :registered, 1000

      # Now start ExecutionMonitor — it should find and re-monitor the process
      monitor = :"TestRecoveryMonitor_#{:erlang.unique_integer([:positive])}"
      start_supervised!({ExecutionMonitor, name: monitor, registry: registry})

      # Kill the process — monitor should detect it (but no callback since recovery
      # doesn't have callbacks)
      Process.exit(pid, :kill)

      # Just verify the monitor didn't crash from the :DOWN message
      Process.sleep(100)
      assert Process.alive?(GenServer.whereis(monitor))
    end
  end

  describe "callback safety" do
    test "monitor survives callback that raises" do
      {monitor, _registry} = start_monitor!()

      pid =
        spawn(fn ->
          ExecutionMonitor.watch(monitor, "key-bad-callback",
            on_crash: fn _reason -> raise "callback exploded" end
          )

          exit(:boom)
        end)

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _}, 1000

      # Give monitor time to process the :DOWN + rescue
      Process.sleep(50)

      # Monitor should still be alive
      assert Process.alive?(GenServer.whereis(monitor))
    end
  end

  # --- Helpers ---

  defp start_monitor! do
    suffix = :erlang.unique_integer([:positive])
    registry = :"TestMonRegistry_#{suffix}"
    monitor = :"TestMonitor_#{suffix}"

    start_supervised!({Registry, keys: :unique, name: registry})
    start_supervised!({ExecutionMonitor, name: monitor, registry: registry})

    {monitor, registry}
  end
end
