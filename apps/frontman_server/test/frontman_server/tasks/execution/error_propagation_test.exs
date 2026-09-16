defmodule FrontmanServer.Tasks.Execution.ErrorPropagationTest do
  @moduledoc """
  Integration test for the error propagation chain.

  Tests that LLM stream errors are caught by try/rescue in execute_llm_call
  and surfaced as graceful {:failed, ...} events (not {:crashed, ...}).

  This verifies that when an LLM API returns an error (e.g., HTTP 400 for
  oversized images), the error reaches the client as a clean error message
  instead of crashing the task process.
  """

  use FrontmanServer.ExecutionCase

  import FrontmanServer.InteractionCase.Helpers,
    only: [assert_receive_interaction: 2]

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  import FrontmanServer.DataCase, only: [setup_sandbox: 1]
  alias FrontmanServer.Tasks.Interaction

  describe "LLM stream error propagation" do
    setup [:setup_sandbox, :setup_user, :setup_task]

    @tag :capture_log
    test "LLM stream raise persists AgentError interaction via PubSub", %{
      task_id: task_id,
      scope: scope
    } do
      expect_llm_responses([
        {:stream_raise, "LLM API error: image exceeds the maximum allowed size"}
      ])

      {:ok, _, _} =
        submit_user_message_and_run(
          scope,
          task_id,
          execution_request_fixture(),
          user_content("Take a screenshot")
        )

      assert_receive_interaction(%Interaction.AgentError{error: reason}, _turn_number)

      assert reason =~ "image exceeds the maximum allowed size"
    end

    @tag :capture_log
    test "LLM returning {:error, reason} persists AgentError interaction", %{
      task_id: task_id,
      scope: scope
    } do
      expect_llm_responses([{:error, :llm_api_failure}])

      {:ok, _, _} =
        submit_user_message_and_run(
          scope,
          task_id,
          execution_request_fixture(),
          user_content("Hello")
        )

      assert_receive_interaction(%Interaction.AgentError{kind: "failed"}, _turn_number)
    end
  end
end
