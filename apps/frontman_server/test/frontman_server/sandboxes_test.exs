defmodule FrontmanServer.SandboxesTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Sandboxes

  alias FrontmanServer.Repo
  alias FrontmanServer.Sandboxes
  alias FrontmanServer.Sandboxes.Sandbox

  setup do
    scope = user_scope_fixture()
    task = task_with_project_fixture(scope)
    %{scope: scope, task: task}
  end

  describe "provision_for_task/3" do
    test "creates a sandbox in provisioning status", %{scope: scope, task: task} do
      assert {:ok, sandbox} = Sandboxes.provision_for_task(scope, task, valid_env_spec())
      assert sandbox.status == :provisioning
      assert sandbox.task_id == task.id
      assert sandbox.project_id == task.project_id
      assert sandbox.env_spec == valid_env_spec()
    end

    test "returns invalid_env_spec when env_spec is missing", %{scope: scope, task: task} do
      assert {:error, {:invalid_env_spec, _reason}} =
               Sandboxes.provision_for_task(scope, task, nil)
    end

    test "returns invalid_env_spec when env_spec is not a map", %{scope: scope, task: task} do
      assert {:error, {:invalid_env_spec, :not_a_map}} =
               Sandboxes.provision_for_task(scope, task, "not a map")
    end

    test "returns {:error, {:invalid_env_spec, _}} when env_spec map is malformed", %{
      scope: scope,
      task: task
    } do
      assert {:error, {:invalid_env_spec, _reason}} =
               Sandboxes.provision_for_task(scope, task, %{"runtime" => "node20"})
    end

    test "returns {:error, :not_found} when task belongs to another user", %{task: task} do
      other_scope = user_scope_fixture()

      assert {:error, :not_found} =
               Sandboxes.provision_for_task(other_scope, task, valid_env_spec())
    end
  end

  describe "current_for_task/2" do
    test "returns nil when task has no active sandbox", %{scope: scope, task: task} do
      assert Sandboxes.current_for_task(scope, task) == nil
    end

    test "returns the sandbox after provisioning", %{scope: scope, task: task} do
      {:ok, sandbox} = Sandboxes.provision_for_task(scope, task, valid_env_spec())
      assert fetched = Sandboxes.current_for_task(scope, task)
      assert fetched.id == sandbox.id
    end

    test "returns nil after sandbox is suspended", %{scope: scope, task: task} do
      {:ok, sandbox} = Sandboxes.provision_for_task(scope, task, valid_env_spec())
      {:ok, _} = Sandboxes.suspend(scope, sandbox.id)
      assert Sandboxes.current_for_task(scope, task) == nil
    end

    test "returns {:error, :not_found} when task belongs to another user", %{
      scope: scope,
      task: task
    } do
      {:ok, _sandbox} = Sandboxes.provision_for_task(scope, task, valid_env_spec())
      other_scope = user_scope_fixture()
      assert {:error, :not_found} = Sandboxes.current_for_task(other_scope, task)
    end
  end

  describe "current_for_task/2 with task_id" do
    test "returns {:ok, sandbox} for active sandbox", %{scope: scope, task: task} do
      {:ok, sandbox} = Sandboxes.provision_for_task(scope, task, valid_env_spec())
      assert {:ok, fetched} = Sandboxes.current_for_task(scope, task.id)
      assert fetched.id == sandbox.id
    end

    test "returns {:error, :not_found} when task has no sandbox", %{scope: scope, task: task} do
      assert {:error, :not_found} = Sandboxes.current_for_task(scope, task.id)
    end
  end

  describe "get_sandbox/2" do
    test "returns sandbox for owner", %{scope: scope, task: task} do
      {:ok, sandbox} = Sandboxes.provision_for_task(scope, task, valid_env_spec())

      assert {:ok, fetched} = Sandboxes.get_sandbox(scope, sandbox.id)
      assert fetched.id == sandbox.id
    end

    test "returns {:error, :not_found} for another user's sandbox", %{scope: scope, task: task} do
      {:ok, sandbox} = Sandboxes.provision_for_task(scope, task, valid_env_spec())
      other_scope = user_scope_fixture()

      assert {:error, :not_found} = Sandboxes.get_sandbox(other_scope, sandbox.id)
    end
  end

  describe "list_sandboxes/1" do
    test "returns all sandboxes for the user", %{scope: scope, task: task} do
      {:ok, sandbox_a} = Sandboxes.provision_for_task(scope, task, valid_env_spec())
      other_task = task_with_project_fixture(scope)
      {:ok, sandbox_b} = Sandboxes.provision_for_task(scope, other_task, valid_env_spec())

      assert {:ok, sandboxes} = Sandboxes.list_sandboxes(scope)
      ids = Enum.map(sandboxes, & &1.id)

      assert sandbox_a.id in ids
      assert sandbox_b.id in ids
    end
  end

  describe "provision_and_start/3" do
    test "returns {:error, :task_id_required} when task_id is missing", %{scope: scope} do
      assert {:error, :task_id_required} =
               Sandboxes.provision_and_start(scope, valid_env_spec(), [])
    end
  end

  describe "suspend/2" do
    test "sets sandbox status to :stopped", %{scope: scope, task: task} do
      {:ok, sandbox} = Sandboxes.provision_for_task(scope, task, valid_env_spec())
      assert {:ok, suspended} = Sandboxes.suspend(scope, sandbox.id)
      assert suspended.status == :stopped
    end

    test "returns {:error, :not_found} for unknown sandbox_id", %{scope: scope} do
      assert {:error, :not_found} = Sandboxes.suspend(scope, Ecto.UUID.generate())
    end
  end

  describe "decommission/2" do
    test "deletes the sandbox row", %{scope: scope, task: task} do
      {:ok, sandbox} = Sandboxes.provision_for_task(scope, task, valid_env_spec())
      assert :ok = Sandboxes.decommission(scope, sandbox.id)
      assert Repo.get(Sandbox, sandbox.id) == nil
    end

    test "decommissioned sandbox no longer appears as current", %{scope: scope, task: task} do
      {:ok, sandbox} = Sandboxes.provision_for_task(scope, task, valid_env_spec())
      :ok = Sandboxes.decommission(scope, sandbox.id)
      assert Sandboxes.current_for_task(scope, task) == nil
    end

    test "returns {:error, :not_found} for unknown sandbox_id", %{scope: scope} do
      assert {:error, :not_found} = Sandboxes.decommission(scope, Ecto.UUID.generate())
    end
  end
end
