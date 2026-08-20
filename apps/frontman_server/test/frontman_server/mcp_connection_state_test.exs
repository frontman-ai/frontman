defmodule FrontmanServer.MCPConnectionStateTest do
  use ExUnit.Case, async: false

  alias FrontmanServer.MCPConnectionState

  test "catalog and project-context reads remain safe while their channel owner dies" do
    parent = self()

    owner =
      spawn(fn ->
        :ok = MCPConnectionState.register(self())
        :ok = MCPConnectionState.update_catalog(self(), :ready, [:tool])
        :ok = MCPConnectionState.update_project_context(self(), "task-1", :ready)
        send(parent, {:registered, self()})

        receive do
          :stop -> :ok
        after
          5_000 -> exit(:owner_wait_timeout)
        end
      end)

    assert_receive {:registered, ^owner}, 1_000
    assert MCPConnectionState.catalog(owner) == {:ok, :ready, [:tool]}
    assert MCPConnectionState.project_context(owner, "task-1") == {:ok, :ready}

    monitor = Process.monitor(owner)

    readers =
      for _index <- 1..20 do
        Task.async(fn ->
          {MCPConnectionState.catalog(owner), MCPConnectionState.project_context(owner, "task-1")}
        end)
      end

    Process.exit(owner, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^owner, :killed}, 1_000

    Enum.each(readers, fn reader ->
      {catalog, context} = Task.await(reader, 1_000)
      assert catalog in [{:ok, :ready, [:tool]}, :unavailable]
      assert context in [{:ok, :ready}, :unavailable]
    end)

    assert_eventually_unavailable(owner, 100)
  end

  test "a live owner can repopulate state after the supervised state owner restarts" do
    owner = spawn(fn -> Process.sleep(5_000) end)

    :ok = MCPConnectionState.register(owner)
    :ok = MCPConnectionState.update_catalog(owner, :ready, [:tool])
    :ok = MCPConnectionState.update_project_context(owner, "task-1", :ready)

    state_owner = Process.whereis(MCPConnectionState)
    monitor = Process.monitor(state_owner)
    Process.exit(state_owner, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^state_owner, :killed}, 1_000

    replacement = wait_for_replacement(state_owner, 100)
    assert is_pid(replacement)
    assert MCPConnectionState.catalog(owner) == :unavailable

    :ok = MCPConnectionState.update_catalog(owner, :ready, [:restored_tool])
    :ok = MCPConnectionState.update_project_context(owner, "task-1", :ready)
    assert MCPConnectionState.catalog(owner) == {:ok, :ready, [:restored_tool]}
    assert MCPConnectionState.project_context(owner, "task-1") == {:ok, :ready}

    Process.exit(owner, :kill)
    assert_eventually_unavailable(owner, 100)
  end

  defp assert_eventually_unavailable(_owner, 0),
    do: flunk("connection state survived owner termination")

  defp assert_eventually_unavailable(owner, attempts) when attempts > 0 do
    case MCPConnectionState.catalog(owner) do
      :unavailable ->
        :ok

      {:ok, _status, _tools} ->
        Process.sleep(10)
        assert_eventually_unavailable(owner, attempts - 1)
    end
  end

  defp wait_for_replacement(_previous, 0), do: flunk("state owner was not restarted")

  defp wait_for_replacement(previous, attempts) when attempts > 0 do
    case Process.whereis(MCPConnectionState) do
      replacement when is_pid(replacement) and replacement != previous ->
        replacement

      _pid ->
        Process.sleep(10)
        wait_for_replacement(previous, attempts - 1)
    end
  end
end
