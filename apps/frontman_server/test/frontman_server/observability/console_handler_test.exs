defmodule FrontmanServer.Observability.ConsoleHandlerTest do
  use ExUnit.Case, async: false

  alias FrontmanServer.Observability.ConsoleHandler

  test "run handlers accept loop-only metadata and clear timing state" do
    table = :ets.new(:frontman_console_timing, [:named_table, :public, :set])
    metadata = %{loop_id: "loop-test"}

    ConsoleHandler.handle_swarm_run_start(nil, %{}, metadata, nil)
    assert [{{:swarm_run, "loop-test"}, _started}] = :ets.tab2list(table)

    ConsoleHandler.handle_swarm_run_stop(
      nil,
      %{},
      Map.merge(metadata, %{status: :completed, step_count: 1}),
      nil
    )

    assert :ets.tab2list(table) == []

    ConsoleHandler.handle_swarm_run_start(nil, %{}, metadata, nil)

    ConsoleHandler.handle_swarm_run_exception(
      nil,
      %{},
      Map.merge(metadata, %{kind: :error, reason: :test}),
      nil
    )

    assert :ets.tab2list(table) == []
  end
end
