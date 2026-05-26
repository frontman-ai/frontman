defmodule FrontmanNotifier.StateTest do
  use ExUnit.Case, async: true

  alias FrontmanNotifier.State

  test "tracks seen keys durably" do
    name = unique_atom("state")
    table = unique_atom("table")
    state_dir = tmp_dir()

    pid = start_supervised!({State, name: name, table: table, state_dir: state_dir})

    refute State.seen?(:stargazer, "octocat", name)
    assert :ok = State.mark_seen(:stargazer, "octocat", name)
    assert State.seen?(:stargazer, "octocat", name)
    assert State.keys(:stargazer, name) == ["octocat"]

    GenServer.stop(pid)
    stop_supervised!(name)

    start_supervised!({State, name: name, table: table, state_dir: state_dir})
    assert State.seen?(:stargazer, "octocat", name)
  end

  test "tracks initialization scopes" do
    name = unique_atom("state")
    table = unique_atom("table")

    start_supervised!({State, name: name, table: table, state_dir: tmp_dir()})

    refute State.initialized?(:stargazers, name)
    assert :ok = State.set_initialized(:stargazers, name)
    assert State.initialized?(:stargazers, name)
  end

  defp tmp_dir do
    Path.join(
      System.tmp_dir!(),
      "frontman_notifier_state_test_#{System.unique_integer([:positive])}"
    )
  end

  defp unique_atom(prefix) do
    String.to_atom("#{prefix}_#{System.unique_integer([:positive])}")
  end
end
