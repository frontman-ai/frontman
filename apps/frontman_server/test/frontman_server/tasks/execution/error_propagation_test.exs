defmodule FrontmanServer.Tasks.Execution.ErrorPropagationTest do
  @moduledoc "Verifies startup and provider failures reach storage and clients as terminal errors."

  use FrontmanServer.ExecutionCase

  import FrontmanServer.InteractionCase.Helpers,
    only: [assert_receive_interaction: 2]

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  import FrontmanServer.DataCase, only: [setup_sandbox: 1]
  alias FrontmanServer.{Repo, Tasks}
  alias FrontmanServer.Tasks.{Interaction, InteractionSchema}
  alias ReqLLM.Error.API.{Request, Stream}

  describe "LLM stream error propagation" do
    @describetag billing: :active
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

    for delivery <- [:error, :stream_raise, :removed_model] do
      @tag :capture_log
      test "#{delivery} preserves safe, non-retryable model guidance in storage and PubSub", %{
        task_id: task_id,
        scope: scope
      } do
        request =
          Request.exception(
            status: 400,
            reason: "HTTP 400",
            response_body: %{
              "detail" =>
                "The 'gpt-5.4-mini' model is not supported when using Codex with a ChatGPT account."
            }
          )

        execution =
          case unquote(delivery) do
            :removed_model ->
              execution_request_fixture(model: "openai_codex:gpt-5.4-mini")

            delivery ->
              failure =
                case delivery do
                  :error ->
                    request

                  :stream_raise ->
                    Stream.exception(cause: request, reason: "HTTP 400")
                end

              expect_llm_responses([{delivery, failure}])
              execution_request_fixture()
          end

        {:ok, _, _} =
          submit_user_message_and_run(
            scope,
            task_id,
            execution,
            user_content("Hello")
          )

        assert_receive_interaction(%Interaction.AgentError{} = error, _turn_number)

        assert %Interaction.AgentError{
                 kind: "failed",
                 category: "unknown",
                 retryable: false,
                 error:
                   "This model is unavailable for your connection. Select another model and send a new message."
               } = error

        assert Repo.get_by!(InteractionSchema,
                 task_id: task_id,
                 type: :agent_error
               ).data == error

        assert {:ok, :no_active_turn} =
                 Tasks.get_active_turn_unresolved_tool_calls(scope, task_id)
      end
    end
  end
end
