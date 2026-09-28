defmodule FrontmanServer.ExecutionCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  import ExUnit.Assertions, only: [refute: 2]

  alias FrontmanServer.Tasks
  alias FrontmanServer.Test.Fixtures.Tasks, as: TaskFixtures

  using do
    quote do
      use SwarmAi.Testing, async: false
      import FrontmanServer.ExecutionCase
      import FrontmanServer.Test.Fixtures.LLMProvider
    end
  end

  def submit_user_message_and_run(scope, task_id, execution_request, message) do
    with {:ok, interaction} <-
           Tasks.submit_user_message(
             scope,
             Map.merge(execution_request, %{
               task_id: task_id,
               message_id: Ecto.UUID.generate(),
               message: message
             })
           ),
         :ok <- Tasks.execute_next_turn(scope, task_id, execution_request) do
      {:ok, interaction, TaskFixtures.latest_turn_number(task_id)}
    else
      result when result in [:already_running, :no_accepted_messages] -> {:error, result}
      result -> result
    end
  end

  def refute_running_eventually(task_id, attempts \\ 50)

  def refute_running_eventually(task_id, 0) do
    refute SwarmAi.running?(FrontmanServer.AgentRuntime, task_id),
           "Agent should not be running after completion"
  end

  def refute_running_eventually(task_id, attempts) when attempts > 0 do
    case SwarmAi.running?(FrontmanServer.AgentRuntime, task_id) do
      false ->
        :ok

      true ->
        Process.sleep(10)
        refute_running_eventually(task_id, attempts - 1)
    end
  end

  setup do
    Mox.set_mox_global()

    Req.Test.set_req_test_to_shared()

    on_exit(fn ->
      Req.Test.set_req_test_to_private()
    end)

    :ok
  end
end
