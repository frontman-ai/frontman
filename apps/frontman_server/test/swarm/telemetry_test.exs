defmodule Swarm.TelemetryTest do
  use FrontmanServer.SwarmCase, async: true

  alias Swarm.ToolCall

  describe "run telemetry" do
    @tag echo_agent: true
    test "emits start and stop events on successful run", %{echo_agent: agent} do
      events = capture_telemetry(fn ->
        {:ok, _} = Swarm.run(agent, "Hello", %{tool_handler: fn _ -> {:ok, ""} end})
      end)

      assert_event(events, [:swarm, :run, :start], fn measurements, metadata ->
        assert is_integer(measurements.system_time)
        assert is_binary(metadata.loop_id)
        assert metadata.agent_module == FrontmanServer.SwarmCase.TestAgent
      end)

      assert_event(events, [:swarm, :run, :stop], fn measurements, metadata ->
        assert is_integer(measurements.system_time)
        assert metadata.status == :completed
        assert metadata.result == "Echo: Hello"
        assert metadata.step_count >= 1
      end)
    end

    @tag error_agent: :intentional_error
    test "emits stop event with error status on failed run", %{error_agent: agent} do
      events = capture_telemetry(fn ->
        {:error, _} = Swarm.run(agent, "Hello", %{tool_handler: fn _ -> {:ok, ""} end})
      end)

      assert_event(events, [:swarm, :run, :stop], fn _measurements, metadata ->
        assert metadata.status == :failed
        assert metadata.error == :intentional_error
      end)
    end
  end

  describe "LLM call telemetry" do
    @tag echo_agent: true
    test "emits start and stop events for LLM calls", %{echo_agent: agent} do
      events = capture_telemetry(fn ->
        {:ok, _} = Swarm.run(agent, "Hello", %{tool_handler: fn _ -> {:ok, ""} end})
      end)

      assert_event(events, [:swarm, :llm, :call, :start], fn measurements, metadata ->
        assert is_integer(measurements.system_time)
        assert is_binary(metadata.loop_id)
        assert metadata.step == 1
      end)

      assert_event(events, [:swarm, :llm, :call, :stop], fn measurements, metadata ->
        assert is_integer(measurements.system_time)
        assert metadata.input_tokens == 5
        assert metadata.output_tokens == 3
        assert metadata.tool_call_count == 0
      end)
    end

    test "includes token usage from response" do
      llm = mock_llm({:ok, %LLM.Response{
        content: "Response",
        tool_calls: [],
        usage: %{input_tokens: 100, output_tokens: 50},
        raw: nil
      }})
      agent = test_agent(llm)

      events = capture_telemetry(fn ->
        {:ok, _} = Swarm.run(agent, "Hello", %{tool_handler: fn _ -> {:ok, ""} end})
      end)

      assert_event(events, [:swarm, :llm, :call, :stop], fn _measurements, metadata ->
        assert metadata.input_tokens == 100
        assert metadata.output_tokens == 50
      end)
    end
  end

  describe "tool execution telemetry" do
    test "emits start and stop events for tool execution" do
      tool_call = %ToolCall{id: "tc_123", name: "get_weather", arguments: ~s({"city":"NYC"})}

      llm = tool_then_complete_llm([tool_call], "The weather is sunny")
      agent = test_agent(llm)

      events = capture_telemetry(fn ->
        {:ok, _} = Swarm.run(agent, "What's the weather?", %{
          tool_handler: fn
            %{name: "get_weather"} -> {:ok, "Sunny, 22C"}
          end
        })
      end)

      assert_event(events, [:swarm, :tool, :execute, :start], fn measurements, metadata ->
        assert is_integer(measurements.system_time)
        assert metadata.tool_id == "tc_123"
        assert metadata.tool_name == "get_weather"
      end)

      assert_event(events, [:swarm, :tool, :execute, :stop], fn _measurements, metadata ->
        assert metadata.tool_id == "tc_123"
        assert metadata.tool_name == "get_weather"
        assert metadata.is_error == false
      end)
    end

    test "marks tool execution as error when handler returns error" do
      tool_call = %ToolCall{id: "tc_456", name: "bad_tool", arguments: "{}"}

      llm = tool_then_complete_llm([tool_call], "Done")
      agent = test_agent(llm)

      events = capture_telemetry(fn ->
        {:ok, _} = Swarm.run(agent, "Call the tool", %{
          tool_handler: fn _ -> {:error, "Tool failed"} end
        })
      end)

      assert_event(events, [:swarm, :tool, :execute, :stop], fn _measurements, metadata ->
        assert metadata.is_error == true
      end)
    end
  end

  describe "Telemetry.Events.all/0" do
    test "returns all event names for handler attachment" do
      events = Swarm.Telemetry.Events.all()

      assert [:swarm, :run, :start] in events
      assert [:swarm, :run, :stop] in events
      assert [:swarm, :run, :exception] in events
      assert [:swarm, :llm, :call, :start] in events
      assert [:swarm, :llm, :call, :stop] in events
      assert [:swarm, :llm, :call, :exception] in events
      assert [:swarm, :tool, :execute, :start] in events
      assert [:swarm, :tool, :execute, :stop] in events
      assert [:swarm, :tool, :execute, :exception] in events
    end
  end

  # --- Test Helpers ---

  defp capture_telemetry(fun) do
    events = :ets.new(:telemetry_events, [:bag, :public])
    handler_id = "test-handler-#{:erlang.unique_integer()}"

    :telemetry.attach_many(
      handler_id,
      Swarm.Telemetry.Events.all(),
      fn event, measurements, metadata, _config ->
        :ets.insert(events, {event, measurements, metadata})
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

    assert length(matching) >= 1,
           "Expected event #{inspect(event_name)} but found: #{inspect(Enum.map(events, &elem(&1, 0)))}"

    {_event, measurements, metadata} = hd(matching)
    assertions.(measurements, metadata)
  end
end
