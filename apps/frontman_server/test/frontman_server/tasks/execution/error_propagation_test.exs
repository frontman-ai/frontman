defmodule FrontmanServer.Tasks.Execution.ErrorPropagationTest do
  @moduledoc "Verifies startup and provider failures reach storage and clients as terminal errors."

  use FrontmanServer.ExecutionCase, async: true

  import FrontmanServer.InteractionCase.Helpers,
    only: [assert_receive_interaction: 2]

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.{Repo, Tasks}
  alias FrontmanServer.Tasks.{Interaction, InteractionSchema}
  alias ReqLLM.Error.API.{Request, Stream}

  describe "LLM stream error propagation" do
    @describetag billing: :active
    @describetag private_runtime: true
    setup [:setup_execution_runtime, :setup_user, :setup_task]

    test "LLM stream raise persists AgentError interaction via PubSub", %{
      task_id: task_id,
      scope: scope,
      runtime: runtime
    } do
      expect_llm_responses([
        {:stream_raise, "LLM API error: image exceeds the maximum allowed size"}
      ])

      {:ok, _, _} =
        submit_user_message_and_run(
          scope,
          task_id,
          %{
            execution: execution_request_fixture(),
            message: user_content("Take a screenshot"),
            runtime: runtime
          }
        )

      assert_receive_interaction(%Interaction.AgentError{error: reason}, _turn_number)
      refute_running_eventually(task_id, runtime)

      assert reason =~ "image exceeds the maximum allowed size"
    end

    test "removed models are rejected before a turn is recorded", %{
      task_id: task_id,
      scope: scope,
      runtime: runtime
    } do
      assert {:error, :unknown_model} =
               submit_user_message_and_run(
                 scope,
                 task_id,
                 %{
                   execution: execution_request_fixture(model: "openai_codex:gpt-5.4-mini"),
                   message: user_content("Hello"),
                   runtime: runtime
                 }
               )

      refute Repo.get_by(InteractionSchema, task_id: task_id, type: :turn_started)
    end

    for delivery <- [:error, :stream_raise] do
      test "#{delivery} preserves safe, non-retryable model guidance in storage and PubSub", %{
        task_id: task_id,
        scope: scope,
        runtime: runtime
      } do
        request =
          Request.exception(
            status: 400,
            provider_code: "model_not_found",
            reason:
              "The 'gpt-6-astra' model is not supported when using Codex with a ChatGPT account.",
            response_body: %{
              "code" => "model_not_found",
              "message" =>
                "The 'gpt-6-astra' model is not supported when using Codex with a ChatGPT account.",
              "type" => "invalid_request_error"
            }
          )

        failure =
          case unquote(delivery) do
            :error -> request
            :stream_raise -> Stream.exception(cause: request, reason: "HTTP 400")
          end

        expect_llm_responses([{unquote(delivery), failure}])

        {:ok, _, _} =
          submit_user_message_and_run(
            scope,
            task_id,
            %{
              execution: execution_request_fixture(),
              message: user_content("Hello"),
              runtime: runtime
            }
          )

        assert_receive_interaction(%Interaction.AgentError{} = error, _turn_number)
        refute_running_eventually(task_id, runtime)

        assert %Interaction.AgentError{
                 kind: "failed",
                 category: "model_unavailable",
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
