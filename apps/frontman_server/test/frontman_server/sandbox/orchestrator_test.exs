defmodule FrontmanServer.Sandbox.OrchestratorTest do
  use FrontmanServer.DataCase

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Sandboxes

  alias FrontmanServer.Sandbox.{Orchestrator, SandboxSchema}
  alias FrontmanServer.Sandboxes
  alias FrontmanServer.Test.Support.Sandbox.IntegrationProvider

  setup do
    IntegrationProvider.reset!()

    scope = user_scope_fixture()
    task = task_with_project_fixture(scope)

    {:ok, sandbox} = Sandboxes.provision_for_task(scope, task, valid_env_spec())

    on_exit(fn ->
      IntegrationProvider.reset!()

      case Registry.lookup(FrontmanServer.Sandbox.Registry, sandbox.id) do
        [{pid, _}] ->
          if Process.alive?(pid) do
            _ = safe_stop(pid)
          end

          :ok

        [] ->
          :ok
      end
    end)

    %{sandbox: sandbox, scope: scope, task: task}
  end

  describe "provisioning" do
    test "transitions to running and stores provider_ref", %{sandbox: sandbox} do
      {:ok, pid} =
        start_orchestrator(sandbox.id,
          provider: IntegrationProvider,
          heartbeat_interval_ms: 10,
          provision_timeout_ms: 5_000
        )

      assert_eventually(fn ->
        persisted = Repo.get!(SandboxSchema, sandbox.id)
        persisted.status == :running and is_binary(persisted.provider_ref)
      end)

      assert Process.alive?(pid)
    end

    test "transitions to error when provider.create fails", %{sandbox: sandbox} do
      sandbox = put_env_overrides(sandbox, %{"create_error" => "true"})

      {:ok, pid} =
        start_orchestrator(sandbox.id,
          provider: IntegrationProvider,
          heartbeat_interval_ms: 10,
          provision_timeout_ms: 5_000
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000

      assert Repo.get!(SandboxSchema, sandbox.id).status == :error
    end

    test "transitions to error on provisioning timeout", %{sandbox: sandbox} do
      sandbox = put_env_overrides(sandbox, %{"initial_running" => "false"})

      {:ok, pid} =
        start_orchestrator(sandbox.id,
          provider: IntegrationProvider,
          heartbeat_interval_ms: 10,
          provision_timeout_ms: 50
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000

      assert Repo.get!(SandboxSchema, sandbox.id).status == :error
    end
  end

  describe "heartbeat behavior" do
    test "detects VM crash and transitions to error", %{sandbox: sandbox} do
      {:ok, pid} =
        start_orchestrator(sandbox.id,
          provider: IntegrationProvider,
          heartbeat_interval_ms: 10,
          provision_timeout_ms: 5_000
        )

      assert_eventually(fn ->
        Repo.get!(SandboxSchema, sandbox.id).status == :running
      end)

      provider_ref = wait_for_provider_ref(sandbox.id)
      ref = Process.monitor(pid)

      :ok = IntegrationProvider.set_running(provider_ref, false)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000

      assert Repo.get!(SandboxSchema, sandbox.id).status == :error
    end

    test "survives metrics errors and retries", %{sandbox: sandbox} do
      {:ok, pid} =
        start_orchestrator(sandbox.id,
          provider: IntegrationProvider,
          heartbeat_interval_ms: 10,
          provision_timeout_ms: 5_000
        )

      assert_eventually(fn ->
        Repo.get!(SandboxSchema, sandbox.id).status == :running
      end)

      provider_ref = wait_for_provider_ref(sandbox.id)

      :ok = IntegrationProvider.set_metrics_error(provider_ref, :econnrefused)
      Process.sleep(40)
      assert Process.alive?(pid)

      :ok = IntegrationProvider.set_metrics_error(provider_ref, nil)
      Process.sleep(40)
      assert Process.alive?(pid)
    end
  end

  describe "exec" do
    test "delegates to provider and returns result", %{sandbox: sandbox} do
      sandbox = put_env_overrides(sandbox, %{"exec_stdout" => "hello\n", "exec_exit_code" => "0"})

      {:ok, _pid} =
        start_orchestrator(sandbox.id,
          provider: IntegrationProvider,
          heartbeat_interval_ms: 50,
          provision_timeout_ms: 5_000
        )

      assert_eventually(fn ->
        Repo.get!(SandboxSchema, sandbox.id).status == :running
      end)

      assert {:ok, %{exit_code: 0, stdout: "hello\n"}} =
               Orchestrator.exec(sandbox.id, "echo", ["hello"])
    end

    test "returns {:error, :not_ready} when still provisioning", %{sandbox: sandbox} do
      sandbox = put_env_overrides(sandbox, %{"initial_running" => "false"})

      {:ok, _pid} =
        start_orchestrator(sandbox.id,
          provider: IntegrationProvider,
          heartbeat_interval_ms: 1_000,
          provision_timeout_ms: 60_000
        )

      assert {:error, :not_ready} = Orchestrator.exec(sandbox.id, "echo", ["hello"])
    end

    test "returns task_start_failed when task supervisor is unavailable", %{sandbox: sandbox} do
      {:ok, _pid} =
        start_orchestrator(sandbox.id,
          provider: IntegrationProvider,
          task_supervisor: FrontmanServer.Sandbox.MissingTaskSupervisor,
          heartbeat_interval_ms: 10,
          provision_timeout_ms: 5_000
        )

      assert_eventually(fn ->
        Repo.get!(SandboxSchema, sandbox.id).status == :running
      end)

      assert {:error, {:task_start_failed, _reason}} =
               Orchestrator.exec(sandbox.id, "echo", ["hello"])
    end

    test "returns timeout instead of crashing when blocked in provision", %{sandbox: sandbox} do
      sandbox = put_env_overrides(sandbox, %{"create_delay_ms" => "6000"})

      {:ok, _pid} =
        start_orchestrator(sandbox.id,
          provider: IntegrationProvider,
          heartbeat_interval_ms: 50,
          provision_timeout_ms: 10_000
        )

      assert {:error, :timeout} = Orchestrator.status(sandbox.id)
    end
  end

  describe "lifecycle commands" do
    test "stop updates DB and terminates", %{sandbox: sandbox} do
      {:ok, pid} =
        start_orchestrator(sandbox.id,
          provider: IntegrationProvider,
          heartbeat_interval_ms: 50,
          provision_timeout_ms: 5_000
        )

      assert_eventually(fn ->
        Repo.get!(SandboxSchema, sandbox.id).status == :running
      end)

      ref = Process.monitor(pid)

      assert :ok = Orchestrator.stop(sandbox.id)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000
      assert Repo.get!(SandboxSchema, sandbox.id).status == :stopped
    end

    test "destroy deletes DB record and terminates", %{sandbox: sandbox} do
      {:ok, pid} =
        start_orchestrator(sandbox.id,
          provider: IntegrationProvider,
          heartbeat_interval_ms: 50,
          provision_timeout_ms: 5_000
        )

      assert_eventually(fn ->
        Repo.get!(SandboxSchema, sandbox.id).status == :running
      end)

      ref = Process.monitor(pid)

      assert :ok = Orchestrator.destroy(sandbox.id)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000
      assert Repo.get(SandboxSchema, sandbox.id) == nil
    end
  end

  # --- Helpers ---

  defp start_orchestrator(sandbox_id, opts) do
    Orchestrator.start_link(Keyword.merge([sandbox_id: sandbox_id], opts))
  end

  defp put_env_overrides(sandbox, env_overrides) do
    env_spec =
      sandbox.env_spec
      |> Map.update("env", env_overrides, &Map.merge(&1, env_overrides))

    sandbox
    |> Ecto.Changeset.change(env_spec: env_spec)
    |> Repo.update!()
  end

  defp wait_for_provider_ref(sandbox_id, timeout \\ 1_000, interval \\ 10) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_wait_for_provider_ref(sandbox_id, deadline, interval)
  end

  defp do_wait_for_provider_ref(sandbox_id, deadline, interval) do
    provider_ref = Repo.get!(SandboxSchema, sandbox_id).provider_ref

    if is_binary(provider_ref) do
      provider_ref
    else
      if System.monotonic_time(:millisecond) >= deadline do
        flunk("wait_for_provider_ref timed out")
      else
        Process.sleep(interval)
        do_wait_for_provider_ref(sandbox_id, deadline, interval)
      end
    end
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

  defp safe_stop(pid) do
    GenServer.stop(pid, :normal, 10_000)
  catch
    :exit, {:timeout, _} ->
      Process.exit(pid, :normal)
      :ok

    :exit, {:noproc, _} ->
      :ok

    :exit, :noproc ->
      :ok
  end
end
