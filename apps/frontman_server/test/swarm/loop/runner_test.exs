defmodule Swarm.Loop.RunnerTest do
  use FrontmanServer.SwarmCase, async: true

  alias Swarm.{Events, LLM, Loop, Message}
  alias Swarm.Loop.{Config, Runner, Step}

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
               %Message{role: :system} = system_msg,
               %Message{role: :user} = user_msg
             ] = messages

      assert Message.text(system_msg) == "You are TestBot"
      assert Message.text(user_msg) == "Hello"
    end

    test "returns Started event and call_llm effect", %{loop: loop} do
      {updated_loop, effects} = Runner.start(loop, [Message.user("Test message")])

      assert [
               {:emit_event, %Events.Started{execution_id: exec_id}},
               {:call_llm, _llm, messages}
             ] = effects

      assert exec_id == updated_loop.id
      assert length(messages) == 2
    end

    test "includes agent's LLM client in effect", %{loop: loop} do
      {_loop, effects} = Runner.start(loop, [Message.user("Test")])

      assert {:call_llm, llm, _messages} = Enum.at(effects, 1)
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

    test "returns Completed event and complete effect", %{loop: loop} do
      {running_loop, _} = Runner.start(loop, [Message.user("Test")])
      response = %LLM.Response{content: "Final answer", usage: nil, raw: nil}

      {_loop, effects} = Runner.handle_llm_response(running_loop, response)

      assert [
               {:emit_event, %Events.Completed{result: "Final answer"}},
               {:complete, "Final answer"}
             ] = effects
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

    test "returns Failed event and fail effect", %{loop: loop} do
      error = :network_error
      {failed_loop, effects} = Runner.handle_llm_error(loop, error)

      assert [
               {:emit_event, %Events.Failed{execution_id: exec_id, error: ^error}},
               {:fail, ^error}
             ] = effects

      assert exec_id == failed_loop.id
    end
  end

  describe "effect flow" do
    test "happy path produces correct effect sequence", %{loop: loop} do
      # Start
      {running_loop, start_effects} = Runner.start(loop, [Message.user("Hello")])

      assert {:emit_event, %Events.Started{}} = Enum.at(start_effects, 0)
      assert {:call_llm, _, _} = Enum.at(start_effects, 1)

      # Response
      response = %LLM.Response{content: "World", usage: nil, raw: nil}
      {completed_loop, response_effects} = Runner.handle_llm_response(running_loop, response)

      assert {:emit_event, %Events.Completed{result: "World"}} = Enum.at(response_effects, 0)
      assert {:complete, "World"} = Enum.at(response_effects, 1)
      assert completed_loop.status == :completed
    end

    test "error path produces correct effect sequence", %{loop: loop} do
      # Start
      {running_loop, start_effects} = Runner.start(loop, [Message.user("Test")])

      assert {:emit_event, %Events.Started{}} = Enum.at(start_effects, 0)
      assert {:call_llm, _, _} = Enum.at(start_effects, 1)

      # Error
      {failed_loop, error_effects} = Runner.handle_llm_error(running_loop, :timeout)

      assert {:emit_event, %Events.Failed{error: :timeout}} = Enum.at(error_effects, 0)
      assert {:fail, :timeout} = Enum.at(error_effects, 1)
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
    alias Swarm.LLM.Chunk

    test "accumulates thinking chunks into reasoning_details" do
      stream = [
        Chunk.thinking("Let me think...", %{"type" => "reasoning.text", "format" => "test"}),
        Chunk.thinking("Still thinking...", %{}),
        Chunk.token("Here's my answer"),
        Chunk.done(:stop)
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
        Chunk.token("Just content"),
        Chunk.done(:stop)
      ]

      response = LLM.Response.from_stream(stream)

      assert response.reasoning_details == []
    end
  end

  describe "LLM.Response.from_stream/1 streaming tool calls" do
    alias Swarm.LLM.Chunk

    test "accumulates streaming tool call with argument fragments" do
      stream = [
        # Tool call name arrives first (streaming)
        Chunk.tool_call_start("call_123", "read_file", 0),
        # Argument fragments arrive separately
        Chunk.tool_call_args(0, ~s({"path":)),
        Chunk.tool_call_args(0, ~s("/home/user)),
        Chunk.tool_call_args(0, ~s(/file.txt"})),
        Chunk.done(:tool_calls)
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
        Chunk.tool_call_start("call_1", "read_file", 0),
        Chunk.tool_call_start("call_2", "list_files", 1),
        # Interleaved argument fragments
        Chunk.tool_call_args(0, ~s({"path":)),
        Chunk.tool_call_args(1, ~s({"dir":)),
        Chunk.tool_call_args(0, ~s("/foo"})),
        Chunk.tool_call_args(1, ~s("/bar"})),
        Chunk.done(:tool_calls)
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
      tool_call = %Swarm.ToolCall{
        id: "call_456",
        name: "get_weather",
        arguments: ~s({"location":"NYC"})
      }

      stream = [
        Chunk.tool_call_end(tool_call),
        Chunk.done(:tool_calls)
      ]

      response = LLM.Response.from_stream(stream)

      assert length(response.tool_calls) == 1
      assert hd(response.tool_calls) == tool_call
    end

    @tag :capture_log
    test "handles streaming tool call with no argument fragments" do
      stream = [
        Chunk.tool_call_start("call_789", "get_time", 0),
        # No argument fragments - tool takes no parameters
        Chunk.done(:tool_calls)
      ]

      response = LLM.Response.from_stream(stream)

      assert length(response.tool_calls) == 1
      [tool_call] = response.tool_calls
      assert tool_call.id == "call_789"
      assert tool_call.name == "get_time"
      # Empty string (no fragments), not masked to "{}" - let error surface at execution
      assert tool_call.arguments == ""
    end

    test "raises when argument fragments arrive before tool_call_start" do
      stream = [
        # Arguments without a preceding tool_call_start - this is a bug
        Chunk.tool_call_args(0, ~s({"path":"/foo"})),
        Chunk.done(:tool_calls)
      ]

      assert_raise ArgumentError, ~r/no tool_call_start was received/, fn ->
        LLM.Response.from_stream(stream)
      end
    end

    @tag :capture_log
    test "truncated stream preserves invalid JSON for debugging (no masking)" do
      stream = [
        Chunk.tool_call_start("call_trunc", "read_file", 0),
        Chunk.tool_call_args(0, ~s[{"path": "app/admin/products/page.tsx"]),
        Chunk.done(:tool_calls)
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
        Chunk.tool_call_start("call_frag", "write_file", 0),
        Chunk.tool_call_args(0, ~s[{"path":]),
        Chunk.tool_call_args(0, ~s[ "src/Button.tsx",]),
        Chunk.tool_call_args(0, ~s[ "content": "export default function() {}"]),
        Chunk.done(:tool_calls)
      ]

      response = LLM.Response.from_stream(stream)

      [tool_call] = response.tool_calls
      # Preserve partial JSON for debugging - don't mask with "{}"
      assert tool_call.arguments ==
               ~s[{"path": "src/Button.tsx", "content": "export default function() {}"]
    end

    test "mixes streaming and non-streaming tool calls" do
      complete_tool_call = %Swarm.ToolCall{
        id: "call_complete",
        name: "complete_tool",
        arguments: ~s({"key":"value"})
      }

      stream = [
        # One streaming tool call
        Chunk.tool_call_start("call_streaming", "streaming_tool", 0),
        Chunk.tool_call_args(0, ~s({"arg":"val"})),
        # One complete tool call
        Chunk.tool_call_end(complete_tool_call),
        Chunk.done(:tool_calls)
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
