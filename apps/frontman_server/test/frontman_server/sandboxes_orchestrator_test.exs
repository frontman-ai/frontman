defmodule FrontmanServer.SandboxesOrchestratorTest do
  @moduledoc """
  Tests for Sandboxes context functions that interact with the Orchestrator.

  Not async — spawns GenServers that access the DB from separate processes.
  """
  use FrontmanServer.DataCase

  import Mox
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Sandboxes

  alias FrontmanServer.Sandbox.SandboxSchema
  alias FrontmanServer.Sandboxes

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    scope = user_scope_fixture()
    task = task_with_project_fixture(scope)

    on_exit(fn ->
      # Stop any Orchestrators that tests may have started
      DynamicSupervisor.which_children(FrontmanServer.Sandbox.DynamicSupervisor)
      |> Enum.each(fn {_, pid, _, _} ->
        if is_pid(pid) and Process.alive?(pid) do
          Process.exit(pid, :kill)
        end
      end)
    end)

    %{scope: scope, task: task}
  end

  describe "provision_and_start/3" do
    test "inserts sandbox and starts orchestrator", %{scope: scope, task: task} do
      MockProvider
      |> expect(:create, fn _env_spec -> {:ok, "msb-ref-ctx"} end)
      |> stub(:metrics, fn "msb-ref-ctx" -> {:ok, %{running: true}} end)

      assert {:ok, sandbox} =
               Sandboxes.provision_and_start(scope, valid_env_spec(),
                 task_id: task.id,
                 provider: MockProvider,
                 heartbeat_interval_ms: 10,
                 provision_timeout_ms: 5_000
               )

      assert sandbox.status == :provisioning
      assert sandbox.task_id == task.id

      assert_eventually(fn ->
        Repo.get!(SandboxSchema, sandbox.id).status == :running
      end)
    end

    test "marks sandbox as error when provider.create fails", %{scope: scope, task: task} do
      MockProvider
      |> expect(:create, fn _env_spec -> {:error, :image_not_found} end)

      assert {:error, :normal} =
               Sandboxes.provision_and_start(scope, valid_env_spec(),
                 task_id: task.id,
                 provider: MockProvider,
                 heartbeat_interval_ms: 10,
                 provision_timeout_ms: 5_000
               )
    end
  end

  describe "exec/5" do
    test "routes exec through orchestrator", %{scope: scope, task: task} do
      MockProvider
      |> expect(:create, fn _env_spec -> {:ok, "msb-ref-exec"} end)
      |> stub(:metrics, fn "msb-ref-exec" -> {:ok, %{running: true}} end)
      |> expect(:exec, fn "msb-ref-exec", "echo", ["hello"], [] ->
        {:ok, %{exit_code: 0, stdout: "hello\n", stderr: ""}}
      end)

      {:ok, sandbox} =
        Sandboxes.provision_and_start(scope, valid_env_spec(),
          task_id: task.id,
          provider: MockProvider,
          heartbeat_interval_ms: 10,
          provision_timeout_ms: 5_000
        )

      assert_eventually(fn ->
        Repo.get!(SandboxSchema, sandbox.id).status == :running
      end)

      assert {:ok, %{exit_code: 0, stdout: "hello\n"}} =
               Sandboxes.exec(scope, sandbox.id, "echo", ["hello"])
    end
  end

  describe "stop_sandbox/2" do
    test "routes stop through orchestrator", %{scope: scope, task: task} do
      MockProvider
      |> expect(:create, fn _env_spec -> {:ok, "msb-ref-stop"} end)
      |> stub(:metrics, fn "msb-ref-stop" -> {:ok, %{running: true}} end)
      |> expect(:stop, fn "msb-ref-stop" -> :ok end)

      {:ok, sandbox} =
        Sandboxes.provision_and_start(scope, valid_env_spec(),
          task_id: task.id,
          provider: MockProvider,
          heartbeat_interval_ms: 10,
          provision_timeout_ms: 5_000
        )

      assert_eventually(fn ->
        Repo.get!(SandboxSchema, sandbox.id).status == :running
      end)

      assert :ok = Sandboxes.stop_sandbox(scope, sandbox.id)
      assert Repo.get!(SandboxSchema, sandbox.id).status == :stopped
    end
  end

  describe "destroy_sandbox/2" do
    test "routes destroy through orchestrator", %{scope: scope, task: task} do
      MockProvider
      |> expect(:create, fn _env_spec -> {:ok, "msb-ref-destroy"} end)
      |> stub(:metrics, fn "msb-ref-destroy" -> {:ok, %{running: true}} end)
      |> expect(:destroy, fn "msb-ref-destroy" -> :ok end)

      {:ok, sandbox} =
        Sandboxes.provision_and_start(scope, valid_env_spec(),
          task_id: task.id,
          provider: MockProvider,
          heartbeat_interval_ms: 10,
          provision_timeout_ms: 5_000
        )

      assert_eventually(fn ->
        Repo.get!(SandboxSchema, sandbox.id).status == :running
      end)

      assert :ok = Sandboxes.destroy_sandbox(scope, sandbox.id)
      assert Repo.get(SandboxSchema, sandbox.id) == nil
    end
  end

  # --- Helpers ---

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
