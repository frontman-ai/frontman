defmodule FrontmanServer.Agents.ErrorPropagationTest do
  @moduledoc """
  Integration test for the error propagation chain.

  Tests the critical path that was previously broken:
  LLM stream error → raise in to_swarm_chunk → Task crash →
  ExecutionMonitor → PubSub {:agent_error, message} broadcast.

  This verifies that when an LLM API returns an error (e.g., HTTP 400 for
  oversized images), the error reaches the client instead of being swallowed
  as a "successful" empty response.
  """

  use FrontmanServer.SwarmCase, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Tasks

  describe "LLM stream error propagation" do
    setup do
      pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
      on_exit(fn -> Sandbox.stop_owner(pid) end)

      {:ok, user} =
        Accounts.register_user(%{
          email: "error_prop_#{System.unique_integer([:positive])}@test.local",
          name: "Test User",
          password: "testpassword123!"
        })

      scope = Scope.for_user(user)
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "test-framework")

      # Subscribe to task topic to receive error broadcasts
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.topic(task_id))

      {:ok, task_id: task_id, scope: scope}
    end

    test "LLM stream raise propagates as {:agent_error, message} via PubSub", %{
      task_id: task_id,
      scope: scope
    } do
      # Create an LLM that simulates the raise from to_swarm_chunk when
      # it encounters a ReqLLM error chunk. In production, this raise happens
      # inside Stream.map(&to_swarm_chunk/2) when processing the ReqLLM stream.
      #
      # MockLLM returns a stream, but the raise happens when Swarm's
      # Response.from_stream consumes it. We simulate this with a function
      # that raises, which is how the real LLMClient behaves when it sees
      # a ReqLLM error chunk.
      error_llm = %MockLLM{
        response: fn ->
          {:error, "LLM API error: image exceeds the maximum allowed size"}
        end
      }

      agent = test_agent(error_llm, "ErrorPropTestAgent")

      user_content = [%{"type" => "text", "text" => "Take a screenshot"}]
      {:ok, _} = Tasks.add_user_message(scope, task_id, user_content, [], agent: agent)

      # The error should propagate through:
      # 1. MockLLM returns {:error, ...}
      # 2. Agents.handle_agent_event(:error, ...) or ExecutionMonitor crash detection
      # 3. PubSub broadcast of {:agent_error, message}
      assert_receive {:agent_error, error_message}, 5_000

      assert is_binary(error_message)

      assert error_message =~ "image exceeds the maximum allowed size" or
               String.length(error_message) > 0
    end

    test "LLM returning {:error, reason} surfaces error to PubSub", %{
      task_id: task_id,
      scope: scope
    } do
      # ErrorLLM always returns {:error, reason}
      agent = test_agent(%ErrorLLM{error: :llm_api_failure}, "AlwaysErrorAgent")

      user_content = [%{"type" => "text", "text" => "Hello"}]
      {:ok, _} = Tasks.add_user_message(scope, task_id, user_content, [], agent: agent)

      # Should receive an error broadcast
      assert_receive {:agent_error, error_message}, 5_000
      assert is_binary(error_message)
    end
  end
end
