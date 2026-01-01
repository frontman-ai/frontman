defmodule Swarm.Loop.RunnerTest do
  use FrontmanServer.SwarmCase, async: true

  alias Swarm.{Loop, Events, LLM}
  alias Swarm.Loop.{Runner, Config, Step}

  setup do
    agent = test_agent(mock_llm("test"))
    config = %Config{max_steps: 10, timeout_ms: 60_000, step_timeout_ms: 30_000}
    loop = Loop.make(agent, config)

    %{agent: agent, loop: loop}
  end

  describe "Runner.start/3" do
    test "transitions loop from :ready to :running", %{loop: loop, agent: agent} do
      {updated_loop, _effects} = Runner.start(loop, agent, "Test")

      assert updated_loop.status == :running
    end

    test "creates step with system and user messages", %{loop: loop, agent: agent} do
      {updated_loop, _effects} = Runner.start(loop, agent, "Hello")

      assert [%Step{input_messages: messages}] = updated_loop.steps

      assert [
               %{role: "system", content: "You are TestBot"},
               %{role: "user", content: "Hello"}
             ] = messages
    end

    test "returns Started event and call_llm effect", %{loop: loop, agent: agent} do
      {updated_loop, effects} = Runner.start(loop, agent, "Test message")

      assert [
               {:emit_event, %Events.Started{execution_id: exec_id, message: "Test message"}},
               {:call_llm, _llm, messages}
             ] = effects

      assert exec_id == updated_loop.id
      assert length(messages) == 2
    end

    test "includes agent's LLM client in effect", %{loop: loop, agent: agent} do
      {_loop, effects} = Runner.start(loop, agent, "Test")

      assert {:call_llm, llm, _messages} = Enum.at(effects, 1)
      assert llm == agent.llm
    end
  end

  describe "Runner.handle_llm_response/2" do
    test "transitions loop from :running to :completed", %{loop: loop, agent: agent} do
      {running_loop, _} = Runner.start(loop, agent, "Hello")
      response = %LLM.Response{content: "Done", usage: nil, raw: nil}

      {completed_loop, _effects} = Runner.handle_llm_response(running_loop, response)

      assert completed_loop.status == :completed
      assert completed_loop.result == "Done"
    end

    test "updates step with response content and usage", %{loop: loop, agent: agent} do
      {running_loop, _} = Runner.start(loop, agent, "Test")

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

    test "returns Completed event and complete effect", %{loop: loop, agent: agent} do
      {running_loop, _} = Runner.start(loop, agent, "Test")
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
    test "happy path produces correct effect sequence", %{loop: loop, agent: agent} do
      # Start
      {running_loop, start_effects} = Runner.start(loop, agent, "Hello")

      assert {:emit_event, %Events.Started{message: "Hello"}} = Enum.at(start_effects, 0)
      assert {:call_llm, _, _} = Enum.at(start_effects, 1)

      # Response
      response = %LLM.Response{content: "World", usage: nil, raw: nil}
      {completed_loop, response_effects} = Runner.handle_llm_response(running_loop, response)

      assert {:emit_event, %Events.Completed{result: "World"}} = Enum.at(response_effects, 0)
      assert {:complete, "World"} = Enum.at(response_effects, 1)
      assert completed_loop.status == :completed
    end

    test "error path produces correct effect sequence", %{loop: loop, agent: agent} do
      # Start
      {running_loop, start_effects} = Runner.start(loop, agent, "Test")

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
    test "increments step number correctly", %{loop: loop, agent: agent} do
      {loop_after_start, _} = Runner.start(loop, agent, "Test")

      assert loop_after_start.current_step == 1
      assert length(loop_after_start.steps) == 1
      assert hd(loop_after_start.steps).number == 1
    end

    test "preserves loop configuration", %{loop: loop, agent: agent} do
      {updated_loop, _} = Runner.start(loop, agent, "Test")

      assert updated_loop.config == loop.config
      assert updated_loop.id == loop.id
    end
  end
end
