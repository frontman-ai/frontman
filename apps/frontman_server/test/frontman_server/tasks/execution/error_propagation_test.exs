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

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Providers
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction

  describe "LLM stream error propagation" do
    setup do
      pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
      on_exit(fn -> Sandbox.stop_owner(pid) end)

      scope = user_scope_fixture()
      task_id = task_with_pubsub_fixture(scope, framework: "nextjs").id

      {:ok, task_id: task_id, scope: scope}
    end

    @tag :capture_log
    test "LLM stream raise persists AgentError interaction via PubSub", %{
      task_id: task_id,
      scope: scope
    } do
      # The provider returns {:ok, stream} where the stream raises when
      # consumed — matching the real LLMClient behavior when ReqLLM emits an
      # error chunk (e.g., HTTP 400 for oversized images). The try/rescue in
      # execute_llm_call catches the raise and routes it through
      # Loop.handle_error → {:failed, ...} instead of crashing the process.
      expect_llm_responses([
        {:stream_raise, "LLM API error: image exceeds the maximum allowed size"}
      ])

      {:ok, _api_key} = Providers.upsert_api_key(scope, "openrouter", "sk-or-test")

      {:ok, _, _} = submit_user_message_and_run(scope, task_id, user_content("Take a screenshot"))

      # Stream errors are now caught and surfaced as graceful failures.
      assert_receive_interaction(%Interaction.AgentError{error: reason}, _turn_number)

      assert reason =~ "image exceeds the maximum allowed size"
    end

    @tag :capture_log
    test "LLM returning {:error, reason} persists AgentError interaction", %{
      task_id: task_id,
      scope: scope
    } do
      expect_llm_responses([{:error, :llm_api_failure}])

      {:ok, _api_key} = Providers.upsert_api_key(scope, "openrouter", "sk-or-test")

      {:ok, _, _} = submit_user_message_and_run(scope, task_id, user_content("Hello"))

      # Should receive a failed interaction broadcast.
      assert_receive_interaction(%Interaction.AgentError{kind: "failed"}, _turn_number)
    end
  end

  defp submit_user_message_and_run(scope, task_id, message, overrides \\ []) do
    execution_request = execution_request_fixture(overrides)

    case Tasks.submit_user_message(
           scope,
           Map.merge(execution_request, %{task_id: task_id, message: message})
         ) do
      {:ok, interaction} ->
        case Tasks.run_next_turn(scope, task_id, execution_request) do
          :ok ->
            {:ok, interaction, latest_turn_number(task_id)}

          result when result in [:already_running, :no_accepted_messages] ->
            {:error, result}

          result ->
            result
        end

      result ->
        result
    end
  end
end
