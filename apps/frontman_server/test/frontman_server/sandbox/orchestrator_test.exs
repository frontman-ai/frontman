defmodule FrontmanServer.Sandbox.OrchestratorTest do
  use FrontmanServer.DataCase

  import Mox
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Sandboxes

  alias FrontmanServer.Sandbox.{Orchestrator, SandboxSchema}
  alias FrontmanServer.Sandboxes

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    scope = user_scope_fixture()
    task = task_with_project_fixture(scope)

    {:ok, sandbox} = Sandboxes.provision_for_task(scope, task, valid_env_spec())

    on_exit(fn ->
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

  describe "provisioning happy path" do
    test "transitions from provisioning to running when provider reports ready", %{
      sandbox: sandbox
    } do
      MockProvider
      |> expect(:create, fn _env_spec -> {:ok, "msb-ref-123"} end)
      |> expect(:metrics, fn "msb-ref-123" -> {:ok, %{running: true}} end)
      |> stub(:metrics, fn "msb-ref-123" -> {:ok, %{running: true}} end)

      {:ok, pid} =
        start_orchestrator(sandbox.id,
          provider: MockProvider,
          heartbeat_interval_ms: 10,
          provision_timeout_ms: 5_000
        )

      assert_eventually(fn ->
        Repo.get!(SandboxSchema, sandbox.id).status == :running
      end)

      assert Process.alive?(pid)
    end

    test "stores provider_ref on sandbox after create", %{sandbox: sandbox} do
      MockProvider
      |> expect(:create, fn _env_spec -> {:ok, "msb-ref-456"} end)
      |> stub(:metrics, fn "msb-ref-456" -> {:ok, %{running: true}} end)

      {:ok, _pid} =
        start_orchestrator(sandbox.id,
          provider: MockProvider,
          heartbeat_interval_ms: 10,
          provision_timeout_ms: 5_000
        )

      assert_eventually(fn ->
        Repo.get!(SandboxSchema, sandbox.id).provider_ref == "msb-ref-456"
      end)
    end
  end

  describe "provisioning failure" do
    test "transitions to error when provider.create fails", %{sandbox: sandbox} do
      MockProvider
      |> expect(:create, fn _env_spec -> {:error, :image_not_found} end)

      assert {:error, :normal} =
               start_orchestrator(sandbox.id,
                 provider: MockProvider,
                 heartbeat_interval_ms: 10,
                 provision_timeout_ms: 5_000
               )

      assert Repo.get!(SandboxSchema, sandbox.id).status == :error
    end

    test "transitions to error on provisioning timeout", %{sandbox: sandbox} do
      MockProvider
      |> expect(:create, fn _env_spec -> {:ok, "msb-ref-slow"} end)
      |> stub(:metrics, fn "msb-ref-slow" -> {:ok, %{running: false}} end)

      {:ok, pid} =
        start_orchestrator(sandbox.id,
          provider: MockProvider,
          heartbeat_interval_ms: 10,
          provision_timeout_ms: 50
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000

      assert Repo.get!(SandboxSchema, sandbox.id).status == :error
    end
  end

  describe "running state" do
    test "detects VM crash via heartbeat and transitions to error", %{sandbox: sandbox} do
      MockProvider
      |> expect(:create, fn _env_spec -> {:ok, "msb-ref-crash"} end)
      |> expect(:metrics, fn "msb-ref-crash" -> {:ok, %{running: true}} end)
      |> expect(:metrics, fn "msb-ref-crash" -> {:ok, %{running: false}} end)

      {:ok, pid} =
        start_orchestrator(sandbox.id,
          provider: MockProvider,
          heartbeat_interval_ms: 10,
          provision_timeout_ms: 5_000
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000

      assert Repo.get!(SandboxSchema, sandbox.id).status == :error
    end

    test "survives daemon unreachability and retries", %{sandbox: sandbox} do
      MockProvider
      |> expect(:create, fn _env_spec -> {:ok, "msb-ref-flaky"} end)
      |> expect(:metrics, fn "msb-ref-flaky" -> {:ok, %{running: true}} end)
      |> expect(:metrics, fn "msb-ref-flaky" -> {:error, :econnrefused} end)
      |> expect(:metrics, fn "msb-ref-flaky" -> {:ok, %{running: true}} end)
      |> stub(:metrics, fn "msb-ref-flaky" -> {:ok, %{running: true}} end)

      {:ok, pid} =
        start_orchestrator(sandbox.id,
          provider: MockProvider,
          heartbeat_interval_ms: 10,
          provision_timeout_ms: 5_000
        )

      # Wait long enough for 3+ heartbeats
      Process.sleep(80)

      assert Process.alive?(pid)
    end
  end

  describe "exec" do
    test "delegates to provider and returns result", %{sandbox: sandbox} do
      MockProvider
      |> expect(:create, fn _env_spec -> {:ok, "msb-ref-exec"} end)
      |> expect(:metrics, fn "msb-ref-exec" -> {:ok, %{running: true}} end)
      |> stub(:metrics, fn "msb-ref-exec" -> {:ok, %{running: true}} end)
      |> expect(:exec, fn "msb-ref-exec", "echo", ["hello"], [] ->
        {:ok, %{exit_code: 0, stdout: "hello\n", stderr: ""}}
      end)

      {:ok, _pid} =
        start_orchestrator(sandbox.id,
          provider: MockProvider,
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
      MockProvider
      |> expect(:create, fn _env_spec -> {:ok, "msb-ref-notready"} end)
      |> stub(:metrics, fn "msb-ref-notready" -> {:ok, %{running: false}} end)

      {:ok, _pid} =
        start_orchestrator(sandbox.id,
          provider: MockProvider,
          heartbeat_interval_ms: 1_000,
          provision_timeout_ms: 60_000
        )

      Process.sleep(20)

      assert {:error, :not_ready} = Orchestrator.exec(sandbox.id, "echo", ["hello"])
    end
  end

  describe "stop" do
    test "calls provider.stop, updates DB, and terminates", %{sandbox: sandbox} do
      MockProvider
      |> expect(:create, fn _env_spec -> {:ok, "msb-ref-stop"} end)
      |> expect(:metrics, fn "msb-ref-stop" -> {:ok, %{running: true}} end)
      |> stub(:metrics, fn "msb-ref-stop" -> {:ok, %{running: true}} end)
      |> expect(:stop, fn "msb-ref-stop" -> :ok end)

      {:ok, pid} =
        start_orchestrator(sandbox.id,
          provider: MockProvider,
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
  end

  describe "destroy" do
    test "calls provider.destroy, deletes DB record, and terminates", %{sandbox: sandbox} do
      MockProvider
      |> expect(:create, fn _env_spec -> {:ok, "msb-ref-destroy"} end)
      |> expect(:metrics, fn "msb-ref-destroy" -> {:ok, %{running: true}} end)
      |> stub(:metrics, fn "msb-ref-destroy" -> {:ok, %{running: true}} end)
      |> expect(:destroy, fn "msb-ref-destroy" -> :ok end)

      {:ok, pid} =
        start_orchestrator(sandbox.id,
          provider: MockProvider,
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
    GenServer.stop(pid, :normal, 1_000)
  catch
    :exit, {:noproc, _} -> :ok
    :exit, :noproc -> :ok
  end
end
