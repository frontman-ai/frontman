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

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.ExecutionEvent

  describe "LLM stream error propagation" do
    setup do
      pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
      on_exit(fn -> Sandbox.stop_owner(pid) end)

      scope = user_scope_fixture()
      task_id = task_with_pubsub_fixture(scope, framework: "nextjs")

      {:ok, task_id: task_id, scope: scope}
    end

    @tag :capture_log
    test "LLM stream raise propagates as ExecutionEvent{type: :failed} via PubSub", %{
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

      scope = Scope.with_env_api_keys(scope, %{"openrouter" => "sk-or-test"})

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Take a screenshot"), [],
          agent: agent
        )

      # Stream errors are now caught and surfaced as graceful failures
      assert_receive {:execution_event,
                      %ExecutionEvent{type: :failed, payload: {:error, reason, _loop_id}}},
                     5_000

      assert Exception.message(reason) =~ "image exceeds the maximum allowed size"
    end

    @tag :capture_log
    test "LLM returning {:error, reason} surfaces as ExecutionEvent{type: :failed}", %{
      task_id: task_id,
      scope: scope
    } do
      # ErrorLLM always returns {:error, reason}
      agent = test_agent(%ErrorLLM{error: :llm_api_failure}, "AlwaysErrorAgent")

      scope = Scope.with_env_api_keys(scope, %{"openrouter" => "sk-or-test"})

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Hello"), [], agent: agent)

      # Should receive a failed event broadcast
      assert_receive {:execution_event,
                      %ExecutionEvent{type: :failed, payload: {:error, _reason, _loop_id}}},
                     5_000
    end
  end
end
