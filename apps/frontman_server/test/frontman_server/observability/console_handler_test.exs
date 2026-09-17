defmodule FrontmanServer.Observability.ConsoleHandlerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias FrontmanServer.Observability.ConsoleHandler
  alias SwarmAi.Telemetry
  alias SwarmAi.Telemetry.Events

  @table :frontman_console_timing

  setup do
    ConsoleHandler.setup()

    on_exit(fn ->
      Enum.each(Events.all(), fn event ->
        :telemetry.detach("frontman_console_#{Enum.join(event, "_")}")
      end)
    end)

    :ok
  end

  for kind <- [:run, :llm, :tool], outcome <- [:stop, :exception] do
    test "#{kind} spans isolate overlapping executions on #{outcome}" do
      kind = unquote(kind)
      outcome = unquote(outcome)
      parent = self()

      logs =
        capture_log(fn ->
          first = Task.async(fn -> overlapping_span(kind, parent) end)
          second = Task.async(fn -> overlapping_span(kind, parent) end)
          assert_receive {:started, first_pid}, 1_000
          assert_receive {:started, second_pid}, 1_000
          refute first_pid == second_pid

          entries = :ets.tab2list(@table)
          assert length(entries) == 2

          send(first.pid, outcome)
          assert Task.await(first) == outcome
          assert [remaining] = :ets.tab2list(@table)
          assert remaining in entries

          send(second.pid, :stop)
          assert Task.await(second) == :stop
          assert :ets.tab2list(@table) == []
        end)

      refute logs =~ "orphaned"
      refute logs =~ "has failed and has been detached"
    end
  end

  for outcome <- [:stop, :exception] do
    test "manual tool events isolate execution processes on #{outcome}" do
      outcome = unquote(outcome)
      parent = self()

      logs =
        capture_log(fn ->
          first = Task.async(fn -> overlapping_tool(parent) end)
          second = Task.async(fn -> overlapping_tool(parent) end)
          assert_receive {:started, _}, 1_000
          assert_receive {:started, _}, 1_000

          first_key = {:swarm_tool, first.pid, "shared-loop", "shared-tool"}
          second_key = {:swarm_tool, second.pid, "shared-loop", "shared-tool"}
          assert :ets.member(@table, first_key)
          assert [second_entry] = :ets.lookup(@table, second_key)

          send(first.pid, outcome)
          assert Task.await(first) == :ok
          refute :ets.member(@table, first_key)
          assert :ets.lookup(@table, second_key) == [second_entry]

          send(second.pid, :stop)
          assert Task.await(second) == :ok
          assert :ets.tab2list(@table) == []
        end)

      refute logs =~ "orphaned"
      refute logs =~ "has failed and has been detached"
    end
  end

  defp overlapping_span(kind, parent) do
    metadata = %{
      loop_id: "shared-loop",
      step: 1,
      model: "test-model",
      tool_id: "shared-tool",
      tool_name: "test-tool",
      status: :completed,
      step_count: 1,
      is_error: false
    }

    span =
      case kind do
        :run -> &Telemetry.run_span/2
        :llm -> &Telemetry.llm_span/2
        :tool -> &Telemetry.tool_span/2
      end

    span.(metadata, fn ->
      case await_outcome(parent) do
        :stop -> {:stop, metadata}
        :exception -> raise "test exception"
      end
    end)
  rescue
    error in RuntimeError ->
      assert error.message == "test exception"
      :exception
  end

  defp overlapping_tool(parent) do
    Telemetry.tool_execute_start("shared-loop", 1, "shared-tool", "test-tool")

    case await_outcome(parent) do
      :stop ->
        Telemetry.tool_execute_stop("shared-loop", 1, "shared-tool", "test-tool")

      :exception ->
        Telemetry.tool_execute_exception(
          "shared-loop",
          1,
          "shared-tool",
          "test-tool",
          :error,
          :test,
          []
        )
    end
  end

  defp await_outcome(parent) do
    send(parent, {:started, self()})

    receive do
      outcome when outcome in [:stop, :exception] -> outcome
    after
      1_000 -> raise "timed out waiting for test outcome"
    end
  end
end
