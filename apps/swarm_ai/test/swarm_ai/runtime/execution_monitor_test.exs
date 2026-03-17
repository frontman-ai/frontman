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

      assert_receive {:test_event, "key-1",
                      {:crashed, %{reason: :something_went_wrong, stacktrace: []}}}
    end

    test "dispatches cancelled event (not crashed) for :cancelled exit" do
      {monitor, _registry} = start_monitor!()

      pid =
        spawn(fn ->
          ExecutionMonitor.watch(monitor, "key-cancel")
          Process.sleep(:infinity)
        end)

      Process.sleep(20)
      Process.exit(pid, :cancelled)

      assert_receive {:test_event, "key-cancel", {:cancelled, _}}, 1000
      refute_receive {:test_event, "key-cancel", {:crashed, _}}, 200
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

      # :shutdown exit
      pid2 =
        spawn(fn ->
          ExecutionMonitor.watch(monitor, "k-shut")
          Process.sleep(:infinity)
        end)

      Process.sleep(20)
      Process.exit(pid2, :shutdown)
      await_exit(pid2)

      # {:shutdown, reason} exit
      pid3 =
        spawn(fn ->
          ExecutionMonitor.watch(monitor, "k-shut2")
          Process.sleep(:infinity)
        end)

      Process.sleep(20)
      Process.exit(pid3, {:shutdown, :draining})
      await_exit(pid3)

      refute_receive {:test_event, _, _}, 200
    end

    test "normalizes exception crashes to {exception, stacktrace}" do
      {monitor, _registry} = start_monitor!()

      pid =
        spawn(fn ->
          ExecutionMonitor.watch(monitor, "key-raise")
          raise "test error"
        end)

      await_exit(pid)

      assert_receive {:test_event, "key-raise",
                      {:crashed, %{reason: %RuntimeError{message: "test error"}, stacktrace: st}}}

      assert is_list(st) and length(st) > 0
    end
  end

  describe "registry cleanup before events" do
    test "registry entry is cleared before event is dispatched" do
      {monitor, registry} = start_monitor!()

      # Crash path
      _pid =
        spawn(fn ->
          Registry.register(registry, {:running, "race-key"}, %{})
          ExecutionMonitor.watch(monitor, "race-key")
          exit(:boom)
        end)

      assert_receive {:test_event, "race-key", {:crashed, _}}, 1000
      assert Registry.lookup(registry, {:running, "race-key"}) == []

      # Cancel path
      pid2 =
        spawn(fn ->
          Registry.register(registry, {:running, "cancel-race"}, %{})
          ExecutionMonitor.watch(monitor, "cancel-race")
          Process.sleep(:infinity)
        end)

      Process.sleep(20)
      Process.exit(pid2, :cancelled)

      assert_receive {:test_event, "cancel-race", {:cancelled, _}}, 1000
      assert Registry.lookup(registry, {:running, "cancel-race"}) == []
    end
  end

  describe "loop snapshot in crash events" do
    test "includes last_response from Registry value" do
      {monitor, registry} = start_monitor!()
      fake_response = %{content: "partial answer", usage: nil}

      _pid =
        spawn(fn ->
          Registry.register(registry, {:running, "snap-key"}, %{last_response: fake_response})
          ExecutionMonitor.watch(monitor, "snap-key")
          exit(:boom)
        end)

      assert_receive {:test_event, "snap-key", {:crashed, %{loop: ^fake_response}}},
                     1000
    end

    test "loop is nil when no response was stashed" do
      {monitor, registry} = start_monitor!()

      _pid =
        spawn(fn ->
          Registry.register(registry, {:running, "empty-key"}, %{})
          ExecutionMonitor.watch(monitor, "empty-key")
          exit(:boom)
        end)

      assert_receive {:test_event, "empty-key", {:crashed, %{loop: nil}}}, 1000
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

      start_supervised!(
        {ExecutionMonitor,
         name: monitor,
         registry: registry,
         event_dispatcher: {__MODULE__.TestDispatcher, :dispatch, [test_pid]}}
      )

      # Kill the process — monitor should detect it and dispatch
      Process.exit(pid, :kill)

      assert_receive {:test_event, "recovered-key", {:crashed, _}}, 1000
      assert Process.alive?(GenServer.whereis(monitor))
    end
  end

  describe "event dispatch safety" do
    test "monitor survives dispatch failure" do
      suffix = :erlang.unique_integer([:positive])
      registry = :"TestBadRegistry_#{suffix}"
      monitor = :"TestBadMonitor_#{suffix}"

      start_supervised!({Registry, keys: :unique, name: registry})

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
      Process.sleep(50)
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

    start_supervised!(
      {ExecutionMonitor,
       name: monitor,
       registry: registry,
       event_dispatcher: {__MODULE__.TestDispatcher, :dispatch, [test_pid]}}
    )

    {monitor, registry}
  end

  defp await_exit(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 1000
  end
end
