defmodule FrontmanServer.Agents.AgentServerTest do
  @moduledoc """
  Tests for AgentServer GenServer.

  LLM interactions use VCR-style fixtures. To record new fixtures:

      REQ_LLM_FIXTURES_MODE=record mix test
  """
  use FrontmanServer.AgentCase, async: false

  describe "basic LLM interaction" do
    @tag fixtures: [:parent_agent]
    test "agent responds to simple message", %{parent_agent: %{pid: pid, id: agent_id}} do
      # Build a simple user message
      messages = [
        ReqLLM.Context.user("Say hello in exactly 3 words.")
      ]

      # Execute the iteration
      send(pid, {:execute_iteration, messages})

      # Should receive tokens as they stream
      assert_receive {:event, {:token, ^agent_id, _text}}, 10_000

      # Should receive a complete response
      assert_receive {:event, {:response, ^agent_id, text, _meta}}, 15_000
      assert is_binary(text)
      assert byte_size(text) > 0
    end
  end
end
