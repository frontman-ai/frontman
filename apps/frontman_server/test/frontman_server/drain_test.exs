defmodule FrontmanServer.DrainTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  setup do
    reset_drain()
    on_exit(fn -> reset_drain() end)
  end

  test "defaults to ready on boot" do
    assert FrontmanServer.Drain.ready?()
  end

  test "start_draining marks node not ready" do
    assert :ok = FrontmanServer.Drain.start_draining()

    refute FrontmanServer.Drain.ready?()
  end

  test "start_draining logs drain entry" do
    prev_level = Logger.level()
    Logger.configure(level: :info)

    log = capture_log(fn -> FrontmanServer.Drain.start_draining() end)

    Logger.configure(level: prev_level)

    assert log =~ "Frontman node entering drain"
    assert log =~ "active_executions=0"
  end

  test "status includes drain state and active execution count" do
    assert FrontmanServer.Drain.status() == %{draining: false, active_executions: 0}

    assert :ok = FrontmanServer.Drain.start_draining()

    assert FrontmanServer.Drain.status() == %{draining: true, active_executions: 0}
  end

  defp reset_drain do
    :sys.replace_state(FrontmanServer.Drain, fn _draining? -> false end)
    assert FrontmanServer.Drain.ready?()
  end
end
