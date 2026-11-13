defmodule FrontmanServer.ExecutionCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  import ExUnit.Assertions, only: [refute: 2]

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

  def refute_running_eventually(task_id), do: refute_running_eventually(task_id, 50)

  def refute_running_eventually(task_id, runtime) when is_atom(runtime),
    do: refute_running_eventually(task_id, runtime, 50)

  def refute_running_eventually(task_id, attempts) when is_integer(attempts),
    do: refute_running_eventually(task_id, FrontmanServer.AgentRuntime, attempts)

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

  def setup_execution_runtime(context) do
    owner = Sandbox.start_owner!(FrontmanServer.Repo, shared: false)
    on_exit(fn -> Sandbox.stop_owner(owner) end)
    runtime = FrontmanServer.PrivateExecutionRuntime.start!(context.module, owner)
    {:ok, runtime: runtime}
  end

  setup context do
    if context[:async] && !context[:private_runtime] do
      raise "Async execution tests require private_runtime: true"
    end

    if context[:private_runtime] do
      Mox.set_mox_private()
      Req.Test.set_req_test_to_private()
    else
      Mox.set_mox_global()
      Req.Test.set_req_test_to_shared()
      on_exit(fn -> Req.Test.set_req_test_to_private() end)
    end

    :ok
  end
end
