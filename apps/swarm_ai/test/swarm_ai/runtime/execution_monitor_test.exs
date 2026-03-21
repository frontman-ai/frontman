defmodule SwarmAi.Runtime.ExecutionMonitorTest do
  use ExUnit.Case, async: true

  alias SwarmAi.Runtime.ExecutionMonitor

  describe "watch/2 and crash detection" do
    test "dispatches crashed event when watched process exits abnormally" do
      {monitor, _registry} = start_monitor!()

      pid =
        spawn(fn ->
          ExecutionMonitor.watch(monitor, "key-1")
          exit(:something_went_wrong)
        end)

      await_exit(pid)
      flush_monitor(monitor)

      assert_receive {:test_event, "key-1",
                      {:crashed, %{reason: :something_went_wrong, stacktrace: []}}}
    end

    test "dispatches cancelled event (not crashed) for :cancelled exit" do
      {monitor, _registry} = start_monitor!()

      pid = spawn_watched(monitor, "key-cancel")
      Process.exit(pid, :cancelled)

      await_exit(pid)
      flush_monitor(monitor)

      assert_receive {:test_event, "key-cancel", {:cancelled, _}}
      refute_received {:test_event, "key-cancel", {:crashed, _}}
    end

    test "silent on normal, :shutdown, and {:shutdown, _} exits" do
      {monitor, _registry} = start_monitor!()

      # normal exit
      pid1 =
        spawn(fn ->
          ExecutionMonitor.watch(monitor, "k-normal")
          :ok
        end)

      await_exit(pid1)
      flush_monitor(monitor)

      # :shutdown exit
      pid2 = spawn_watched(monitor, "k-shut")
      Process.exit(pid2, :shutdown)
      await_exit(pid2)
      flush_monitor(monitor)

      # {:shutdown, reason} exit
      pid3 = spawn_watched(monitor, "k-shut2")
      Process.exit(pid3, {:shutdown, :draining})
      await_exit(pid3)
      flush_monitor(monitor)

      refute_received {:test_event, _, _}
    end

    test "normalizes exception crashes to {exception, stacktrace}" do
      {monitor, _registry} = start_monitor!()

      pid =
        spawn(fn ->
          ExecutionMonitor.watch(monitor, "key-raise")
          raise "test error"
        end)

      await_exit(pid)
      flush_monitor(monitor)

      assert_receive {:test_event, "key-raise",
                      {:crashed, %{reason: %RuntimeError{message: "test error"}, stacktrace: st}}}

      assert is_list(st) and length(st) > 0
    end
  end

  describe "loop snapshot in crash events" do
    test "includes stashed snapshot" do
      {monitor, _registry} = start_monitor!()
      fake_response = %{content: "partial answer", usage: nil}

      pid =
        spawn(fn ->
          ExecutionMonitor.watch(monitor, "snap-key")
          ExecutionMonitor.stash_snapshot(monitor, "snap-key", fake_response)
          exit(:boom)
        end)

      await_exit(pid)
      flush_monitor(monitor)

      assert_receive {:test_event, "snap-key", {:crashed, %{loop: ^fake_response}}}
    end

    test "loop is nil when no snapshot was stashed" do
      {monitor, _registry} = start_monitor!()

      pid =
        spawn(fn ->
          ExecutionMonitor.watch(monitor, "empty-key")
          exit(:boom)
        end)

      await_exit(pid)
      flush_monitor(monitor)

      assert_receive {:test_event, "empty-key", {:crashed, %{loop: nil}}}
    end
  end

  describe "recovery from restart" do
    test "re-monitors and dispatches events for pre-existing processes" do
      registry = :"TestRecoveryRegistry_#{:erlang.unique_integer([:positive])}"
      start_supervised!({Registry, keys: :unique, name: registry})

      test_pid = self()

      pid =
        spawn(fn ->
          Registry.register(registry, {:running, "recovered-key"}, %{})
          send(test_pid, :registered)
          Process.sleep(:infinity)
        end)

      assert_receive :registered, 1000

      monitor = :"TestRecoveryMonitor_#{:erlang.unique_integer([:positive])}"

      :ets.new(ExecutionMonitor.snapshot_table_name(monitor), [:set, :public, :named_table])

      start_supervised!(
        {ExecutionMonitor,
         name: monitor,
         registry: registry,
         event_dispatcher: {__MODULE__.TestDispatcher, :dispatch, [test_pid]}}
      )

      Process.exit(pid, :kill)

      await_exit(pid)
      flush_monitor(monitor)

      assert_receive {:test_event, "recovered-key", {:crashed, _}}
      assert Process.alive?(GenServer.whereis(monitor))
    end
  end

  describe "event dispatch safety" do
    test "monitor survives dispatch failure" do
      suffix = :erlang.unique_integer([:positive])
      registry = :"TestBadRegistry_#{suffix}"
      monitor = :"TestBadMonitor_#{suffix}"

      start_supervised!({Registry, keys: :unique, name: registry})

      :ets.new(ExecutionMonitor.snapshot_table_name(monitor), [:set, :public, :named_table])

      start_supervised!(
        {ExecutionMonitor,
         name: monitor,
         registry: registry,
         event_dispatcher: {__MODULE__.FailingDispatcher, :dispatch, []}}
      )

      pid =
        spawn(fn ->
          ExecutionMonitor.watch(monitor, "key-bad-dispatch")
          exit(:boom)
        end)

      await_exit(pid)
      flush_monitor(monitor)

      assert Process.alive?(GenServer.whereis(monitor))
    end
  end

  # --- Test Dispatchers ---

  defmodule TestDispatcher do
    def dispatch(test_pid, key, event, _metadata) do
      send(test_pid, {:test_event, key, event})
    end
  end

  defmodule FailingDispatcher do
    def dispatch(_key, _event, _metadata), do: raise("dispatch exploded")
  end

  # --- Helpers ---

  defp start_monitor! do
    suffix = :erlang.unique_integer([:positive])
    registry = :"TestMonRegistry_#{suffix}"
    monitor = :"TestMonitor_#{suffix}"
    test_pid = self()

    start_supervised!({Registry, keys: :unique, name: registry})

    :ets.new(ExecutionMonitor.snapshot_table_name(monitor), [:set, :public, :named_table])

    start_supervised!(
      {ExecutionMonitor,
       name: monitor,
       registry: registry,
       event_dispatcher: {__MODULE__.TestDispatcher, :dispatch, [test_pid]}}
    )

    {monitor, registry}
  end

  # Spawns a process that calls watch/2 and then blocks.
  # Returns only after watch has completed (proper handshake, no sleep).
  defp spawn_watched(monitor, key) do
    test_pid = self()

    pid =
      spawn(fn ->
        ExecutionMonitor.watch(monitor, key)
        send(test_pid, {:watched, key})
        Process.sleep(:infinity)
      end)

    assert_receive {:watched, ^key}, 1000
    pid
  end

  defp await_exit(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 1000
  end

  # Forces the monitor GenServer to process all pending messages (including :DOWN).
  # :sys.get_state/1 makes a synchronous call — it can only return after all
  # messages queued before it have been handled.
  defp flush_monitor(monitor) do
    :sys.get_state(monitor)
    :ok
  end
end
