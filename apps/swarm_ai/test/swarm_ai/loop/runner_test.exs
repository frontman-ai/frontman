defmodule SwarmAi.Loop.RunnerTest do
  use SwarmAi.Testing, async: true

  alias SwarmAi.{LLM, Loop, Message}
  alias SwarmAi.Loop.{Config, Runner, Step}

  setup do
    agent = test_agent(mock_llm("test"))
    config = %Config{max_steps: 10, timeout_ms: 60_000, step_timeout_ms: 120_000}
    loop = Loop.make(agent, config)

    %{agent: agent, loop: loop}
  end

  describe "Runner.start/2" do
    test "transitions loop from :ready to :running", %{loop: loop} do
      {updated_loop, _effects} = Runner.start(loop, [Message.user("Test")])

      assert updated_loop.status == :running
    end

    test "creates step with system and user messages", %{loop: loop} do
      {updated_loop, _effects} = Runner.start(loop, [Message.user("Hello")])

      assert [%Step{input_messages: messages}] = updated_loop.steps

      assert [
               %Message.System{} = system_msg,
               %Message.User{} = user_msg
             ] = messages

      assert Message.text(system_msg) == "You are TestBot"
      assert Message.text(user_msg) == "Hello"
    end

    test "returns call_llm effect", %{loop: loop} do
      {_updated_loop, effects} = Runner.start(loop, [Message.user("Test message")])

      assert [{:call_llm, _llm, messages}] = effects
      assert length(messages) == 2
    end

    test "includes agent's LLM client in effect", %{loop: loop} do
      {_loop, effects} = Runner.start(loop, [Message.user("Test")])

      assert {:call_llm, llm, _messages} = Enum.at(effects, 0)
      assert llm == loop.agent.llm
    end
  end

  describe "Runner.handle_llm_response/2" do
    test "transitions loop from :running to :completed", %{loop: loop} do
      {running_loop, _} = Runner.start(loop, [Message.user("Hello")])
      response = %LLM.Response{content: "Done", usage: nil, raw: nil}

      {completed_loop, _effects} = Runner.handle_llm_response(running_loop, response)

      assert completed_loop.status == :completed
      assert completed_loop.result == "Done"
    end

    test "updates step with response content and usage", %{loop: loop} do
      {running_loop, _} = Runner.start(loop, [Message.user("Test")])

      response = %LLM.Response{
        content: "Response text",
        usage: %{input_tokens: 20, output_tokens: 15},
        raw: nil
      }

      {completed_loop, _} = Runner.handle_llm_response(running_loop, response)

      [step] = completed_loop.steps
      assert step.content == "Response text"
      assert step.usage == %{input_tokens: 20, output_tokens: 15}
      assert step.completed_at != nil
      assert is_integer(step.duration_ms)
    end

    test "updates step with reasoning_details from response", %{loop: loop} do
      {running_loop, _} = Runner.start(loop, [Message.user("Test")])

      reasoning = [
        %{"type" => "reasoning.text", "index" => 0, "text" => "Let me think..."},
        %{"type" => "reasoning.text", "index" => 1, "text" => "Got it!"}
      ]

      response = %LLM.Response{
        content: "Answer",
        reasoning_details: reasoning,
        usage: nil,
        raw: nil
      }

      {completed_loop, _} = Runner.handle_llm_response(running_loop, response)

      [step] = completed_loop.steps
      assert step.reasoning_details == reasoning
    end

    test "returns complete effect", %{loop: loop} do
      {running_loop, _} = Runner.start(loop, [Message.user("Test")])
      response = %LLM.Response{content: "Final answer", usage: nil, raw: nil}

      {_loop, effects} = Runner.handle_llm_response(running_loop, response)

      assert [{:complete, "Final answer"}] = effects
    end
  end

  describe "Runner.handle_llm_error/2" do
    test "transitions loop to :failed status", %{loop: loop} do
      {failed_loop, _effects} = Runner.handle_llm_error(loop, :timeout)

      assert failed_loop.status == :failed
      assert failed_loop.error == :timeout
    end

    test "preserves error details", %{loop: loop} do
      error = {:rate_limit, "Too many requests"}
      {failed_loop, _} = Runner.handle_llm_error(loop, error)

      assert failed_loop.error == error
    end

    test "returns fail effect", %{loop: loop} do
      error = :network_error
      {_failed_loop, effects} = Runner.handle_llm_error(loop, error)

      assert [{:fail, ^error}] = effects
    end
  end

  describe "effect flow" do
    test "happy path produces correct effect sequence", %{loop: loop} do
      {running_loop, start_effects} = Runner.start(loop, [Message.user("Hello")])
      assert [{:call_llm, _, _}] = start_effects

      response = %LLM.Response{content: "World", usage: nil, raw: nil}
      {completed_loop, response_effects} = Runner.handle_llm_response(running_loop, response)

      assert [{:complete, "World"}] = response_effects
      assert completed_loop.status == :completed
    end

    test "error path produces correct effect sequence", %{loop: loop} do
      {running_loop, start_effects} = Runner.start(loop, [Message.user("Test")])
      assert [{:call_llm, _, _}] = start_effects

      {failed_loop, error_effects} = Runner.handle_llm_error(running_loop, :timeout)

      assert [{:fail, :timeout}] = error_effects
      assert failed_loop.status == :failed
    end
  end

  describe "loop state tracking" do
    test "increments step number correctly", %{loop: loop} do
      {loop_after_start, _} = Runner.start(loop, [Message.user("Test")])

      assert loop_after_start.current_step == 1
      assert length(loop_after_start.steps) == 1
      assert hd(loop_after_start.steps).number == 1
    end

    test "preserves loop configuration", %{loop: loop} do
      {updated_loop, _} = Runner.start(loop, [Message.user("Test")])

      assert updated_loop.config == loop.config
      assert updated_loop.id == loop.id
    end
  end

  describe "LLM.Response.from_stream/1 reasoning_details" do
    alias ReqLLM.StreamChunk

    test "accumulates thinking chunks into reasoning_details" do
      stream = [
        StreamChunk.thinking("Let me think...", %{"type" => "reasoning.text", "format" => "test"}),
        StreamChunk.thinking("Still thinking...", %{}),
        StreamChunk.text("Here's my answer"),
        StreamChunk.meta(%{finish_reason: :stop})
      ]

      response = LLM.Response.from_stream(stream)

      assert response.content == "Here's my answer"
      assert length(response.reasoning_details) == 2

      [first, second] = response.reasoning_details
      assert first["text"] == "Let me think..."
      assert first["index"] == 0
      assert first["type"] == "reasoning.text"

      assert second["text"] == "Still thinking..."
      assert second["index"] == 1
    end

    test "returns empty reasoning_details when no thinking chunks" do
      stream = [
        StreamChunk.text("Just content"),
        StreamChunk.meta(%{finish_reason: :stop})
      ]

      response = LLM.Response.from_stream(stream)

      assert response.reasoning_details == []
    end
  end

  describe "LLM.Response.from_stream/1 streaming tool calls" do
    alias ReqLLM.StreamChunk

    test "accumulates streaming tool call with argument fragments" do
      stream = [
        # Tool call name arrives first (streaming)
        StreamChunk.tool_call("read_file", %{}, %{id: "call_123", index: 0}),
        # Argument fragments arrive separately
        StreamChunk.meta(%{tool_call_args: %{index: 0, fragment: "{\"path\":"}}),
        StreamChunk.meta(%{tool_call_args: %{index: 0, fragment: "\"/home/user"}}),
        StreamChunk.meta(%{tool_call_args: %{index: 0, fragment: "/file.txt\"}"}}),
        StreamChunk.meta(%{finish_reason: :tool_calls})
      ]

      response = LLM.Response.from_stream(stream)

      assert length(response.tool_calls) == 1
      [tool_call] = response.tool_calls
      assert tool_call.id == "call_123"
      assert tool_call.name == "read_file"
      assert tool_call.arguments == ~s({"path":"/home/user/file.txt"})
    end

    test "handles multiple parallel streaming tool calls" do
      stream = [
        # Two tool calls starting
        StreamChunk.tool_call("read_file", %{}, %{id: "call_1", index: 0}),
        StreamChunk.tool_call("list_files", %{}, %{id: "call_2", index: 1}),
        # Interleaved argument fragments
        StreamChunk.meta(%{tool_call_args: %{index: 0, fragment: ~s({"path":)}}),
        StreamChunk.meta(%{tool_call_args: %{index: 1, fragment: ~s({"dir":)}}),
        StreamChunk.meta(%{tool_call_args: %{index: 0, fragment: ~s("/foo"})}}),
        StreamChunk.meta(%{tool_call_args: %{index: 1, fragment: ~s("/bar"})}}),
        StreamChunk.meta(%{finish_reason: :tool_calls})
      ]

      response = LLM.Response.from_stream(stream)

      assert length(response.tool_calls) == 2

      tool_calls_by_id = Map.new(response.tool_calls, &{&1.id, &1})

      assert tool_calls_by_id["call_1"].name == "read_file"
      assert tool_calls_by_id["call_1"].arguments == ~s({"path":"/foo"})

      assert tool_calls_by_id["call_2"].name == "list_files"
      assert tool_calls_by_id["call_2"].arguments == ~s({"dir":"/bar"})
    end

    test "handles non-streaming complete tool calls" do
      stream = [
        StreamChunk.tool_call("get_weather", %{"location" => "NYC"}, %{id: "call_456", index: 0}),
        StreamChunk.meta(%{finish_reason: :tool_calls})
      ]

      response = LLM.Response.from_stream(stream)

      assert length(response.tool_calls) == 1
      [tool_call] = response.tool_calls
      assert tool_call.id == "call_456"
      assert tool_call.name == "get_weather"
      assert tool_call.arguments == ~s({"location":"NYC"})
    end

    @tag :capture_log
    test "handles streaming tool call with no argument fragments" do
      stream = [
        StreamChunk.tool_call("get_time", %{}, %{id: "call_789", index: 0}),
        # No argument fragments - tool takes no parameters
        StreamChunk.meta(%{finish_reason: :tool_calls})
      ]

      response = LLM.Response.from_stream(stream)

      assert length(response.tool_calls) == 1
      [tool_call] = response.tool_calls
      assert tool_call.id == "call_789"
      assert tool_call.name == "get_time"
      # Preserve missing fragments so downstream parsing fails loudly.
      assert tool_call.arguments == ""
    end

    test "raises when argument fragments arrive before tool_call_start" do
      stream = [
        # Arguments without a preceding tool_call_start - this is a bug
        StreamChunk.meta(%{tool_call_args: %{index: 0, fragment: ~s({"path":"/foo"})}}),
        StreamChunk.meta(%{finish_reason: :tool_calls})
      ]

      assert_raise ArgumentError, ~r/no tool_call_start was received/, fn ->
        LLM.Response.from_stream(stream)
      end
    end

    @tag :capture_log
    test "truncated stream preserves invalid JSON for debugging (no masking)" do
      stream = [
        StreamChunk.tool_call("read_file", %{}, %{id: "call_trunc", index: 0}),
        StreamChunk.meta(%{
          tool_call_args: %{index: 0, fragment: ~s[{"path": "app/admin/products/page.tsx"]}
        }),
        StreamChunk.meta(%{finish_reason: :tool_calls})
      ]

      response = LLM.Response.from_stream(stream)

      assert length(response.tool_calls) == 1
      [tool_call] = response.tool_calls
      assert tool_call.id == "call_trunc"
      assert tool_call.name == "read_file"
      # Preserve truncated JSON for debugging - don't mask with "{}"
      assert tool_call.arguments == ~s[{"path": "app/admin/products/page.tsx"]
    end

    @tag :capture_log
    test "multi-fragment truncation: preserves partial JSON for debugging (no masking)" do
      stream = [
        StreamChunk.tool_call("write_file", %{}, %{id: "call_frag", index: 0}),
        StreamChunk.meta(%{tool_call_args: %{index: 0, fragment: ~s[{"path":]}}),
        StreamChunk.meta(%{tool_call_args: %{index: 0, fragment: ~s[ "src/Button.tsx",]}}),
        StreamChunk.meta(%{
          tool_call_args: %{index: 0, fragment: ~s[ "content": "export default function() {}"]}
        }),
        StreamChunk.meta(%{finish_reason: :tool_calls})
      ]

      response = LLM.Response.from_stream(stream)

      [tool_call] = response.tool_calls
      # Preserve partial JSON for debugging - don't mask with "{}"
      assert tool_call.arguments ==
               ~s[{"path": "src/Button.tsx", "content": "export default function() {}"]
    end

    test "mixes streaming and non-streaming tool calls" do
      stream = [
        # One streaming tool call
        StreamChunk.tool_call("streaming_tool", %{}, %{id: "call_streaming", index: 0}),
        StreamChunk.meta(%{tool_call_args: %{index: 0, fragment: ~s({"arg":"val"})}}),
        # One complete tool call
        StreamChunk.tool_call("complete_tool", %{"key" => "value"}, %{
          id: "call_complete",
          index: 1
        }),
        StreamChunk.meta(%{finish_reason: :tool_calls})
      ]

      response = LLM.Response.from_stream(stream)

      assert length(response.tool_calls) == 2

      tool_calls_by_id = Map.new(response.tool_calls, &{&1.id, &1})

      assert tool_calls_by_id["call_streaming"].name == "streaming_tool"
      assert tool_calls_by_id["call_streaming"].arguments == ~s({"arg":"val"})

      assert tool_calls_by_id["call_complete"].name == "complete_tool"
      assert tool_calls_by_id["call_complete"].arguments == ~s({"key":"value"})
    end
  end
end
