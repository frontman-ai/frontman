defmodule FrontmanServer.ExecutionCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  import ExUnit.Assertions, only: [assert: 1, refute: 2]

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Tasks
  alias FrontmanServer.Test.Fixtures.Tasks, as: TaskFixtures

  using opts do
    quote do
      use SwarmAi.Testing, async: unquote(Keyword.get(opts, :async, false))
      import FrontmanServer.ExecutionCase
      import FrontmanServer.Test.Fixtures.LLMProvider
    end
  end

  def submit_user_message_and_run(scope, task_id, %{
        execution: execution_request,
        message: message,
        runtime: runtime
      }) do
    with {:ok, interaction} <-
           Tasks.submit_user_message(
             scope,
             Map.merge(execution_request, %{
               task_id: task_id,
               message_id: Ecto.UUID.generate(),
               message: message
             })
           ),
         :ok <-
           Tasks.execute_next_turn(scope, task_id, %{
             execution: execution_request,
             runtime: runtime
           }) do
      {:ok, interaction, TaskFixtures.latest_turn_number(task_id)}
    else
      result when result in [:already_running, :no_accepted_messages] -> {:error, result}
      result -> result
    end
  end

  def refute_running_eventually(task_id, runtime \\ FrontmanServer.AgentRuntime, attempts \\ 50)

  def refute_running_eventually(task_id, runtime, 0) do
    refute SwarmAi.running?(runtime, task_id),
           "Agent should not be running after completion"
  end

  def refute_running_eventually(task_id, runtime, attempts) when attempts > 0 do
    case SwarmAi.running?(runtime, task_id) do
      false ->
        :ok

      true ->
        Process.sleep(10)
        refute_running_eventually(task_id, runtime, attempts - 1)
    end
  end

  def assert_active_count(runtime, expected, attempts \\ 50)

  def assert_active_count(runtime, expected, 0) do
    assert SwarmAi.active_count(runtime) == expected
  end

  def assert_active_count(runtime, expected, attempts) when attempts > 0 do
    case SwarmAi.active_count(runtime) do
      ^expected ->
        :ok

      _count ->
        Process.sleep(10)
        assert_active_count(runtime, expected, attempts - 1)
    end
  end

  setup context do
    Mox.set_mox_from_context(context)
    Req.Test.set_req_test_from_context(context)

    if context[:async] do
      owner = Sandbox.start_owner!(FrontmanServer.Repo, shared: false)
      on_exit(fn -> Sandbox.stop_owner(owner) end)
      runtime = FrontmanServer.PrivateExecutionRuntime.start!(context.module, owner)
      {:ok, runtime: runtime}
    else
      on_exit(fn -> Req.Test.set_req_test_to_private() end)
      :ok
    end
  end
end
