defmodule FrontmanServer.Tasks.Execution.ErrorPropagationTest do
  @moduledoc """
  Integration test for the error propagation chain.

  Tests that LLM stream errors are caught by try/rescue in execute_llm_call
  and surfaced as graceful {:failed, ...} events (not {:crashed, ...}).

  This verifies that when an LLM API returns an error (e.g., HTTP 400 for
  oversized images), the error reaches the client as a clean error message
  instead of crashing the task process.
  """

  use SwarmAi.Testing, async: false

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

    test "LLM stream raise propagates as {:swarm_event, {:failed, ...}} via PubSub", %{
      task_id: task_id,
      scope: scope
    } do
      # StreamErrorLLM returns {:ok, stream} where the stream raises when
      # consumed — matching the real LLMClient behavior when ReqLLM emits an
      # error chunk (e.g., HTTP 400 for oversized images). The try/rescue in
      # execute_llm_call catches the raise and routes it through
      # Loop.handle_error → {:failed, ...} instead of crashing the process.
      error_llm = %StreamErrorLLM{
        error_message: "LLM API error: image exceeds the maximum allowed size"
      }

      agent = test_agent(error_llm, "ErrorPropTestAgent")

      user_content = [%{"type" => "text", "text" => "Take a screenshot"}]

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content, [],
          agent: agent,
          env_api_key: %{"openrouter" => "sk-or-test"}
        )

      # Stream errors are now caught and surfaced as graceful failures
      assert_receive {:swarm_event, {:failed, {:error, reason, _loop_id}}}, 5_000
      assert Exception.message(reason) =~ "image exceeds the maximum allowed size"
    end

    test "LLM returning {:error, reason} surfaces as {:swarm_event, {:failed, ...}}", %{
      task_id: task_id,
      scope: scope
    } do
      # ErrorLLM always returns {:error, reason}
      agent = test_agent(%ErrorLLM{error: :llm_api_failure}, "AlwaysErrorAgent")

      user_content = [%{"type" => "text", "text" => "Hello"}]

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content, [],
          agent: agent,
          env_api_key: %{"openrouter" => "sk-or-test"}
        )

      # Should receive a failed event broadcast
      assert_receive {:swarm_event, {:failed, {:error, _reason, _loop_id}}}, 5_000
    end
  end
end
