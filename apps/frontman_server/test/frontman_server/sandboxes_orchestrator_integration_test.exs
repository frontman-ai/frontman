defmodule FrontmanServer.SandboxesOrchestratorIntegrationTest do
  @moduledoc """
  Higher-fidelity integration tests for Sandboxes + Orchestrator lifecycle.

  Uses a concrete test provider module instead of Mox expectations to keep
  behavior close to production orchestration.
  """

  use FrontmanServer.DataCase

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Sandboxes

  alias FrontmanServer.Sandbox.SandboxSchema
  alias FrontmanServer.Sandboxes
  alias FrontmanServer.Test.Support.Sandbox.IntegrationProvider

  setup do
    scope = user_scope_fixture()
    task = task_with_project_fixture(scope)

    IntegrationProvider.reset!()

    on_exit(fn ->
      IntegrationProvider.reset!()

      DynamicSupervisor.which_children(FrontmanServer.Sandbox.DynamicSupervisor)
      |> Enum.each(fn {_, pid, _, _} ->
        if is_pid(pid) and Process.alive?(pid) do
          Process.exit(pid, :kill)
        end
      end)
    end)

    %{scope: scope, task: task}
  end

  test "rebuilds persisted env_spec into EnvironmentSpec before provider.create", %{
    scope: scope,
    task: task
  } do
    assert {:ok, sandbox} =
             Sandboxes.provision_and_start(scope, unique_env_spec(),
               task_id: task.id,
               provider: IntegrationProvider,
               heartbeat_interval_ms: 10,
               provision_timeout_ms: 5_000
             )

    assert_eventually(fn ->
      Repo.get!(SandboxSchema, sandbox.id).status == :running
    end)

    assert {:ok, %{exit_code: 0, stdout: "ok\n"}} =
             Sandboxes.exec(scope, sandbox.id, "echo", ["hello"])
  end

  test "marks sandbox as error when provider.create fails", %{scope: scope, task: task} do
    assert {:ok, sandbox} =
             Sandboxes.provision_and_start(scope, unique_env_spec(%{"create_error" => "true"}),
               task_id: task.id,
               provider: IntegrationProvider,
               heartbeat_interval_ms: 10,
               provision_timeout_ms: 5_000
             )

    assert_eventually(fn ->
      Repo.get!(SandboxSchema, sandbox.id).status == :error
    end)
  end

  test "provisioning work runs asynchronously after init", %{scope: scope, task: task} do
    delayed_env_spec =
      unique_env_spec(%{
        "create_delay_ms" => "500"
      })

    started_at = System.monotonic_time(:millisecond)

    assert {:ok, sandbox} =
             Sandboxes.provision_and_start(scope, delayed_env_spec,
               task_id: task.id,
               provider: IntegrationProvider,
               heartbeat_interval_ms: 10,
               provision_timeout_ms: 5_000
             )

    elapsed_ms = System.monotonic_time(:millisecond) - started_at
    assert elapsed_ms < 250

    assert_eventually(
      fn ->
        Repo.get!(SandboxSchema, sandbox.id).status == :running
      end,
      2_000
    )
  end

  test "returns task_start_failed when task supervisor cannot start exec task", %{
    scope: scope,
    task: task
  } do
    assert {:ok, sandbox} =
             Sandboxes.provision_and_start(scope, unique_env_spec(),
               task_id: task.id,
               provider: IntegrationProvider,
               task_supervisor: FrontmanServer.Sandbox.MissingTaskSupervisor,
               heartbeat_interval_ms: 10,
               provision_timeout_ms: 5_000
             )

    assert_eventually(fn ->
      Repo.get!(SandboxSchema, sandbox.id).status == :running
    end)

    assert {:error, {:task_start_failed, _reason}} =
             Sandboxes.exec(scope, sandbox.id, "echo", ["hello"])
  end

  test "returns orchestrator_not_running when sandbox row exists but process is gone", %{
    scope: scope,
    task: task
  } do
    assert {:ok, sandbox} =
             Sandboxes.provision_and_start(scope, unique_env_spec(),
               task_id: task.id,
               provider: IntegrationProvider,
               heartbeat_interval_ms: 10,
               provision_timeout_ms: 5_000
             )

    assert_eventually(fn ->
      Repo.get!(SandboxSchema, sandbox.id).status == :running
    end)

    assert :ok = Sandboxes.stop_sandbox(scope, sandbox.id)

    assert {:error, :orchestrator_not_running} =
             Sandboxes.exec(scope, sandbox.id, "echo", ["hello"])

    assert {:error, :orchestrator_not_running} = Sandboxes.stop_sandbox(scope, sandbox.id)
  end

  test "stop_sandbox routes stop through orchestrator and updates status", %{
    scope: scope,
    task: task
  } do
    assert {:ok, sandbox} =
             Sandboxes.provision_and_start(scope, unique_env_spec(),
               task_id: task.id,
               provider: IntegrationProvider,
               heartbeat_interval_ms: 10,
               provision_timeout_ms: 5_000
             )

    assert_eventually(fn ->
      Repo.get!(SandboxSchema, sandbox.id).status == :running
    end)

    assert :ok = Sandboxes.stop_sandbox(scope, sandbox.id)
    assert Repo.get!(SandboxSchema, sandbox.id).status == :stopped
  end

  test "destroy_sandbox routes destroy through orchestrator and deletes row", %{
    scope: scope,
    task: task
  } do
    assert {:ok, sandbox} =
             Sandboxes.provision_and_start(scope, unique_env_spec(),
               task_id: task.id,
               provider: IntegrationProvider,
               heartbeat_interval_ms: 10,
               provision_timeout_ms: 5_000
             )

    assert_eventually(fn ->
      Repo.get!(SandboxSchema, sandbox.id).status == :running
    end)

    assert :ok = Sandboxes.destroy_sandbox(scope, sandbox.id)
    assert Repo.get(SandboxSchema, sandbox.id) == nil
  end

  defp unique_env_spec(env_overrides \\ %{}) do
    env_spec = valid_env_spec()
    existing_env = Map.get(env_spec, "env", %{})

    env_spec
    |> Map.put("name", "integration-sandbox-#{System.unique_integer([:positive])}")
    |> Map.put("env", Map.merge(existing_env, env_overrides))
  end

  defp assert_eventually(fun, timeout \\ 1_000, interval \\ 10) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_assert_eventually(fun, deadline, interval)
  end

  defp do_assert_eventually(fun, deadline, interval) do
    if fun.() do
      true
    else
      if System.monotonic_time(:millisecond) >= deadline do
        flunk("assert_eventually timed out")
      else
        Process.sleep(interval)
        do_assert_eventually(fun, deadline, interval)
      end
    end
  end
end
