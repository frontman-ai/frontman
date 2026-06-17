defmodule SwarmAi.TelemetryTest do
  use SwarmAi.Testing, async: true

  alias SwarmAi.Telemetry.Events, as: TelemetryEvents

  describe "Telemetry.Events.all/0" do
    test "returns all event names for handler attachment" do
      events = TelemetryEvents.all()

      assert [:swarm_ai, :run, :start] in events
      assert [:swarm_ai, :run, :stop] in events
      assert [:swarm_ai, :run, :exception] in events
      assert [:swarm_ai, :llm, :call, :start] in events
      assert [:swarm_ai, :llm, :call, :stop] in events
      assert [:swarm_ai, :llm, :call, :exception] in events
      assert [:swarm_ai, :tool, :execute, :start] in events
      assert [:swarm_ai, :tool, :execute, :stop] in events
      assert [:swarm_ai, :tool, :execute, :exception] in events
    end
  end

  describe "Telemetry span helpers" do
    test "run_span executes function and returns result" do
      result =
        SwarmAi.Telemetry.run_span(%{loop_id: "test", task_id: "task_123", turn_number: 1}, fn ->
          {"my_result",
           %{
             loop_id: "test",
             task_id: "task_123",
             turn_number: 1,
             status: :completed,
             step_count: 1
           }}
        end)

      assert result == "my_result"
    end

    test "run_span stop event includes callback metadata" do
      events =
        capture_telemetry(fn ->
          SwarmAi.Telemetry.run_span(
            %{loop_id: "loop_123", task_id: "task_123", turn_number: 1},
            fn ->
              {"result",
               %{
                 task_id: "task_123",
                 turn_number: 1,
                 loop_id: "loop_123",
                 status: :completed,
                 step_count: 3
               }}
            end
          )
        end)

      assert_event(events, [:swarm_ai, :run, :stop], fn _measurements, metadata ->
        assert Map.has_key?(metadata, :loop_id), "stop event must include loop_id"
        assert metadata.loop_id == "loop_123"
        assert metadata.task_id == "task_123"
        assert metadata.turn_number == 1
        assert metadata.status == :completed
        assert metadata.step_count == 3
      end)
    end

    test "llm_span executes function and returns result" do
      result =
        SwarmAi.Telemetry.llm_span(%{loop_id: "test", step: 1, model: "claude"}, fn ->
          {"response", %{loop_id: "test", step: 1, input_tokens: 100, output_tokens: 50}}
        end)

      assert result == "response"
    end

    test "tool_span executes function and returns result" do
      result =
        SwarmAi.Telemetry.tool_span(
          %{loop_id: "test", step: 1, tool_id: "tc1", tool_name: "search"},
          fn ->
            {"tool_result", %{tool_id: "tc1", is_error: false}}
          end
        )

      assert result == "tool_result"
    end
  end

  describe "manual telemetry emission" do
    test "run_start emits correct event" do
      events =
        capture_telemetry(fn ->
          SwarmAi.Telemetry.run_start("loop_123", "task_123", 1)
        end)

      assert_event(events, [:swarm_ai, :run, :start], fn measurements, metadata ->
        assert is_integer(measurements.system_time)
        assert metadata.loop_id == "loop_123"
        assert metadata.task_id == "task_123"
        assert metadata.turn_number == 1
      end)
    end

    test "run_stop emits correct event" do
      events =
        capture_telemetry(fn ->
          SwarmAi.Telemetry.run_stop("loop_123",
            task_id: "task_123",
            turn_number: 1,
            status: :completed,
            result: "done",
            step_count: 2
          )
        end)

      assert_event(events, [:swarm_ai, :run, :stop], fn measurements, metadata ->
        assert is_integer(measurements.system_time)
        assert metadata.loop_id == "loop_123"
        assert metadata.task_id == "task_123"
        assert metadata.turn_number == 1
        assert metadata.status == :completed
        assert metadata.result == "done"
        assert metadata.step_count == 2
      end)
    end

    test "llm_call_start emits correct event" do
      events =
        capture_telemetry(fn ->
          SwarmAi.Telemetry.llm_call_start("loop_123", 1, "claude-3")
        end)

      assert_event(events, [:swarm_ai, :llm, :call, :start], fn measurements, metadata ->
        assert is_integer(measurements.system_time)
        assert metadata.loop_id == "loop_123"
        assert metadata.step == 1
        assert metadata.model == "claude-3"
      end)
    end

    test "llm_call_stop emits correct event" do
      events =
        capture_telemetry(fn ->
          SwarmAi.Telemetry.llm_call_stop("loop_123", 1,
            input_tokens: 100,
            output_tokens: 50,
            tool_call_count: 2
          )
        end)

      assert_event(events, [:swarm_ai, :llm, :call, :stop], fn measurements, metadata ->
        assert is_integer(measurements.system_time)
        assert metadata.input_tokens == 100
        assert metadata.output_tokens == 50
        assert metadata.tool_call_count == 2
      end)
    end

    test "tool_execute_start emits correct event" do
      events =
        capture_telemetry(fn ->
          SwarmAi.Telemetry.tool_execute_start("loop_123", 1, "tc_456", "get_weather")
        end)

      assert_event(events, [:swarm_ai, :tool, :execute, :start], fn measurements, metadata ->
        assert is_integer(measurements.system_time)
        assert metadata.tool_id == "tc_456"
        assert metadata.tool_name == "get_weather"
      end)
    end

    test "tool_execute_stop emits correct event" do
      events =
        capture_telemetry(fn ->
          SwarmAi.Telemetry.tool_execute_stop("loop_123", 1, "tc_456", "get_weather",
            is_error: false
          )
        end)

      assert_event(events, [:swarm_ai, :tool, :execute, :stop], fn measurements, metadata ->
        assert is_integer(measurements.system_time)
        assert metadata.tool_id == "tc_456"
        assert metadata.tool_name == "get_weather"
        assert metadata.is_error == false
      end)
    end
  end

  defp capture_telemetry(fun) do
    events = :ets.new(:telemetry_events, [:bag, :public])
    handler_id = "test-handler-#{:erlang.unique_integer()}"
    test_pid = self()

    :telemetry.attach_many(
      handler_id,
      TelemetryEvents.all(),
      fn event, measurements, metadata, _config ->
        # Capture only current-process events to avoid async test interference.
        if self() == test_pid do
          :ets.insert(events, {event, measurements, metadata})
        end
      end,
      nil
    )

    try do
      fun.()
      :ets.tab2list(events)
    after
      :telemetry.detach(handler_id)
      :ets.delete(events)
    end
  end

  defp assert_event(events, event_name, assertions) do
    matching = Enum.filter(events, fn {event, _m, _md} -> event == event_name end)

    assert matching != [],
           "Expected event #{inspect(event_name)} but found: #{inspect(Enum.map(events, &elem(&1, 0)))}"

    {_event, measurements, metadata} = hd(matching)
    assertions.(measurements, metadata)
  end
end
